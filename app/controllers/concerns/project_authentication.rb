# frozen_string_literal: true

module ProjectAuthentication

  extend ActiveSupport::Concern

  AUTH_HEADER_KEY_PATTERN = /sentry_key=([^,\s]+)/i

  included do
    before_action :authenticate_project
  end

  private

  def authenticate_project
    token = bearer_token || sentry_key
    return render_unauthorized unless token.present?

    scope = Project.where(ingest_token: token)
    if sentry_action?
      project_identifier = params[:project_id]
      scope = scope.where(id: project_identifier).or(scope.where(slug: project_identifier))
    end

    @project = scope.first
    return if @project.present?

    render_unauthorized
  end

  def render_unauthorized
    render json: { error: credentials_present? ? "Invalid token" : "Missing token" },
           status: :unauthorized
  end

  def bearer_token
    authorization = request.headers["Authorization"].to_s
    scheme, token = authorization.split(/\s+/, 2)
    token if scheme&.casecmp("Bearer")&.zero?
  end

  def sentry_key
    request.params[:sentry_key].presence ||
      request.headers["X-Sentry-Auth"].to_s[AUTH_HEADER_KEY_PATTERN, 1].presence
  end

  def credentials_present?
    bearer_token.present? || sentry_key.present?
  end

  def sentry_action?
    action_name.in?(%w[create_sentry_store create_sentry_envelope])
  end

end
