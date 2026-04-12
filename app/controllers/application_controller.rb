# frozen_string_literal: true

class ApplicationController < ActionController::Base

  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotDestroyed, with: :handle_record_not_destroyed_error
  rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid_error

  private

  def handle_record_not_destroyed_error(exception)
    redirect_to request.referer || root_path, alert: exception.record.errors.full_messages.to_sentence
  end

  def handle_record_invalid_error(exception)
    redirect_to request.referer || root_path, alert: exception.record.errors.full_messages.to_sentence
  end

  def require_admin
    return if Current.user&.admin?

    redirect_to root_path, alert: "Administrator access required."
  end

end
