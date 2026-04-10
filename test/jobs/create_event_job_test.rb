# frozen_string_literal: true

require "test_helper"

class CreateEventJobTest < ActiveJob::TestCase

  # rubocop:disable Metrics/BlockLength
  setup do
    @project = projects(:one)
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

    result = CreateEventJob.perform_now(
      project_id: @project.id,
      event_payload: event_payload,
      raw_json: '{"test": "json"}'
    )

    event = Event.find(result[:event_id])
    issue = Issue.find(result[:issue_id])

    assert_equal @project, event.project
    assert_equal issue, event.issue
    assert_equal "job-evt-001", event.event_uuid
    assert_equal "RuntimeError", event.exception_type
    assert_equal "test error", event.exception_message
    assert_equal "pending", event.notification_state
    assert_equal 1, issue.occurrences_count
    assert_equal "RuntimeError: test error", issue.title
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

    result1 = CreateEventJob.perform_now(
      project_id: @project.id,
      event_payload: event_payload,
      raw_json: "{}"
    )

    result2 = CreateEventJob.perform_now(
      project_id: @project.id,
      event_payload: event_payload,
      raw_json: "{}"
    )

    assert_equal result1[:issue_id], result2[:issue_id]

    issue = Issue.find(result1[:issue_id])
    assert_equal 2, issue.occurrences_count
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
  # rubocop:enable Metrics/BlockLength

end
