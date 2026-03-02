# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'dotenv'
require_relative '../../lib/getstream_ruby'
require_relative 'suite_cleanup'

# Base class for integration tests with common setup and cleanup
class BaseIntegrationTest

  attr_reader :client, :created_user_ids, :created_activity_ids, :created_comment_ids, :banned_user_ids, :muted_user_ids

  def initialize
    @created_user_ids = []
    @created_activity_ids = []
    @created_comment_ids = []
    @banned_user_ids = []
    @muted_user_ids = []

    setup_environment
    @client = GetStreamRuby.client
  end

  def setup_environment
    # Load environment variables from .env file if it exists (for local development)
    # In CI, environment variables are already set
    Dotenv.load('.env') if File.exist?('.env')

    # Validate required environment variables
    unless ENV.fetch('STREAM_API_KEY', nil) && ENV.fetch('STREAM_API_SECRET', nil)
      raise 'Missing required environment variables. Please create a .env file with STREAM_API_KEY, STREAM_API_SECRET'
    end

    # Configuration is handled automatically by GetStreamRuby.client
    # which uses Configuration.from_env by default
  end

  def create_test_user(_user_id = nil)
    # user_id ||= "test-user-#{SecureRandom.hex(8)}"
    #
    # user_request = {
    #   id: user_id,
    #   name: "Test User #{user_id}",
    #   role: 'user'
    # }
    #
    # response = client.common.update_users(GetStream::Generated::Models::UpdateUsersRequest.new(
    #   users: { user_id => user_request }
    # ))
    #
    # raise "Failed to create user: #{response.inspect}" unless response.is_a?(GetStreamRuby::StreamResponse)
    #
    # @created_user_ids << user_id
    'test-user-68e41d8ebb318'
  end

  def create_test_feed(feed_group_id, feed_id, _user_id)
    feed_request = GetStream::Generated::Models::GetOrCreateFeedRequest.new(
      user_id: feed_id, # Use feed_id as user_id for the feed
    )

    begin
      feed = client.feed(feed_group_id, feed_id)
      response = feed.get_or_create_feed(feed_request)
      raise "Failed to create feed: #{response.inspect}" unless response.is_a?(GetStreamRuby::StreamResponse)

      response
    rescue StandardError => e
      puts e.inspect
    end
  end

  def create_test_activity(feed_group_id, feed_id, _user_id, text = nil)
    text ||= "Test activity from Ruby SDK integration test - #{Time.now.to_i}"

    activity_request = GetStream::Generated::Models::AddActivityRequest.new(
      type: 'post',
      text: text,
      user_id: feed_id, # Use feed_id as user_id for the activity
      feeds: ["#{feed_group_id}:#{feed_id}"],
      custom: {
        test_field: 'test_value',
        timestamp: Time.now.to_i,
      },
    )

    begin
      response = client.feeds.add_activity(activity_request)
      raise "Failed to create activity: #{response.inspect}" unless response.is_a?(GetStreamRuby::StreamResponse)

      activity_id = response.activity.id
      @created_activity_ids << activity_id
      activity_id
    rescue StandardError => e
      puts e.inspect
    end
  end

  def cleanup_resources
    puts "\n🧹 Cleaning up test resources..."

    # Clean up activities
    @created_activity_ids.each do |activity_id|

      client.feeds.delete_activity(activity_id, true) # hard delete
      puts "✅ Cleaned up activity: #{activity_id}"
    rescue StandardError => e
      puts "⚠️ Failed to cleanup activity #{activity_id}: #{e.message}"

    end

    # Clean up comments
    @created_comment_ids.each do |comment_id|

      client.feeds.delete_comment(comment_id, true) # hard delete
      puts "✅ Cleaned up comment: #{comment_id}"
    rescue StandardError => e
      puts "⚠️ Failed to cleanup comment #{comment_id}: #{e.message}"

    end

    # Clean up banned users
    @banned_user_ids.each do |user_id|

      unban_request = GetStream::Generated::Models::UnbanRequest.new(
        unbanned_by_id: @created_user_ids.first || user_id,
      )
      client.moderation.unban(unban_request, user_id)
      puts "✅ Cleaned up ban for user: #{user_id}"
    rescue StandardError => e
      puts "⚠️ Failed to cleanup ban for user #{user_id}: #{e.message}"

    end

    # Clean up muted users
    @muted_user_ids.each do |user_id|

      unmute_request = GetStream::Generated::Models::UnmuteRequest.new(
        target_ids: [user_id],
        user_id: @created_user_ids.first || user_id,
      )
      client.moderation.unmute(unmute_request)
      puts "✅ Cleaned up mute for user: #{user_id}"
    rescue StandardError => e
      puts "⚠️ Failed to cleanup mute for user #{user_id}: #{e.message}"

    end

    puts '✅ Cleanup completed'
  end

  def wait_for_backend_propagation(seconds = 1)
    sleep(seconds)
  end

  def assert_response_success(response, operation)
    raise "Failed to #{operation}: #{response.inspect}" unless response.is_a?(GetStreamRuby::StreamResponse)
  end

end
