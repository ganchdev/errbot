# frozen_string_literal: true

module Api
  module V1
    class EventsController < ActionController::API

      include ProjectAuthentication

      def create
        payload = parse_json_payload
        event_payload = payload.fetch("event", payload)

        result = CreateEventJob.perform_now(
          project_id: @project.id,
          event_payload: event_payload,
          raw_json: payload.to_json
        )

        render json: {
          ok: true,
          issue_id: result[:issue_id],
          event_id: result[:event_id]
        }, status: :created
      rescue Ingestion::InvalidPayloadError => e
        render json: { error: e.message }, status: :bad_request
      end

      def create_sentry_store
        event_payload = parse_json_payload

        result = CreateEventJob.perform_now(
          project_id: @project.id,
          event_payload: event_payload,
          raw_json: event_payload.to_json
        )

        render json: {
          ok: true,
          issue_id: result[:issue_id],
          event_id: result[:event_id]
        }, status: :created
      rescue Ingestion::InvalidPayloadError => e
        render json: { error: e.message }, status: :bad_request
      end

      def create_sentry_envelope
        raw_body = request.raw_post
        event_payload = Ingestion::EnvelopeParser.call(raw_body)

        result = CreateEventJob.perform_now(
          project_id: @project.id,
          event_payload: event_payload,
          raw_json: raw_body
        )

        render json: {
          ok: true,
          issue_id: result[:issue_id],
          event_id: result[:event_id]
        }, status: :created
      rescue Ingestion::InvalidPayloadError => e
        render json: { error: e.message }, status: :bad_request
      end

      private

      def parse_json_payload
        payload = request.raw_post.present? ? JSON.parse(request.raw_post) : request.request_parameters
        raise Ingestion::InvalidPayloadError, "Request body must be a JSON object" unless payload.is_a?(Hash)

        payload
      rescue JSON::ParserError
        raise Ingestion::InvalidPayloadError, "Request body must be valid JSON"
      end

    end
  end
end
