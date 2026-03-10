# frozen_string_literal: true

require_relative "message/base"
require_relative "message/channel"
require_relative "message/system"
require_relative "message/parser"
require_relative "message/ump"

module Webmidi
  module Message
    # Factory methods
    def self.note_on(note, velocity: 100, channel: 0)
      Channel::NoteOn.new(note: note, velocity: velocity, channel: channel)
    end

    def self.note_off(note, velocity: 0, channel: 0)
      Channel::NoteOff.new(note: note, velocity: velocity, channel: channel)
    end

    def self.control_change(cc, value, channel: 0)
      Channel::ControlChange.new(cc: cc, value: value, channel: channel)
    end

    def self.program_change(program, channel: 0)
      Channel::ProgramChange.new(program: program, channel: channel)
    end

    def self.channel_pressure(pressure, channel: 0)
      Channel::ChannelPressure.new(pressure: pressure, channel: channel)
    end

    def self.polyphonic_pressure(note, pressure, channel: 0)
      Channel::PolyphonicPressure.new(note: note, pressure: pressure, channel: channel)
    end

    def self.pitch_bend(value, channel: 0)
      Channel::PitchBend.new(value: value, channel: channel)
    end

    def self.sysex(*data)
      System::SysEx.new(data: data)
    end

    def self.clock
      System::Clock.new
    end

    def self.start
      System::Start.new
    end

    def self.continue
      System::Continue.new
    end

    def self.stop
      System::Stop.new
    end

    def self.active_sensing
      System::ActiveSensing.new
    end

    def self.system_reset
      System::SystemReset.new
    end

    def self.time_code(type, value)
      System::TimeCode.new(type: type, value: value)
    end

    def self.song_position(position)
      System::SongPosition.new(position: position)
    end

    def self.song_select(song)
      System::SongSelect.new(song: song)
    end

    def self.tune_request
      System::TuneRequest.new
    end

    def self.from_bytes(*bytes)
      bytes = bytes.flatten
      Parser.parse_single(bytes)
    end

    def self.upgrade(midi1_message)
      UMP.upgrade(midi1_message)
    end

    def self.downgrade(midi2_message)
      UMP.downgrade(midi2_message)
    end
  end
end
