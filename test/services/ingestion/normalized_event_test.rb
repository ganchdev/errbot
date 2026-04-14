# frozen_string_literal: true

require "test_helper"

module Ingestion
  class NormalizedEventTest < ActiveSupport::TestCase

    test "normalizes custom exception payload" do
      event = EventNormalizer.call(custom_payload, raw_json: "{}")

      assert_equal "evt-normalized-001", event.event_uuid
      assert_equal "NoMethodError", event.exception_type
      assert_equal "undefined method id", event.exception_message
      assert_equal false, event.handled
      assert_equal "POST /payments", event.transaction_name
      assert_equal({ "runtime" => "ruby-3.3.0" }, event.tags)
      assert_equal "NoMethodError", event.title
      assert_equal "app/services/payments.rb in call", event.culprit
    end

    test "normalizes sentry exception values and tag pairs" do
      event = EventNormalizer.call(sentry_payload, raw_json: "{}")

      assert_equal "RuntimeError", event.exception_type
      assert_equal "inner", event.exception_message
      assert_equal "GET /dashboard", event.transaction_name
      assert_equal({ "runtime" => "ruby-3.3.0" }, event.tags)
      assert_equal "app/controllers/dashboard_controller.rb", event.frames.first["filename"]
    end

    test "raises for transaction payload without exception data" do
      error = assert_raises(InvalidPayloadError) do
        EventNormalizer.call({ event_id: "transaction-001", transaction: "GET /dashboard" }, raw_json: "{}")
      end

      assert_equal "Event payload must include exception data", error.message
    end

    private

    def custom_payload
      {
        event_id: "evt-normalized-001",
        timestamp: "2026-04-05T10:15:00Z",
        platform: "ruby",
        level: "fatal",
        environment: "production",
        release: "2026.04.05.1",
        server_name: "web-1",
        transaction_name: "POST /payments",
        exception: custom_exception,
        tags: { runtime: "ruby-3.3.0" }
      }
    end

    def custom_exception
      {
        type: "NoMethodError",
        value: "undefined method id",
        stacktrace: { frames: [payment_frame] },
        mechanism: { handled: false }
      }
    end

    def sentry_payload
      {
        event_id: "evt-normalized-002",
        transaction: "GET /dashboard",
        exception: { values: [{ type: "StandardError", value: "outer" }, sentry_exception] },
        tags: [["runtime", "ruby-3.3.0"]]
      }
    end

    def sentry_exception
      {
        type: "RuntimeError",
        value: "inner",
        stacktrace: { frames: [dashboard_frame] }
      }
    end

    def payment_frame
      { filename: "app/services/payments.rb", function: "call", lineno: 42, in_app: true }
    end

    def dashboard_frame
      { filename: "app/controllers/dashboard_controller.rb", function: "show", lineno: 8, in_app: true }
    end

  end
end
