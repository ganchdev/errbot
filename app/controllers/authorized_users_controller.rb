# frozen_string_literal: true

class AuthorizedUsersController < ApplicationController

  before_action :require_admin

  def index
    @authorized_users = AuthorizedUser.all
  end

  private

  def require_admin
    redirect_to root_path unless Current.user&.admin?
  end

end
