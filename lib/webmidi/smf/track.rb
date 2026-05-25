# frozen_string_literal: true

module Webmidi
  module SMF
    class Track
      include Enumerable

      NoteSpan = Struct.new(:note, :channel, :start_time, :end_time, :duration, :note_on, :note_off, keyword_init: true)

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

      def note_spans
        active = Hash.new { |hash, key| hash[key] = [] }
        spans = []
        use_delta_time = @events.all? { |event| event.absolute_time.zero? }
        tick = 0

        @events.each do |event|
          tick += event.delta_time
          next unless event.is_a?(MIDIEvent) && note_event?(event.message)

          time = use_delta_time ? tick : event.absolute_time
          message = event.message
          key = [message.channel, message.note]

          if message.is_a?(Message::Channel::NoteOn) && message.velocity.positive?
            active[key] << [event, time]
          elsif (started = active[key].shift)
            start_event, start_time = started
            spans << NoteSpan.new(
              note: message.note,
              channel: message.channel,
              start_time: start_time,
              end_time: time,
              duration: time - start_time,
              note_on: start_event,
              note_off: event
            )
          end
        end

        spans
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
            new_msg = msg.with(note: new_note)
            new_track << MIDIEvent.new(message: new_msg, delta_time: event.delta_time, absolute_time: event.absolute_time)
          else
            new_track << event
          end
        end
        new_track
      end

      def sort_by_absolute_time!
        @events.sort_by!(&:absolute_time)
        self
      end

      def recalculate_delta_times!
        sort_by_absolute_time!
        previous = 0
        @events.each do |event|
          event.delta_time = event.absolute_time - previous
          previous = event.absolute_time
        end
        self
      end

      def quantize!(grid)
        raise InvalidSMFError, "Quantize grid must be a positive integer, got #{grid.inspect}" unless grid.is_a?(Integer) && grid.positive?

        @events.each do |event|
          event.absolute_time = ((event.absolute_time.to_f / grid).round * grid).to_i
        end
        recalculate_delta_times!
      end

      private

      def note_event?(message)
        message.is_a?(Message::Channel::NoteOn) || message.is_a?(Message::Channel::NoteOff)
      end
    end
  end
end
