# frozen_string_literal: true

require "sentry-ruby"

SENTRY_DSN = "http://one@127.0.0.1:3000/one"

module SmokeTest
  module Checkout

    class CustomerGateway

      def self.fetch_customer(customer_id)
        payload = { id: customer_id, profile: nil, plan: "pro" }
        decorate_customer(payload)
      end

      def self.decorate_customer(payload)
        # Simulate the sort of nil access bug we want to inspect in Errbot.
        payload[:profile][:billing_email].downcase
      end

    end

    class PaymentSync

      def self.call(order_id:, customer_id:)
        customer_email = CustomerGateway.fetch_customer(customer_id)

        {
          order_id: order_id,
          customer_id: customer_id,
          customer_email: customer_email
        }
      end

    end

  end
end

Sentry.init do |config|
  config.dsn = SENTRY_DSN
  config.environment = "production"
  config.release = "smoke-test-2026-04-13"
  config.server_name = "smoke-test-web-01"
  config.debug = true
  config.traces_sample_rate = 0.0
end

begin
  Sentry.set_tags(feature: "checkout", job: "payment_sync", smoke_test: "true")
  Sentry.set_context(
    "order",
    {
      id: "ord_9f3a2c",
      number: "R100042",
      total_cents: 12_900,
      currency: "GBP"
    }
  )
  Sentry.set_context(
    "customer",
    {
      id: "cus_demo_42",
      account_id: "acct_uk_storefront",
      segment: "paid"
    }
  )
  Sentry.set_extras(
    queue: "default",
    release_channel: "local-dev",
    request_id: "req_smoke_test_001"
  )

  SmokeTest::Checkout::PaymentSync.call(order_id: "ord_9f3a2c", customer_id: "cus_demo_42")
rescue StandardError => e
  Sentry.capture_exception(e)
  Sentry.close if Sentry.respond_to?(:close)
end
