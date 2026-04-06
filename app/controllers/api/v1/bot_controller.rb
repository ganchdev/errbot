# frozen_string_literal: true

module Api
  module V1
    class BotController < ActionController::Base

      skip_before_action :authenticate_api_token, only: [:verify]

      def verify
        code = params[:code]
        chat_id = params[:chat_id]

        bot_user = BotUser.fetch_by_code_and_chat_id!(code, chat_id)

        if bot_user
          user = bot_user.authorized_user

          render json: {
            success: true,
            user: {
              id: user.id,
              email: user.email_address
            },
            token: bot_user.token
          }
        else
          render json: { success: false, error: "Invalid or expired code" }, status: :unauthorized
        end
      end

      private

      def authenticate_api_token
        token = request.headers["Authorization"]&.gsub("Bearer ", "")

        if token.blank?
          return render json: { error: "Missing token" }, status: :unauthorized
        end

        bot_user = BotUser.find_by(api_token: token)

        if bot_user.nil?
          return render json: { error: "Invalid token" }, status: :unauthorized
        end

        Current.user = bot_user.authorized_user.user
      end

    end
  end
end
