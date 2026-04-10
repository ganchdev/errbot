# frozen_string_literal: true

module Ingestion
  # Raised when an incoming ingest request is parseable but not a supported exception event.
  class InvalidPayloadError < StandardError; end
end
