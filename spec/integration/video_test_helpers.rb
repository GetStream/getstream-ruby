# frozen_string_literal: true

require 'securerandom'
require 'json'
require 'dotenv'
require_relative '../../lib/getstream_ruby'
require_relative 'suite_cleanup'

# Shared helpers for video integration tests.
# Include this module in RSpec describe blocks and call `init_video_client`
# in a before(:all) hook.
module VideoTestHelpers

  # ---------------------------------------------------------------------------
  # Setup / teardown
  # ---------------------------------------------------------------------------

  def init_video_client
    Dotenv.load('.env') if File.exist?('.env')
    @client = GetStreamRuby.client
    @created_user_ids = []
    @created_call_ids = [] # [call_type, call_id] pairs
    @created_call_type_names = []
  end

  def retry_on_rate_limit(max_attempts: 3)
    attempts = 0
    begin
      yield
    rescue GetStreamRuby::APIError => e
      raise unless e.message.include?('Too many requests')

      attempts += 1
      raise if attempts >= max_attempts

      wait = 61 - Time.now.sec
      puts "Rate limited, waiting #{wait}s for window reset (attempt #{attempts}/#{max_attempts})..."
      sleep(wait)
      retry
    end
  end

  def cleanup_video_resources
    # Delete calls (soft delete)
    @created_call_ids&.each do |call_type, call_id|

      @client.video.delete_call(
        call_type, call_id,
        GetStream::Generated::Models::DeleteCallRequest.new
      )
    rescue StandardError => e
      puts "Warning: Failed to delete call #{call_type}:#{call_id}: #{e.message}"

    end

    # Delete call types
    @created_call_type_names&.each do |name|

      @client.video.delete_call_type(name)
    rescue StandardError => e
      puts "Warning: Failed to delete call type #{name}: #{e.message}"

    end

    # Register users for deferred deletion at suite end.
    SuiteCleanup.register_users(@created_user_ids)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def random_string(length = 8)
    SecureRandom.alphanumeric(length)
  end

  def create_test_users(count)
    ids = Array.new(count) { "test-user-#{SecureRandom.uuid}" }
    users = {}
    ids.each do |id|

      users[id] = GetStream::Generated::Models::UserRequest.new(
        id: id,
        name: "Test User #{id}",
        role: 'user',
      )

    end

    response = @client.common.update_users(
      GetStream::Generated::Models::UpdateUsersRequest.new(users: users),
    )
    @created_user_ids.concat(ids)
    [ids, response]
  end

  def new_call_id
    "test-call-#{random_string(10)}"
  end

  def new_call_type_name
    "testct#{random_string(8)}"
  end

  def wait_for_task(task_id, max_attempts: 60, interval_seconds: 1)
    max_attempts.times do

      result = @client.common.get_task(task_id)
      return result if %w[completed failed].include?(result.status)

      sleep(interval_seconds)

    end
    raise "Task #{task_id} did not complete after #{max_attempts} attempts"
  end

end
