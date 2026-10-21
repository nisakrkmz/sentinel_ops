class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login
  before_action :set_current_actor

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_actor

  private

  def current_actor
    return if session[:actor_id].blank?

    @current_actor ||= Actor.find_by(id: session[:actor_id], kind: :human, active: true)
  end

  def require_login
    return if current_actor

    session[:return_to] = request.fullpath if request.get? && request.path != login_path
    redirect_to login_path
  end

  def set_current_actor
    Current.actor = current_actor
  end
end
