# frozen_string_literal: true

module Webmidi
  module Transport
    class Base
      def self.available?
        false
      end

      def self.list_inputs
        raise NotImplementedError
      end

      def self.list_outputs
        raise NotImplementedError
      end

      def self.open_input(device_info)
        raise NotImplementedError
      end

      def self.open_output(device_info)
        raise NotImplementedError
      end

      def self.create_virtual_input(name)
        raise NotImplementedError
      end

      def self.create_virtual_output(name)
        raise NotImplementedError
      end
    end

    module InputHandle
      def read(timeout: nil)
        raise NotImplementedError
      end

      def on_data(&block)
        raise NotImplementedError
      end

      def close
        raise NotImplementedError
      end
    end

    module OutputHandle
      def write(bytes)
        raise NotImplementedError
      end

      def close
        raise NotImplementedError
      end
    end
  end
end
