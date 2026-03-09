# frozen_string_literal: true

RSpec.describe Webmidi::Music::Scale do
  describe ".build" do
    it "builds a C major scale" do
      expect(described_class.build(:C4, :major)).to eq([60, 62, 64, 65, 67, 69, 71])
    end

    it "builds a minor pentatonic scale" do
      expect(described_class.build(:A4, :minor_pentatonic)).to eq([69, 72, 74, 76, 79])
    end

    it "builds a blues scale" do
      expect(described_class.build(:E4, :blues)).to eq([64, 67, 69, 70, 71, 74])
    end

    it "builds a dorian scale" do
      expect(described_class.build(:D4, :dorian)).to eq([62, 64, 65, 67, 69, 71, 72])
    end

    it "raises on unknown type" do
      expect { described_class.build(:C4, :unknown) }
        .to raise_error(Webmidi::InvalidMessageError)
    end
  end

  describe ".degree" do
    it "returns the nth degree" do
      expect(described_class.degree(:C4, :major, 1)).to eq(60) # C
      expect(described_class.degree(:C4, :major, 3)).to eq(64) # E
      expect(described_class.degree(:C4, :major, 5)).to eq(67) # G
    end
  end

  describe ".types" do
    it "lists available scale types" do
      expect(described_class.types).to include(:major, :minor, :blues, :pentatonic)
    end
  end
end
