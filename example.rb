#!/usr/bin/env ruby

require_relative "lib/getstream_ruby"

# Method 1: Manual (highest priority)
# client = GetStreamRuby.manual(
#   api_key: "your_api_key",
#   api_secret: "your_api_secret",
#   app_id: "your_app_id"
# )

# Method 2: .env file
# STREAM_API_KEY, STREAM_API_SECRET, STREAM_APP_ID
# client = GetStreamRuby.env

# Method 3: Environment variables
# export STREAM_API_KEY=your_key
# client = GetStreamRuby.env_vars

# Default: uses .env file
client = GetStreamRuby.client

# Example: Create a user feed
puts "Creating user feed..."
begin
  feed_response = client.feed.create("user", "123", {
    name: "John Doe",
    email: "john@example.com"
  })
  puts "Feed created successfully:"
  puts JSON.pretty_generate(feed_response)
rescue GetStreamRuby::Error => e
  puts "Error creating feed: #{e.message}"
end

