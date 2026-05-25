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

    it "supports range policies" do
      expect { described_class.build(:B8, :major) }.to raise_error(Webmidi::InvalidMessageError)
      expect(described_class.build(:B8, :major, range: :clamp).last).to eq(127)
      expect(described_class.build(:B8, :major, range: :allow_out_of_range).last).to eq(130)
    end
  end

  describe ".define" do
    it "defines custom scale intervals" do
      described_class.define(:two_note, [0, 7])
      expect(described_class.build(:C4, :two_note)).to eq([60, 67])
    end
  end

  describe ".degree" do
    it "returns the nth degree" do
      expect(described_class.degree(:C4, :major, 1)).to eq(60) # C
      expect(described_class.degree(:C4, :major, 3)).to eq(64) # E
      expect(described_class.degree(:C4, :major, 5)).to eq(67) # G
    end

    it "is octave-aware" do
      expect(described_class.degree(:C4, :major, 8)).to eq(72)
      expect(described_class.degree(:C4, :major, 10)).to eq(76)
    end

    it "validates degree values" do
      expect { described_class.degree(:C4, :major, 0) }.to raise_error(Webmidi::InvalidMessageError)
    end
  end

  describe ".types" do
    it "lists available scale types" do
      expect(described_class.types).to include(:major, :minor, :blues, :pentatonic)
    end
  end
end
