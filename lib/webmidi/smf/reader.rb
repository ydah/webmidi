# frozen_string_literal: true

module Webmidi
  module SMF
    module Reader
      module_function

      def read(path_or_io, **options)
        data = if path_or_io.respond_to?(:read)
          path_or_io.read
        else
          File.binread(path_or_io)
        end
        parse(data, **options)
      end

      def parse(binary, skip_unknown_chunks: true, stop_at_end_of_track: true)
        binary = binary.b if binary.encoding != Encoding::ASCII_8BIT
        stream = StringStream.new(binary)

        format, num_tracks, ppqn = read_header(stream)
        sequence = Sequence.new(format: format, ppqn: ppqn)

        num_tracks.times do
          track = read_track(stream, skip_unknown_chunks: skip_unknown_chunks,
            stop_at_end_of_track: stop_at_end_of_track)
          sequence.add_track(track)
        end

        sequence
      end

      def read_header(stream)
        chunk_id = stream.read_bytes(4)
        raise InvalidSMFError, "Invalid SMF header: expected 'MThd'" unless chunk_id == "MThd"

        chunk_size = stream.read_uint32
        raise InvalidSMFError, "Invalid header size: #{chunk_size}" unless chunk_size == 6

        format = stream.read_uint16
        num_tracks = stream.read_uint16
        division = stream.read_uint16
        raise InvalidSMFError, "SMF format 0 must have exactly one track" if format.zero? && num_tracks != 1

        if (division & 0x8000).zero?
          ppqn = division
        else
          raise UnsupportedFormatError, "SMPTE time division is not supported"
        end

        [format, num_tracks, ppqn]
      end

      def read_track(stream, skip_unknown_chunks:, stop_at_end_of_track:) # rubocop:disable Metrics/MethodLength
        loop do
          chunk_id = stream.read_bytes(4)
          chunk_size = stream.read_uint32

          unless chunk_id == "MTrk"
            raise InvalidSMFError, "Invalid track header: expected 'MTrk', got '#{chunk_id}'" unless skip_unknown_chunks

            stream.skip(chunk_size)
            next
          end

          track_end = stream.position + chunk_size
          track = Track.new
          running_status = nil
          absolute_time = 0

          stream.with_limit(track_end) do
            while stream.position < track_end
              delta_time = stream.read_vlq
              absolute_time += delta_time

              status_byte = stream.peek_byte

              if status_byte >= 0x80
                stream.read_byte
                running_status = status_byte if status_byte < 0xF0
              else
                status_byte = running_status
                raise InvalidSMFError, "No running status available" unless status_byte
              end

              event = parse_event(stream, status_byte, delta_time, absolute_time)
              track << event if event
              if stop_at_end_of_track && end_of_track?(event)
                stream.skip(track_end - stream.position)
                break
              end
            end
          end

          return track
        end
      end

      def parse_event(stream, status_byte, delta_time, absolute_time)
        case status_byte
        when 0xFF
          parse_meta_event(stream, delta_time, absolute_time)
        when 0xF0, 0xF7
          parse_sysex_event(stream, delta_time, absolute_time)
        else
          parse_midi_event(stream, status_byte, delta_time, absolute_time)
        end
      end

      def parse_meta_event(stream, delta_time, absolute_time)
        type = stream.read_byte
        length = stream.read_vlq
        data = stream.read_raw_bytes(length)
        MetaEvent.new(type: type, data: data, delta_time: delta_time, absolute_time: absolute_time)
      end

      def parse_sysex_event(stream, delta_time, absolute_time)
        length = stream.read_vlq
        data = stream.read_raw_bytes(length)
        SysExEvent.new(data: data, delta_time: delta_time, absolute_time: absolute_time)
      end

      def parse_midi_event(stream, status_byte, delta_time, absolute_time) # rubocop:disable Metrics/MethodLength
        high = status_byte & 0xF0

        bytes = case high
        when 0xC0, 0xD0
          [status_byte, stream.read_byte]
        when 0x80, 0x90, 0xA0, 0xB0, 0xE0
          [status_byte, stream.read_byte, stream.read_byte]
        else
          raise InvalidSMFError, "Unknown MIDI status: #{format("0x%02X", status_byte)}"
        end

        message = Message.from_bytes(bytes, normalize_note_on_zero: false)
        MIDIEvent.new(message: message, delta_time: delta_time, absolute_time: absolute_time)
      end

      def end_of_track?(event)
        event.is_a?(MetaEvent) && event.type == MetaEvent::META_TYPES[:end_of_track]
      end

      private_class_method :read_header, :read_track, :parse_event,
        :parse_meta_event, :parse_sysex_event, :parse_midi_event,
        :end_of_track?

      class StringStream
        attr_reader :position

        def initialize(data)
          @data = data
          @position = 0
        end

        def read_bytes(n)
          ensure_available!(n)
          result = @data[@position, n]
          @position += n
          result
        end

        def read_raw_bytes(n)
          ensure_available!(n)
          result = @data[@position, n].bytes
          @position += n
          result
        end

        def read_byte
          ensure_available!(1)
          byte = @data.getbyte(@position)
          @position += 1
          byte
        end

        def peek_byte
          ensure_available!(1)
          @data.getbyte(@position)
        end

        def skip(n)
          ensure_available!(n)
          @position += n
        end

        def with_limit(limit)
          @limits ||= []
          @limits.push(limit)
          yield
        ensure
          @limits.pop
        end

        def read_uint16
          ensure_available!(2)
          val = (@data.getbyte(@position) << 8) | @data.getbyte(@position + 1)
          @position += 2
          val
        end

        def read_uint32
          ensure_available!(4)
          val = (@data.getbyte(@position) << 24) |
            (@data.getbyte(@position + 1) << 16) |
            (@data.getbyte(@position + 2) << 8) |
            @data.getbyte(@position + 3)
          @position += 4
          val
        end

        def read_vlq
          value = 0
          4.times do
            byte = read_byte
            value = (value << 7) | (byte & 0x7F)
            return value unless (byte & 0x80) != 0
          end

          raise InvalidSMFError, "VLQ exceeds 4 bytes"
        end

        private

        def ensure_available!(n)
          limit = [@data.bytesize, current_limit].min
          return if @position + n <= limit

          raise InvalidSMFError, "Unexpected end of data at position #{@position}, need #{n} more bytes"
        end

        def current_limit
          @limits&.last || @data.bytesize
        end
      end
    end
  end
end
