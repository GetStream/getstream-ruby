#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

def run_command(command)
  output = `#{command}`.to_s
  output.strip
end

def find_latest_semver_tag
  tags = run_command("git tag --list").split(/\R/)
  versions = tags.map(&:strip).map { |tag| tag.sub(/^v/, "") }
                 .select { |value| value.match?(/^\d+\.\d+\.\d+$/) }
  return "0.0.0" if versions.empty?

  versions.sort_by { |version| version.split(".").map(&:to_i) }.last
end

def determine_bump_type(title, body)
  return "major" if body.match?(/BREAKING[ -]CHANGE/i)

  match = title.strip.match(/^([a-z]+)(\([^)]+\))?(!)?:/i)
  return "none" unless match

  type = match[1].downcase
  return "major" if match[3] == "!"
  return "minor" if type == "feat"
  return "patch" if ["fix", "bug"].include?(type)

  "none"
end

def increment_version(version, bump)
  major, minor, patch = version.split(".").map(&:to_i)

  case bump
  when "major"
    "#{major + 1}.0.0"
  when "minor"
    "#{major}.#{minor + 1}.0"
  when "patch"
    "#{major}.#{minor}.#{patch + 1}"
  else
    version
  end
end

def update_version_file(path, version)
  content = File.read(path)
  updated = content.sub(/VERSION = '[^']+'/, "VERSION = '#{version}'")
  raise "Could not update version.rb" if updated == content

  File.write(path, updated)
end

def write_outputs(output_path, values)
  lines = values.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n"
  if output_path.empty?
    print(lines)
    return
  end

  File.open(output_path, "a") { |f| f.write(lines) }
end

options = {
  title: "",
  body: "",
  body_file: "",
  output: ""
}

OptionParser.new do |opts|
  opts.on("--title TITLE") { |v| options[:title] = v }
  opts.on("--body BODY") { |v| options[:body] = v }
  opts.on("--body-file FILE") { |v| options[:body_file] = v }
  opts.on("--output FILE") { |v| options[:output] = v }
end.parse!

body = if options[:body_file].empty?
         options[:body].to_s
       else
         File.read(options[:body_file])
       end

bump = determine_bump_type(options[:title].to_s, body.to_s)
if bump == "none"
  write_outputs(options[:output], {
                  "should_release" => "false",
                  "bump" => "none"
                })
  exit(0)
end

current_version = find_latest_semver_tag
next_version = increment_version(current_version, bump)

update_version_file("lib/getstream_ruby/version.rb", next_version)

write_outputs(options[:output], {
                "should_release" => "true",
                "bump" => bump,
                "previous_version" => current_version,
                "version" => next_version,
                "tag" => "v#{next_version}"
              })
