# frozen_string_literal: true

RSpec.describe Webmidi::Virtual::Loopback do
  after { Webmidi::Transport::Virtual.reset! }

  it "routes output to input" do
    loopback = described_class.create(name: "Test Loopback")
    received = []
    loopback.input.on_message { |msg| received << msg }

    loopback.output.note_on(60, velocity: 100)

    expect(received.size).to eq(1)
    expect(received.first).to be_a(Webmidi::Message::Channel::NoteOn)
    expect(received.first.note).to eq(60)

    loopback.close
  end
end

RSpec.describe Webmidi::Virtual::Port do
  after { Webmidi::Transport::Virtual.reset! }

  describe ".create" do
    it "creates bidirectional port by default" do
      port = described_class.create(name: "Test")
      expect(port.input).to be_a(Webmidi::Port::Input)
      expect(port.output).to be_a(Webmidi::Port::Output)
      port.close
    end

    it "creates input-only port" do
      port = described_class.create(name: "Input Only", direction: :input)
      expect(port.input).to be_a(Webmidi::Port::Input)
      expect(port.output).to be_nil
      port.close
    end

    it "creates output-only port" do
      port = described_class.create(name: "Output Only", direction: :output)
      expect(port.input).to be_nil
      expect(port.output).to be_a(Webmidi::Port::Output)
      port.close
    end
  end
end
