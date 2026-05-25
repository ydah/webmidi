# frozen_string_literal: true

require "stringio"

module Webmidi
  module SMF
    module Writer
      module_function

      def write(sequence, path_or_io, **options)
        binary = to_binary(sequence, **options)
        if path_or_io.respond_to?(:write)
          path_or_io.write(binary)
        else
          File.binwrite(path_or_io, binary)
        end
      end

      def to_binary(sequence, running_status: false)
        validate_sequence!(sequence)
        out = StringIO.new(String.new(encoding: Encoding::ASCII_8BIT))
        write_header(out, sequence)
        sequence.each { |track| write_track(out, track, running_status: running_status) }
        out.string
      end

      def write_header(out, sequence)
        out.write("MThd")
        write_uint32(out, 6)
        write_uint16(out, sequence.format)
        write_uint16(out, sequence.size)
        write_uint16(out, sequence.ppqn)
      end

      def write_track(out, track, running_status: false)
        track_data = StringIO.new(String.new(encoding: Encoding::ASCII_8BIT))
        has_end_of_track = false
        last_status = nil

        track.each do |event|
          write_vlq(track_data, event.delta_time)

          case event
          when MetaEvent
            track_data.putc(0xFF)
            track_data.putc(event.type)
            write_vlq(track_data, event.data.size)
            event.data.each { |b| track_data.putc(b) }
            has_end_of_track = true if event.type == MetaEvent::META_TYPES[:end_of_track]
            last_status = nil
          when SysExEvent
            data = event.data.last == 0xF7 ? event.data : [*event.data, 0xF7]
            track_data.putc(0xF0)
            write_vlq(track_data, data.size)
            data.each { |b| track_data.putc(b) }
            last_status = nil
          when MIDIEvent
            bytes = event.to_bytes
            if running_status && channel_status?(bytes[0]) && last_status == bytes[0]
              bytes[1..].each { |b| track_data.putc(b) }
            else
              bytes.each { |b| track_data.putc(b) }
              last_status = channel_status?(bytes[0]) ? bytes[0] : nil
            end
          end
        end

        unless has_end_of_track
          write_vlq(track_data, 0)
          track_data.putc(0xFF)
          track_data.putc(0x2F)
          write_vlq(track_data, 0)
        end

        track_bytes = track_data.string
        out.write("MTrk")
        write_uint32(out, track_bytes.bytesize)
        out.write(track_bytes)
      end

      def write_uint16(out, value)
        out.putc((value >> 8) & 0xFF)
        out.putc(value & 0xFF)
      end

      def write_uint32(out, value)
        out.putc((value >> 24) & 0xFF)
        out.putc((value >> 16) & 0xFF)
        out.putc((value >> 8) & 0xFF)
        out.putc(value & 0xFF)
      end

      def write_vlq(out, value)
        unless value.is_a?(Integer) && value.between?(0, 0x0FFF_FFFF)
          raise InvalidSMFError, "VLQ value must be between 0 and 0x0FFFFFFF, got #{value.inspect}"
        end

        bytes = [value & 0x7F]
        value >>= 7
        while value > 0
          bytes.unshift((value & 0x7F) | 0x80)
          value >>= 7
        end
        bytes.each { |b| out.putc(b) }
      end

      def validate_sequence!(sequence)
        if sequence.format.zero? && sequence.size != 1
          raise InvalidSMFError, "SMF format 0 must contain exactly one track"
        end
      end

      def channel_status?(status)
        status < 0xF0
      end

      private_class_method :write_header, :write_track, :write_uint16, :write_uint32, :write_vlq,
                           :validate_sequence!, :channel_status?
    end
  end
end
