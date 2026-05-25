# frozen_string_literal: true

module Webmidi
  module Message
    module System
      class Base < Message::Base
      end

      class SysEx < Base
        attr_reader :data

        def initialize(data:, timestamp: nil)
          unless data.respond_to?(:each)
            raise InvalidMessageError, "SysEx data must be enumerable, got #{data.class}"
          end

          data.each_with_index do |byte, i|
            unless byte.is_a?(Integer) && byte.between?(0, 127)
              raise InvalidMessageError, "SysEx data byte at index #{i} must be between 0 and 127, got #{byte.inspect}"
            end
          end
          @data = data.dup.freeze
          super(timestamp: timestamp)
        end

        def to_bytes
          [0xF0, *@data, 0xF7]
        end

        def deconstruct_keys(keys)
          { data: @data }
        end

        def chunks(max_data_bytes:)
          self.class.split(self, max_data_bytes: max_data_bytes)
        end

        def self.split(data, max_data_bytes:)
          unless max_data_bytes.is_a?(Integer) && max_data_bytes.positive?
            raise InvalidMessageError, "max_data_bytes must be a positive integer, got #{max_data_bytes.inspect}"
          end

          bytes = data.is_a?(self) ? data.data : data
          bytes.each_slice(max_data_bytes).map { |slice| new(data: slice) }
        end

        def self.join(messages)
          data = messages.flat_map do |message|
            message.is_a?(self) ? message.data : message
          end
          new(data: data)
        end
      end

      class TimeCode < Base
        attr_reader :type, :value

        def initialize(type:, value:, timestamp: nil)
          unless type.is_a?(Integer) && type.between?(0, 7)
            raise InvalidMessageError, "TimeCode type must be between 0 and 7, got #{type.inspect}"
          end
          unless value.is_a?(Integer) && value.between?(0, 15)
            raise InvalidMessageError, "TimeCode value must be between 0 and 15, got #{value.inspect}"
          end
          @type = type
          @value = value
          super(timestamp: timestamp)
        end

        def to_bytes
          [0xF1, (@type << 4) | @value]
        end

        def deconstruct_keys(keys)
          { type: @type, value: @value }
        end
      end

      class SongPosition < Base
        attr_reader :position

        def initialize(position:, timestamp: nil)
          unless position.is_a?(Integer) && position.between?(0, 16383)
            raise InvalidMessageError, "Song position must be between 0 and 16383, got #{position.inspect}"
          end
          @position = position
          super(timestamp: timestamp)
        end

        def to_bytes
          [0xF2, @position & 0x7F, (@position >> 7) & 0x7F]
        end

        def deconstruct_keys(keys)
          { position: @position }
        end
      end

      class SongSelect < Base
        attr_reader :song

        def initialize(song:, timestamp: nil)
          unless song.is_a?(Integer) && song.between?(0, 127)
            raise InvalidMessageError, "Song number must be between 0 and 127, got #{song.inspect}"
          end
          @song = song
          super(timestamp: timestamp)
        end

        def to_bytes
          [0xF3, @song]
        end

        def deconstruct_keys(keys)
          { song: @song }
        end
      end

      class TuneRequest < Base
        def to_bytes
          [0xF6]
        end
      end

      class Clock < Base
        def to_bytes
          [0xF8]
        end
      end

      class Start < Base
        def to_bytes
          [0xFA]
        end
      end

      class Continue < Base
        def to_bytes
          [0xFB]
        end
      end

      class Stop < Base
        def to_bytes
          [0xFC]
        end
      end

      class ActiveSensing < Base
        def to_bytes
          [0xFE]
        end
      end

      class SystemReset < Base
        def to_bytes
          [0xFF]
        end
      end
    end
  end
end
