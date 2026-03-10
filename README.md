# Webmidi

A pure-Ruby MIDI library inspired by the [W3C Web MIDI API](https://www.w3.org/TR/webmidi/). Provides MIDI message handling, Standard MIDI File I/O, a middleware pipeline, music theory DSL, network MIDI, and MIDI 2.0 UMP support — all with zero runtime dependencies.

## Features

- **W3C Web MIDI API design** — `Access`, `Port::Input`, `Port::Output` modeled after the browser API
- **MIDI message parsing & generation** — All channel and system messages with round-trip byte conversion
- **Standard MIDI File (SMF)** — Read and write `.mid` files (Format 0 and 1)
- **Middleware pipeline** — Rack-like composable message processing (filter, transpose, velocity scale, logger, recorder)
- **Music theory DSL** — Note names, chords, scales, and rhythm utilities
- **Virtual ports** — Pure-Ruby virtual MIDI ports and loopback for testing
- **Network MIDI** — RTP-MIDI and OSC bridge
- **MIDI 2.0** — Universal MIDI Packet (UMP) with 1.0 ↔ 2.0 conversion
- **Pattern matching** — All messages support Ruby's `case/in` pattern matching
- **Thread-safe** — Mutex-protected port and transport operations

## Installation

Add this line to your application's Gemfile:

```ruby
gem "webmidi"
```

## Quick Start

```ruby
require "webmidi"

# Create a virtual loopback for testing
loopback = Webmidi::Virtual::Loopback.create(name: "My Loopback")

# Listen for messages
loopback.input.on_message do |msg|
  puts "Received: #{msg.class.name.split('::').last} - #{msg.to_hex}"
end

# Send messages
loopback.output.note_on(60, velocity: 100)
loopback.output.note_off(60)

loopback.close
```

## Usage

### Messages

```ruby
# Create messages
msg = Webmidi::Message.note_on(60, velocity: 100, channel: 0)
msg.to_bytes  # => [0x90, 0x3C, 0x64]
msg.to_hex    # => "90 3C 64"

# Parse from bytes
parsed = Webmidi::Message.from_bytes(0x90, 0x3C, 0x64)

# Pattern matching
case msg
in Webmidi::Message::Channel::NoteOn => note_on
  puts "Note: #{note_on.note}, Velocity: #{note_on.velocity}"
end
```

### Standard MIDI Files

```ruby
# Read a MIDI file
seq = Webmidi::SMF::Sequence.read("song.mid")
seq.tracks.each { |track| puts track.notes.count }

# Write a MIDI file
seq = Webmidi::SMF::Sequence.new(format: 0, ppqn: 480)
track = Webmidi::SMF::Track.new
track << Webmidi::SMF::MetaEvent.tempo(120)
track << Webmidi::SMF::MIDIEvent.new(
  message: Webmidi::Message.note_on(60, velocity: 100),
  delta_time: 0
)
track << Webmidi::SMF::MIDIEvent.new(
  message: Webmidi::Message.note_off(60),
  delta_time: 480
)
track << Webmidi::SMF::MetaEvent.end_of_track
seq.add_track(track)
seq.write("output.mid")
```

### Middleware Pipeline

```ruby
stack = Webmidi::Middleware::Stack.new do
  use Webmidi::Middleware::Logger, output: $stderr
  use Webmidi::Middleware::Filter, channels: [0, 1]
  use Webmidi::Middleware::Transpose, semitones: 3
  use Webmidi::Middleware::VelocityScale, factor: 0.8
end

result = stack.call(Webmidi::Message.note_on(60, velocity: 100))
```

### Music Theory DSL

```ruby
include Webmidi::Music

note(:C4)                    # => 60
note(:Fs4)                   # => 66

chord(:C4, :major)           # => [60, 64, 67]
chord(:Am4, :minor7)         # => [69, 72, 76, 79] (from A4)

scale(:C4, :major)           # => [60, 62, 64, 65, 67, 69, 71]
scale(:A4, :minor_pentatonic) # => [69, 72, 74, 76, 79]
```

### Network MIDI

```ruby
# RTP-MIDI
server = Webmidi::Network::RTP.server(port: 5004, name: "My Server")
server.start
server.on_message { |msg| puts msg.to_hex }

# OSC Bridge
bridge = Webmidi::Network::OSC.bridge(osc_host: "127.0.0.1", osc_port: 9000)
bridge.start
```

### MIDI 2.0

```ruby
# Upgrade MIDI 1.0 → 2.0
midi1 = Webmidi::Message.note_on(60, velocity: 100)
midi2 = Webmidi::Message.upgrade(midi1)

# Downgrade MIDI 2.0 → 1.0
back = Webmidi::Message.downgrade(midi2)
```

## Development

```bash
bundle install
bundle exec rake spec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/webmidi.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
