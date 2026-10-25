class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login
  before_action :set_current_actor

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_actor, :current_user

  private

  def current_user
    return if session[:user_id].blank?

    @current_user ||= User.includes(:actor).find_by(id: session[:user_id])
  end

  def current_actor
    actor = current_user&.actor
    actor if actor&.human? && actor.active?
  end

  def require_login
    return if current_actor

    session[:return_to] = request.fullpath if request.get? && request.path != login_path
    redirect_to login_path
  end

  def set_current_actor
    Current.actor = current_actor
  end

  def start_session_for(user)
    return_path = safe_return_path
    reset_session
    session[:user_id] = user.id
    user.update_column(:last_sign_in_at, Time.current)
    return_path
  end

  def safe_return_path
    url_from(session.delete(:return_to)) || root_path
  end

  def within_rate_limit?(scope, limit:, window:)
    key = "#{scope}-rate-limit:#{Digest::SHA256.hexdigest(request.remote_ip.to_s)}"
    count = Rails.cache.increment(key, 1, expires_in: window)
    count ||= begin
      Rails.cache.write(key, 1, expires_in: window)
      1
    end
    count <= limit
  end
end
