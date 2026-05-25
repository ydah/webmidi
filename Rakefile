# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "tmpdir"

RSpec::Core::RakeTask.new(:spec)

task :smoke_require do
  ruby "-Ilib", "-e", "require 'webmidi'"
end

task :build_gem do
  Dir.mktmpdir("webmidi-gem-build") do |dir|
    sh "gem build webmidi.gemspec --output #{File.join(dir, "webmidi.gem")}"
  end
end

namespace :release do
  task check: [:spec, :smoke_require, :build_gem] do
    spec = Gem::Specification.load("webmidi.gemspec")
    raise "Missing version" if spec.version.to_s.empty?
    raise "CHANGELOG.md is missing" unless File.exist?("CHANGELOG.md")
    raise "MFA metadata is required" unless spec.metadata["rubygems_mfa_required"] == "true"
    raise "gemspec must be included in package files" unless spec.files.include?("webmidi.gemspec")
  end
end

task default: :spec
