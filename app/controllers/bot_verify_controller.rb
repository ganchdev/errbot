# frozen_string_literal: true

class BotVerifyController < ApplicationController

  def show
    @chat_id = params[:chat_id]
    @email = params[:email].to_s.downcase

    return redirect_to "/auth", alert: "Missing chat_id or email" if @chat_id.blank? || @email.blank?

    @authorized_user = AuthorizedUser.find_by(email_address: @email)

    if @authorized_user.nil?
      @error = "Email not found in authorized users"
      return
    end

    unless Current.user&.email_address.to_s.downcase == @authorized_user.email_address.downcase
      @error = "Signed-in Google account does not match the requested email"
      return
    end

    bot_user = BotUser.begin_verification!(chat_id: @chat_id, authorized_user: @authorized_user)
    @code = bot_user.code
  end

end
