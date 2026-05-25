# frozen_string_literal: true

RSpec.describe Webmidi::Middleware::Stack do
  it "executes middlewares in order" do
    log = []
    stack = described_class.new do
      use ->(msg, app) { log << "first"; app.call(msg) }
      use ->(msg, app) { log << "second"; app.call(msg) }
    end

    stack.call(Webmidi::Message.note_on(60))
    expect(log).to eq(%w[first second])
  end

  it "supports class-based middlewares" do
    stack = described_class.new do
      use Webmidi::Middleware::Transpose, semitones: 5
    end

    result = stack.call(Webmidi::Message.note_on(60))
    expect(result.note).to eq(65)
  end

  it "caches the built middleware chain" do
    built = 0
    middleware = Class.new(Webmidi::Middleware::Base) do
      define_method(:initialize) do |app, **options|
        built += 1
        super(app, **options)
      end
    end
    stack = described_class.new { use middleware }

    2.times { stack.call(Webmidi::Message.note_on(60)) }

    expect(built).to eq(1)
  end
end

RSpec.describe Webmidi::Middleware::Filter do
  it "filters by channel" do
    app = ->(msg) { msg }
    filter = described_class.new(app, channels: [0, 1])

    expect(filter.call(Webmidi::Message.note_on(60, channel: 0))).not_to be_nil
    expect(filter.call(Webmidi::Message.note_on(60, channel: 5))).to be_nil
  end

  it "filters by type" do
    app = ->(msg) { msg }
    filter = described_class.new(app, types: [Webmidi::Message::Channel::NoteOn])

    expect(filter.call(Webmidi::Message.note_on(60))).not_to be_nil
    expect(filter.call(Webmidi::Message.control_change(1, 64))).to be_nil
  end

  it "can exclude system messages when filtering by channel" do
    app = ->(msg) { msg }
    filter = described_class.new(app, channels: [0], include_system: false)

    expect(filter.call(Webmidi::Message.clock)).to be_nil
  end
end

RSpec.describe Webmidi::Middleware::Transpose do
  it "transposes notes" do
    app = ->(msg) { msg }
    transposer = described_class.new(app, semitones: 3)

    result = transposer.call(Webmidi::Message.note_on(60))
    expect(result.note).to eq(63)
  end

  it "clamps to 0-127" do
    app = ->(msg) { msg }
    transposer = described_class.new(app, semitones: 100)

    result = transposer.call(Webmidi::Message.note_on(60))
    expect(result.note).to eq(127)
  end

  it "does not affect non-note messages" do
    app = ->(msg) { msg }
    transposer = described_class.new(app, semitones: 3)

    msg = Webmidi::Message.control_change(1, 64)
    result = transposer.call(msg)
    expect(result).to eq(msg)
  end

  it "preserves timestamps" do
    app = ->(msg) { msg }
    transposer = described_class.new(app, semitones: 1)
    msg = Webmidi::Message.note_on(60)

    expect(transposer.call(msg).timestamp).to eq(msg.timestamp)
  end
end

RSpec.describe Webmidi::Middleware::VelocityScale do
  it "scales velocity linearly" do
    app = ->(msg) { msg }
    scaler = described_class.new(app, factor: 0.5)

    result = scaler.call(Webmidi::Message.note_on(60, velocity: 100))
    expect(result.velocity).to eq(50)
  end

  it "clamps to min/max" do
    app = ->(msg) { msg }
    scaler = described_class.new(app, factor: 2.0, max: 100)

    result = scaler.call(Webmidi::Message.note_on(60, velocity: 100))
    expect(result.velocity).to eq(100)
  end

  it "supports exponential curve" do
    app = ->(msg) { msg }
    scaler = described_class.new(app, factor: 1.0, curve: :exponential)

    result = scaler.call(Webmidi::Message.note_on(60, velocity: 90))
    expect(result.velocity).to be < 90
  end

  it "can leave note-off velocity unchanged" do
    app = ->(msg) { msg }
    scaler = described_class.new(app, factor: 2.0, include_note_off: false)
    msg = Webmidi::Message.note_off(60, velocity: 10)

    expect(scaler.call(msg)).to eq(msg)
  end

  it "validates options" do
    app = ->(msg) { msg }
    expect { described_class.new(app, factor: -1) }.to raise_error(Webmidi::InvalidMessageError)
    expect { described_class.new(app, min: 100, max: 10) }.to raise_error(Webmidi::InvalidMessageError)
    expect { described_class.new(app, curve: :unknown) }.to raise_error(Webmidi::InvalidMessageError)
  end
end

RSpec.describe Webmidi::Middleware::Logger do
  it "logs messages" do
    output = StringIO.new
    app = ->(msg) { msg }
    logger = described_class.new(app, output: output)

    logger.call(Webmidi::Message.note_on(60, velocity: 100))
    expect(output.string).to include("NoteOn")
    expect(output.string).to include("90 3C 64")
  end
end

RSpec.describe Webmidi::Middleware::Recorder do
  it "records messages" do
    recorder = described_class.new
    recorder.record do
      recorder.call(Webmidi::Message.note_on(60))
      recorder.call(Webmidi::Message.note_off(60))
    end

    expect(recorder.tape.message_count).to eq(2)
  end

  it "tracks recording state" do
    recorder = described_class.new
    expect(recorder.recording?).to be false

    recorder.record
    expect(recorder.recording?).to be true

    recorder.stop
    expect(recorder.recording?).to be false
  end

  it "stops recording when a block raises" do
    recorder = described_class.new
    expect do
      recorder.record { raise "boom" }
    end.to raise_error(RuntimeError, "boom")

    expect(recorder.recording?).to be false
  end
end
