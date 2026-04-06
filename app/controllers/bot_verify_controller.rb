# frozen_string_literal: true

class BotVerifyController < ApplicationController

  def show
    @chat_id = params[:chat_id]
    @email = params[:email]

    return redirect_to "/auth", alert: "Missing chat_id or email" if @chat_id.blank? || @email.blank?

    @authorized_user = AuthorizedUser.find_by(email_address: @email)

    if @authorized_user.nil?
      @error = "Email not found in authorized users"
      return
    end

    bot_user = BotUser.find_or_initialize_by(chat_id: @chat_id)
    bot_user.authorized_user = @authorized_user
    bot_user.save!

    @code = bot_user.code
  end

end
