# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'chat_test_helpers'

RSpec.describe 'Video Integration', type: :integration do
  include ChatTestHelpers

  before(:all) do
    init_chat_client
    @created_call_type_names = []
    @created_call_ids = [] # [call_type, call_id] pairs
    @shared_user_ids, _resp = create_test_users(4)
    @user1 = @shared_user_ids[0]
    @user2 = @shared_user_ids[1]
    @user3 = @shared_user_ids[2]
    @user4 = @shared_user_ids[3]
  end

  after(:all) do
    # Clean up calls (soft delete)
    @created_call_ids&.each do |call_type, call_id|
      @client.make_request(
        :post,
        "/api/v2/video/call/#{call_type}/#{call_id}/delete",
        body: {}
      )
    rescue StandardError => e
      puts "Warning: Failed to delete call #{call_type}:#{call_id}: #{e.message}"
    end

    # Clean up call types
    @created_call_type_names&.each do |name|
      @client.make_request(:delete, "/api/v2/video/calltypes/#{name}")
    rescue StandardError => e
      puts "Warning: Failed to delete call type #{name}: #{e.message}"
    end

    cleanup_chat_resources
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_call(call_type, call_id, body = {})
    @client.make_request(:post, "/api/v2/video/call/#{call_type}/#{call_id}", body: body)
  end

  def get_call(call_type, call_id)
    @client.make_request(:get, "/api/v2/video/call/#{call_type}/#{call_id}")
  end

  def update_call(call_type, call_id, body)
    @client.make_request(:patch, "/api/v2/video/call/#{call_type}/#{call_id}", body: body)
  end

  def delete_call_req(call_type, call_id, body = {})
    @client.make_request(:post, "/api/v2/video/call/#{call_type}/#{call_id}/delete", body: body)
  end

  def new_call_id
    "test-call-#{random_string(10)}"
  end

  def new_call_type_name
    "testct#{random_string(8)}"
  end

  # ---------------------------------------------------------------------------
  # CRUDCallTypeOperations
  # ---------------------------------------------------------------------------

  describe 'CRUDCallTypeOperations' do
    it 'creates a call type with settings, updates, reads, and deletes' do
      ct_name = new_call_type_name
      @created_call_type_names << ct_name

      # Create call type
      resp = @client.make_request(:post, '/api/v2/video/calltypes', body: {
        name: ct_name,
        grants: {
          'admin' => %w[send-audio send-video mute-users],
          'user' => %w[send-audio send-video]
        },
        settings: {
          audio: { default_device: 'speaker', mic_default_on: true },
          screensharing: { access_request_enabled: false, enabled: true }
        },
        notification_settings: {
          enabled: true,
          call_notification: {
            enabled: true,
            apns: { title: '{{ user.display_name }} invites you to a call', body: '' }
          },
          session_started: { enabled: false },
          call_live_started: { enabled: false },
          call_ring: { enabled: false }
        }
      })
      expect(resp.name).to eq(ct_name)

      # Poll for eventual consistency
      10.times do
        @client.make_request(:get, "/api/v2/video/calltypes/#{ct_name}")
        break
      rescue GetStreamRuby::APIError
        sleep(1)
      end

      # Update call type settings (with retry for eventual consistency)
      resp2 = nil
      3.times do |i|
        resp2 = @client.make_request(:put, "/api/v2/video/calltypes/#{ct_name}", body: {
          settings: {
            audio: { default_device: 'earpiece', mic_default_on: false },
            recording: { mode: 'disabled' },
            backstage: { enabled: true }
          },
          grants: {
            'host' => %w[join-backstage]
          }
        })
        break
      rescue GetStreamRuby::APIError
        raise if i == 2

        sleep(2)
      end
      expect(resp2).not_to be_nil

      # Read call type (with retry)
      resp3 = nil
      3.times do |i|
        resp3 = @client.make_request(:get, "/api/v2/video/calltypes/#{ct_name}")
        break
      rescue GetStreamRuby::APIError
        raise if i == 2

        sleep(2)
      end
      expect(resp3.name).to eq(ct_name)

      # Delete call type (with retry for eventual consistency)
      sleep(2)
      5.times do |i|
        @client.make_request(:delete, "/api/v2/video/calltypes/#{ct_name}")
        @created_call_type_names.delete(ct_name)
        break
      rescue GetStreamRuby::APIError => e
        raise if i == 4

        sleep(2)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # CreateCallWithMembers
  # ---------------------------------------------------------------------------

  describe 'CreateCallWithMembers' do
    it 'creates a call and adds members' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      resp = create_call('default', call_id, {
        data: {
          created_by_id: @user1,
          members: [
            { user_id: @user1 },
            { user_id: @user2 }
          ]
        }
      })
      expect(resp).not_to be_nil
      call_h = resp.to_h
      expect(call_h['call']).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # BlockUnblockUserFromCalls
  # ---------------------------------------------------------------------------

  describe 'BlockUnblockUserFromCalls' do
    it 'blocks a user from a call and unblocks' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      create_call('default', call_id, {
        data: { created_by_id: @user1 }
      })

      # Block user
      @client.make_request(
        :post,
        "/api/v2/video/call/default/#{call_id}/block",
        body: { user_id: @user2 }
      )

      # Verify blocked
      resp = get_call('default', call_id)
      call_h = resp.to_h
      blocked_ids = call_h.dig('call', 'blocked_user_ids') || []
      expect(blocked_ids).to include(@user2)

      # Unblock user
      @client.make_request(
        :post,
        "/api/v2/video/call/default/#{call_id}/unblock",
        body: { user_id: @user2 }
      )

      # Verify unblocked (with retry for eventual consistency)
      unblocked = false
      5.times do
        sleep(1)
        resp2 = get_call('default', call_id)
        call_h2 = resp2.to_h
        blocked_ids2 = call_h2.dig('call', 'blocked_user_ids') || []
        unless blocked_ids2.include?(@user2)
          unblocked = true
          break
        end
      end
      expect(unblocked).to be(true), 'Expected user to be unblocked after unblock call'
    end
  end

  # ---------------------------------------------------------------------------
  # SendCustomEvent
  # ---------------------------------------------------------------------------

  describe 'SendCustomEvent' do
    it 'sends a custom event in a call' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      create_call('default', call_id, {
        data: { created_by_id: @user1 }
      })

      resp = @client.make_request(
        :post,
        "/api/v2/video/call/default/#{call_id}/event",
        body: { user_id: @user1, custom: { bananas: 'good' } }
      )
      expect(resp).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # MuteAll
  # ---------------------------------------------------------------------------

  describe 'MuteAll' do
    it 'mutes all users in a call' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      create_call('default', call_id, {
        data: { created_by_id: @user1 }
      })

      resp = @client.make_request(
        :post,
        "/api/v2/video/call/default/#{call_id}/mute_users",
        body: {
          muted_by_id: @user1,
          mute_all_users: true,
          audio: true
        }
      )
      expect(resp).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # MuteSomeUsers
  # ---------------------------------------------------------------------------

  describe 'MuteSomeUsers' do
    it 'mutes specific users with audio, video, screenshare' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      create_call('default', call_id, {
        data: { created_by_id: @user1 }
      })

      resp = @client.make_request(
        :post,
        "/api/v2/video/call/default/#{call_id}/mute_users",
        body: {
          muted_by_id: @user1,
          user_ids: [@user2, @user3],
          audio: true,
          video: true,
          screenshare: true,
          screenshare_audio: true
        }
      )
      expect(resp).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # UpdateUserPermissions
  # ---------------------------------------------------------------------------

  describe 'UpdateUserPermissions' do
    it 'revokes and grants permissions in a call' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      create_call('default', call_id, {
        data: { created_by_id: @user1 }
      })

      # Revoke send-audio
      resp1 = @client.make_request(
        :post,
        "/api/v2/video/call/default/#{call_id}/user_permissions",
        body: {
          user_id: @user2,
          revoke_permissions: ['send-audio']
        }
      )
      expect(resp1).not_to be_nil

      # Grant send-audio back
      resp2 = @client.make_request(
        :post,
        "/api/v2/video/call/default/#{call_id}/user_permissions",
        body: {
          user_id: @user2,
          grant_permissions: ['send-audio']
        }
      )
      expect(resp2).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # DeactivateUser (video context: deactivate/reactivate/batch)
  # ---------------------------------------------------------------------------

  describe 'DeactivateUser' do
    it 'deactivates, reactivates, and batch deactivates users' do
      user_ids, _resp = create_test_users(2)
      alice = user_ids[0]
      bob = user_ids[1]

      # Deactivate single user
      @client.common.deactivate_user(
        alice,
        GetStream::Generated::Models::DeactivateUserRequest.new
      )

      # Reactivate single user
      @client.common.reactivate_user(
        alice,
        GetStream::Generated::Models::ReactivateUserRequest.new
      )

      # Batch deactivate
      resp = @client.common.deactivate_users(
        GetStream::Generated::Models::DeactivateUsersRequest.new(user_ids: [alice, bob])
      )
      expect(resp.task_id).not_to be_nil

      task_result = wait_for_task(resp.task_id)
      expect(task_result.status).to eq('completed')
    end
  end

  # ---------------------------------------------------------------------------
  # CreateCallWithSessionTimer
  # ---------------------------------------------------------------------------

  describe 'CreateCallWithSessionTimer' do
    it 'creates a call with max_duration_seconds and updates it' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      resp = create_call('default', call_id, {
        data: {
          created_by_id: @user1,
          settings_override: {
            limits: { max_duration_seconds: 3600 }
          }
        }
      })
      call_h = resp.to_h
      max_dur = call_h.dig('call', 'settings', 'limits', 'max_duration_seconds')
      expect(max_dur).to eq(3600)

      # Update to 7200
      resp2 = update_call('default', call_id, {
        settings_override: {
          limits: { max_duration_seconds: 7200 }
        }
      })
      call_h2 = resp2.to_h
      max_dur2 = call_h2.dig('call', 'settings', 'limits', 'max_duration_seconds')
      expect(max_dur2).to eq(7200)

      # Reset to 0
      resp3 = update_call('default', call_id, {
        settings_override: {
          limits: { max_duration_seconds: 0 }
        }
      })
      call_h3 = resp3.to_h
      max_dur3 = call_h3.dig('call', 'settings', 'limits', 'max_duration_seconds')
      expect(max_dur3).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # UserBlocking (app-level user block/unblock, not call-level)
  # ---------------------------------------------------------------------------

  describe 'UserBlocking' do
    it 'blocks and unblocks a user at app level' do
      user_ids, _resp = create_test_users(2)
      alice = user_ids[0]
      bob = user_ids[1]

      # Block
      @client.common.block_users(
        GetStream::Generated::Models::BlockUsersRequest.new(
          blocked_user_id: bob,
          user_id: alice
        )
      )

      # Verify blocked
      resp = @client.common.get_blocked_users(alice)
      blocks = resp.blocks || []
      expect(blocks.length).to be >= 1
      block_h = blocks[0].is_a?(Hash) ? blocks[0] : blocks[0].to_h
      expect(block_h['blocked_user_id']).to eq(bob)

      # Unblock
      @client.common.unblock_users(
        GetStream::Generated::Models::UnblockUsersRequest.new(
          blocked_user_id: bob,
          user_id: alice
        )
      )

      # Verify unblocked
      resp2 = @client.common.get_blocked_users(alice)
      blocks2 = resp2.blocks || []
      blocked_ids = blocks2.map do |b|
        h = b.is_a?(Hash) ? b : b.to_h
        h['blocked_user_id']
      end
      expect(blocked_ids).not_to include(bob)
    end
  end

  # ---------------------------------------------------------------------------
  # CreateCallWithBackstageAndJoinAhead
  # ---------------------------------------------------------------------------

  describe 'CreateCallWithBackstageAndJoinAhead' do
    it 'creates a call with backstage and join_ahead_time_seconds' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      starts_at = (Time.now.utc + 30 * 60).strftime('%Y-%m-%dT%H:%M:%S.%NZ')

      resp = create_call('default', call_id, {
        data: {
          starts_at: starts_at,
          created_by_id: @user1,
          settings_override: {
            backstage: { enabled: true, join_ahead_time_seconds: 300 }
          }
        }
      })
      call_h = resp.to_h
      join_ahead = call_h.dig('call', 'settings', 'backstage', 'join_ahead_time_seconds')
      expect(join_ahead).to eq(300)

      # Update to 600
      resp2 = update_call('default', call_id, {
        settings_override: {
          backstage: { enabled: true, join_ahead_time_seconds: 600 }
        }
      })
      call_h2 = resp2.to_h
      join_ahead2 = call_h2.dig('call', 'settings', 'backstage', 'join_ahead_time_seconds')
      expect(join_ahead2).to eq(600)

      # Reset to 0
      resp3 = update_call('default', call_id, {
        settings_override: {
          backstage: { enabled: true, join_ahead_time_seconds: 0 }
        }
      })
      call_h3 = resp3.to_h
      join_ahead3 = call_h3.dig('call', 'settings', 'backstage', 'join_ahead_time_seconds')
      expect(join_ahead3).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # DeleteCall (soft)
  # ---------------------------------------------------------------------------

  describe 'DeleteCall (soft)' do
    it 'soft deletes a call and verifies not found' do
      call_id = new_call_id
      # Don't add to @created_call_ids since we're deleting it here

      create_call('default', call_id, {
        data: { created_by_id: @user1 }
      })

      resp = delete_call_req('default', call_id, {})
      resp_h = resp.to_h
      expect(resp_h['call']).not_to be_nil
      # task_id should be nil for soft delete
      expect(resp_h['task_id']).to be_nil

      # Verify not found (with retry for eventual consistency)
      found = false
      5.times do
        sleep(1)
        begin
          get_call('default', call_id)
        rescue GetStreamRuby::APIError => e
          found = true if e.message.include?("Can't find call with id")
          break
        end
      end
      expect(found).to be(true), 'Expected call to be not found after soft delete'
    end
  end

  # ---------------------------------------------------------------------------
  # HardDeleteCall
  # ---------------------------------------------------------------------------

  describe 'HardDeleteCall' do
    it 'hard deletes a call with task polling' do
      call_id = new_call_id
      # Don't add to @created_call_ids since we're deleting it here

      create_call('default', call_id, {
        data: { created_by_id: @user1 }
      })

      resp = delete_call_req('default', call_id, { hard: true })
      resp_h = resp.to_h
      task_id = resp_h['task_id']
      expect(task_id).not_to be_nil

      task_result = wait_for_task(task_id)
      expect(task_result.status).to eq('completed')

      # Verify not found (with retry for eventual consistency)
      found = false
      5.times do
        sleep(1)
        begin
          get_call('default', call_id)
        rescue GetStreamRuby::APIError => e
          found = true if e.message.include?("Can't find call with id")
          break
        end
      end
      expect(found).to be(true), 'Expected call to be not found after hard delete'
    end
  end

  # ---------------------------------------------------------------------------
  # Teams
  # ---------------------------------------------------------------------------

  describe 'Teams' do
    it 'creates a user with teams, creates a call with team, queries' do
      team_user_id = "test-user-#{SecureRandom.uuid}"
      @created_user_ids << team_user_id

      @client.common.update_users(
        GetStream::Generated::Models::UpdateUsersRequest.new(
          users: {
            team_user_id => GetStream::Generated::Models::UserRequest.new(
              id: team_user_id,
              name: 'Team User',
              role: 'user',
              teams: %w[red blue]
            )
          }
        )
      )

      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      resp = create_call('default', call_id, {
        data: {
          created_by_id: team_user_id,
          team: 'blue'
        }
      })
      call_h = resp.to_h
      expect(call_h.dig('call', 'team')).to eq('blue')

      # Query calls by team
      query_resp = @client.make_request(:post, '/api/v2/video/calls', body: {
        filter_conditions: {
          'id' => call_id,
          'team' => { '$eq' => 'blue' }
        }
      })
      query_h = query_resp.to_h
      expect(query_h['calls'].length).to be >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # ExternalStorageOperations
  # ---------------------------------------------------------------------------

  describe 'ExternalStorageOperations' do
    it 'creates, lists, and deletes external storage' do
      storage_name = "test-storage-#{random_string(10)}"

      # Create external storage (fake credentials for API contract testing only)
      create_resp = @client.make_request(:post, '/api/v2/external_storage', body: {
        bucket: 'test-bucket',
        name: storage_name,
        storage_type: 's3',
        path: 'test-directory/',
        aws_s3: {
          s3_region: 'us-east-1',
          s3_api_key: 'test-access-key',
          s3_secret: 'test-secret'
        }
      })
      expect(create_resp).not_to be_nil

      # Verify via list (with retry for eventual consistency)
      found = false
      10.times do
        sleep(1)
        list_resp = @client.make_request(:get, '/api/v2/external_storage')
        storages_h = list_resp.to_h['external_storages'] || {}
        if storages_h.key?(storage_name)
          found = true
          break
        end
      end
      expect(found).to be(true), "Expected storage #{storage_name} to appear in list"

      # Delete external storage (with retry for eventual consistency)
      5.times do |i|
        @client.make_request(:delete, "/api/v2/external_storage/#{storage_name}")
        break
      rescue GetStreamRuby::APIError => e
        raise if i == 4

        sleep(2)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # EnableCallRecordingAndBackstageMode
  # ---------------------------------------------------------------------------

  describe 'EnableCallRecordingAndBackstageMode' do
    it 'updates call settings for recording and backstage' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      create_call('default', call_id, {
        data: { created_by_id: @user1 }
      })

      # Enable recording
      resp1 = update_call('default', call_id, {
        settings_override: {
          recording: { mode: 'available', audio_only: true }
        }
      })
      call_h1 = resp1.to_h
      expect(call_h1.dig('call', 'settings', 'recording', 'mode')).to eq('available')

      # Enable backstage
      resp2 = update_call('default', call_id, {
        settings_override: {
          backstage: { enabled: true }
        }
      })
      call_h2 = resp2.to_h
      expect(call_h2.dig('call', 'settings', 'backstage', 'enabled')).to eq(true)
    end
  end

  # ---------------------------------------------------------------------------
  # DeleteRecordingsAndTranscriptions
  # ---------------------------------------------------------------------------

  describe 'DeleteRecordingsAndTranscriptions' do
    it 'returns error when deleting non-existent recording' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      create_call('default', call_id, {
        data: { created_by_id: @user1 }
      })

      expect do
        @client.make_request(
          :delete,
          "/api/v2/video/call/default/#{call_id}/non-existent-session/recordings/non-existent-filename"
        )
      end.to raise_error(GetStreamRuby::APIError)
    end

    it 'returns error when deleting non-existent transcription' do
      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      create_call('default', call_id, {
        data: { created_by_id: @user1 }
      })

      expect do
        @client.make_request(
          :delete,
          "/api/v2/video/call/default/#{call_id}/non-existent-session/transcriptions/non-existent-filename"
        )
      end.to raise_error(GetStreamRuby::APIError)
    end
  end
end
