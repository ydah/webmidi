# frozen_string_literal: true

require_relative "lib/webmidi/version"

Gem::Specification.new do |spec|
  spec.name = "webmidi"
  spec.version = Webmidi::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "A Ruby MIDI library inspired by the W3C Web MIDI API"
  spec.description = "Webmidi brings the W3C Web MIDI API design to Ruby with idiomatic DSL, " \
                     "MIDI message parsing, Standard MIDI File I/O, middleware pipeline, " \
                     "music theory DSL, network MIDI (RTP/OSC), and MIDI 2.0 UMP support."
  spec.homepage = "https://github.com/ydah/webmidi"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = "https://github.com/ydah/webmidi"
  spec.metadata["changelog_uri"] = "https://github.com/ydah/webmidi/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .idea/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
