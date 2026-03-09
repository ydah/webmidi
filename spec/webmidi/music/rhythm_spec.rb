# frozen_string_literal: true

RSpec.describe Webmidi::Music::Rhythm do
  describe ".duration_in_beats" do
    it "returns beats for standard durations" do
      expect(described_class.duration_in_beats(:whole)).to eq(4.0)
      expect(described_class.duration_in_beats(:half)).to eq(2.0)
      expect(described_class.duration_in_beats(:quarter)).to eq(1.0)
      expect(described_class.duration_in_beats(:eighth)).to eq(0.5)
      expect(described_class.duration_in_beats(:sixteenth)).to eq(0.25)
    end

    it "supports dotted durations" do
      expect(described_class.duration_in_beats(:dotted_quarter)).to eq(1.5)
    end

    it "raises on unknown duration" do
      expect { described_class.duration_in_beats(:invalid) }
        .to raise_error(Webmidi::InvalidMessageError)
    end
  end

  describe ".duration_in_ticks" do
    it "converts to ticks at 480 ppqn" do
      expect(described_class.duration_in_ticks(:quarter, ppqn: 480)).to eq(480)
      expect(described_class.duration_in_ticks(:half, ppqn: 480)).to eq(960)
      expect(described_class.duration_in_ticks(:eighth, ppqn: 480)).to eq(240)
    end
  end

  describe ".duration_in_seconds" do
    it "converts to seconds at given BPM" do
      expect(described_class.duration_in_seconds(:quarter, bpm: 120)).to eq(0.5)
      expect(described_class.duration_in_seconds(:half, bpm: 60)).to eq(2.0)
    end
  end

  describe ".beats_to_ticks / .ticks_to_beats" do
    it "converts between beats and ticks" do
      expect(described_class.beats_to_ticks(1.0, ppqn: 480)).to eq(480)
      expect(described_class.ticks_to_beats(480, ppqn: 480)).to eq(1.0)
    end
  end
end
