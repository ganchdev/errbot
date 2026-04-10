# frozen_string_literal: true

require "test_helper"

module Ingestion
  class FingerprintTest < ActiveSupport::TestCase

    test "hashes exception type and top in-app frame" do
      event = EventNormalizer.call(
        {
          exception: {
            type: "RuntimeError",
            value: "boom",
            stacktrace: {
              frames: [
                { filename: "vendor/gem.rb", function: "call", lineno: 1, in_app: false },
                { filename: "app/jobs/example_job.rb", function: "perform", lineno: 42, in_app: true }
              ]
            }
          }
        },
        raw_json: "{}"
      )

      expected = Digest::SHA256.hexdigest("RuntimeError|app/jobs/example_job.rb|perform|42")

      assert_equal expected, FingerprintBuilder.call(event)
    end

    test "falls back to exception type when there is no in-app frame" do
      event = EventNormalizer.call(
        {
          exception: {
            type: "RuntimeError",
            value: "boom",
            stacktrace: {
              frames: [
                { filename: "vendor/gem.rb", function: "call", lineno: 1, in_app: false }
              ]
            }
          }
        },
        raw_json: "{}"
      )

      assert_equal Digest::SHA256.hexdigest("RuntimeError"), FingerprintBuilder.call(event)
    end

  end
end
