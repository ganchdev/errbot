# frozen_string_literal: true

class CreateEventJob < ApplicationJob

  queue_as :default

  # Normalizes and persists an incoming exception event for a project.
  #
  # @param project_id [Integer]
  # @param event_payload [Hash, ActionController::Parameters]
  # @param raw_json [String]
  # @return [Hash]
  def perform(project_id:, event_payload:, raw_json:)
    project = Project.find(project_id)
    normalized_event = Ingestion::EventNormalizer.call(event_payload, raw_json: raw_json)
    enqueue_notification = false

    result = Event.transaction do
      fingerprint_hash = Ingestion::FingerprintBuilder.call(normalized_event)
      issue, issue_state = find_or_create_issue(project, normalized_event, fingerprint_hash)
      event = create_event(project, issue, normalized_event, issue_state[:notification_reason])

      create_event_tags(event, normalized_event)
      update_issue(issue, event, normalized_event, issue_state)
      enqueue_notification = event.notification_state == "pending"

      {
        issue_id: issue.id,
        event_id: event.id,
        new_issue: issue_state[:new_issue],
        fingerprint_hash: fingerprint_hash
      }
    end

    NotifyTelegramJob.perform_later(result[:event_id]) if enqueue_notification

    result
  end

  private

  # Finds an existing grouped issue or creates a new one for the event fingerprint,
  # then derives the notification decision from the issue's pre-update state.
  #
  # @param project [Project]
  # @param normalized_event [Ingestion::EventNormalizer]
  # @param fingerprint_hash [String]
  # @return [Array<(Issue, Hash)>]
  def find_or_create_issue(project, normalized_event, fingerprint_hash)
    issue = Issue.create_or_find_by!(project: project, fingerprint_hash: fingerprint_hash) do |issue|
      issue.title = normalized_event.title
      issue.platform = normalized_event.platform
      issue.level = normalized_event.level
      issue.first_seen_at = normalized_event.occurred_at
      issue.last_seen_at = normalized_event.occurred_at
      issue.last_environment = normalized_event.environment
      issue.last_release = normalized_event.release
      issue.occurrences_count = 0
      issue.status = "open"
    end

    [
      issue,
      {
        new_issue: issue.previously_new_record?,
        previous_status: issue.previously_new_record? ? nil : issue.status,
        notification_reason: notification_reason_for(issue)
      }
    ]
  end

  # Creates the concrete event record linked to the grouped issue.
  #
  # @param project [Project]
  # @param issue [Issue]
  # @param normalized_event [Ingestion::EventNormalizer]
  # @param notification_reason [String, nil]
  # @return [Event]
  def create_event(project, issue, normalized_event, notification_reason)
    Event.create!(
      project: project,
      issue: issue,
      event_uuid: normalized_event.event_uuid,
      occurred_at: normalized_event.occurred_at,
      level: normalized_event.level,
      environment: normalized_event.environment,
      release: normalized_event.release,
      server_name: normalized_event.server_name,
      transaction_name: normalized_event.transaction_name,
      exception_type: normalized_event.exception_type,
      exception_message: normalized_event.exception_message,
      handled: normalized_event.handled,
      raw_json: normalized_event.raw_json,
      notification_reason: notification_reason,
      notification_state: notification_reason.present? ? "pending" : "skipped"
    )
  end

  # Persists the normalized event tags for later filtering and display.
  #
  # @param event [Event]
  # @param normalized_event [Ingestion::EventNormalizer]
  # @return [void]
  def create_event_tags(event, normalized_event)
    normalized_event.tags.each do |key, value|
      event.event_tags.create!(key: key.to_s, value: value.to_s)
    end
  end

  # Refreshes issue aggregates from the latest occurrence.
  #
  # @param issue [Issue]
  # @param event [Event]
  # @param normalized_event [Ingestion::EventNormalizer]
  # @param issue_state [Hash]
  # @return [void]
  def update_issue(issue, event, normalized_event, issue_state)
    issue.update!(
      occurrences_count: issue.events.count,
      title: normalized_event.title.presence || issue.title,
      level: normalized_event.level.presence || issue.level,
      platform: normalized_event.platform.presence || issue.platform,
      last_seen_at: event.occurred_at,
      last_environment: event.environment,
      last_release: event.release,
      status: reopened_status(issue, issue_state)
    )
  end

  # Determines whether the event should notify because it is new or reappearing.
  #
  # @param issue [Issue]
  # @return [String, nil]
  def notification_reason_for(issue)
    return "new_issue" if issue.previously_new_record?
    return "reappeared" if issue.status == "resolved"

    nil
  end

  # Reopens resolved issues that have just reappeared; otherwise preserves status.
  #
  # @param issue [Issue]
  # @param issue_state [Hash]
  # @return [String]
  def reopened_status(issue, issue_state)
    return "open" if issue_state[:notification_reason] == "reappeared"

    issue.status
  end

end
