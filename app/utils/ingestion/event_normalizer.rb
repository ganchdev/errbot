# frozen_string_literal: true

module Ingestion
  # Converts custom and Sentry exception payloads into the internal event shape.
  class EventNormalizer

    attr_reader :event_uuid, :occurred_at, :platform, :level, :environment, :release, :server_name, :transaction_name,
                :exception_type, :exception_message, :handled, :tags, :frames, :raw_payload, :raw_json, :title, :culprit

    # Normalizes an incoming exception payload into the internal event shape.
    #
    # @param payload [Hash, ActionController::Parameters]
    # @param raw_json [String]
    # @return [EventNormalizer]
    def self.call(payload, raw_json:)
      new(payload, raw_json: raw_json).call
    end

    # @param payload [Hash, ActionController::Parameters]
    # @param raw_json [String]
    # @return [void]
    def initialize(payload, raw_json:)
      @payload = payload
      @raw_json = raw_json
    end

    # Validates and assigns normalized event attributes.
    #
    # @return [EventNormalizer]
    # @raise [InvalidPayloadError] if the payload is not a supported exception event
    def call
      @raw_payload = normalize_hash(@payload)
      @exception = extract_exception(@raw_payload)

      validate!
      assign_attributes

      self
    end

    private

    attr_reader :exception

    # Converts the incoming payload into a string-keyed hash.
    #
    # @param payload [Hash, ActionController::Parameters]
    # @return [Hash]
    # @raise [InvalidPayloadError] if the payload cannot be treated as a hash
    def normalize_hash(payload)
      hash = payload.respond_to?(:to_unsafe_h) ? payload.to_unsafe_h : payload.to_h
      hash.deep_stringify_keys
    rescue NoMethodError
      raise InvalidPayloadError, "Event payload must be a JSON object"
    end

    # Ensures the payload contains usable exception data.
    #
    # @return [void]
    # @raise [InvalidPayloadError] if the exception payload is missing or incomplete
    def validate!
      raise InvalidPayloadError, "Event payload must include exception data" if exception.blank?
      raise InvalidPayloadError, "Exception payload must include a type" if exception["type"].blank?
    end

    # Copies normalized values from the payload onto the normalizer instance.
    #
    # @return [void]
    def assign_attributes
      @event_uuid = raw_payload["event_id"]
      @occurred_at = raw_payload["timestamp"].presence || Time.current
      @platform = raw_payload["platform"]
      @level = raw_payload["level"].presence || "error"
      @environment = raw_payload["environment"]
      @release = raw_payload["release"]
      @server_name = raw_payload["server_name"]
      @transaction_name = raw_payload["transaction"].presence || raw_payload["transaction_name"]
      @exception_type = exception["type"]
      @exception_message = exception["value"]
      @handled = exception.dig("mechanism", "handled")
      @tags = normalize_tags(raw_payload["tags"])
      @frames = Array(exception.dig("stacktrace", "frames")).filter_map do |frame|
        frame.to_h.deep_stringify_keys if frame.respond_to?(:to_h)
      end
      @culprit = build_culprit
      @title = exception_type
    end

    # Pulls the exception object from either custom or Sentry-style payloads.
    #
    # @param payload [Hash]
    # @return [Hash, nil]
    def extract_exception(payload)
      values = payload.dig("exception", "values")
      return values.last if values.respond_to?(:last) && values.last.present?

      payload["exception"]
    end

    # Coerces tags into a simple hash regardless of the incoming shape.
    #
    # @param tags [Hash, Array, nil]
    # @return [Hash]
    def normalize_tags(tags)
      case tags
      when Hash
        tags
      when Array
        tags.to_h
      else
        {}
      end
    rescue TypeError
      {}
    end

    def build_culprit
      frame = frames.reverse.find do |candidate|
        ActiveModel::Type::Boolean.new.cast(candidate["in_app"])
      end || frames.last

      return if frame.blank?

      [frame["filename"].presence, frame["function"].presence].compact.join(" in ").presence
    end

  end
end
