# frozen_string_literal: true

module Webmidi
  module Virtual
    class Loopback
      attr_reader :input, :output

      def self.create(name: "Loopback")
        new(name: name)
      end

      def initialize(name:)
        @name = name
        input_handle, output_handle = Transport::Virtual.create_loopback(name)

        @input = Webmidi::Port::Input.new(
          id: input_handle.device_info.id,
          name: input_handle.device_info.name,
          manufacturer: input_handle.device_info.manufacturer,
          version: input_handle.device_info.version,
          transport_handle: input_handle
        )
        @input.open

        @output = Webmidi::Port::Output.new(
          id: output_handle.device_info.id,
          name: output_handle.device_info.name,
          manufacturer: output_handle.device_info.manufacturer,
          version: output_handle.device_info.version,
          transport_handle: output_handle
        )

        # Wire up: when data comes in from transport, dispatch to input port
        input_handle.on_data do |bytes|
          @input.dispatch(bytes)
        end
      end

      def close
        @input&.disconnect
        @output&.disconnect
      end
    end
  end
end
