# frozen_string_literal: true

require "thread"

module Webmidi
  module Port
    class Output < Base
      def initialize(**kwargs)
        super(**kwargs, type: :output)
        @scheduled_messages = []
        @scheduler_mutex = Mutex.new
        @scheduler_cv = ConditionVariable.new
        @scheduler_thread = nil
        @scheduler_shutdown = false
      end

      def send(message, timestamp: nil)
        open unless open?
        byte_messages = outbound_byte_messages(message)
        byte_messages.each { |bytes| ensure_sysex_permitted!(bytes) }

        if timestamp && timestamp > current_timestamp
          schedule(byte_messages, timestamp)
        else
          byte_messages.each { |bytes| write_bytes(bytes) }
        end
        self
      end

      def clear
        @scheduler_mutex.synchronize do
          @scheduled_messages.clear
          @scheduler_cv.broadcast
        end
        self
      end

      def note_on(note, velocity: 100, channel: 0)
        send(Message.note_on(note, velocity: velocity, channel: channel))
      end

      def note_off(note, velocity: 0, channel: 0)
        send(Message.note_off(note, velocity: velocity, channel: channel))
      end

      def control_change(cc, value, channel: 0)
        send(Message.control_change(cc, value, channel: channel))
      end

      def program_change(program, channel: 0)
        send(Message.program_change(program, channel: channel))
      end

      def pitch_bend(value, channel: 0)
        send(Message.pitch_bend(value, channel: channel))
      end

      def all_notes_off(channel: nil)
        if channel
          send(Message.control_change(Message::Channel::ControlChange::ALL_NOTES_OFF, 0, channel: channel))
        else
          16.times { |ch| send(Message.control_change(Message::Channel::ControlChange::ALL_NOTES_OFF, 0, channel: ch)) }
        end
        self
      end

      def reset
        send(Message.system_reset)
        self
      end

      def <<(message)
        send(message)
      end

      def send_all(*messages)
        items = if messages.size == 1 && messages.first.is_a?(Array) &&
                   messages.first.all? { |message| message.is_a?(Message::Base) }
                  messages.first
                else
                  messages
                end
        items.each { |msg| send(msg) }
        self
      end

      def close
        shutdown_scheduler
        super
      end

      private

      def outbound_byte_messages(message)
        case message
        when Message::Base
          [message.to_bytes]
        when Array
          Message.parse_many(message, normalize_note_on_zero: false).map(&:to_bytes)
        else
          raise InvalidMessageError, "Expected Message or byte Array, got #{message.class}"
        end
      end

      def ensure_sysex_permitted!(bytes)
        return unless bytes[0] == 0xF0
        return if sysex_enabled?

        raise SysExNotPermittedError, "System exclusive messages require sysex: true"
      end

      def schedule(byte_messages, timestamp)
        @scheduler_mutex.synchronize do
          byte_messages.each { |bytes| @scheduled_messages << [timestamp, bytes] }
          @scheduled_messages.sort_by!(&:first)
          start_scheduler_locked
          @scheduler_cv.broadcast
        end
      end

      def start_scheduler_locked
        return if @scheduler_thread&.alive?

        @scheduler_shutdown = false
        @scheduler_thread = Thread.new { scheduler_loop }
      end

      def scheduler_loop
        loop do
          item = next_scheduled_item
          break unless item

          write_bytes(item[1])
        rescue PortClosedError
          break
        end
      end

      def next_scheduled_item
        @scheduler_mutex.synchronize do
          loop do
            return nil if @scheduler_shutdown

            if @scheduled_messages.empty?
              @scheduler_cv.wait(@scheduler_mutex)
              next
            end

            timestamp, bytes = @scheduled_messages.first
            delay = timestamp - current_timestamp
            if delay.positive?
              @scheduler_cv.wait(@scheduler_mutex, delay)
              next
            end

            @scheduled_messages.shift
            return [timestamp, bytes]
          end
        end
      end

      def write_bytes(bytes)
        @transport_handle.write(bytes)
      end

      def current_timestamp
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def shutdown_scheduler
        thread = @scheduler_mutex.synchronize do
          @scheduled_messages.clear
          @scheduler_shutdown = true
          @scheduler_cv.broadcast
          @scheduler_thread
        end
        thread&.join
      end
    end
  end
end
