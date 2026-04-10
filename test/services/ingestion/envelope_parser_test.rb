# frozen_string_literal: true

require "test_helper"

module Ingestion
  class EnvelopeParserTest < ActiveSupport::TestCase

    test "extracts event item payload from envelope" do
      event_payload = {
        event_id: "evt-envelope-001",
        exception: { values: [{ type: "RuntimeError", value: "boom" }] }
      }
      envelope = [
        { event_id: "evt-envelope-001" }.to_json,
        { type: "event" }.to_json,
        event_payload.to_json
      ].join("\n")

      assert_equal event_payload.deep_stringify_keys, EnvelopeParser.call(envelope)
    end

    test "skips unsupported items until it finds an event" do
      event_payload = {
        event_id: "evt-envelope-002",
        exception: { values: [{ type: "RuntimeError", value: "boom" }] }
      }
      envelope = [
        {}.to_json,
        { type: "attachment" }.to_json,
        { filename: "log.txt" }.to_json,
        { type: "error" }.to_json,
        event_payload.to_json
      ].join("\n")

      assert_equal event_payload.deep_stringify_keys, EnvelopeParser.call(envelope)
    end

    test "raises when envelope has no event item" do
      envelope = [
        {}.to_json,
        { type: "transaction" }.to_json,
        { transaction: "GET /dashboard" }.to_json
      ].join("\n")

      error = assert_raises(InvalidPayloadError) { EnvelopeParser.call(envelope) }
      assert_equal "Envelope did not contain an event item", error.message
    end

    test "raises when envelope event payload is invalid json" do
      envelope = [
        {}.to_json,
        { type: "event" }.to_json,
        "{not-json"
      ].join("\n")

      error = assert_raises(InvalidPayloadError) { EnvelopeParser.call(envelope) }
      assert_equal "Invalid envelope event payload", error.message
    end

  end
end
