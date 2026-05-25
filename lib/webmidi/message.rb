# frozen_string_literal: true

require_relative "message/base"
require_relative "message/channel"
require_relative "message/system"
require_relative "message/parser"
require_relative "message/ump"
require_relative "music/note"

module Webmidi
  module Message
    DEFAULT_ARGUMENT = Object.new.freeze

    # Factory methods
    def self.note_on(note, velocity: DEFAULT_ARGUMENT, channel: DEFAULT_ARGUMENT, timestamp: nil)
      Channel::NoteOn.new(
        note: coerce_note(note),
        velocity: default_value(velocity, Webmidi.configuration.default_velocity),
        channel: default_value(channel, Webmidi.configuration.default_channel),
        timestamp: timestamp
      )
    end

    def self.note_off(note, velocity: 0, channel: DEFAULT_ARGUMENT, timestamp: nil)
      Channel::NoteOff.new(
        note: coerce_note(note),
        velocity: velocity,
        channel: default_value(channel, Webmidi.configuration.default_channel),
        timestamp: timestamp
      )
    end

    def self.control_change(cc, value, channel: DEFAULT_ARGUMENT, timestamp: nil)
      Channel::ControlChange.new(
        cc: cc,
        value: value,
        channel: default_value(channel, Webmidi.configuration.default_channel),
        timestamp: timestamp
      )
    end

    def self.program_change(program, channel: DEFAULT_ARGUMENT, timestamp: nil)
      Channel::ProgramChange.new(
        program: program,
        channel: default_value(channel, Webmidi.configuration.default_channel),
        timestamp: timestamp
      )
    end

    def self.channel_pressure(pressure, channel: DEFAULT_ARGUMENT, timestamp: nil)
      Channel::ChannelPressure.new(
        pressure: pressure,
        channel: default_value(channel, Webmidi.configuration.default_channel),
        timestamp: timestamp
      )
    end

    def self.polyphonic_pressure(note, pressure, channel: DEFAULT_ARGUMENT, timestamp: nil)
      Channel::PolyphonicPressure.new(
        note: coerce_note(note),
        pressure: pressure,
        channel: default_value(channel, Webmidi.configuration.default_channel),
        timestamp: timestamp
      )
    end

    def self.pitch_bend(value = Channel::PitchBend::CENTER, channel: DEFAULT_ARGUMENT, timestamp: nil)
      Channel::PitchBend.new(
        value: value,
        channel: default_value(channel, Webmidi.configuration.default_channel),
        timestamp: timestamp
      )
    end

    def self.pitch_bend_signed(value, channel: DEFAULT_ARGUMENT, timestamp: nil)
      Channel::PitchBend.from_signed(
        value,
        channel: default_value(channel, Webmidi.configuration.default_channel),
        timestamp: timestamp
      )
    end

    def self.sysex(*data, timestamp: nil)
      System::SysEx.new(data: data, timestamp: timestamp)
    end

    def self.clock(timestamp: nil)
      System::Clock.new(timestamp: timestamp)
    end

    def self.start(timestamp: nil)
      System::Start.new(timestamp: timestamp)
    end

    def self.continue(timestamp: nil)
      System::Continue.new(timestamp: timestamp)
    end

    def self.stop(timestamp: nil)
      System::Stop.new(timestamp: timestamp)
    end

    def self.active_sensing(timestamp: nil)
      System::ActiveSensing.new(timestamp: timestamp)
    end

    def self.system_reset(timestamp: nil)
      System::SystemReset.new(timestamp: timestamp)
    end

    def self.time_code(type, value, timestamp: nil)
      System::TimeCode.new(type: type, value: value, timestamp: timestamp)
    end

    def self.song_position(position, timestamp: nil)
      System::SongPosition.new(position: position, timestamp: timestamp)
    end

    def self.song_select(song, timestamp: nil)
      System::SongSelect.new(song: song, timestamp: timestamp)
    end

    def self.tune_request(timestamp: nil)
      System::TuneRequest.new(timestamp: timestamp)
    end

    def self.from_bytes(*bytes, normalize_note_on_zero: true)
      bytes = bytes.flatten
      Parser.parse_single(bytes, normalize_note_on_zero: normalize_note_on_zero)
    end

    def self.parse_many(bytes, normalize_note_on_zero: true)
      Parser.parse_many(bytes, normalize_note_on_zero: normalize_note_on_zero)
    end

    def self.upgrade(midi1_message, group: DEFAULT_ARGUMENT)
      UMP.upgrade(midi1_message, group: default_value(group, Webmidi.configuration.default_group))
    end

    def self.downgrade(midi2_message)
      UMP.downgrade(midi2_message)
    end

    def self.coerce_note(note)
      Music::Note.to_midi(note)
    end
    private_class_method :coerce_note

    def self.default_value(value, default)
      value.equal?(DEFAULT_ARGUMENT) ? default : value
    end
    private_class_method :default_value
  end
end
