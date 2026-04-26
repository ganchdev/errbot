# frozen_string_literal: true

require "net/http"

class CheckUptimeJob < ApplicationJob

  queue_as :default

  def perform
    Project.with_url.find_each do |project|
      check_project(project)
    end
  end

  private

  def check_project(project)
    uri = URI.parse(project.url)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    response_code = nil
    status = "down"

    begin
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 10) do |http|
        response = http.head(uri.request_uri.presence || "/")
        response_code = response.code.to_i
        status = response_code < 400 ? "up" : "down"
      end
    rescue StandardError
      status = "down"
    end

    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

    project.uptime_checks.create!(
      status: status,
      checked_at: Time.current,
      response_code: response_code,
      response_time_ms: elapsed_ms
    )
  end

end
