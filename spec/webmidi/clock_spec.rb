# frozen_string_literal: true

RSpec.describe Webmidi::Clock do
  subject(:clock) { described_class.new(bpm: 120) }

  describe "#bpm" do
    it "has a default bpm" do
      expect(clock.bpm).to eq(120)
    end

    it "can change bpm" do
      clock.bpm = 140
      expect(clock.bpm).to eq(140)
    end
  end

  describe "#start / #stop" do
    it "starts and stops" do
      clock.start
      expect(clock).to be_running
      clock.stop
      expect(clock).not_to be_running
    end
  end

  describe "#on_tick" do
    it "calls back on ticks" do
      ticks = []
      clock.on_tick { |t| ticks << t }
      clock.start
      sleep 0.15
      clock.stop
      expect(ticks).not_to be_empty
    end
  end

  describe "#tick_count / #beat_count" do
    it "starts at zero" do
      expect(clock.tick_count).to eq(0)
      expect(clock.beat_count).to eq(0)
    end
  end
end
