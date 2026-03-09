# frozen_string_literal: true

module Webmidi
  module Port
    class Input < Base
      include Enumerable

      def initialize(**kwargs)
        super(**kwargs, type: :input)
        @message_callbacks = []
        @typed_callbacks = {}
      end

      def on_message(&block)
        open unless open?
        @mutex.synchronize { @message_callbacks << block }
        self
      end

      def on_note_on(&block)
        register_typed_callback(Message::Channel::NoteOn, &block)
      end

      def on_note_off(&block)
        register_typed_callback(Message::Channel::NoteOff, &block)
      end

      def on_control_change(&block)
        register_typed_callback(Message::Channel::ControlChange, &block)
      end

      def on_program_change(&block)
        register_typed_callback(Message::Channel::ProgramChange, &block)
      end

      def on_pitch_bend(&block)
        register_typed_callback(Message::Channel::PitchBend, &block)
      end

      def on_sysex(&block)
        register_typed_callback(Message::System::SysEx, &block)
      end

      def on_clock(&block)
        register_typed_callback(Message::System::Clock, &block)
      end

      def each(&block)
        return to_enum(:each) unless block_given?

        open unless open?
        loop do
          bytes = @transport_handle.read(timeout: 0.1)
          next unless bytes

          msg = Message.from_bytes(bytes)
          block.call(msg)
        end
      end

      def messages
        each.lazy
      end

      def dispatch(bytes)
        return unless open?

        msg = Message.from_bytes(bytes)
        callbacks = @mutex.synchronize { @message_callbacks.dup }
        callbacks.each { |cb| cb.call(msg) }

        typed = @mutex.synchronize { (@typed_callbacks[msg.class] || []).dup }
        typed.each { |cb| cb.call(msg) }
      end

      private

      def register_typed_callback(klass, &block)
        open unless open?
        @mutex.synchronize do
          @typed_callbacks[klass] ||= []
          @typed_callbacks[klass] << block
        end
        self
      end
    end
  end
end
