# frozen_string_literal: true

require "test_helper"

class CreateEventJobTest < ActiveJob::TestCase

  # rubocop:disable Metrics/BlockLength

  setup do
    @project = projects(:one)
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "creates event and issue from payload" do
    event_payload = {
      event_id: "job-evt-001",
      timestamp: "2026-04-06T10:00:00Z",
      platform: "ruby",
      level: "error",
      environment: "production",
      release: "1.0.0",
      exception: {
        type: "RuntimeError",
        value: "test error",
        stacktrace: {
          frames: [
            { filename: "app.rb", function: "main", lineno: 10, in_app: true }
          ]
        }
      },
      tags: { runtime: "ruby-3.3" }
    }

    result = nil

    assert_enqueued_jobs 1, only: NotifyTelegramJob do
      result = CreateEventJob.perform_now(
        project_id: @project.id,
        event_payload: event_payload,
        raw_json: '{"test": "json"}'
      )
    end

    event = Event.find(result[:event_id])
    issue = Issue.find(result[:issue_id])

    assert_equal @project, event.project
    assert_equal issue, event.issue
    assert_equal "job-evt-001", event.event_uuid
    assert_equal "RuntimeError", event.exception_type
    assert_equal "test error", event.exception_message
    assert_equal "pending", event.notification_state
    assert_equal "new_issue", event.notification_reason
    assert_equal 1, issue.occurrences_count
    assert_equal "RuntimeError", issue.title
    assert_equal "app.rb in main", issue.culprit
    assert_equal "open", issue.status
  end

  test "groups events by fingerprint" do
    event_payload = {
      event_id: "job-evt-002",
      timestamp: "2026-04-06T11:00:00Z",
      level: "error",
      exception: {
        type: "RuntimeError",
        value: "test error",
        stacktrace: {
          frames: [
            { filename: "app.rb", function: "main", lineno: 10, in_app: true }
          ]
        }
      }
    }

    result1 = nil

    assert_enqueued_jobs 1, only: NotifyTelegramJob do
      result1 = CreateEventJob.perform_now(
        project_id: @project.id,
        event_payload: event_payload,
        raw_json: "{}"
      )
    end

    assert_no_enqueued_jobs only: NotifyTelegramJob do
      @result2 = CreateEventJob.perform_now(
        project_id: @project.id,
        event_payload: event_payload,
        raw_json: "{}"
      )
    end

    result2 = @result2

    assert_equal result1[:issue_id], result2[:issue_id]

    issue = Issue.find(result1[:issue_id])
    event = Event.find(result2[:event_id])
    assert_equal 2, issue.occurrences_count
    assert_equal "skipped", event.notification_state
    assert_nil event.notification_reason
  end

  test "creates event tags" do
    event_payload = {
      event_id: "job-evt-004",
      timestamp: "2026-04-06T12:00:00Z",
      level: "error",
      exception: {
        type: "RuntimeError",
        value: "test"
      },
      tags: { runtime: "ruby-3.3", os: "linux" }
    }

    result = CreateEventJob.perform_now(
      project_id: @project.id,
      event_payload: event_payload,
      raw_json: "{}"
    )

    event = Event.find(result[:event_id])
    assert_equal 2, event.event_tags.count
    assert_equal "ruby-3.3", event.event_tags.find_by(key: "runtime").value
    assert_equal "linux", event.event_tags.find_by(key: "os").value
  end

  test "resolved issue reappearing enqueues notification and reopens issue" do
    issue = Issue.create!(
      project: @project,
      fingerprint_hash: "resolved-fingerprint",
      title: "Old error",
      status: "resolved",
      level: "error",
      platform: "ruby",
      first_seen_at: 1.day.ago,
      last_seen_at: 1.day.ago,
      occurrences_count: 1
    )

    event_payload = {
      event_id: "job-evt-005",
      timestamp: "2026-04-06T13:00:00Z",
      level: "error",
      platform: "ruby",
      exception: {
        type: "RuntimeError",
        value: "resolved error",
        stacktrace: {
          frames: [
            { filename: "resolved.rb", function: "call", lineno: 15, in_app: true }
          ]
        }
      }
    }

    normalized_event = Ingestion::EventNormalizer.call(event_payload, raw_json: "{}")
    issue.update!(fingerprint_hash: Ingestion::FingerprintBuilder.call(normalized_event))

    result = nil

    assert_enqueued_jobs 1, only: NotifyTelegramJob do
      result = CreateEventJob.perform_now(
        project_id: @project.id,
        event_payload: event_payload,
        raw_json: "{}"
      )
    end

    issue.reload
    event = Event.find(result[:event_id])

    assert_equal "open", issue.status
    assert_equal "pending", event.notification_state
    assert_equal "reappeared", event.notification_reason
  end

  # rubocop:enable Metrics/BlockLength

end
