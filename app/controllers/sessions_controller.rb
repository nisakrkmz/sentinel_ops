class SessionsController < ApplicationController
  skip_before_action :require_login
  skip_before_action :set_current_actor

  RATE_LIMIT = 10
  RATE_WINDOW = 1.minute

  def new
    return redirect_to root_path if current_actor

    @password_configured = password_configured?
  end

  def create
    return redirect_to root_path if current_actor

    unless within_rate_limit?
      flash.now[:alert] = "Çok fazla giriş denemesi. Bir dakika sonra tekrar deneyin."
      @password_configured = password_configured?
      return render :new, status: :too_many_requests
    end

    unless valid_credentials?
      flash.now[:alert] = "Kullanıcı adı veya şifre doğrulanamadı."
      @password_configured = password_configured?
      return render :new, status: :unprocessable_entity
    end

    return_path = safe_return_path
    reset_session
    actor = Actor.find_or_create_by!(kind: :human, name: "Nisa")
    session[:actor_id] = actor.id

    redirect_to return_path, notice: "Hoş geldin, Nisa."
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Güvenli çıkış yapıldı."
  end

  private

  def password_configured?
    ENV["NISA_PASSWORD"].to_s.length >= 12
  end

  def valid_credentials?
    expected_password = ENV["NISA_PASSWORD"].to_s
    submitted_password = params[:password].to_s
    submitted_username = params[:username].to_s.strip.downcase
    return false unless password_configured?

    secure_digest_compare(submitted_username, "nisa") &&
      secure_digest_compare(submitted_password, expected_password)
  end

  def secure_digest_compare(left, right)
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(left),
      Digest::SHA256.hexdigest(right)
    )
  end

  def within_rate_limit?
    key = "login-rate-limit:#{Digest::SHA256.hexdigest(request.remote_ip.to_s)}"
    count = Rails.cache.increment(key, 1, expires_in: RATE_WINDOW)
    count ||= begin
      Rails.cache.write(key, 1, expires_in: RATE_WINDOW)
      1
    end
    count <= RATE_LIMIT
  end

  def safe_return_path
    url_from(session.delete(:return_to)) || root_path
  end
end
