# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'chat_test_helpers'

RSpec.describe 'Chat Misc Integration', type: :integration do
  include ChatTestHelpers

  before(:all) do
    init_chat_client
    @shared_user_ids, _resp = create_test_users(4)
    @user1 = @shared_user_ids[0]
    @user2 = @shared_user_ids[1]
    @user3 = @shared_user_ids[2]
    @user4 = @shared_user_ids[3]
    @created_blocklist_names = []
    @created_command_names = []
    @created_channel_type_names = []
    @created_role_names = []
  end

  after(:all) do
    # Clean up blocklists
    @created_blocklist_names&.each do |name|
      @client.common.delete_block_list(name)
    rescue StandardError => e
      puts "Warning: Failed to delete blocklist #{name}: #{e.message}"
    end

    # Clean up commands
    @created_command_names&.each do |name|
      @client.make_request(:delete, "/api/v2/chat/commands/#{name}")
    rescue StandardError => e
      puts "Warning: Failed to delete command #{name}: #{e.message}"
    end

    # Clean up channel types (with retry due to eventual consistency)
    @created_channel_type_names&.each do |name|
      5.times do |i|
        @client.make_request(:delete, "/api/v2/chat/channeltypes/#{name}")
        break
      rescue StandardError => e
        puts "Warning: Failed to delete channel type #{name} (attempt #{i + 1}): #{e.message}"
        sleep(2)
      end
    end

    # Clean up roles
    @created_role_names&.each do |name|
      sleep(2)
      5.times do |i|
        @client.common.delete_role(name)
        break
      rescue StandardError => e
        puts "Warning: Failed to delete role #{name} (attempt #{i + 1}): #{e.message}"
        sleep(1)
      end
    end

    cleanup_chat_resources
  end

  # ---------------------------------------------------------------------------
  # Devices
  # ---------------------------------------------------------------------------

  describe 'CreateListDeleteDevice' do
    it 'creates a firebase device, lists it, deletes it, and verifies gone' do
      device_id = "integration-test-device-#{random_string(12)}"

      # Create device
      @client.common.create_device(
        GetStream::Generated::Models::CreateDeviceRequest.new(
          id: device_id,
          push_provider: 'firebase',
          user_id: @user1
        )
      )

      # List devices
      list_resp = @client.common.list_devices(@user1)
      devices = list_resp.devices || []
      found = devices.any? { |d| h = d.is_a?(Hash) ? d : d.to_h; h['id'] == device_id }
      expect(found).to be(true), "Created device should appear in list"

      # Delete device
      @client.common.delete_device(device_id, @user1)

      # Verify deleted
      list_resp2 = @client.common.list_devices(@user1)
      devices2 = list_resp2.devices || []
      still_found = devices2.any? { |d| h = d.is_a?(Hash) ? d : d.to_h; h['id'] == device_id }
      expect(still_found).to be(false), "Device should be deleted"
    rescue GetStreamRuby::APIError => e
      skip('Push providers not configured for this app') if e.message.include?('push provider') || e.message.include?('no push')
      raise
    end
  end

  # ---------------------------------------------------------------------------
  # Blocklists
  # ---------------------------------------------------------------------------

  describe 'CreateListDeleteBlocklist' do
    it 'creates a custom blocklist, lists it, verifies found, and deletes it' do
      blocklist_name = "test-blocklist-#{random_string(8)}"

      # Create blocklist
      @client.common.create_block_list(
        GetStream::Generated::Models::CreateBlockListRequest.new(
          name: blocklist_name,
          words: %w[badword1 badword2 badword3]
        )
      )
      @created_blocklist_names << blocklist_name

      # Get blocklist and verify
      get_resp = @client.common.get_block_list(blocklist_name)
      expect(get_resp.blocklist).not_to be_nil
      bl_h = get_resp.blocklist.to_h
      expect(bl_h['name']).to eq(blocklist_name)
      expect(bl_h['words'].length).to eq(3)

      # Update blocklist
      @client.common.update_block_list(
        blocklist_name,
        GetStream::Generated::Models::UpdateBlockListRequest.new(
          words: %w[badword1 badword2 badword3 badword4]
        )
      )

      # Verify update
      get_resp2 = @client.common.get_block_list(blocklist_name)
      bl_h2 = get_resp2.blocklist.to_h
      expect(bl_h2['words'].length).to eq(4)

      # List blocklists and verify found
      list_resp = @client.common.list_block_lists
      blocklists = list_resp.blocklists || []
      found = blocklists.any? do |bl|
        h = bl.is_a?(Hash) ? bl : bl.to_h
        h['name'] == blocklist_name
      end
      expect(found).to be(true), "Created blocklist should appear in list"

      # Delete a separate blocklist to test deletion
      del_name = "test-del-bl-#{random_string(8)}"
      @client.common.create_block_list(
        GetStream::Generated::Models::CreateBlockListRequest.new(
          name: del_name,
          words: %w[word1]
        )
      )
      @client.common.delete_block_list(del_name)
    end
  end

  # ---------------------------------------------------------------------------
  # Commands
  # ---------------------------------------------------------------------------

  describe 'CreateListDeleteCommand' do
    it 'creates a custom command, lists it, verifies found, and deletes it' do
      cmd_name = "testcmd#{random_string(6)}"

      # Create command
      resp = @client.make_request(:post, '/api/v2/chat/commands', body: {
        name: cmd_name,
        description: 'A test command'
      })
      expect(resp).not_to be_nil
      @created_command_names << cmd_name

      # Get command
      get_resp = @client.make_request(:get, "/api/v2/chat/commands/#{cmd_name}")
      expect(get_resp.name).to eq(cmd_name)
      expect(get_resp.description).to eq('A test command')

      # Update command
      @client.make_request(:put, "/api/v2/chat/commands/#{cmd_name}", body: {
        description: 'Updated test command'
      })

      # Verify update
      get_resp2 = @client.make_request(:get, "/api/v2/chat/commands/#{cmd_name}")
      expect(get_resp2.description).to eq('Updated test command')

      # List commands
      list_resp = @client.make_request(:get, '/api/v2/chat/commands')
      commands = list_resp.commands || []
      found = commands.any? do |c|
        h = c.is_a?(Hash) ? c : c.to_h
        h['name'] == cmd_name
      end
      expect(found).to be(true), "Created command should appear in list"

      # Delete a separate command
      del_name = "testdelcmd#{random_string(6)}"
      @client.make_request(:post, '/api/v2/chat/commands', body: {
        name: del_name,
        description: 'Command to delete'
      })
      del_resp = @client.make_request(:delete, "/api/v2/chat/commands/#{del_name}")
      expect(del_resp).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Channel Types
  # ---------------------------------------------------------------------------

  describe 'CreateUpdateDeleteChannelType' do
    it 'creates a channel type, updates settings, verifies, and deletes' do
      type_name = "testtype#{random_string(6)}"

      # Create channel type
      create_resp = @client.make_request(:post, '/api/v2/chat/channeltypes', body: {
        name: type_name,
        automod: 'disabled',
        automod_behavior: 'flag',
        max_message_length: 5000
      })
      expect(create_resp.name).to eq(type_name)
      @created_channel_type_names << type_name

      # Wait for eventual consistency
      sleep(6)

      # Get channel type
      get_resp = @client.make_request(:get, "/api/v2/chat/channeltypes/#{type_name}")
      expect(get_resp.name).to eq(type_name)

      # Update channel type
      update_resp = @client.make_request(:put, "/api/v2/chat/channeltypes/#{type_name}", body: {
        automod: 'disabled',
        automod_behavior: 'flag',
        max_message_length: 10_000,
        typing_events: false
      })
      expect(update_resp.max_message_length).to eq(10_000)

      # Delete a separate channel type
      del_name = "testdeltype#{random_string(6)}"
      @client.make_request(:post, '/api/v2/chat/channeltypes', body: {
        name: del_name,
        automod: 'disabled',
        automod_behavior: 'flag',
        max_message_length: 5000
      })
      @created_channel_type_names << del_name

      sleep(6)

      delete_err = nil
      5.times do |i|
        begin
          @client.make_request(:delete, "/api/v2/chat/channeltypes/#{del_name}")
          @created_channel_type_names.delete(del_name)
          delete_err = nil
          break
        rescue StandardError => e
          delete_err = e
          sleep(1)
        end
      end
      expect(delete_err).to be_nil, "Channel type deletion should succeed: #{delete_err&.message}"
    end
  end

  describe 'ListChannelTypes' do
    it 'lists all channel types and verifies default types present' do
      resp = @client.make_request(:get, '/api/v2/chat/channeltypes')
      expect(resp.channel_types).not_to be_nil

      types_h = resp.channel_types.to_h
      expect(types_h.key?('messaging')).to be(true), "Default 'messaging' type should be present"
    end
  end

  # ---------------------------------------------------------------------------
  # Permissions & Roles
  # ---------------------------------------------------------------------------

  describe 'ListPermissions' do
    it 'lists all permissions and verifies non-empty' do
      resp = @client.common.list_permissions
      expect(resp.permissions).not_to be_nil
      expect(resp.permissions.length).to be > 0
    end
  end

  describe 'CreatePermission' do
    it 'creates a custom role, lists it, and verifies custom flag' do
      role_name = "testrole#{random_string(6)}"

      # Create role
      @client.common.create_role(
        GetStream::Generated::Models::CreateRoleRequest.new(name: role_name)
      )
      @created_role_names << role_name

      # List roles and verify
      list_resp = @client.common.list_roles
      roles = list_resp.roles || []
      found = roles.any? do |r|
        h = r.is_a?(Hash) ? r : r.to_h
        h['name'] == role_name && h['custom'] == true
      end
      expect(found).to be(true), "Created role should appear in list as custom"
    end
  end

  describe 'GetPermission' do
    it 'gets a specific permission by ID' do
      resp = @client.common.get_permission('create-channel')
      expect(resp.permission).not_to be_nil
      perm_h = resp.permission.to_h
      expect(perm_h['id']).to eq('create-channel')
      expect(perm_h['action']).not_to be_nil
      expect(perm_h['action']).not_to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # Banned Users
  # ---------------------------------------------------------------------------

  describe 'QueryBannedUsers' do
    it 'bans a user in channel, queries banned users, and verifies' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])
      cid = "messaging:#{channel_id}"

      # Ban user in channel
      @client.moderation.ban(
        GetStream::Generated::Models::BanRequest.new(
          target_user_id: @user2,
          banned_by_id: @user1,
          channel_cid: cid,
          reason: 'test ban reason',
          timeout: 60
        )
      )

      # Query banned users
      resp = @client.make_request(:get, '/api/v2/chat/query_banned_users', query_params: {
        'payload' => JSON.generate({
          filter_conditions: { 'channel_cid' => { '$eq' => cid } }
        })
      })
      bans = resp.bans || []
      expect(bans.length).to be >= 1

      ban_h = bans[0].is_a?(Hash) ? bans[0] : bans[0].to_h
      expect(ban_h['reason']).to eq('test ban reason')

      # Unban
      @client.moderation.unban(
        GetStream::Generated::Models::UnbanRequest.new,
        @user2,
        cid
      )

      # Verify ban is gone
      resp2 = @client.make_request(:get, '/api/v2/chat/query_banned_users', query_params: {
        'payload' => JSON.generate({
          filter_conditions: { 'channel_cid' => { '$eq' => cid } }
        })
      })
      bans2 = resp2.bans || []
      expect(bans2.length).to eq(0), "Bans should be empty after unban"
    end
  end

  # ---------------------------------------------------------------------------
  # Mute/Unmute User
  # ---------------------------------------------------------------------------

  describe 'MuteUnmuteUser' do
    it 'mutes user, verifies via query, and unmutes' do
      # Mute user
      mute_resp = @client.moderation.mute(
        GetStream::Generated::Models::MuteRequest.new(
          target_ids: [@user3],
          user_id: @user1
        )
      )
      expect(mute_resp.mutes).not_to be_nil
      expect(mute_resp.mutes.length).to be >= 1

      mute_h = mute_resp.mutes[0].is_a?(Hash) ? mute_resp.mutes[0] : mute_resp.mutes[0].to_h
      expect(mute_h['target']).not_to be_nil

      # Verify via QueryUsers that user has mutes
      q_resp = @client.common.query_users(JSON.generate({
        filter_conditions: { 'id' => { '$eq' => @user1 } }
      }))
      expect(q_resp.users).not_to be_nil
      expect(q_resp.users.length).to be >= 1
      user_h = q_resp.users[0].is_a?(Hash) ? q_resp.users[0] : q_resp.users[0].to_h
      expect(user_h['mutes']).not_to be_nil
      expect(user_h['mutes'].length).to be >= 1

      # Unmute
      @client.moderation.unmute(
        GetStream::Generated::Models::UnmuteRequest.new(
          target_ids: [@user3],
          user_id: @user1
        )
      )
    end
  end

  # ---------------------------------------------------------------------------
  # App Settings
  # ---------------------------------------------------------------------------

  describe 'GetAppSettings' do
    it 'gets app settings and verifies response' do
      resp = @client.common.get_app
      expect(resp).not_to be_nil
      expect(resp.app).not_to be_nil
      app_h = resp.app.to_h
      expect(app_h['name']).not_to be_nil
      expect(app_h['name']).not_to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # Export Channels
  # ---------------------------------------------------------------------------

  describe 'ExportChannels' do
    it 'exports channel messages and polls task until completed' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])
      send_test_message('messaging', channel_id, @user1, "Message for export test #{SecureRandom.hex(4)}")

      cid = "messaging:#{channel_id}"

      # Export channels
      export_resp = @client.make_request(:post, '/api/v2/chat/export_channels', body: {
        channels: [{ cid: cid }]
      })
      expect(export_resp.task_id).not_to be_nil
      expect(export_resp.task_id).not_to be_empty

      # Wait for task
      task_result = wait_for_task(export_resp.task_id)
      expect(task_result.status).to eq('completed')
    end
  end

  # ---------------------------------------------------------------------------
  # Threads
  # ---------------------------------------------------------------------------

  describe 'Threads' do
    it 'creates parent + replies, queries threads, and verifies' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])
      channel_cid = "messaging:#{channel_id}"

      # Create thread: parent message + replies
      parent_id = send_test_message('messaging', channel_id, @user1, 'Thread parent message')

      send_message('messaging', channel_id, {
        message: {
          text: 'First reply in thread',
          user_id: @user2,
          parent_id: parent_id
        }
      })

      send_message('messaging', channel_id, {
        message: {
          text: 'Second reply in thread',
          user_id: @user1,
          parent_id: parent_id
        }
      })

      # Query threads
      resp = @client.make_request(:post, '/api/v2/chat/threads', body: {
        user_id: @user1,
        filter: {
          'channel_cid' => { '$eq' => channel_cid }
        }
      })
      expect(resp.threads).not_to be_nil
      expect(resp.threads.length).to be >= 1

      found = resp.threads.any? do |t|
        h = t.is_a?(Hash) ? t : t.to_h
        h['parent_message_id'] == parent_id
      end
      expect(found).to be(true), "Thread should appear in query results"

      # Get thread
      get_resp = @client.make_request(:get, "/api/v2/chat/threads/#{parent_id}", query_params: {
        'reply_limit' => '10'
      })
      thread_h = get_resp.thread.is_a?(Hash) ? get_resp.thread : get_resp.thread.to_h
      expect(thread_h['parent_message_id']).to eq(parent_id)
      latest_replies = thread_h['latest_replies'] || []
      expect(latest_replies.length).to be >= 2
    end
  end

  # ---------------------------------------------------------------------------
  # Unread Counts
  # ---------------------------------------------------------------------------

  describe 'GetUnreadCounts' do
    it 'sends message and gets unread counts for user' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])
      send_test_message('messaging', channel_id, @user1, "Unread test #{SecureRandom.hex(4)}")

      resp = @client.make_request(:get, '/api/v2/chat/unread', query_params: {
        'user_id' => @user2
      })
      expect(resp).not_to be_nil
      expect(resp.total_unread_count).to be >= 0
    end
  end

  describe 'GetUnreadCountsBatch' do
    it 'gets unread counts for multiple users' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])
      send_test_message('messaging', channel_id, @user1, "Batch unread test #{SecureRandom.hex(4)}")

      resp = @client.make_request(:post, '/api/v2/chat/unread_batch', body: {
        user_ids: [@user1, @user2]
      })
      expect(resp).not_to be_nil
      expect(resp.counts_by_user).not_to be_nil
      counts_h = resp.counts_by_user.to_h
      expect(counts_h.key?(@user1)).to be(true)
      expect(counts_h.key?(@user2)).to be(true)
    end
  end

  # ---------------------------------------------------------------------------
  # Reminders
  # ---------------------------------------------------------------------------

  describe 'Reminders' do
    it 'creates a reminder, lists it, updates it, and deletes it' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])
      msg_id = send_test_message('messaging', channel_id, @user1, "Reminder test #{SecureRandom.hex(4)}")

      remind_at = (Time.now + 24 * 3600).utc.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')

      # Create reminder
      create_resp = @client.make_request(:post, "/api/v2/chat/messages/#{msg_id}/reminders", body: {
        user_id: @user1,
        remind_at: remind_at
      })
      expect(create_resp).not_to be_nil

      # Query reminders
      query_resp = @client.make_request(:post, '/api/v2/chat/reminders/query', body: {
        user_id: @user1,
        filter: { 'message_id' => msg_id },
        sort: []
      })
      reminders = query_resp.reminders || []
      expect(reminders.length).to be >= 1

      # Update reminder
      new_remind_at = (Time.now + 48 * 3600).utc.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')
      update_resp = @client.make_request(:patch, "/api/v2/chat/messages/#{msg_id}/reminders", body: {
        user_id: @user1,
        remind_at: new_remind_at
      })
      expect(update_resp).not_to be_nil

      # Delete reminder
      @client.make_request(:delete, "/api/v2/chat/messages/#{msg_id}/reminders", query_params: {
        'user_id' => @user1
      })
    rescue GetStreamRuby::APIError => e
      skip('Reminders not enabled for this app') if e.message.include?('not enabled') || e.message.include?('reminder')
      raise
    end
  end

  # ---------------------------------------------------------------------------
  # Send User Custom Event
  # ---------------------------------------------------------------------------

  describe 'SendUserCustomEvent' do
    it 'sends a custom event to a user' do
      resp = @client.make_request(:post, "/api/v2/chat/users/#{@user1}/event", body: {
        event: {
          type: 'friendship_request',
          message: "Let's be friends!"
        }
      })
      expect(resp).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Query Team Usage Stats
  # ---------------------------------------------------------------------------

  describe 'QueryTeamUsageStats' do
    it 'queries team usage stats' do
      resp = @client.make_request(:post, '/api/v2/chat/stats/team_usage', body: {})
      expect(resp).not_to be_nil
    rescue GetStreamRuby::APIError => e
      skip('QueryTeamUsageStats not available on this app') if e.message.include?('Token signature') || e.message.include?('not available') || e.message.include?('not found') || e.message.include?('Not Found')
      raise
    end
  end

  # ---------------------------------------------------------------------------
  # Channel Batch Update
  # ---------------------------------------------------------------------------

  describe 'ChannelBatchUpdate' do
    it 'batch updates multiple channels at once' do
      _type1, ch_id1, _resp1 = create_test_channel(@user1)
      _type2, ch_id2, _resp2 = create_test_channel(@user1)

      # Batch update: set a custom field on both channels
      cids = ["messaging:#{ch_id1}", "messaging:#{ch_id2}"]

      resp = @client.make_request(:post, '/api/v2/chat/channels/batch_update', body: {
        set: { 'color' => 'blue' },
        filter: {
          'cid' => { '$in' => cids }
        }
      })
      expect(resp).not_to be_nil
    rescue GetStreamRuby::APIError => e
      skip('Channel batch update not available') if e.message.include?('not available') || e.message.include?('Not Found') || e.message.include?('unknown') || e.message.include?('not found')
      raise
    end
  end
end
