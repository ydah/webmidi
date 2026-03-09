# frozen_string_literal: true

require_relative "music/note"
require_relative "music/chord"
require_relative "music/scale"
require_relative "music/rhythm"

module Webmidi
  module Music
    def note(name_or_number)
      Note.to_midi(name_or_number)
    end

    def chord(root, type = :major, inversion: 0)
      Chord.build(root, type, inversion: inversion)
    end

    def scale(root, type = :major)
      Scale.build(root, type)
    end

    module_function :note, :chord, :scale
  end
end
