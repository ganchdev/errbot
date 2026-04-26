# frozen_string_literal: true

class UptimeMonitorController < ApplicationController

  def index
    projects = Project.with_url.order(:name)
    latest_check_ids = UptimeCheck.select("MAX(id)").where(project: projects).group(:project_id)
    latest_checks = UptimeCheck.where(id: latest_check_ids).index_by(&:project_id)
    @rows = projects.map { |p| [p, latest_checks[p.id]] }
  end

end
