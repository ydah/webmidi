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

    it "validates bpm" do
      expect { described_class.new(bpm: 0) }.to raise_error(Webmidi::InvalidMessageError)
      expect { clock.bpm = -1 }.to raise_error(Webmidi::InvalidMessageError)
    end
  end

  describe "#start / #stop" do
    it "starts and stops" do
      clock.start
      expect(clock).to be_running
      clock.stop
      expect(clock).not_to be_running
    end

    it "is idempotent while running" do
      clock.start
      sleep 0.05
      before = clock.tick_count
      clock.start
      expect(clock.tick_count).to be >= before
      clock.stop
    end

    it "can stop from a callback" do
      clock.on_tick { clock.stop }
      clock.start
      sleep 0.05
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

    it "routes callback errors to on_error" do
      errors = []
      clock.on_tick { raise "boom" }
      clock.on_error { |error, tick| errors << [error.message, tick] }
      clock.start
      sleep 0.05
      clock.stop
      expect(errors.first.first).to eq("boom")
    end
  end

  describe "#tick_count / #beat_count" do
    it "starts at zero" do
      expect(clock.tick_count).to eq(0)
      expect(clock.beat_count).to eq(0)
    end
  end

  describe "#pipe_to" do
    it "sends MIDI clock messages to an output" do
      handle = Webmidi::Transport::Virtual.create_virtual_output("Clock Out")
      output = Webmidi::Port::Output.new(
        id: "clock-out",
        name: "Clock Out",
        manufacturer: "Test",
        version: "1.0",
        transport_handle: handle
      )

      clock.pipe_to(output)
      clock.start
      sleep 0.05
      clock.stop

      expect(handle.sent_messages).to include([0xF8])
    ensure
      Webmidi::Transport::Virtual.reset!
    end
  end

  describe "#start_message / #stop_message" do
    it "builds MIDI transport messages" do
      expect(clock.start_message).to be_a(Webmidi::Message::System::Start)
      expect(clock.stop_message).to be_a(Webmidi::Message::System::Stop)
    end
  end
end
