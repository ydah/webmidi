# frozen_string_literal: true

module Webmidi
  module SMF
    class Track
      include Enumerable

      attr_accessor :name, :channel

      def initialize(name: nil, channel: nil)
        @name = name
        @channel = channel
        @events = []
      end

      def events
        @events.dup
      end

      def add_event(event)
        @events << event
        self
      end

      def <<(event)
        add_event(event)
      end

      def each(&block)
        @events.each(&block)
      end

      def size
        @events.size
      end

      def notes
        @events.lazy.select { |e| e.is_a?(MIDIEvent) && note_event?(e.message) }
      end

      def control_changes
        @events.lazy.select { |e| e.is_a?(MIDIEvent) && e.message.is_a?(Message::Channel::ControlChange) }
      end

      def tempo_changes
        @events.lazy.select { |e| e.is_a?(MetaEvent) && e.type == MetaEvent::META_TYPES[:tempo] }
      end

      def transpose(semitones)
        new_track = Track.new(name: @name, channel: @channel)
        @events.each do |event|
          if event.is_a?(MIDIEvent) && note_event?(event.message)
            msg = event.message
            new_note = (msg.note + semitones).clamp(0, 127)
            new_msg = msg.class.new(
              note: new_note,
              **msg.deconstruct_keys(nil).except(:note)
            )
            new_track << MIDIEvent.new(message: new_msg, delta_time: event.delta_time, absolute_time: event.absolute_time)
          else
            new_track << event
          end
        end
        new_track
      end

      private

      def note_event?(message)
        message.is_a?(Message::Channel::NoteOn) || message.is_a?(Message::Channel::NoteOff)
      end
    end
  end
end
