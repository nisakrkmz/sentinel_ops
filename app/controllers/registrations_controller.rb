class RegistrationsController < ApplicationController
  skip_before_action :require_login
  skip_before_action :set_current_actor

  RATE_LIMIT = 5
  RATE_WINDOW = 10.minutes

  def new
    return redirect_to root_path if current_actor

    @user = User.new
  end

  def create
    return redirect_to root_path if current_actor

    @user = User.new(params.require(:user).permit(:name, :email, :password, :password_confirmation))
    unless within_rate_limit?("signup", limit: RATE_LIMIT, window: RATE_WINDOW)
      flash.now[:alert] = "Çok fazla kayıt denemesi. Biraz sonra tekrar deneyin."
      return render :new, status: :too_many_requests
    end

    if @user.save
      redirect_to start_session_for(@user), notice: "Hesabın oluşturuldu. Hoş geldin, #{@user.name}."
    else
      render :new, status: :unprocessable_entity
    end
  end
end
