require "net/http"
require "json"
require "uri"

module Jev
  # Minimal HTTPS client for TypeSafe's System One endpoint.
  # Contract (docs.typesafe.ai/api, checked 2026-10-25):
  #   POST /v1/systemone { model, state, questions } -> { model, answers, usage }
  #   question types: choice (criteria hash), score (criteria array), noul (optional true/false criteria)
  class Client
    DEFAULT_ENDPOINT = "https://api.typesafe.ai/v1/systemone".freeze
    DEFAULT_MODEL = "jev-latest".freeze
    TOTAL_TIMEOUT_SECONDS = 8
    MAX_ATTEMPTS = 2

    class Error < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    attr_reader :model

    def self.from_env
      new(
        api_key: ENV["JEV_API_KEY"],
        model: ENV["JEV_MODEL"].presence || DEFAULT_MODEL,
        endpoint: ENV["JEV_BASE_URL"].presence || DEFAULT_ENDPOINT
      )
    end

    def initialize(api_key:, model: DEFAULT_MODEL, endpoint: DEFAULT_ENDPOINT)
      @api_key = api_key
      @model = model
      @endpoint = endpoint
    end

    def configured?
      @api_key.present? && @model.present? && @endpoint.present?
    end

    # Returns [answers_hash, served_model]
    def ask(state:, questions:)
      raise Error.new("jev_not_configured", "Jev is not configured") unless configured?

      uri = URI.parse(@endpoint)
      raise Error.new("invalid_jev_configuration", "Jev endpoint must use HTTPS") unless uri.is_a?(URI::HTTPS) && uri.host.present?

      deadline = monotonic_time + TOTAL_TIMEOUT_SECONDS
      attempts = 0
      begin
        attempts += 1
        body = post(uri, { model: @model, state: state, questions: questions }, deadline)
        parsed = JSON.parse(body)
        answers = parsed["answers"]
        raise Error.new("invalid_jev_output", "Jev response has no answers") unless answers.is_a?(Hash)

        missing = questions.keys.map(&:to_s) - answers.keys
        raise Error.new("invalid_jev_output", "Jev response is missing answers: #{missing.join(', ')}") if missing.any?

        [ answers, parsed["model"].presence || @model ]
      rescue Error => error
        raise error unless error.code == "jev_http_retryable" && attempts < MAX_ATTEMPTS && monotonic_time < deadline

        retry
      rescue JSON::ParserError
        raise Error.new("invalid_jev_output", "Jev returned invalid JSON")
      rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError, EOFError, IOError
        raise Error.new("jev_timeout", "Jev request failed or exceeded the 8 second budget") if attempts >= MAX_ATTEMPTS || monotonic_time >= deadline

        retry
      end
    rescue URI::InvalidURIError
      raise Error.new("invalid_jev_configuration", "Jev endpoint URL is invalid")
    end

    private

    def post(uri, payload, deadline)
      remaining = deadline - monotonic_time
      raise Error.new("jev_timeout", "Jev request exceeded the 8 second budget") if remaining <= 0

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
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
      code = [ 408, 429 ].include?(status) || status.between?(500, 599) ? "jev_http_retryable" : "jev_http_error"
      raise Error.new(code, "Jev returned HTTP #{response.code}")
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
