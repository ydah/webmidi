# frozen_string_literal: true

require_relative "transport/device_info"
require_relative "transport/base"
require_relative "transport/virtual"
require_relative "transport/null"

module Webmidi
  module Transport
    @registered_transports = []
    @registry_mutex = Mutex.new

    module_function

    def register(transport)
      validate_transport_adapter!(transport)
      @registry_mutex.synchronize do
        @registered_transports << transport unless @registered_transports.include?(transport)
      end
      transport
    end

    def unregister(transport)
      @registry_mutex.synchronize { @registered_transports.delete(transport) }
      transport
    end

    def registered
      @registry_mutex.synchronize { @registered_transports.dup.freeze }
    end

    def auto_detect(transport: Webmidi.configuration.transport,
      fallback_transport: Webmidi.configuration.fallback_transport,
      candidates: default_candidates)
      return resolve_transport!(transport) unless transport == :auto

      detected = candidates.find { |candidate| candidate.respond_to?(:available?) && candidate.available? }
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

    def default_candidates
      registered + [Virtual]
    end

    def validate_transport_adapter!(transport)
      return if transport.respond_to?(:available?)

      raise TransportNotAvailableError, "Transport adapter must respond to available?: #{transport.inspect}"
    end

    private_class_method :resolve_transport!, :available_transport!, :default_candidates,
      :validate_transport_adapter!
  end
end
