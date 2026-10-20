require "json"
require "net/http"
require "openssl"
require "socket"
require "timeout"
require "uri"

class PageAgentProxy
  MAX_REQUEST_BYTES = 64.kilobytes
  MAX_RESPONSE_BYTES = 1.megabyte
  MAX_COMPLETION_TOKENS = 1_200
  OPEN_TIMEOUT_SECONDS = 2
  READ_TIMEOUT_SECONDS = 8

  Result = Struct.new(:status, :body, keyword_init: true)

  class ConfigurationError < StandardError; end
  class InvalidRequest < StandardError; end
  class UpstreamError < StandardError; end
  class ResponseTooLarge < StandardError; end

  def self.configured?
    new.configured?
  end

  def self.public_model
    new.public_model
  end

  def self.call(payload, http_client: Net::HTTP)
    new(http_client).call(payload)
  end

  def initialize(http_client = Net::HTTP)
    @http_client = http_client
  end

  def configured?
    configuration_ready?
  end

  def public_model
    model = ENV["PAGE_AGENT_MODEL"].to_s.strip
    model if allowed_models.include?(model)
  end

  def call(payload)
    raise ConfigurationError unless configuration_ready?
    raise InvalidRequest, "messages must be a non-empty array" unless valid_messages?(payload["messages"])
    raise InvalidRequest, "model is not allowed" unless allowed_models.include?(payload["model"])

    request_payload = payload.deep_dup
    request_payload["model"] = public_model
    request_payload["stream"] = false
    request_payload["max_tokens"] = [ request_payload["max_tokens"].to_i, MAX_COMPLETION_TOKENS ].reject(&:zero?).min || MAX_COMPLETION_TOKENS
    redact_payload!(request_payload)

    upstream_response = request_upstream(request_payload)
    Result.new(status: upstream_response.status, body: upstream_response.body)
  end

  private

  def configuration_ready?
    ENV["PAGE_AGENT_API_KEY"].present? &&
      ENV["PAGE_AGENT_BASE_URL"].present? &&
      public_model.present? &&
      upstream_uri.present?
  end

  def allowed_models
    ENV.fetch("PAGE_AGENT_ALLOWED_MODELS", "")
      .split(",")
      .map(&:strip)
      .reject(&:blank?)
  end

  def upstream_uri
    base_url = ENV["PAGE_AGENT_BASE_URL"].to_s.strip
    return if base_url.blank?

    uri = URI.parse(base_url)
    return unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?

    URI.join("#{uri.to_s.sub(%r{/+\z}, '')}/", "chat/completions")
  rescue URI::InvalidURIError
    nil
  end

  def valid_messages?(messages)
    messages.is_a?(Array) &&
      messages.any? &&
      messages.length <= 40 &&
      messages.all? do |message|
        message.is_a?(Hash) &&
          %w[system user assistant tool].include?(message["role"]) &&
          (message["content"].nil? || message["content"].is_a?(String))
      end
  end

  def redact_payload!(payload)
    private_values = Incident.where.not(requested_by: [ nil, "" ]).distinct.pluck(:requested_by)
      .sort_by { |value| -value.length }
    redact_value!(payload, private_values)
  end

  def redact_value!(value, private_values)
    case value
    when Hash
      value.each_value { |nested| redact_value!(nested, private_values) }
    when Array
      value.each { |nested| redact_value!(nested, private_values) }
    when String
      private_values.each do |private_value|
        value.gsub!(/#{Regexp.escape(private_value)}/i, "[REDACTED_CALLER]")
      end
      value.gsub!(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i, "[REDACTED_EMAIL]")
      value.gsub!(/(?<!\w)\+?\d[\d\s().-]{7,}\d(?!\w)/, "[REDACTED_PHONE]")
    end
  end

  def request_upstream(payload)
    uri = upstream_uri
    raise ConfigurationError unless uri

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV.fetch('PAGE_AGENT_API_KEY')}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request.body = JSON.generate(payload)

    response_body = +""
    status = nil
    @http_client.start(
      uri.host,
      uri.port,
      use_ssl: true,
      verify_mode: OpenSSL::SSL::VERIFY_PEER,
      open_timeout: OPEN_TIMEOUT_SECONDS,
      read_timeout: READ_TIMEOUT_SECONDS,
      write_timeout: OPEN_TIMEOUT_SECONDS
    ) do |http|
      http.request(request) do |response|
        status = response.code.to_i
        next unless status.between?(200, 299)

        response.read_body do |chunk|
          response_body << chunk
          raise ResponseTooLarge if response_body.bytesize > MAX_RESPONSE_BYTES
        end
      end
    end

    raise UpstreamError unless status&.between?(200, 299)

    parsed_response = JSON.parse(response_body)
    raise UpstreamError unless parsed_response.is_a?(Hash)

    Result.new(status: status, body: parsed_response)
  rescue JSON::ParserError
    raise UpstreamError
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => error
    Rails.logger.warn("Page Agent provider request failed (#{error.class}).")
    raise UpstreamError
  end
end
