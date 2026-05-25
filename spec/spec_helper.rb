# frozen_string_literal: true

if ENV["COVERAGE"]
  begin
    require "simplecov"
    SimpleCov.start do
      add_filter "/spec/"
      enable_coverage :branch
    end
  rescue LoadError
    require "coverage"
    require "fileutils"
    Coverage.start(lines: true, branches: true)
    at_exit do
      lib_root = File.expand_path("../lib", __dir__)
      covered = 0
      executable = 0

      Coverage.result.each do |path, result|
        next unless path.start_with?(lib_root)

        lines = result.fetch(:lines)
        executable_lines = lines.compact
        executable += executable_lines.size
        covered += executable_lines.count(&:positive?)
      end

      percent = executable.zero? ? 100.0 : ((covered.to_f / executable) * 100).round(2)
      FileUtils.mkdir_p("coverage")
      File.write("coverage/coverage.txt", "Line coverage: #{percent}% (#{covered}/#{executable})\n")
      warn "Line coverage: #{percent}% (#{covered}/#{executable})"
    end
  end
end

require "webmidi"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
