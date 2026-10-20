require "net/http"
require "json"
require "uri"

module Rag
  module Providers
    class Embedding
      TOTAL_TIMEOUT_SECONDS = 8
      MAX_ATTEMPTS = 2

      attr_reader :provider, :model

      def initialize(provider:, api_key:, model:, endpoint:)
        @provider = provider
        @api_key = api_key
        @model = model
        @endpoint = endpoint
      end

      def configured?
        @api_key.present? && @model.present? && @endpoint.present?
      end

      def embed(text)
        embed_many([ text ]).fetch(0)
      end

      def embed_many(texts)
        raise ProviderError.new("embedding_provider_not_configured", "Embedding provider is not configured") unless configured?
        raise ProviderError.new("invalid_embedding_input", "Embedding input must contain text") unless texts.is_a?(Array) && texts.any? && texts.all? { |text| text.is_a?(String) && text.present? }

        uri = URI.parse(@endpoint)
        raise ProviderError.new("invalid_embedding_configuration", "Embedding endpoint must use HTTPS") unless uri.is_a?(URI::HTTPS) && uri.host.present?

        deadline = monotonic_time + TOTAL_TIMEOUT_SECONDS
        attempts = 0
        begin
          attempts += 1
          response = post(uri, { model: @model, input: texts }, deadline)
          data = JSON.parse(response).fetch("data")
          vectors = data.sort_by { |item| item.fetch("index") }.map { |item| item.fetch("embedding") }
          valid = vectors.length == texts.length && vectors.all? do |vector|
            vector.is_a?(Array) && vector.any? && vector.all? { |value| value.is_a?(Numeric) && value.finite? }
          end
          unless valid
            raise ProviderError.new("invalid_embedding_output", "Embedding provider returned an invalid vector")
          end

          vectors.map { |vector| vector.map(&:to_f) }
        rescue ProviderError => error
          raise error unless retryable?(error) && attempts < MAX_ATTEMPTS && monotonic_time < deadline

          retry
        rescue JSON::ParserError
          raise ProviderError.new("invalid_embedding_output", "Embedding provider returned invalid JSON") if attempts >= MAX_ATTEMPTS || monotonic_time >= deadline

          retry
        rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError, EOFError, IOError
          raise ProviderError.new("embedding_timeout", "Embedding request failed or exceeded the 8 second budget") if attempts >= MAX_ATTEMPTS || monotonic_time >= deadline

          retry
        end
      rescue URI::InvalidURIError
        raise ProviderError.new("invalid_embedding_configuration", "Embedding endpoint URL is invalid")
      end

      private

      def post(uri, body, deadline)
        remaining = deadline - monotonic_time
        raise ProviderError.new("embedding_timeout", "Embedding request exceeded the 8 second budget") if remaining <= 0

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)
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
        code = [ 408, 429 ].include?(status) || status.between?(500, 599) ? "embedding_provider_retryable" : "embedding_provider_http_error"
        raise ProviderError.new(code, "Embedding provider returned HTTP #{response.code}")
      end

      def retryable?(error)
        %w[embedding_provider_retryable].include?(error.code)
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
