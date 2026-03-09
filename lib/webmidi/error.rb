# frozen_string_literal: true

module Webmidi
  class Error < StandardError; end

  # Port-related errors
  class PortNotFoundError < Error; end
  class PortOpenError < Error; end
  class PortClosedError < Error; end

  # Message-related errors
  class InvalidMessageError < Error; end
  class SysExNotPermittedError < Error; end

  # File-related errors
  class InvalidSMFError < Error; end
  class UnsupportedFormatError < Error; end

  # Network-related errors
  class NetworkError < Error; end
  class ConnectionTimeoutError < NetworkError; end

  # Transport-related errors
  class TransportNotAvailableError < Error; end
  class TransportError < Error; end
end
