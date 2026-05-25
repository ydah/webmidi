# frozen_string_literal: true

module Webmidi
  module Middleware
    class Panic < Base
      DEFAULT_CONTROLS = [:all_sound_off, :all_notes_off].freeze
      DEFAULT_TRIGGER = Message::System::SystemReset

      def initialize(app, channels: 0..15, controls: DEFAULT_CONTROLS, trigger: DEFAULT_TRIGGER,
        pass_trigger: false, **options)
        super(app, **options)
        @channels = self.class.send(:normalize_channels, channels)
        @controls = self.class.send(:normalize_controls, controls)
        @trigger = trigger
        @pass_trigger = pass_trigger
      end

      def call(message)
        return @app.call(message) unless trigger?(message)

        results = self.class.messages(channels: @channels, controls: @controls, timestamp: message.timestamp)
          .filter_map { |panic_message| @app.call(panic_message) }
        results << @app.call(message) if @pass_trigger
        results.compact
      end

      def self.all_notes_off(channels: 0..15, timestamp: nil)
        messages(channels: channels, controls: [:all_notes_off], timestamp: timestamp)
      end

      def self.messages(channels: 0..15, controls: DEFAULT_CONTROLS, timestamp: nil)
        normalize_channels(channels).flat_map do |channel|
          normalize_controls(controls).map do |control|
            Message.control_change(control, 0, channel: channel, timestamp: timestamp)
          end
        end
      end

      def self.normalize_channels(channels)
        Array(channels).each_with_object([]) do |channel, result|
          unless channel.is_a?(Integer) && channel.between?(0, 15)
            raise InvalidMessageError, "Channel must be between 0 and 15, got #{channel.inspect}"
          end

          result << channel
        end
      end

      def self.normalize_controls(controls)
        Array(controls).map do |control|
          Message::Channel::ControlChange.controller_number(control)
        end
      end

      private_class_method :normalize_channels, :normalize_controls

      private

      def trigger?(message)
        case @trigger
        when nil
          false
        when Proc
          @trigger.call(message)
        when Class, Module
          message.is_a?(@trigger)
        else
          message == @trigger
        end
      end
    end
  end
end
