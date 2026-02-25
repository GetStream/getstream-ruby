# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'chat_test_helpers'

RSpec.describe 'Chat User Integration', type: :integration do
  include ChatTestHelpers

  before(:all) do
    init_chat_client
  end

  after(:all) do
    cleanup_chat_resources
  end

  # Helper to query users with a filter
  def query_users_with_filter(filter, **opts)
    payload = { 'filter_conditions' => filter }
    payload['limit'] = opts[:limit] if opts[:limit]
    payload['offset'] = opts[:offset] if opts[:offset]
    payload['include_deactivated_users'] = opts[:include_deactivated_users] if opts.key?(:include_deactivated_users)
    payload['sort'] = opts[:sort] if opts[:sort]
    @client.common.query_users(JSON.generate(payload))
  end

  describe 'UpsertUsers' do
    it 'creates 2 users and verifies both in response' do
      user_ids, response = create_test_users(2)

      expect(response).to be_a(GetStreamRuby::StreamResponse)
      expect(user_ids.length).to eq(2)

      users_hash = response.users
      expect(users_hash).not_to be_nil
      user_ids.each do |uid|
        expect(users_hash.to_h.key?(uid)).to be true
      end
    end
  end

  describe 'QueryUsers' do
    it 'queries users with $in filter and verifies found' do
      user_ids, _resp = create_test_users(2)

      resp = query_users_with_filter({ 'id' => { '$in' => user_ids } })
      expect(resp.users).not_to be_nil
      expect(resp.users.length).to be >= 2

      returned_ids = resp.users.map { |u| u.to_h['id'] || u.id }
      user_ids.each do |uid|
        expect(returned_ids).to include(uid)
      end
    end
  end

  describe 'QueryUsersWithOffsetLimit' do
    it 'queries with offset=1 limit=2 and verifies exactly 2 returned' do
      user_ids, _resp = create_test_users(3)

      resp = query_users_with_filter(
        { 'id' => { '$in' => user_ids } },
        offset: 1,
        limit: 2,
        sort: [{ 'field' => 'id', 'direction' => 1 }]
      )
      expect(resp.users).not_to be_nil
      expect(resp.users.length).to eq(2)
    end
  end

  describe 'PartialUpdateUser' do
    it 'sets custom fields then unsets one' do
      user_ids, _resp = create_test_users(1)
      uid = user_ids.first

      # Set country and role
      @client.common.update_users_partial(
        GetStream::Generated::Models::UpdateUsersPartialRequest.new(
          users: [
            GetStream::Generated::Models::UpdateUserPartialRequest.new(
              id: uid,
              set: { 'country' => 'NL', 'role' => 'admin' }
            )
          ]
        )
      )

      # Verify set
      resp = query_users_with_filter({ 'id' => uid })
      user = resp.users.first
      user_h = user.to_h
      # Custom fields may be at top-level or under 'custom'
      country = user_h['custom'].is_a?(Hash) ? user_h['custom']['country'] : user_h['country']
      expect(country).to eq('NL')

      # Unset country
      @client.common.update_users_partial(
        GetStream::Generated::Models::UpdateUsersPartialRequest.new(
          users: [
            GetStream::Generated::Models::UpdateUserPartialRequest.new(
              id: uid,
              unset: ['country']
            )
          ]
        )
      )

      # Verify unset
      resp2 = query_users_with_filter({ 'id' => uid })
      user2 = resp2.users.first
      user2_hash = user2.to_h
      country2 = user2_hash['custom'].is_a?(Hash) ? user2_hash['custom']['country'] : user2_hash['country']
      expect(country2).to be_nil
    end
  end

  describe 'BlockUnblockUser' do
    it 'blocks user, verifies in blocked list, unblocks, verifies removed' do
      user_ids, _resp = create_test_users(2)
      blocker_id = user_ids[0]
      blocked_id = user_ids[1]

      # Block
      @client.common.block_users(
        GetStream::Generated::Models::BlockUsersRequest.new(
          blocked_user_id: blocked_id,
          user_id: blocker_id
        )
      )

      # Verify blocked
      blocked_resp = @client.common.get_blocked_users(blocker_id)
      expect(blocked_resp.blocks).not_to be_nil
      blocked_user_ids = blocked_resp.blocks.map { |b| b.to_h['blocked_user_id'] || b.blocked_user_id }
      expect(blocked_user_ids).to include(blocked_id)

      # Unblock
      @client.common.unblock_users(
        GetStream::Generated::Models::UnblockUsersRequest.new(
          blocked_user_id: blocked_id,
          user_id: blocker_id
        )
      )

      # Verify unblocked
      blocked_resp2 = @client.common.get_blocked_users(blocker_id)
      blocked_user_ids2 = (blocked_resp2.blocks || []).map { |b| b.to_h['blocked_user_id'] || b.blocked_user_id }
      expect(blocked_user_ids2).not_to include(blocked_id)
    end
  end

  describe 'DeactivateReactivateUser' do
    it 'deactivates then reactivates a user' do
      user_ids, _resp = create_test_users(1)
      uid = user_ids.first

      # Deactivate
      @client.common.deactivate_user(
        uid,
        GetStream::Generated::Models::DeactivateUserRequest.new
      )

      # Reactivate
      @client.common.reactivate_user(
        uid,
        GetStream::Generated::Models::ReactivateUserRequest.new
      )

      # Verify active by querying
      resp = query_users_with_filter({ 'id' => uid })
      expect(resp.users.length).to eq(1)
    end
  end

  describe 'DeleteUsers' do
    it 'deletes 2 users with retry and polls task until completed' do
      user_ids, _resp = create_test_users(2)

      # Remove from tracked list so cleanup doesn't double-delete
      user_ids.each { |uid| @created_user_ids.delete(uid) }

      resp = nil
      10.times do |i|
        resp = @client.common.delete_users(
          GetStream::Generated::Models::DeleteUsersRequest.new(
            user_ids: user_ids,
            user: 'hard',
            messages: 'hard',
            conversations: 'hard'
          )
        )
        break
      rescue GetStreamRuby::APIError => e
        raise unless e.message.include?('Too many requests')

        sleep((i + 1) * 3)
      end

      expect(resp).not_to be_nil
      task_id = resp.task_id
      expect(task_id).not_to be_nil

      result = wait_for_task(task_id)
      expect(result.status).to eq('completed')
    end
  end

  describe 'ExportUser' do
    it 'exports a user and verifies response not nil' do
      user_ids, _resp = create_test_users(1)
      uid = user_ids.first

      resp = @client.common.export_user(uid)
      expect(resp).not_to be_nil
    end
  end

  describe 'CreateGuest' do
    it 'creates guest and verifies access token' do
      guest_id = "test-guest-#{SecureRandom.uuid}"

      resp = @client.common.create_guest(
        GetStream::Generated::Models::CreateGuestRequest.new(
          user: GetStream::Generated::Models::UserRequest.new(
            id: guest_id,
            name: 'Test Guest'
          )
        )
      )

      expect(resp.access_token).not_to be_nil
      expect(resp.access_token).not_to be_empty

      # Clean up the guest user
      @created_user_ids << guest_id
    rescue GetStreamRuby::APIError => e
      skip('Guest access not enabled') if e.message.downcase.include?('guest')
      raise
    end
  end

  describe 'UpsertUsersWithRoleAndTeamsRole' do
    it 'creates user with role=admin, teams, and teams_role' do
      uid = "test-user-#{SecureRandom.uuid}"
      @created_user_ids << uid

      @client.common.update_users(
        GetStream::Generated::Models::UpdateUsersRequest.new(
          users: {
            uid => GetStream::Generated::Models::UserRequest.new(
              id: uid,
              name: "Admin User #{uid[0..7]}",
              role: 'admin',
              teams: ['blue'],
              teams_role: { 'blue' => 'admin' }
            )
          }
        )
      )

      resp = query_users_with_filter({ 'id' => uid })
      user = resp.users.first
      user_h = user.to_h
      expect(user_h['role']).to eq('admin')
      expect(user_h['teams']).to include('blue')
      expect(user_h['teams_role']).to eq({ 'blue' => 'admin' })
    end
  end

  describe 'PartialUpdateUserWithTeam' do
    it 'partial updates to add teams and teams_role' do
      user_ids, _resp = create_test_users(1)
      uid = user_ids.first

      @client.common.update_users_partial(
        GetStream::Generated::Models::UpdateUsersPartialRequest.new(
          users: [
            GetStream::Generated::Models::UpdateUserPartialRequest.new(
              id: uid,
              set: {
                'teams' => ['blue'],
                'teams_role' => { 'blue' => 'admin' }
              }
            )
          ]
        )
      )

      resp = query_users_with_filter({ 'id' => uid })
      user = resp.users.first
      user_h = user.to_h
      expect(user_h['teams']).to include('blue')
      expect(user_h['teams_role']).to eq({ 'blue' => 'admin' })
    end
  end

  describe 'UpdatePrivacySettings' do
    it 'sets typing_indicators disabled then sets both typing + read_receipts' do
      uid = "test-user-#{SecureRandom.uuid}"
      @created_user_ids << uid

      # Create user with typing_indicators disabled
      @client.common.update_users(
        GetStream::Generated::Models::UpdateUsersRequest.new(
          users: {
            uid => GetStream::Generated::Models::UserRequest.new(
              id: uid,
              name: "Privacy User #{uid[0..7]}",
              privacy_settings: GetStream::Generated::Models::PrivacySettingsResponse.new(
                typing_indicators: GetStream::Generated::Models::TypingIndicatorsResponse.new(enabled: false)
              )
            )
          }
        )
      )

      resp = query_users_with_filter({ 'id' => uid })
      user_h = resp.users.first.to_h
      expect(user_h.dig('privacy_settings', 'typing_indicators', 'enabled')).to eq(false)

      # Update both typing_indicators and read_receipts
      @client.common.update_users(
        GetStream::Generated::Models::UpdateUsersRequest.new(
          users: {
            uid => GetStream::Generated::Models::UserRequest.new(
              id: uid,
              privacy_settings: GetStream::Generated::Models::PrivacySettingsResponse.new(
                typing_indicators: GetStream::Generated::Models::TypingIndicatorsResponse.new(enabled: true),
                read_receipts: GetStream::Generated::Models::ReadReceiptsResponse.new(enabled: false)
              )
            )
          }
        )
      )

      resp2 = query_users_with_filter({ 'id' => uid })
      user_h2 = resp2.users.first.to_h
      expect(user_h2.dig('privacy_settings', 'typing_indicators', 'enabled')).to eq(true)
      expect(user_h2.dig('privacy_settings', 'read_receipts', 'enabled')).to eq(false)
    end
  end

  describe 'PartialUpdatePrivacySettings' do
    it 'partial updates privacy settings incrementally' do
      user_ids, _resp = create_test_users(1)
      uid = user_ids.first

      # First: set typing_indicators.enabled = true
      @client.common.update_users_partial(
        GetStream::Generated::Models::UpdateUsersPartialRequest.new(
          users: [
            GetStream::Generated::Models::UpdateUserPartialRequest.new(
              id: uid,
              set: {
                'privacy_settings' => {
                  'typing_indicators' => { 'enabled' => true }
                }
              }
            )
          ]
        )
      )

      resp = query_users_with_filter({ 'id' => uid })
      user_h = resp.users.first.to_h
      expect(user_h.dig('privacy_settings', 'typing_indicators', 'enabled')).to eq(true)

      # Second: set read_receipts.enabled = false
      @client.common.update_users_partial(
        GetStream::Generated::Models::UpdateUsersPartialRequest.new(
          users: [
            GetStream::Generated::Models::UpdateUserPartialRequest.new(
              id: uid,
              set: {
                'privacy_settings' => {
                  'read_receipts' => { 'enabled' => false }
                }
              }
            )
          ]
        )
      )

      resp2 = query_users_with_filter({ 'id' => uid })
      user_h2 = resp2.users.first.to_h
      expect(user_h2.dig('privacy_settings', 'read_receipts', 'enabled')).to eq(false)
    end
  end

  describe 'QueryUsersWithDeactivated' do
    it 'deactivates one user, queries without/with include_deactivated' do
      user_ids, _resp = create_test_users(3)
      deactivated_id = user_ids.first

      # Deactivate one user
      @client.common.deactivate_user(
        deactivated_id,
        GetStream::Generated::Models::DeactivateUserRequest.new
      )

      # Query WITHOUT include_deactivated_users — expect 2
      resp = query_users_with_filter({ 'id' => { '$in' => user_ids } })
      expect(resp.users.length).to eq(2)

      # Query WITH include_deactivated_users — expect 3
      resp2 = query_users_with_filter(
        { 'id' => { '$in' => user_ids } },
        include_deactivated_users: true
      )
      expect(resp2.users.length).to eq(3)

      # Reactivate for cleanup
      @client.common.reactivate_user(
        deactivated_id,
        GetStream::Generated::Models::ReactivateUserRequest.new
      )
    end
  end

  describe 'DeactivateUsersPlural' do
    it 'deactivates multiple users at once via async task' do
      user_ids, _resp = create_test_users(2)

      resp = @client.common.deactivate_users(
        GetStream::Generated::Models::DeactivateUsersRequest.new(
          user_ids: user_ids
        )
      )

      task_id = resp.task_id
      expect(task_id).not_to be_nil

      result = wait_for_task(task_id)
      expect(result.status).to eq('completed')

      # Verify deactivated users don't appear in default query
      query_resp = query_users_with_filter({ 'id' => { '$in' => user_ids } })
      expect(query_resp.users.length).to eq(0)

      # Reactivate for cleanup
      user_ids.each do |uid|
        @client.common.reactivate_user(uid, GetStream::Generated::Models::ReactivateUserRequest.new)
      end
    end
  end

  describe 'UserCustomData' do
    it 'creates user with custom fields and verifies persistence' do
      uid = "test-user-#{SecureRandom.uuid}"
      @created_user_ids << uid

      custom_data = {
        'favorite_color' => 'blue',
        'age' => 30,
        'tags' => %w[vip early_adopter]
      }

      resp = @client.common.update_users(
        GetStream::Generated::Models::UpdateUsersRequest.new(
          users: {
            uid => GetStream::Generated::Models::UserRequest.new(
              id: uid,
              name: "Custom User #{uid[0..7]}",
              custom: custom_data
            )
          }
        )
      )

      # Verify in upsert response
      users_hash = resp.users.to_h
      expect(users_hash).to have_key(uid)

      # Verify via query
      query_resp = query_users_with_filter({ 'id' => uid })
      user_h = query_resp.users.first.to_h
      expect(user_h['custom']['favorite_color'] || user_h['favorite_color']).to eq('blue')
    end
  end
end
