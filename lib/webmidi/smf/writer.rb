# frozen_string_literal: true

require "stringio"

module Webmidi
  module SMF
    module Writer
      module_function

      def write(sequence, path_or_io)
        binary = to_binary(sequence)
        if path_or_io.respond_to?(:write)
          path_or_io.write(binary)
        else
          File.binwrite(path_or_io, binary)
        end
      end

      def to_binary(sequence)
        out = StringIO.new(String.new(encoding: Encoding::ASCII_8BIT))
        write_header(out, sequence)
        sequence.each { |track| write_track(out, track) }
        out.string
      end

      def write_header(out, sequence)
        out.write("MThd")
        write_uint32(out, 6)
        write_uint16(out, sequence.format)
        write_uint16(out, sequence.size)
        write_uint16(out, sequence.ppqn)
      end

      def write_track(out, track)
        track_data = StringIO.new(String.new(encoding: Encoding::ASCII_8BIT))
        has_end_of_track = false

        track.each do |event|
          write_vlq(track_data, event.delta_time)

          case event
          when MetaEvent
            track_data.putc(0xFF)
            track_data.putc(event.type)
            write_vlq(track_data, event.data.size)
            event.data.each { |b| track_data.putc(b) }
            has_end_of_track = true if event.type == MetaEvent::META_TYPES[:end_of_track]
          when SysExEvent
            track_data.putc(0xF0)
            write_vlq(track_data, event.data.size)
            event.data.each { |b| track_data.putc(b) }
          when MIDIEvent
            event.to_bytes.each { |b| track_data.putc(b) }
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
        bytes = [value & 0x7F]
        value >>= 7
        while value > 0
          bytes.unshift((value & 0x7F) | 0x80)
          value >>= 7
        end
        bytes.each { |b| out.putc(b) }
      end

      private_class_method :write_header, :write_track, :write_uint16, :write_uint32, :write_vlq
    end
  end
end
