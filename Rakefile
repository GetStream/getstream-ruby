# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

# RSpec tasks
RSpec::Core::RakeTask.new(:spec)
RSpec::Core::RakeTask.new(:test_unit) do |t|

  t.pattern = 'spec/**/*_spec.rb'
  t.exclude_pattern = 'spec/integration/**/*_spec.rb'

end

RSpec::Core::RakeTask.new(:test_integration) do |t|

  t.pattern = 'spec/integration/**/*_spec.rb'

end

# RuboCop tasks
begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new(:rubocop)
  RuboCop::RakeTask.new(:rubocop_fix) do |task|

    task.options = ['-A']

  end
rescue LoadError
  # RuboCop not available
end

# Documentation tasks
begin
  require 'yard'
  YARD::Rake::YardocTask.new(:docs) do |t|

    t.files = ['lib/**/*.rb', 'README.md']
    t.options = ['--output-dir', 'doc']

  end
rescue LoadError
  # YARD not available
end

# Security audit task
task :security do

  sh 'bundle audit'

end

# Clean task
task :clean do

  rm_rf 'coverage'
  rm_rf 'tmp'
  rm_rf '.rspec_status'
  rm_rf 'doc'
  rm_rf 'rubocop-report.*'
  Dir.glob('*.gem').each { |f| rm_f f }
  Dir.glob('*.rbc').each { |f| rm_f f }

end

# Version task
task :version do

  require_relative 'lib/getstream_ruby/version'
  puts GetStreamRuby::VERSION

end

# Release tasks
namespace :release do

  desc 'Release major version'
  task :major do

    sh 'make release-major'

  end

  desc 'Release minor version'
  task :minor do

    sh 'make release-minor'

  end

  desc 'Release patch version'
  task :patch do

    sh 'make release-patch'

  end

end

# Test tasks
namespace :test do

  desc 'Run unit tests only'
  task unit: :test_unit

  desc 'Run integration tests only'
  task integration: :test_integration

  desc 'Run all tests'
  task all: [:test_unit, :test_integration]

end

# Format tasks
namespace :format do

  desc 'Check code formatting'
  task :check do

    sh 'make format-check'

  end

  desc 'Fix code formatting'
  task :fix do

    sh 'make format-fix'

  end

  desc 'Show formatting differences'
  task :diff do

    sh 'make format-diff'

  end

end

# Default task
task default: :spec

# Help task
desc 'Show available tasks'
task :help do

  puts 'Available tasks:'
  puts '  rake spec              - Run all tests'
  puts '  rake test:unit         - Run unit tests only'
  puts '  rake test:integration  - Run integration tests only'
  puts '  rake test:all          - Run all tests'
  puts '  rake rubocop           - Run RuboCop linter'
  puts '  rake rubocop_fix       - Auto-fix RuboCop issues'
  puts '  rake format:check      - Check code formatting'
  puts '  rake format:fix        - Fix code formatting'
  puts '  rake format:diff       - Show formatting differences'
  puts '  rake docs              - Generate documentation'
  puts '  rake security          - Run security audit'
  puts '  rake clean             - Clean generated files'
  puts '  rake version           - Show current version'
  puts '  rake release:major     - Release major version'
  puts '  rake release:minor     - Release minor version'
  puts '  rake release:patch     - Release patch version'
  puts ''
  puts 'For more detailed help, run: make help'

end
