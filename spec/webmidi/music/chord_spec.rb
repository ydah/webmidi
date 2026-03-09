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
  end

  describe ".types" do
    it "lists available chord types" do
      expect(described_class.types).to include(:major, :minor, :dom7)
    end
  end
end
