# frozen_string_literal: true

RSpec.describe Webmidi::Access do
  after { Webmidi::Transport::Virtual.reset! }

  subject(:access) { described_class.new(transport: Webmidi::Transport::Virtual) }

  describe "#inputs / #outputs" do
    it "returns Port::Map instances" do
      expect(access.inputs).to be_a(Webmidi::Port::Map)
      expect(access.outputs).to be_a(Webmidi::Port::Map)
    end
  end

  describe "#create_input" do
    it "creates and registers a virtual input port" do
      port = access.create_input("My Input")
      expect(port).to be_a(Webmidi::Port::Input)
      expect(access.input("My Input")).to eq(port)
    end
  end

  describe "#create_output" do
    it "creates and registers a virtual output port" do
      port = access.create_output("My Output")
      expect(port).to be_a(Webmidi::Port::Output)
      expect(access.output("My Output")).to eq(port)
    end
  end

  describe "#sysex_enabled?" do
    it "defaults to false" do
      expect(access.sysex_enabled?).to be false
    end

    it "can be enabled" do
      access = described_class.new(sysex: true, transport: Webmidi::Transport::Virtual)
      expect(access.sysex_enabled?).to be true
    end
  end

  describe "#close" do
    it "closes all ports" do
      input = access.create_input("In")
      output = access.create_output("Out")
      input.open
      output.open
      access.close
      expect(input).not_to be_open
      expect(output).not_to be_open
    end
  end

  describe "#each" do
    it "iterates over all ports" do
      access.create_input("In")
      access.create_output("Out")
      ports = access.to_a
      expect(ports.size).to eq(2)
    end
  end
end

RSpec.describe Webmidi do
  after { Webmidi::Transport::Virtual.reset! }

  describe ".request_access" do
    it "returns an Access instance" do
      access = described_class.request_access
      expect(access).to be_a(Webmidi::Access)
    end

    it "yields to block and cleans up" do
      yielded = nil
      described_class.request_access do |access|
        yielded = access
        access.create_input("Test")
      end
      expect(yielded).to be_a(Webmidi::Access)
    end
  end
end
