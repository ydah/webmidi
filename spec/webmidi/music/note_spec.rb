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

    it "handles negative octaves" do
      expect(described_class.to_midi("C-1")).to eq(0)
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
  end

  describe ".to_frequency" do
    it "converts A4 to 440Hz" do
      expect(described_class.to_frequency(69)).to be_within(0.01).of(440.0)
    end

    it "converts C4 to ~261.63Hz" do
      expect(described_class.to_frequency(60)).to be_within(0.01).of(261.63)
    end
  end

  describe ".from_frequency" do
    it "converts 440Hz to A4" do
      expect(described_class.from_frequency(440.0)).to eq(69)
    end
  end
end
