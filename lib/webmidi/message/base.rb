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

      def to_binary
        to_bytes.pack("C*").b
      end

      def channel
        nil
      end

      def ==(other)
        other.is_a?(self.class) && same_bytes?(other)
      end

      def eql?(other)
        self == other
      end

      def hash
        [self.class, to_bytes].hash
      end

      def same_bytes?(other)
        other.respond_to?(:to_bytes) && to_bytes == other.to_bytes
      end

      def same_event?(other)
        other.is_a?(self.class) && same_bytes?(other) && timestamp == other.timestamp
      end

      def with(**changes)
        changes = changes.dup
        next_timestamp = changes.key?(:timestamp) ? changes.delete(:timestamp) : @timestamp
        self.class.new(**deconstruct_keys(nil).merge(changes), timestamp: next_timestamp)
      end

      def deconstruct
        to_bytes
      end

      def deconstruct_keys(keys)
        {}
      end
    end
  end
end
