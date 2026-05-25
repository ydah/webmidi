# frozen_string_literal: true

module Webmidi
  module Virtual
    class Port
      attr_reader :input, :output

      def self.create(name:, direction: :bidirectional)
        new(name: name, direction: direction)
      end

      def initialize(name:, direction: :bidirectional)
        @name = name
        @direction = direction
        transport = Transport::Virtual

        case direction
        when :bidirectional, :input
          input_handle = transport.create_virtual_input(name)
          @input = Webmidi::Port::Input.new(
            id: input_handle.device_info.id,
            name: input_handle.device_info.name,
            manufacturer: input_handle.device_info.manufacturer,
            version: input_handle.device_info.version,
            transport_handle: input_handle
          )
        end

        case direction
        when :bidirectional, :output
          output_handle = transport.create_virtual_output(name)
          @output = Webmidi::Port::Output.new(
            id: output_handle.device_info.id,
            name: output_handle.device_info.name,
            manufacturer: output_handle.device_info.manufacturer,
            version: output_handle.device_info.version,
            transport_handle: output_handle
          )
        end
      end

      def close
        @input&.disconnect
        @output&.disconnect
      end
    end
  end
end
