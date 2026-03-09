# frozen_string_literal: true

module Webmidi
  module Port
    class Output < Base
      def initialize(**kwargs)
        super(**kwargs, type: :output)
      end

      def send(message, timestamp: nil)
        open unless open?
        bytes = case message
                when Message::Base
                  message.to_bytes
                when Array
                  message
                else
                  raise InvalidMessageError, "Expected Message or Array, got #{message.class}"
                end
        @transport_handle.write(bytes)
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
          send(Message.control_change(123, 0, channel: channel))
        else
          16.times { |ch| send(Message.control_change(123, 0, channel: ch)) }
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
        messages.flatten.each { |msg| send(msg) }
        self
      end
    end
  end
end
