# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class EventsControllerTest < ActionDispatch::IntegrationTest

      # rubocop:disable Metrics/BlockLength
      setup do
        @project = projects(:one)
      end

      test "create event with valid token" do
        post "/api/v1/events",
             params: {
               event: {
                 event_id: "evt-001",
                 timestamp: "2026-04-05T10:15:00Z",
                 platform: "ruby",
                 level: "error",
                 environment: "production",
                 release: "2026.04.05.1",
                 exception: {
                   type: "NoMethodError",
                   value: "undefined method `id' for nil:NilClass",
                   stacktrace: {
                     frames: [
                       { filename: "app/services/payments.rb", function: "call", lineno: 42, in_app: true }
                     ]
                   }
                 },
                 tags: { runtime: "ruby-3.3.0" }
               }
             },
             headers: { "Authorization" => "Bearer #{@project.ingest_token}" },
             as: :json

        assert_response :created
        json = JSON.parse(response.body)
        assert json["ok"]
        assert json["issue_id"]
        assert json["event_id"]

        issue = Issue.find(json["issue_id"])
        assert_equal "NoMethodError: undefined method `id' for nil:NilClass", issue.title
        assert_equal 1, issue.occurrences_count
        assert_equal "open", issue.status
      end

      test "group events by fingerprint" do
        post "/api/v1/events",
             params: {
               event: {
                 event_id: "evt-002",
                 timestamp: "2026-04-05T11:00:00Z",
                 level: "error",
                 environment: "staging",
                 exception: {
                   type: "StandardError",
                   value: "test message",
                   stacktrace: {
                     frames: [
                       { filename: "app.rb", function: "index", lineno: 1, in_app: true }
                     ]
                   }
                 }
               }
             },
             headers: { "Authorization" => "Bearer #{@project.ingest_token}" },
             as: :json

        assert_response :created
        json = JSON.parse(response.body)

        issue = Issue.find(json["issue_id"])
        assert_equal 1, issue.occurrences_count

        post "/api/v1/events",
             params: {
               event: {
                 event_id: "evt-003",
                 timestamp: "2026-04-05T12:00:00Z",
                 level: "error",
                 environment: "staging",
                 exception: {
                   type: "StandardError",
                   value: "test message",
                   stacktrace: {
                     frames: [
                       { filename: "app.rb", function: "index", lineno: 1, in_app: true }
                     ]
                   }
                 }
               }
             },
             headers: { "Authorization" => "Bearer #{@project.ingest_token}" },
             as: :json

        assert_response :created
        json2 = JSON.parse(response.body)
        assert_equal json["issue_id"], json2["issue_id"]

        issue.reload
        assert_equal 2, issue.occurrences_count
      end

      test "reject request without token" do
        post "/api/v1/events",
             params: { event: { event_id: "evt-003", timestamp: "2026-04-05T12:00:00Z", level: "error" } },
             as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal "Missing token", json["error"]
      end

      test "reject request with invalid token" do
        post "/api/v1/events",
             params: { event: { event_id: "evt-004", timestamp: "2026-04-05T12:00:00Z", level: "error" } },
             headers: { "Authorization" => "Bearer invalid_token_123" },
             as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal "Invalid token", json["error"]
      end

      test "reject non-exception event" do
        post "/api/v1/events",
             params: {
               event: {
                 event_id: "evt-transaction-001",
                 timestamp: "2026-04-05T12:00:00Z",
                 type: "transaction",
                 transaction: "GET /dashboard"
               }
             },
             headers: { "Authorization" => "Bearer #{@project.ingest_token}" },
             as: :json

        assert_response :bad_request
        json = JSON.parse(response.body)
        assert_equal "Event payload must include exception data", json["error"]
      end

      test "creates event from sentry store payload" do
        post "/api/#{@project.slug}/store",
             params: {
               event_id: "sentry-store-001",
               timestamp: "2026-04-05T15:00:00Z",
               platform: "ruby",
               level: "error",
               environment: "production",
               transaction: "POST /payments",
               exception: {
                 values: [
                   {
                     type: "NoMethodError",
                     value: "undefined method `id' for nil:NilClass",
                     stacktrace: {
                       frames: [
                         { filename: "app/services/payments.rb", function: "call", lineno: 42, in_app: true }
                       ]
                     },
                     mechanism: { handled: false }
                   }
                 ]
               },
               tags: [["runtime", "ruby-3.3.0"]]
             },
             headers: { "X-Sentry-Auth" => "Sentry sentry_version=7, sentry_key=#{@project.ingest_token}" },
             as: :json

        assert_response :created
        event = Event.find(JSON.parse(response.body)["event_id"])

        assert_equal "sentry-store-001", event.event_uuid
        assert_equal "POST /payments", event.transaction_name
        assert_equal false, event.handled
        assert_equal "ruby-3.3.0", event.event_tags.find_by(key: "runtime").value
      end

      test "creates event from sentry envelope payload" do
        event_payload = {
          event_id: "sentry-envelope-001",
          timestamp: "2026-04-05T16:00:00Z",
          platform: "ruby",
          level: "error",
          exception: {
            values: [
              {
                type: "RuntimeError",
                value: "envelope error",
                stacktrace: {
                  frames: [
                    { filename: "app/jobs/example_job.rb", function: "perform", lineno: 12, in_app: true }
                  ]
                }
              }
            ]
          }
        }
        envelope = [
          { event_id: "sentry-envelope-001" }.to_json,
          { type: "event" }.to_json,
          event_payload.to_json
        ].join("\n")

        post "/api/#{@project.slug}/envelope?sentry_key=#{@project.ingest_token}",
             params: envelope,
             headers: { "Content-Type" => "application/x-sentry-envelope" }

        assert_response :created
        event = Event.find(JSON.parse(response.body)["event_id"])

        assert_equal "sentry-envelope-001", event.event_uuid
        assert_equal "RuntimeError", event.exception_type
        assert_equal "envelope error", event.exception_message
      end

      test "fingerprint includes in_app frame" do
        post "/api/v1/events",
             params: {
               event: {
                 event_id: "evt-005",
                 timestamp: "2026-04-05T13:00:00Z",
                 level: "error",
                 exception: {
                   type: "RuntimeError",
                   value: "test",
                   stacktrace: {
                     frames: [
                       { filename: "vendor/gems/foo.rb", function: "bar", lineno: 1, in_app: false },
                       { filename: "app/services/orders.rb", function: "process", lineno: 10, in_app: true }
                     ]
                   }
                 }
               }
             },
             headers: { "Authorization" => "Bearer #{@project.ingest_token}" },
             as: :json

        assert_response :created
        json = JSON.parse(response.body)
        issue = Issue.find(json["issue_id"])

        expected_fingerprint = Digest::SHA256.hexdigest("RuntimeError|app/services/orders.rb|process|10")
        assert_equal expected_fingerprint, issue.fingerprint_hash, "Fingerprint should use in_app frame"
      end

      test "fingerprint falls back to exception type when no in_app frame" do
        post "/api/v1/events",
             params: {
               event: {
                 event_id: "evt-006",
                 timestamp: "2026-04-05T14:00:00Z",
                 level: "error",
                 exception: {
                   type: "RuntimeError",
                   value: "all vendor frames",
                   stacktrace: {
                     frames: [
                       { filename: "vendor/gems/foo.rb", function: "bar", lineno: 1, in_app: false }
                     ]
                   }
                 }
               }
             },
             headers: { "Authorization" => "Bearer #{@project.ingest_token}" },
             as: :json

        assert_response :created
        issue = Issue.find(JSON.parse(response.body)["issue_id"])

        expected_hash = Digest::SHA256.hexdigest("RuntimeError")
        assert_equal expected_hash, issue.fingerprint_hash
      end
      # rubocop:enable Metrics/BlockLength

    end
  end
end
