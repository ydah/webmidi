# frozen_string_literal: true

require "securerandom"

RSpec.describe Webmidi::Transport::Virtual do
  after { described_class.reset! }

  describe ".available?" do
    it "returns true" do
      expect(described_class.available?).to be true
    end
  end

  describe ".create_loopback" do
    it "sends messages from output to input" do
      input, output = described_class.create_loopback("Test Loopback")
      received = []
      input.on_data { |bytes| received << bytes }

      output.write([0x90, 60, 100])
      output.write([0x80, 60, 0])

      expect(received).to eq([[0x90, 60, 100], [0x80, 60, 0]])
    end

    it "does not duplicate connections" do
      input = described_class.create_virtual_input("Input")
      output = described_class.create_virtual_output("Output")
      received = []
      input.on_data { |bytes| received << bytes }

      output.connect(input)
      output.connect(input)
      output.write([0x90, 60, 100])

      expect(received).to eq([[0x90, 60, 100]])
    end
  end

  describe ".open_input / .open_output" do
    it "returns existing open virtual handles by device info" do
      input = described_class.create_virtual_input("Input")
      output = described_class.create_virtual_output("Output")

      expect(described_class.open_input(input.device_info)).to eq(input)
      expect(described_class.open_output(output.device_info)).to eq(output)
    end

    it "raises when the handle is missing or has the wrong direction" do
      input = described_class.create_virtual_input("Input")
      input.close

      expect { described_class.open_input(input.device_info) }
        .to raise_error(Webmidi::PortNotFoundError)
      expect { described_class.open_output(input.device_info) }
        .to raise_error(Webmidi::PortNotFoundError)
    end
  end

  describe "VirtualInputHandle" do
    it "can read pushed messages" do
      handle = described_class.create_virtual_input("Test Input")
      handle.receive([0x90, 60, 100])
      expect(handle.read).to eq([0x90, 60, 100])
    end

    it "returns nil when empty with non-blocking read" do
      handle = described_class.create_virtual_input("Test Input")
      expect(handle.read).to be_nil
    end
  end

  describe "VirtualOutputHandle" do
    it "records sent messages" do
      handle = described_class.create_virtual_output("Test Output")
      handle.write([0x90, 60, 100])
      expect(handle.sent_messages).to eq([[0x90, 60, 100]])
    end

    it "raises when closed" do
      handle = described_class.create_virtual_output("Test Output")
      handle.close
      expect { handle.write([0x90, 60, 100]) }.to raise_error(Webmidi::PortClosedError)
    end
  end

  describe ".list_inputs / .list_outputs" do
    it "lists created ports" do
      described_class.create_virtual_input("Input 1")
      described_class.create_virtual_output("Output 1")

      expect(described_class.list_inputs.size).to eq(1)
      expect(described_class.list_outputs.size).to eq(1)
      expect(described_class.list_inputs.first.name).to eq("Input 1")
    end

    it "removes closed ports from the registry" do
      input = described_class.create_virtual_input("Input 1")
      output = described_class.create_virtual_output("Output 1")
      input.close
      output.close

      expect(described_class.list_inputs).to be_empty
      expect(described_class.list_outputs).to be_empty
    end
  end
end
