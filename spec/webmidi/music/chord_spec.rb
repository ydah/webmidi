# frozen_string_literal: true

RSpec.describe Webmidi::Music::Chord do
  describe ".build" do
    it "builds a C major chord" do
      expect(described_class.build(:C4, :major)).to eq([60, 64, 67])
    end

    it "builds a minor chord" do
      expect(described_class.build(:A4, :minor)).to eq([69, 72, 76])
    end

    it "builds a dominant 7th chord" do
      expect(described_class.build(:G4, :dom7)).to eq([67, 71, 74, 77])
    end

    it "supports inversions" do
      first = described_class.build(:C4, :major, inversion: 1)
      expect(first).to eq([64, 67, 72])
    end

    it "supports second inversion" do
      second = described_class.build(:C4, :major, inversion: 2)
      expect(second).to eq([67, 72, 76])
    end

    it "builds a power chord" do
      expect(described_class.build(:E4, :power)).to eq([64, 71])
    end

    it "raises on unknown type" do
      expect { described_class.build(:C4, :unknown) }
        .to raise_error(Webmidi::InvalidMessageError)
    end

    it "validates negative inversions" do
      expect { described_class.build(:C4, :major, inversion: -1) }
        .to raise_error(Webmidi::InvalidMessageError)
    end

    it "supports range policies" do
      expect { described_class.build(:D9, :major) }.to raise_error(Webmidi::InvalidMessageError)
      expect(described_class.build(:D9, :major, range: :clamp)).to eq([122, 126, 127])
      expect(described_class.build(:D9, :dom13, range: :allow_out_of_range).last).to eq(143)
    end
  end

  describe ".define" do
    it "defines custom chord intervals directly" do
      described_class.define(:quartal, [0, 5, 10])
      expect(described_class.build(:C4, :quartal)).to eq([60, 65, 70])
    end

    it "keeps block-based definitions working" do
      described_class.define(:stacked_fifths) { |_root| [0, 7, 14] }
      expect(described_class.build(:C4, :stacked_fifths)).to eq([60, 67, 74])
    end
  end

  describe ".types" do
    it "lists available chord types" do
      expect(described_class.types).to include(:major, :minor, :dom7)
    end
  end
end
