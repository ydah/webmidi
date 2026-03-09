# frozen_string_literal: true

module Webmidi
  module Transport
    class Null < Base
      def self.available?
        true
      end

      def self.list_inputs
        []
      end

      def self.list_outputs
        []
      end

      def self.create_virtual_input(name)
        info = DeviceInfo.new(id: "null-input", name: name, manufacturer: "Null", version: "0")
        NullInputHandle.new(info)
      end

      def self.create_virtual_output(name)
        info = DeviceInfo.new(id: "null-output", name: name, manufacturer: "Null", version: "0")
        NullOutputHandle.new(info)
      end

      class NullInputHandle
        include InputHandle

        attr_reader :device_info

        def initialize(device_info)
          @device_info = device_info
        end

        def read(timeout: nil)
          nil
        end

        def on_data(&block)
          # no-op
        end

        def close
          # no-op
        end
      end

      class NullOutputHandle
        include OutputHandle

        attr_reader :device_info

        def initialize(device_info)
          @device_info = device_info
          @sent_messages = []
        end

        def write(bytes)
          @sent_messages << bytes
        end

        def sent_messages
          @sent_messages.dup
        end

        def close
          # no-op
        end
      end
    end
  end
end
