# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'video_test_helpers'

RSpec.describe 'Video Client Integration', type: :integration do

  include VideoTestHelpers

  before(:all) do

    init_video_client
    @shared_user_ids, _resp = create_test_users(3)
    @user_a = @shared_user_ids[0]
    @user_b = @shared_user_ids[1]
    @user_c = @shared_user_ids[2]

  end

  after(:all) do

    cleanup_video_resources

  end

  # ---------------------------------------------------------------------------
  # GetOrCreateCall via generated client
  # ---------------------------------------------------------------------------

  describe 'GetOrCreateCall' do

    it 'creates a call using the generated video client' do

      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      resp = @client.video.get_or_create_call(
        'default', call_id,
        GetStream::Generated::Models::GetOrCreateCallRequest.new(
          data: {
            created_by_id: @user_a,
            members: [
              { user_id: @user_a },
              { user_id: @user_b },
            ],
          },
        )
      )
      expect(resp).not_to be_nil
      call_h = resp.to_h
      expect(call_h['call']).not_to be_nil

    end

  end

  # ---------------------------------------------------------------------------
  # GetCall via generated client
  # ---------------------------------------------------------------------------

  describe 'GetCall' do

    it 'retrieves a call using the generated video client' do

      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      @client.video.get_or_create_call(
        'default', call_id,
        GetStream::Generated::Models::GetOrCreateCallRequest.new(
          data: { created_by_id: @user_a },
        )
      )

      resp = @client.video.get_call('default', call_id)
      call_h = resp.to_h
      expect(call_h['call']).not_to be_nil

    end

  end

  # ---------------------------------------------------------------------------
  # UpdateCall via generated client
  # ---------------------------------------------------------------------------

  describe 'UpdateCall' do

    it 'updates call settings using the generated video client' do

      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      @client.video.get_or_create_call(
        'default', call_id,
        GetStream::Generated::Models::GetOrCreateCallRequest.new(
          data: { created_by_id: @user_a },
        )
      )

      resp = @client.video.update_call(
        'default', call_id,
        GetStream::Generated::Models::UpdateCallRequest.new(
          settings_override: {
            limits: { max_duration_seconds: 3600 },
          },
        )
      )
      call_h = resp.to_h
      max_dur = call_h.dig('call', 'settings', 'limits', 'max_duration_seconds')
      expect(max_dur).to eq(3600)

    end

  end

  # ---------------------------------------------------------------------------
  # BlockUser / UnblockUser via generated client
  # ---------------------------------------------------------------------------

  describe 'BlockUnblockUser' do

    it 'blocks and unblocks a user from a call using the generated video client' do

      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      @client.video.get_or_create_call(
        'default', call_id,
        GetStream::Generated::Models::GetOrCreateCallRequest.new(
          data: { created_by_id: @user_a },
        )
      )

      # Block user
      @client.video.block_user(
        'default', call_id,
        GetStream::Generated::Models::BlockUserRequest.new(user_id: @user_b)
      )

      # Verify blocked
      resp = @client.video.get_call('default', call_id)
      blocked_ids = resp.to_h.dig('call', 'blocked_user_ids') || []
      expect(blocked_ids).to include(@user_b)

      # Unblock user
      @client.video.unblock_user(
        'default', call_id,
        GetStream::Generated::Models::UnblockUserRequest.new(user_id: @user_b)
      )

      # Verify unblocked (with retry for eventual consistency)
      unblocked = false
      5.times do

        sleep(1)
        resp_b = @client.video.get_call('default', call_id)
        blocked_ids_b = resp_b.to_h.dig('call', 'blocked_user_ids') || []
        unless blocked_ids_b.include?(@user_b)
          unblocked = true
          break
        end

      end
      expect(unblocked).to be(true), 'Expected user to be unblocked after unblock call'

    end

  end

  # ---------------------------------------------------------------------------
  # SendCallEvent via generated client
  # ---------------------------------------------------------------------------

  describe 'SendCallEvent' do

    it 'sends a custom event in a call using the generated video client' do

      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      @client.video.get_or_create_call(
        'default', call_id,
        GetStream::Generated::Models::GetOrCreateCallRequest.new(
          data: { created_by_id: @user_a },
        )
      )

      resp = @client.video.send_call_event(
        'default', call_id,
        GetStream::Generated::Models::SendCallEventRequest.new(
          user_id: @user_a,
          custom: { bananas: 'good' },
        )
      )
      expect(resp).not_to be_nil

    end

  end

  # ---------------------------------------------------------------------------
  # MuteUsers via generated client
  # ---------------------------------------------------------------------------

  describe 'MuteUsers' do

    it 'mutes all users in a call using the generated video client' do

      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      @client.video.get_or_create_call(
        'default', call_id,
        GetStream::Generated::Models::GetOrCreateCallRequest.new(
          data: { created_by_id: @user_a },
        )
      )

      resp = @client.video.mute_users(
        'default', call_id,
        GetStream::Generated::Models::MuteUsersRequest.new(
          muted_by_id: @user_a,
          mute_all_users: true,
          audio: true,
        )
      )
      expect(resp).not_to be_nil

    end

  end

  # ---------------------------------------------------------------------------
  # DeleteCall (soft) via generated client
  # ---------------------------------------------------------------------------

  describe 'DeleteCall' do

    it 'soft deletes a call using the generated video client' do

      call_id = new_call_id
      # Don't track since we're deleting

      @client.video.get_or_create_call(
        'default', call_id,
        GetStream::Generated::Models::GetOrCreateCallRequest.new(
          data: { created_by_id: @user_a },
        )
      )

      resp = @client.video.delete_call(
        'default', call_id,
        GetStream::Generated::Models::DeleteCallRequest.new
      )
      resp_h = resp.to_h
      expect(resp_h['call']).not_to be_nil

    end

  end

  # ---------------------------------------------------------------------------
  # DeleteCall (hard) via generated client
  # ---------------------------------------------------------------------------

  describe 'HardDeleteCall' do

    it 'hard deletes a call using the generated video client' do

      call_id = new_call_id
      # Don't track since we're deleting

      @client.video.get_or_create_call(
        'default', call_id,
        GetStream::Generated::Models::GetOrCreateCallRequest.new(
          data: { created_by_id: @user_a },
        )
      )

      resp = @client.video.delete_call(
        'default', call_id,
        GetStream::Generated::Models::DeleteCallRequest.new(hard: true)
      )
      resp_h = resp.to_h
      task_id = resp_h['task_id']
      expect(task_id).not_to be_nil

      task_result = wait_for_task(task_id)
      expect(task_result.status).to eq('completed')

    end

  end

  # ---------------------------------------------------------------------------
  # QueryCalls via generated client
  # ---------------------------------------------------------------------------

  describe 'QueryCalls' do

    it 'queries calls using the generated video client' do

      call_id = new_call_id
      @created_call_ids << ['default', call_id]

      @client.video.get_or_create_call(
        'default', call_id,
        GetStream::Generated::Models::GetOrCreateCallRequest.new(
          data: { created_by_id: @user_a },
        )
      )

      resp = @client.video.query_calls(
        GetStream::Generated::Models::QueryCallsRequest.new(
          filter_conditions: { 'id' => call_id },
        ),
      )
      resp_h = resp.to_h
      expect(resp_h['calls']).not_to be_nil
      expect(resp_h['calls'].length).to be >= 1

    end

  end

  # ---------------------------------------------------------------------------
  # ListCallTypes via generated client
  # ---------------------------------------------------------------------------

  describe 'ListCallTypes' do

    it 'lists call types using the generated video client' do

      resp = @client.video.list_call_types
      resp_h = resp.to_h
      expect(resp_h['call_types']).not_to be_nil
      expect(resp_h['call_types']).not_to be_empty

    end

  end

  # ---------------------------------------------------------------------------
  # GetCallType via generated client
  # ---------------------------------------------------------------------------

  describe 'GetCallType' do

    it 'gets the default call type using the generated video client' do

      resp = @client.video.get_call_type('default')
      expect(resp.name).to eq('default')

    end

  end

  # ---------------------------------------------------------------------------
  # GetEdges via generated client
  # ---------------------------------------------------------------------------

  describe 'GetEdges' do

    it 'gets edge servers using the generated video client' do

      resp = @client.video.get_edges
      resp_h = resp.to_h
      expect(resp_h['edges']).not_to be_nil

    end

  end

end
