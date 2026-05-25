# frozen_string_literal: true

module Webmidi
  module Message
    module Parser
      CHANNEL_LENGTHS = {
        0x80 => 3,
        0x90 => 3,
        0xA0 => 3,
        0xB0 => 3,
        0xC0 => 2,
        0xD0 => 2,
        0xE0 => 3
      }.freeze

      SYSTEM_LENGTHS = {
        0xF1 => 2,
        0xF2 => 3,
        0xF3 => 2,
        0xF6 => 1,
        0xF8 => 1,
        0xFA => 1,
        0xFB => 1,
        0xFC => 1,
        0xFE => 1,
        0xFF => 1
      }.freeze

      REAL_TIME_STATUSES = [0xF8, 0xFA, 0xFB, 0xFC, 0xFE, 0xFF].freeze
      INVALID_SYSTEM_STATUSES = [0xF4, 0xF5, 0xF7, 0xF9, 0xFD].freeze

      module_function

      def parse_single(bytes, normalize_note_on_zero: true)
        bytes = validate_bytes!(bytes)
        raise InvalidMessageError, "Empty message" if bytes.empty?

        status = bytes[0]
        validate_status!(status)

        if status == 0xF0
          return parse_sysex(bytes)
        end

        validate_exact_length!(bytes, message_length(status))
        validate_data_bytes!(bytes[1..])

        case status & 0xF0
        when 0x80
          parse_note_off(bytes)
        when 0x90
          parse_note_on(bytes, normalize_note_on_zero: normalize_note_on_zero)
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
        end
      end

      def parse_many(bytes, normalize_note_on_zero: true)
        parse_stream(bytes, running_status: false, normalize_note_on_zero: normalize_note_on_zero)
      end

      def parse_stream(bytes, running_status: true, normalize_note_on_zero: true)
        bytes = validate_bytes!(bytes)
        messages = []
        pending = []
        needed = nil
        last_channel_status = nil

        bytes.each do |byte|
          if real_time_status?(byte)
            messages << parse_single([byte], normalize_note_on_zero: normalize_note_on_zero)
            next
          end

          if pending.empty?
            if byte < 0x80
              raise InvalidMessageError, "Data byte #{format_byte(byte)} without status" unless running_status && last_channel_status

              pending = [last_channel_status, byte]
              needed = message_length(last_channel_status)
            else
              validate_status!(byte)
              pending = [byte]
              needed = (byte == 0xF0) ? :sysex : message_length(byte)
              last_channel_status = channel_status?(byte) ? byte : nil
            end
          elsif needed == :sysex
            validate_sysex_data_or_end!(byte)
            pending << byte
          else
            raise InvalidMessageError, "Unexpected status byte #{format_byte(byte)} inside message" if byte >= 0x80

            pending << byte
          end

          next unless message_complete?(pending, needed)

          messages << parse_single(pending, normalize_note_on_zero: normalize_note_on_zero)
          pending = []
          needed = nil
        end

        raise_incomplete!(pending, needed) unless pending.empty?

        messages
      end

      def parse_note_off(bytes)
        Channel::NoteOff.new(
          note: bytes[1],
          velocity: bytes[2],
          channel: bytes[0] & 0x0F
        )
      end

      def parse_note_on(bytes, normalize_note_on_zero: true)
        if normalize_note_on_zero && bytes[2].zero?
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
        Channel::PolyphonicPressure.new(
          note: bytes[1],
          pressure: bytes[2],
          channel: bytes[0] & 0x0F
        )
      end

      def parse_control_change(bytes)
        Channel::ControlChange.new(
          cc: bytes[1],
          value: bytes[2],
          channel: bytes[0] & 0x0F
        )
      end

      def parse_program_change(bytes)
        Channel::ProgramChange.new(
          program: bytes[1],
          channel: bytes[0] & 0x0F
        )
      end

      def parse_channel_pressure(bytes)
        Channel::ChannelPressure.new(
          pressure: bytes[1],
          channel: bytes[0] & 0x0F
        )
      end

      def parse_pitch_bend(bytes)
        value = bytes[1] | (bytes[2] << 7)
        Channel::PitchBend.new(
          value: value,
          channel: bytes[0] & 0x0F
        )
      end

      def parse_system(bytes)
        case bytes[0]
        when 0xF1
          System::TimeCode.new(type: (bytes[1] >> 4) & 0x07, value: bytes[1] & 0x0F)
        when 0xF2
          System::SongPosition.new(position: bytes[1] | (bytes[2] << 7))
        when 0xF3
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
        end
      end

      def parse_sysex(bytes)
        raise InvalidMessageError, "SysEx message too short" if bytes.length < 2
        raise InvalidMessageError, "SysEx message must end with 0xF7" unless bytes.last == 0xF7

        bytes[1...-1].each { |byte| validate_sysex_data!(byte) }
        System::SysEx.new(data: bytes[1..-2])
      end

      def message_length(status)
        high = status & 0xF0
        CHANNEL_LENGTHS[high] || SYSTEM_LENGTHS[status] || invalid_status!(status)
      end

      def validate_bytes!(bytes)
        unless bytes.respond_to?(:each)
          raise InvalidMessageError, "MIDI bytes must be enumerable, got #{bytes.class}"
        end

        bytes.to_a.each_with_index do |byte, index|
          next if byte.is_a?(Integer) && byte.between?(0, 255)

          raise InvalidMessageError, "Byte at index #{index} must be between 0 and 255, got #{byte.inspect}"
        end
      end

      def validate_status!(status)
        raise InvalidMessageError, "Invalid status byte: #{format_byte(status)}" if status < 0x80

        invalid_status!(status) if INVALID_SYSTEM_STATUSES.include?(status)
      end

      def invalid_status!(status)
        if INVALID_SYSTEM_STATUSES.include?(status)
          raise InvalidMessageError, "Invalid system message status: #{format_byte(status)}"
        end

        raise InvalidMessageError, "Invalid status byte: #{format_byte(status)}"
      end

      def validate_exact_length!(bytes, expected)
        return if bytes.length == expected

        detail = (bytes.length < expected) ? "Expected" : "Expected exactly"
        raise InvalidMessageError,
          "#{detail} #{expected} bytes for #{format_byte(bytes[0])}, got #{bytes.length}"
      end

      def validate_sysex_data_or_end!(byte)
        return if byte == 0xF7

        validate_sysex_data!(byte)
      end

      def validate_sysex_data!(byte)
        return if byte.between?(0, 127)

        raise InvalidMessageError, "SysEx data byte must be between 0 and 127, got #{format_byte(byte)}"
      end

      def validate_data_bytes!(bytes)
        bytes.each_with_index do |byte, index|
          next if byte.between?(0, 127)

          raise InvalidMessageError, "Data byte at index #{index + 1} must be between 0 and 127, got #{format_byte(byte)}"
        end
      end

      def message_complete?(pending, needed)
        return pending.last == 0xF7 if needed == :sysex

        pending.length == needed
      end

      def raise_incomplete!(pending, needed)
        if needed == :sysex
          raise InvalidMessageError, "SysEx message must end with 0xF7"
        end

        raise InvalidMessageError,
          "Expected #{needed} bytes for #{format_byte(pending[0])}, got #{pending.length}"
      end

      def real_time_status?(byte)
        REAL_TIME_STATUSES.include?(byte)
      end

      def channel_status?(byte)
        (byte & 0xF0).between?(0x80, 0xE0)
      end

      def format_byte(byte)
        format("0x%02X", byte)
      end

      private_class_method :parse_note_off, :parse_note_on, :parse_polyphonic_pressure,
        :parse_control_change, :parse_program_change, :parse_channel_pressure,
        :parse_pitch_bend, :parse_system, :parse_sysex, :message_length,
        :validate_bytes!, :validate_status!, :invalid_status!,
        :validate_exact_length!, :validate_sysex_data_or_end!,
        :validate_sysex_data!, :validate_data_bytes!, :message_complete?, :raise_incomplete!,
        :real_time_status?, :channel_status?, :format_byte
    end
  end
end
