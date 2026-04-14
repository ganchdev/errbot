# frozen_string_literal: true

class DashboardController < ApplicationController

  def index
    @projects = Project.order(:name)
    @environments = Issue.where.not(
      last_environment: [nil, ""]
    ).distinct.order(:last_environment).pluck(:last_environment)
    @issues = filtered_issues
  end

  private

  def filtered_issues
    issues = Issue.includes(:project).order(last_seen_at: :desc, updated_at: :desc)
    issues = issues.where(project_id: params[:project_id]) if params[:project_id].present?
    issues = issues.where(status: params[:status]) if params[:status].present?
    issues = issues.where(last_environment: params[:environment]) if params[:environment].present?
    issues
  end

end
