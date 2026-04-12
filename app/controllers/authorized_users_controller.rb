# frozen_string_literal: true

class AuthorizedUsersController < ApplicationController

  before_action :require_admin
  before_action :set_authorized_user, only: [:edit, :update, :destroy]

  def index
    @authorized_users = AuthorizedUser.includes(:user).order(:email_address)
    @authorized_user = AuthorizedUser.new
  end

  def new
    @authorized_user = AuthorizedUser.new
  end

  def create
    @authorized_user = AuthorizedUser.new(authorized_user_params)

    if @authorized_user.save
      redirect_to authorized_users_path, notice: "Authorized user added."
    else
      @authorized_users = AuthorizedUser.includes(:user).order(:email_address)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @authorized_user.update(authorized_user_params)
      redirect_to authorized_users_path, notice: "Authorized user updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    email_address = @authorized_user.email_address
    @authorized_user.destroy!
    redirect_to authorized_users_path, notice: "#{email_address} removed."
  end

  private

  def set_authorized_user
    @authorized_user = AuthorizedUser.find(params[:id])
  end

  def authorized_user_params
    params.require(:authorized_user).permit(:email_address)
  end

end
