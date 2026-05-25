# frozen_string_literal: true

RSpec.describe Webmidi::Music::Note do
  describe ".to_midi" do
    it "converts C4 to 60" do
      expect(described_class.to_midi("C4")).to eq(60)
      expect(described_class.to_midi(:C4)).to eq(60)
    end

    it "converts sharp notes" do
      expect(described_class.to_midi(:Fs4)).to eq(66)
      expect(described_class.to_midi("F#4")).to eq(66)
      expect(described_class.to_midi(:Cs4)).to eq(61)
    end

    it "converts flat notes" do
      expect(described_class.to_midi(:Bb3)).to eq(58)
      expect(described_class.to_midi("Eb4")).to eq(63)
    end

    it "passes through integers" do
      expect(described_class.to_midi(60)).to eq(60)
    end

    it "validates integer range by default" do
      expect { described_class.to_midi(200) }.to raise_error(Webmidi::InvalidMessageError)
      expect(described_class.to_midi(200, validate: false)).to eq(200)
    end

    it "handles negative octaves" do
      expect(described_class.to_midi("C-1")).to eq(0)
    end

    it "supports double accidentals" do
      expect(described_class.to_midi("C##4")).to eq(62)
      expect(described_class.to_midi("Dbb4")).to eq(60)
    end

    it "raises on invalid input" do
      expect { described_class.to_midi("XY") }.to raise_error(Webmidi::InvalidMessageError)
    end
  end

  describe ".to_name" do
    it "converts 60 to C4" do
      expect(described_class.to_name(60)).to eq("C4")
    end

    it "converts 69 to A4" do
      expect(described_class.to_name(69)).to eq("A4")
    end

    it "supports flats" do
      expect(described_class.to_name(61, sharps: false)).to eq("Db4")
    end

    it "validates MIDI note range" do
      expect { described_class.to_name(128) }.to raise_error(Webmidi::InvalidMessageError)
    end
  end

  describe ".to_frequency" do
    it "converts A4 to 440Hz" do
      expect(described_class.to_frequency(69)).to be_within(0.01).of(440.0)
    end

    it "converts C4 to ~261.63Hz" do
      expect(described_class.to_frequency(60)).to be_within(0.01).of(261.63)
    end

    it "validates inputs" do
      expect { described_class.to_frequency(128) }.to raise_error(Webmidi::InvalidMessageError)
      expect { described_class.to_frequency(60, a4: 0) }.to raise_error(Webmidi::InvalidMessageError)
    end
  end

  describe ".from_frequency" do
    it "converts 440Hz to A4" do
      expect(described_class.from_frequency(440.0)).to eq(69)
    end

    it "validates inputs" do
      expect { described_class.from_frequency(0) }.to raise_error(Webmidi::InvalidMessageError)
      expect { described_class.from_frequency(440.0, a4: -1) }.to raise_error(Webmidi::InvalidMessageError)
    end
  end
end
