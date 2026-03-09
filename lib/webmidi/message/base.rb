# frozen_string_literal: true

module Webmidi
  module Message
    class Base
      attr_reader :timestamp

      def initialize(timestamp: nil)
        @timestamp = timestamp || Process.clock_gettime(Process::CLOCK_MONOTONIC)
        freeze
      end

      def to_bytes
        raise NotImplementedError, "#{self.class}#to_bytes must be implemented"
      end

      def to_hex
        to_bytes.map { |b| format("%02X", b) }.join(" ")
      end

      def channel
        nil
      end

      def ==(other)
        other.is_a?(self.class) && to_bytes == other.to_bytes
      end

      def eql?(other)
        self == other
      end

      def hash
        [self.class, to_bytes].hash
      end

      def deconstruct_keys(keys)
        {}
      end
    end
  end
end
