# frozen_string_literal: true

require 'securerandom'
require 'json'
require 'dotenv'
require_relative '../../lib/getstream_ruby'

# Shared helpers for chat integration tests.
# Include this module in RSpec describe blocks and call `init_chat_client`
# in a before(:all) hook.
module ChatTestHelpers

  # ---------------------------------------------------------------------------
  # Setup / teardown
  # ---------------------------------------------------------------------------

  def init_chat_client
    Dotenv.load('.env') if File.exist?('.env')
    @client = GetStreamRuby.client
    @created_user_ids = []
    @created_channel_cids = []
  end

  def cleanup_chat_resources
    # Delete channels first (they reference users)
    @created_channel_cids&.each do |cid|

      type, id = cid.split(':', 2)
      @client.make_request(
        :delete,
        "/api/v2/chat/channels/#{type}/#{id}",
        query_params: { 'hard_delete' => 'true' },
      )
    rescue StandardError => e
      puts "Warning: Failed to delete channel #{cid}: #{e.message}"

    end

    # Users are intentionally not deleted here. The delete_users endpoint is
    # heavily rate-limited; calling it from every spec file's cleanup exhausts
    # the quota and causes the DeleteUsers integration test to fail.
    # Test users have random UUIDs and do not interfere with other tests.
  end

  # ---------------------------------------------------------------------------
  # Helper 1: random_string
  # ---------------------------------------------------------------------------

  def random_string(length = 8)
    SecureRandom.alphanumeric(length)
  end

  # ---------------------------------------------------------------------------
  # Helper 2: create_test_users
  # ---------------------------------------------------------------------------

  def create_test_users(count)
    ids = Array.new(count) { "test-user-#{SecureRandom.uuid}" }
    users = {}
    ids.each do |id|

      users[id] = GetStream::Generated::Models::UserRequest.new(
        id: id,
        name: "Test User #{id[0..7]}",
        role: 'user',
      )

    end

    response = @client.common.update_users(
      GetStream::Generated::Models::UpdateUsersRequest.new(users: users),
    )
    @created_user_ids.concat(ids)
    [ids, response]
  end

  # ---------------------------------------------------------------------------
  # Helper 3: create_test_channel
  # ---------------------------------------------------------------------------

  def create_test_channel(creator_id)
    channel_id = "test-ch-#{SecureRandom.hex(6)}"
    body = { data: { created_by_id: creator_id } }
    response = @client.make_request(
      :post,
      "/api/v2/chat/channels/messaging/#{channel_id}/query",
      body: body,
    )
    @created_channel_cids << "messaging:#{channel_id}"
    ['messaging', channel_id, response]
  end

  # ---------------------------------------------------------------------------
  # Helper 4: create_test_channel_with_members
  # ---------------------------------------------------------------------------

  def create_test_channel_with_members(creator_id, member_ids)
    channel_id = "test-ch-#{SecureRandom.hex(6)}"
    members = member_ids.map { |id| { user_id: id } }
    body = { data: { created_by_id: creator_id, members: members } }
    response = @client.make_request(
      :post,
      "/api/v2/chat/channels/messaging/#{channel_id}/query",
      body: body,
    )
    @created_channel_cids << "messaging:#{channel_id}"
    ['messaging', channel_id, response]
  end

  # ---------------------------------------------------------------------------
  # Helper 5: send_test_message
  # ---------------------------------------------------------------------------

  def send_test_message(channel_type, channel_id, user_id, text)
    body = { message: { text: text, user_id: user_id } }
    resp = @client.make_request(
      :post,
      "/api/v2/chat/channels/#{channel_type}/#{channel_id}/message",
      body: body,
    )
    resp.message.id
  end

  # ---------------------------------------------------------------------------
  # Helper 6: delete_users_with_retry
  # ---------------------------------------------------------------------------

  def delete_users_with_retry(user_ids)
    10.times do |i|

      @client.common.delete_users(
        GetStream::Generated::Models::DeleteUsersRequest.new(
          user_ids: user_ids,
          user: 'hard',
          messages: 'hard',
          conversations: 'hard',
        ),
      )
      break
    rescue GetStreamRuby::APIError => e
      break unless e.message.include?('Too many requests')

      sleep([2**i, 16].min)

    end
  end

  # ---------------------------------------------------------------------------
  # Helper 7: wait_for_task
  # ---------------------------------------------------------------------------

  def wait_for_task(task_id, max_attempts: 60, interval_seconds: 1)
    max_attempts.times do

      result = @client.common.get_task(task_id)
      return result if %w[completed failed].include?(result.status)

      sleep(interval_seconds)

    end
    raise "Task #{task_id} did not complete after #{max_attempts} attempts"
  end

  # ---------------------------------------------------------------------------
  # Channel API wrappers (for tests that need direct channel operations)
  # ---------------------------------------------------------------------------

  def get_or_create_channel(type, id, body = {})
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/query", body: body)
  end

  def delete_channel(type, id, hard: false)
    query_params = hard ? { 'hard_delete' => 'true' } : {}
    @client.make_request(:delete, "/api/v2/chat/channels/#{type}/#{id}", query_params: query_params)
  end

  def query_channels(body)
    @client.make_request(:post, '/api/v2/chat/channels', body: body)
  end

  def send_message(type, id, body)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/message", body: body)
  end

end
