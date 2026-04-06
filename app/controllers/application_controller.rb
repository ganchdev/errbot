# frozen_string_literal: true

class ApplicationController < ActionController::Base

  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotDestroyed, with: :handle_record_not_destroyed_error

  private

  def handle_record_not_destroyed_error(exception)
    redirect_to request.referer || root_path, alert: exception.record.errors.full_messages.to_sentence
  end

end
