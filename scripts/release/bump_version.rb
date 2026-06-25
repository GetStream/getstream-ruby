#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'

def run_command(command)
  `#{command}`.to_s.strip
end

def find_latest_semver_tag
  tags = run_command('git tag --list').split(/\R/)
  versions = tags.map(&:strip).map { |tag| tag.sub(/^v/, '') }.grep(/^\d+\.\d+\.\d+$/)
  return '0.0.0' if versions.empty?

  versions.max_by { |version| version.split('.').map(&:to_i) }
end

def determine_bump_type(title)
  # Breaking changes are signalled only by the `!` marker in the title
  # (e.g. `feat!:`). Free-text body/title prose is not trusted: a PR that
  # merely mentions "BREAKING CHANGE" must not force a major bump.
  match = title.strip.match(/^([a-z]+)(\([^)]+\))?(!)?:/i)
  return 'none' unless match

  type = match[1].downcase
  return 'major' if match[3] == '!'
  return 'minor' if type == 'feat'
  return 'patch' if %w[fix bug].include?(type)

  'none'
end

def increment_version(version, bump)
  major, minor, patch = version.split('.').map(&:to_i)

  case bump
  when 'major'
    "#{major + 1}.0.0"
  when 'minor'
    "#{major}.#{minor + 1}.0"
  when 'patch'
    "#{major}.#{minor}.#{patch + 1}"
  else
    version
  end
end

def read_version_file(path)
  content = File.read(path)
  match = content.match(/VERSION\s*=\s*'([^']+)'/)
  raise "Could not find VERSION in #{path}" unless match

  match[1]
end

def update_version_file(path, version)
  content = File.read(path)
  updated = content.sub(/VERSION = '[^']+'/, "VERSION = '#{version}'")
  raise "Could not update VERSION in #{path}" if updated == content

  File.write(path, updated)
end

def write_outputs(output_path, values)
  lines = "#{values.map { |k, v| "#{k}=#{v}" }.join("\n")}\n"
  if output_path.empty?
    print(lines)
    return
  end

  File.open(output_path, 'a') { |file| file.write(lines) }
end

def truthy?(value)
  value.to_s.strip.downcase == 'true'
end

options = {
  title: '',
  output: '',
  manual_bump: '',
  use_current_version: 'false',
}

OptionParser.new do |opts|

  opts.on('--title TITLE') { |value| options[:title] = value }
  opts.on('--output FILE') { |value| options[:output] = value }
  opts.on('--manual-bump TYPE') { |value| options[:manual_bump] = value }
  opts.on('--use-current-version VAL') { |value| options[:use_current_version] = value }

end.parse!

VERSION_FILE = 'lib/getstream_ruby/version.rb'

manual = options[:manual_bump].to_s.strip.downcase

unless manual.empty?
  unless %w[major minor patch].include?(manual)
    warn('manual-bump must be one of: major, minor, patch')
    exit(1)
  end

  previous_version = find_latest_semver_tag
  next_version = if truthy?(options[:use_current_version])
                   read_version_file(VERSION_FILE)
                 else
                   updated = increment_version(previous_version, manual)
                   update_version_file(VERSION_FILE, updated)
                   updated
                 end

  write_outputs(options[:output], {
                  'should_release' => 'true',
                  'bump' => manual,
                  'previous_version' => previous_version,
                  'version' => next_version,
                  'tag' => "v#{next_version}",
                })
  exit(0)
end

bump = determine_bump_type(options[:title].to_s)
if bump == 'none'
  write_outputs(options[:output], {
                  'should_release' => 'false',
                  'bump' => 'none',
                })
  exit(0)
end

current_version = find_latest_semver_tag
next_version = increment_version(current_version, bump)

update_version_file(VERSION_FILE, next_version)

write_outputs(options[:output], {
                'should_release' => 'true',
                'bump' => bump,
                'previous_version' => current_version,
                'version' => next_version,
                'tag' => "v#{next_version}",
              })
