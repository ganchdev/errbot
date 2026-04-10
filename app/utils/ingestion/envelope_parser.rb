# frozen_string_literal: true

module Ingestion
  # Extracts the first exception event item from a Sentry envelope body.
  class EnvelopeParser

    # Parses an envelope body and returns the first supported event item payload.
    #
    # @param raw_body [String]
    # @return [Hash]
    def self.call(raw_body)
      new(raw_body).call
    end

    # @param raw_body [String]
    # @return [void]
    def initialize(raw_body)
      @raw_body = raw_body.to_s
    end

    # Walks the envelope items and returns the first event payload.
    #
    # @return [Hash]
    # @raise [InvalidPayloadError] if the envelope is malformed or has no event item
    def call
      lines = raw_body.lines.map(&:chomp)
      raise InvalidPayloadError, "Empty envelope" if lines.empty?

      index = 1
      while index < lines.length
        item_header = parse_json(lines[index], "Invalid envelope item header")
        item_payload = lines[index + 1]
        raise InvalidPayloadError, "Envelope item is missing a payload" if item_payload.blank?

        return parse_json(item_payload, "Invalid envelope event payload") if event_item?(item_header)

        index += 2
      end

      raise InvalidPayloadError, "Envelope did not contain an event item"
    end

    private

    attr_reader :raw_body

    # Checks whether an envelope item header represents a supported event item.
    #
    # @param header [Hash]
    # @return [Boolean]
    def event_item?(header)
      %w[event error].include?(header["type"].to_s)
    end

    # Parses a JSON fragment and raises a domain-specific payload error on failure.
    #
    # @param json [String]
    # @param message [String]
    # @return [Hash]
    # @raise [InvalidPayloadError] if the fragment is not valid JSON
    def parse_json(json, message)
      JSON.parse(json)
    rescue JSON::ParserError
      raise InvalidPayloadError, message
    end

  end
end
