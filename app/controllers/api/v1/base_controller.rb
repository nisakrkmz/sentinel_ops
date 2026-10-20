module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_agent!
      before_action :enforce_rate_limit!

      rescue_from ActionDispatch::Http::Parameters::ParseError do
        render_error(
          code: "invalid_json",
          message: "The request body is not valid JSON.",
          status: :bad_request
        )
      end

      private

      attr_reader :api_token

      def authenticate_agent!
        match = request.authorization.to_s.match(/\ABearer\s+(\S+)\z/i)
        @api_token = ApiToken.authenticate(match[1]) if match
        if @api_token
          Current.actor = @api_token.actor
          return
        end

        render_error(
          code: "unauthorized",
          message: "A valid bearer token is required.",
          status: :unauthorized
        )
      rescue ArgumentError
        render_error(
          code: "authentication_not_configured",
          message: "API token authentication is not configured.",
          status: :service_unavailable,
          retryable: true
        )
      end

      def require_scope!(scope)
        return true if api_token.allows?(scope)

        render_error(
          code: "insufficient_scope",
          message: "The token does not grant the required scope.",
          status: :forbidden,
          field_errors: { scope: [ scope ] }
        )
        false
      end

      def render_error(code:, message:, status:, retryable: false, field_errors: {})
        render json: {
          code: code,
          message: message,
          retryable: retryable,
          field_errors: field_errors
        }, status: status
      end

      def current_actor
        api_token.actor
      end

      def rate_limit_settings
        @rate_limit_settings ||= YAML.safe_load_file(
          Rails.root.join("config/api.yml"),
          aliases: true
        ).fetch(Rails.env).deep_stringify_keys
      end

      def enforce_rate_limit!
        return unless api_token

        limit = rate_limit_settings.fetch("requests")
        period = rate_limit_settings.fetch("period_seconds")
        now = Time.current.to_i
        window_start = now - (now % period)
        key = "api-v1-rate-limit:#{api_token.id}:#{window_start}"
        Rails.cache.fetch(key, expires_in: period.seconds) { 0 }
        count = Rails.cache.increment(key, 1)
        reset_at = window_start + period
        headers["X-RateLimit-Limit"] = limit.to_s
        headers["X-RateLimit-Remaining"] = [ limit - count, 0 ].max.to_s
        headers["X-RateLimit-Reset"] = reset_at.to_s
        return if count <= limit

        render_error(
          code: "rate_limit_exceeded",
          message: "The request rate limit has been exceeded.",
          status: :too_many_requests,
          retryable: true
        )
      end
    end
  end
end
