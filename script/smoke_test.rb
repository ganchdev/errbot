# frozen_string_literal: true

require "sentry-ruby"

SENTRY_DSN = "http://one@127.0.0.1:3000/one"

Sentry.init do |config|
  config.dsn = SENTRY_DSN
  config.environment = "development"
  config.release = "smoke-test"
  config.debug = true
  config.traces_sample_rate = 0.0
end

begin
  raise "Errbot smoke test"
rescue StandardError => e
  Sentry.capture_exception(e)
  Sentry.close if Sentry.respond_to?(:close)
end
