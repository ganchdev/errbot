# frozen_string_literal: true

module Ingestion
  # Builds the deterministic issue grouping hash from exception type and top in-app frame.
  class FingerprintBuilder

    # Computes the issue fingerprint for a normalized event.
    #
    # @param normalized_event [Ingestion::EventNormalizer]
    # @return [String]
    def self.call(normalized_event)
      new(normalized_event).call
    end

    # @param normalized_event [Ingestion::EventNormalizer]
    # @return [void]
    def initialize(normalized_event)
      @normalized_event = normalized_event
    end

    # Hashes the grouping components into a stable fingerprint.
    #
    # @return [String]
    def call
      Digest::SHA256.hexdigest(components.join("|"))
    end

    private

    attr_reader :normalized_event

    # Returns the fingerprint components, falling back to exception type alone when needed.
    #
    # @return [Array<String, Integer>]
    def components
      return [normalized_event.exception_type] if frame.blank?

      [normalized_event.exception_type, frame["filename"], frame["function"], frame["lineno"]].compact_blank
    end

    # Finds the first stack frame marked as in-app.
    #
    # @return [Hash, nil]
    def frame
      @frame ||= normalized_event.frames.find { |candidate| ActiveModel::Type::Boolean.new.cast(candidate["in_app"]) }
    end

  end
end
