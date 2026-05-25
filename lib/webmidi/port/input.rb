# frozen_string_literal: true

module Webmidi
  module Port
    class Input < Base
      include Enumerable

      def initialize(**kwargs)
        @error_policy = kwargs.delete(:error_policy) || :notify
        super(**kwargs, type: :input)
        @message_callbacks = []
        @typed_callbacks = []
        @error_callbacks = []
      end

      def on_message(&block)
        raise ArgumentError, "on_message requires a block" unless block

        open unless open?
        @mutex.synchronize { @message_callbacks << block }
        CallbackSubscription.new do
          @mutex.synchronize { @message_callbacks.delete(block) }
        end
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

      def on_type(matcher, &block)
        register_typed_callback(matcher, &block)
      end

      def on_error(&block)
        raise ArgumentError, "on_error requires a block" unless block

        open unless open?
        @mutex.synchronize { @error_callbacks << block }
        CallbackSubscription.new do
          @mutex.synchronize { @error_callbacks.delete(block) }
        end
      end

      def each(timeout: 0.1, stop_when: nil, &block)
        return enum_for(:each, timeout: timeout, stop_when: stop_when) unless block_given?

        open unless open?
        while open?
          break if stop_when&.call

          bytes = @transport_handle.read(timeout: timeout)
          next unless bytes

          begin
            Message.parse_many(bytes).each do |msg|
              next if masked_sysex?(msg)

              block.call(msg)
            end
          rescue InvalidMessageError => e
            handle_parse_error(e, bytes)
          end
        end
      end

      def messages(**kwargs)
        each(**kwargs).lazy
      end

      def pipe(stack = nil)
        require_relative "../middleware/pipeline"

        Middleware::Pipeline.new(self, stack)
      end

      def dispatch(bytes)
        return unless open?

        Message.parse_many(bytes).each { |msg| dispatch_message(msg) }
      rescue InvalidMessageError => e
        handle_parse_error(e, bytes)
      end

      private

      def register_typed_callback(klass, &block)
        raise ArgumentError, "typed callback requires a block" unless block

        open unless open?
        entry = [klass, block]
        @mutex.synchronize { @typed_callbacks << entry }
        CallbackSubscription.new do
          @mutex.synchronize { @typed_callbacks.delete(entry) }
        end
      end

      def dispatch_message(msg)
        return if masked_sysex?(msg)

        callbacks, typed = @mutex.synchronize do
          [
            @message_callbacks.dup,
            @typed_callbacks.select { |matcher, _callback| callback_matches?(matcher, msg) }.map(&:last)
          ]
        end
        callbacks.each { |cb| cb.call(msg) }
        typed.each { |cb| cb.call(msg) }
      end

      def callback_matches?(matcher, msg)
        case matcher
        when Class, Module
          msg.is_a?(matcher)
        when Proc
          matcher.call(msg)
        else
          matcher === msg
        end
      end

      def masked_sysex?(msg)
        msg.is_a?(Message::System::SysEx) && !sysex_enabled?
      end

      def handle_parse_error(error, bytes)
        raise error if @error_policy == :raise

        callbacks = @mutex.synchronize { @error_callbacks.dup }
        callbacks.each { |cb| cb.call(error, bytes) }
        nil
      end
    end
  end
end
