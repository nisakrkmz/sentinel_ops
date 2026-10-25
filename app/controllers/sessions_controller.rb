class SessionsController < ApplicationController
  skip_before_action :require_login
  skip_before_action :set_current_actor

  RATE_LIMIT = 10
  RATE_WINDOW = 1.minute

  def new
    redirect_to root_path if current_actor
  end

  def create
    return redirect_to root_path if current_actor

    unless within_rate_limit?("login", limit: RATE_LIMIT, window: RATE_WINDOW)
      flash.now[:alert] = "Çok fazla giriş denemesi. Bir dakika sonra tekrar deneyin."
      return render :new, status: :too_many_requests
    end

    user = User.authenticate(params[:email], params[:password])
    unless user&.actor&.active?
      flash.now[:alert] = "E-posta veya şifre doğrulanamadı."
      return render :new, status: :unprocessable_entity
    end

    redirect_to start_session_for(user), notice: "Hoş geldin, #{user.name}."
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Güvenli çıkış yapıldı."
  end
end
