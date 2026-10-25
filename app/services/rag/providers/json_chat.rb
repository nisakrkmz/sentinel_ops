require "net/http"
require "json"
require "uri"

module Rag
  module Providers
    class JsonChat
      TOTAL_TIMEOUT_SECONDS = 8
      MAX_ATTEMPTS = 2

      attr_reader :provider, :model

      def initialize(provider:, api_key:, model:, endpoint:, reasoning_effort: nil)
        @provider = provider
        @api_key = api_key
        @model = model
        @endpoint = endpoint
        @reasoning_effort = reasoning_effort.presence
      end

      def configured?
        @api_key.present? && @model.present? && @endpoint.present?
      end

      def call(schema_name:, schema:, system_prompt:, user_content:, validator: nil)
        raise ProviderError.new("json_provider_not_configured", "JSON chat provider is not configured") unless configured?

        uri = URI.parse(@endpoint)
        raise ProviderError.new("invalid_json_provider_configuration", "JSON chat endpoint must use HTTPS") unless uri.is_a?(URI::HTTPS) && uri.host.present?

        deadline = monotonic_time + TOTAL_TIMEOUT_SECONDS
        attempts = 0
        messages = [
          { role: "system", content: "#{system_prompt}\nReturn only output matching this schema: #{JSON.generate(schema)}" },
          { role: "user", content: user_content }
        ]
        begin
          attempts += 1
          body = request(uri, messages, schema_name, schema, deadline)
          content = JSON.parse(body).dig("choices", 0, "message", "content")
          raise ProviderError.new("invalid_json_provider_output", "JSON chat provider returned no content") unless content.is_a?(String)

          output = JSON.parse(content)
          validation_error = validator&.call(output)
          raise ProviderError.new("invalid_json_provider_output", "JSON chat output failed schema validation: #{validation_error}") if validation_error.present?

          output
        rescue ProviderError => error
          retryable = %w[invalid_json_provider_output json_provider_retryable json_provider_http_error].include?(error.code)
          raise error unless retryable && attempts < MAX_ATTEMPTS && monotonic_time < deadline

          messages << { role: "user", content: "The previous response could not be used. Retry once and return only an object matching the same schema." }
          retry
        rescue JSON::ParserError
          raise ProviderError.new("invalid_json_provider_output", "JSON chat provider returned invalid JSON") if attempts >= MAX_ATTEMPTS || monotonic_time >= deadline

          messages << { role: "user", content: "Retry once and return valid JSON matching the same schema." }
          retry
        rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError, EOFError, IOError
          raise ProviderError.new("json_provider_timeout", "JSON chat request failed or exceeded the 8 second budget") if attempts >= MAX_ATTEMPTS || monotonic_time >= deadline

          retry
        end
      rescue URI::InvalidURIError
        raise ProviderError.new("invalid_json_provider_configuration", "JSON chat endpoint URL is invalid")
      end

      private

      def request(uri, messages, schema_name, schema, deadline)
        remaining = deadline - monotonic_time
        raise ProviderError.new("json_provider_timeout", "JSON chat request exceeded the 8 second budget") if remaining <= 0

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(
          model: @model,
          temperature: 0,
          **(@reasoning_effort ? { reasoning_effort: @reasoning_effort } : {}),
          response_format: {
            type: "json_schema",
            json_schema: { name: schema_name, strict: true, schema: schema }
          },
          messages: messages
        )
        response = Timeout.timeout(remaining) do
          Net::HTTP.start(
            uri.host,
            uri.port,
            use_ssl: true,
            open_timeout: remaining,
            read_timeout: remaining,
            write_timeout: remaining
          ) { |http| http.request(request) }
        end
        return response.body if response.code.to_i.between?(200, 299)

        status = response.code.to_i
        code = [ 408, 429 ].include?(status) || status.between?(500, 599) ? "json_provider_retryable" : "json_provider_http_error"
        raise ProviderError.new(code, "JSON chat provider returned HTTP #{response.code}")
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
