#!/usr/bin/env ruby
# frozen_string_literal: true

# Integration Test Runner
# This script runs the integration tests with proper setup

require 'rspec'
require 'dotenv'

# Load environment variables
Dotenv.load('.env')

# Check if required environment variables are present
unless ENV.fetch('STREAM_API_KEY', nil) && ENV.fetch('STREAM_API_SECRET', nil)
  puts '❌ Missing required environment variables!'
  puts 'Please create a .env file with the following variables:'
  puts 'STREAM_API_KEY=your_api_key_here'
  puts 'STREAM_API_SECRET=your_api_secret_here'
  puts ''
  puts 'You can copy from env.example:'
  puts 'cp env.example .env'
  puts 'Then edit .env with your actual values'
  exit 1
end

puts '🚀 Starting GetStream Ruby SDK Integration Tests'
puts '📋 Environment:'
puts "   API Key: #{ENV.fetch('STREAM_API_KEY', nil)[0..8]}..."
puts "   Base URL: #{ENV['STREAM_BASE_URL'] || 'https://api.getstream.io/api/v1.0'}"
puts ''

# Run the integration tests using bundle exec
system("bundle exec rspec #{File.join(__dir__,
                                      'feed_integration_spec.rb')} #{File.join(__dir__,
                                                                               'moderation_integration_spec.rb')}")
