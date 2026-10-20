class PageAgentProxyController < ApplicationController
  RATE_LIMIT = 10
  RATE_WINDOW = 1.minute

  def create
    return render_error("provider_not_configured", :service_unavailable) unless PageAgentProxy.configured?
    return render_error("same_origin_request_required", :forbidden) unless same_origin_request?
    return render_error("json_content_type_required", :unsupported_media_type) unless request.media_type == "application/json"
    return render_error("request_too_large", :content_too_large) if request.content_length.to_i > PageAgentProxy::MAX_REQUEST_BYTES
    return render_rate_limit unless within_rate_limit?

    raw_body = request.raw_post
    return render_error("request_too_large", :content_too_large) if raw_body.bytesize > PageAgentProxy::MAX_REQUEST_BYTES

    payload = JSON.parse(raw_body)
    return render_error("invalid_request", :bad_request) unless payload.is_a?(Hash)

    result = PageAgentProxy.call(payload)
    render json: result.body, status: result.status
  rescue JSON::ParserError
    render_error("invalid_json", :bad_request)
  rescue PageAgentProxy::InvalidRequest
    render_error("invalid_request", :bad_request)
  rescue PageAgentProxy::ConfigurationError
    render_error("provider_not_configured", :service_unavailable)
  rescue PageAgentProxy::ResponseTooLarge, PageAgentProxy::UpstreamError
    render_error("provider_unavailable", :bad_gateway)
  end

  private

  def same_origin_request?
    origin = request.headers["Origin"]
    origin.present? && origin == request.base_url
  end

  def within_rate_limit?
    key = "page-agent-proxy:#{Digest::SHA256.hexdigest(request.remote_ip.to_s)}"
    count = Rails.cache.increment(key, 1, expires_in: RATE_WINDOW)
    count ||= begin
      Rails.cache.write(key, 1, expires_in: RATE_WINDOW)
      1
    end
    count <= RATE_LIMIT
  end

  def render_rate_limit
    response.set_header("Retry-After", RATE_WINDOW.to_i.to_s)
    render_error("rate_limit_exceeded", :too_many_requests)
  end

  def render_error(code, status)
    render json: { error: { code: code, message: "Page Agent request could not be completed." } }, status: status
  end
end
