# frozen_string_literal: true

require "openssl"
require "socket"
require "timeout"

module Uptime
  # Fetches SSL certificate metadata for HTTPS uptime checks.
  class SslInspector

    DEFAULT_WARNING_DAYS = ENV.fetch("UPTIME_SSL_EXPIRY_WARNING_DAYS", 14).to_i
    CONNECT_TIMEOUT = 10

    # Inspects the remote certificate for an HTTPS endpoint and returns
    # persisted uptime-check attributes describing its SSL state.
    #
    # @param uri [URI::HTTP, URI::HTTPS]
    # @param warning_window [ActiveSupport::Duration]
    # @return [Hash]
    def self.call(uri, warning_window: DEFAULT_WARNING_DAYS.days)
      new(uri, warning_window: warning_window).call
    end

    # @param uri [URI::HTTP, URI::HTTPS]
    # @param warning_window [ActiveSupport::Duration]
    def initialize(uri, warning_window:)
      @uri = uri
      @warning_window = warning_window
      @now = Time.current
    end

    # Returns SSL metadata for the endpoint, or a non-applicable/error payload
    # when the endpoint is not HTTPS or certificate inspection fails.
    #
    # @return [Hash]
    def call
      return not_applicable_attributes unless uri.scheme == "https"

      certificate = fetch_certificate
      expires_at = certificate&.not_after

      if expires_at.present?
        {
          ssl_status: ssl_status_for(expires_at),
          ssl_expires_at: expires_at,
          ssl_error: nil
        }
      else
        error_attributes("Peer certificate missing")
      end
    rescue StandardError => e
      error_attributes(e.message)
    ensure
      close_sockets
    end

    private

    attr_reader :uri, :warning_window, :now

    # Opens a TLS socket and returns the peer certificate presented by the host.
    #
    # @return [OpenSSL::X509::Certificate, nil]
    def fetch_certificate
      @tcp_socket = Socket.tcp(uri.host, uri.port, connect_timeout: CONNECT_TIMEOUT)
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      @ssl_socket = OpenSSL::SSL::SSLSocket.new(@tcp_socket, ssl_context)
      @ssl_socket.hostname = uri.host if @ssl_socket.respond_to?(:hostname=)
      @ssl_socket.sync_close = true

      Timeout.timeout(CONNECT_TIMEOUT) { @ssl_socket.connect }
      @ssl_socket.peer_cert
    end

    # Maps a certificate expiry time to the app's persisted SSL status values.
    #
    # @param expires_at [Time]
    # @return [String]
    def ssl_status_for(expires_at)
      return "expired" if expires_at <= now
      return "expiring_soon" if expires_at <= now + warning_window

      "valid"
    end

    # Returns the default payload for non-HTTPS monitored URLs.
    #
    # @return [Hash]
    def not_applicable_attributes
      {
        ssl_status: "not_applicable",
        ssl_expires_at: nil,
        ssl_error: nil
      }
    end

    # Returns a normalized error payload when certificate inspection fails.
    #
    # @param message [#to_s]
    # @return [Hash]
    def error_attributes(message)
      {
        ssl_status: "error",
        ssl_expires_at: nil,
        ssl_error: message.to_s[0, 255]
      }
    end

    # Closes any sockets opened during certificate inspection.
    #
    # @return [nil]
    def close_sockets
      @ssl_socket&.close
      @tcp_socket&.close
    rescue StandardError
      nil
    end

  end
end
