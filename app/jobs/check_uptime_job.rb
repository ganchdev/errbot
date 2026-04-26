# frozen_string_literal: true

require "net/http"

class CheckUptimeJob < ApplicationJob

  queue_as :default

  # Runs uptime checks for every project with a configured monitoring URL.
  #
  # @return [void]
  def perform
    Project.with_url.find_each do |project|
      check_project(project)
    end
  end

  private

  # Executes the HTTP and SSL checks for a single project, persists the result,
  # and enqueues any state-transition alerts.
  #
  # @param project [Project]
  # @return [void]
  def check_project(project)
    previous_check = project.uptime_checks.order(checked_at: :desc, id: :desc).first
    uri = URI.parse(project.url)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ssl_attributes = Uptime::SslInspector.call(uri)

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

    uptime_check = project.uptime_checks.create!(
      status: status,
      checked_at: Time.current,
      response_code: response_code,
      response_time_ms: elapsed_ms,
      **ssl_attributes
    )

    enqueue_project_down_alert(previous_check, uptime_check) if status == "down"
    enqueue_ssl_certificate_warning(previous_check, uptime_check) if uptime_check.ssl_alert?
  end

  # Enqueues a project-down alert only when the project has newly transitioned
  # into a down state.
  #
  # @param previous_check [UptimeCheck, nil]
  # @param uptime_check [UptimeCheck]
  # @return [void]
  def enqueue_project_down_alert(previous_check, uptime_check)
    return if previous_check&.status == "down"

    TelegramMessage.enqueue_for!(source: uptime_check, message_type: "project_down")
  end

  # Enqueues an SSL warning only when the certificate has newly entered an
  # alerting state, avoiding repeated warnings on every check.
  #
  # @param previous_check [UptimeCheck, nil]
  # @param uptime_check [UptimeCheck]
  # @return [void]
  def enqueue_ssl_certificate_warning(previous_check, uptime_check)
    return if previous_check&.ssl_alert?

    TelegramMessage.enqueue_for!(source: uptime_check, message_type: "ssl_certificate_warning")
  end

end
