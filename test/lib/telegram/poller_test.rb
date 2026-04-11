# frozen_string_literal: true

require "test_helper"

module Telegram
  class PollerTest < ActiveSupport::TestCase

    test "run_once passes updates to handler and advances offset" do
      client = FakeClient.new(
        [{ "update_id" => 41, "message" => { "text" => "/start", "chat" => { "id" => 123 } } }]
      )
      handler = FakeHandler.new
      poller = TestPoller.new(client: client, handler: handler, logger: Logger.new(nil), error_backoff: 0)

      poller.run_once
      poller.run_once

      assert_equal [nil, 42], client.offsets
      assert_equal [41], handler.update_ids
    end

    test "run_once swallows telegram client errors and backs off" do
      client = Class.new do
        def get_updates(**)
          raise Telegram::Error, "boom"
        end
      end.new
      handler = FakeHandler.new
      poller = TestPoller.new(client: client, handler: handler, logger: Logger.new(nil), error_backoff: 0)

      poller.run_once

      assert_empty handler.update_ids
      assert_equal [0], poller.sleep_calls
    end

    class FakeClient

      attr_reader :offsets

      def initialize(first_response)
        @responses = [first_response, []]
        @offsets = []
      end

      def get_updates(offset:, **)
        @offsets << offset
        @responses.shift || []
      end

    end

    class FakeHandler

      attr_reader :update_ids

      def initialize
        @update_ids = []
      end

      def call(update)
        @update_ids << update.fetch("update_id")
      end

    end

    class TestPoller < Poller

      attr_reader :sleep_calls

      def initialize(**)
        super
        @sleep_calls = []
      end

      private

      def sleep(seconds)
        @sleep_calls << seconds
      end

    end

  end
end
