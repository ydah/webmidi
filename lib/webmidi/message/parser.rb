# frozen_string_literal: true

module Webmidi
  module Message
    module Parser
      module_function

      def parse_single(bytes) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
        raise InvalidMessageError, "Empty message" if bytes.empty?

        status = bytes[0]

        case status & 0xF0
        when 0x80
          parse_note_off(bytes)
        when 0x90
          parse_note_on(bytes)
        when 0xA0
          parse_polyphonic_pressure(bytes)
        when 0xB0
          parse_control_change(bytes)
        when 0xC0
          parse_program_change(bytes)
        when 0xD0
          parse_channel_pressure(bytes)
        when 0xE0
          parse_pitch_bend(bytes)
        when 0xF0
          parse_system(bytes)
        else
          raise InvalidMessageError, "Invalid status byte: #{format("0x%02X", status)}"
        end
      end

      def parse_note_off(bytes)
        validate_length!(bytes, 3)
        Channel::NoteOff.new(
          note: bytes[1],
          velocity: bytes[2],
          channel: bytes[0] & 0x0F
        )
      end

      def parse_note_on(bytes)
        validate_length!(bytes, 3)
        if bytes[2].zero?
          Channel::NoteOff.new(
            note: bytes[1],
            velocity: 0,
            channel: bytes[0] & 0x0F
          )
        else
          Channel::NoteOn.new(
            note: bytes[1],
            velocity: bytes[2],
            channel: bytes[0] & 0x0F
          )
        end
      end

      def parse_polyphonic_pressure(bytes)
        validate_length!(bytes, 3)
        Channel::PolyphonicPressure.new(
          note: bytes[1],
          pressure: bytes[2],
          channel: bytes[0] & 0x0F
        )
      end

      def parse_control_change(bytes)
        validate_length!(bytes, 3)
        Channel::ControlChange.new(
          cc: bytes[1],
          value: bytes[2],
          channel: bytes[0] & 0x0F
        )
      end

      def parse_program_change(bytes)
        validate_length!(bytes, 2)
        Channel::ProgramChange.new(
          program: bytes[1],
          channel: bytes[0] & 0x0F
        )
      end

      def parse_channel_pressure(bytes)
        validate_length!(bytes, 2)
        Channel::ChannelPressure.new(
          pressure: bytes[1],
          channel: bytes[0] & 0x0F
        )
      end

      def parse_pitch_bend(bytes)
        validate_length!(bytes, 3)
        value = bytes[1] | (bytes[2] << 7)
        Channel::PitchBend.new(
          value: value,
          channel: bytes[0] & 0x0F
        )
      end

      def parse_system(bytes) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
        status = bytes[0]

        case status
        when 0xF0
          parse_sysex(bytes)
        when 0xF1
          validate_length!(bytes, 2)
          System::TimeCode.new(type: (bytes[1] >> 4) & 0x07, value: bytes[1] & 0x0F)
        when 0xF2
          validate_length!(bytes, 3)
          System::SongPosition.new(position: bytes[1] | (bytes[2] << 7))
        when 0xF3
          validate_length!(bytes, 2)
          System::SongSelect.new(song: bytes[1])
        when 0xF6
          System::TuneRequest.new
        when 0xF8
          System::Clock.new
        when 0xFA
          System::Start.new
        when 0xFB
          System::Continue.new
        when 0xFC
          System::Stop.new
        when 0xFE
          System::ActiveSensing.new
        when 0xFF
          System::SystemReset.new
        else
          raise InvalidMessageError, "Invalid system message status: #{format("0x%02X", status)}"
        end
      end

      def parse_sysex(bytes)
        raise InvalidMessageError, "SysEx message must end with 0xF7" unless bytes.last == 0xF7
        raise InvalidMessageError, "SysEx message too short" if bytes.length < 2

        System::SysEx.new(data: bytes[1..-2])
      end

      def validate_length!(bytes, expected)
        return if bytes.length >= expected

        raise InvalidMessageError,
              "Expected #{expected} bytes for #{format("0x%02X", bytes[0])}, got #{bytes.length}"
      end

      private_class_method :parse_note_off, :parse_note_on, :parse_polyphonic_pressure,
                           :parse_control_change, :parse_program_change, :parse_channel_pressure,
                           :parse_pitch_bend, :parse_system, :parse_sysex, :validate_length!
    end
  end
end
