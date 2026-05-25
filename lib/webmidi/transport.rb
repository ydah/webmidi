# frozen_string_literal: true

require_relative "transport/device_info"
require_relative "transport/base"
require_relative "transport/virtual"
require_relative "transport/null"

module Webmidi
  module Transport
    module_function

    def auto_detect(transport: Webmidi.configuration.transport, fallback_transport: Webmidi.configuration.fallback_transport)
      return resolve_transport!(transport) unless transport == :auto

      detected = [Virtual].find(&:available?)
      detected || resolve_transport!(fallback_transport)
    end

    def resolve_transport!(transport)
      case transport
      when :auto
        auto_detect(transport: :auto, fallback_transport: :null)
      when :virtual
        available_transport!(Virtual)
      when :null, nil
        Null
      else
        unless transport.respond_to?(:available?)
          raise TransportNotAvailableError, "Unknown transport: #{transport.inspect}"
        end

        available_transport!(transport)
      end
    end

    def available_transport!(transport)
      return transport unless transport.respond_to?(:available?) && !transport.available?

      raise TransportNotAvailableError, "Transport is not available: #{transport}"
    end

    private_class_method :resolve_transport!, :available_transport!
  end
end
