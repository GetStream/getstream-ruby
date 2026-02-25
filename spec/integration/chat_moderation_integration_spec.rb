# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'chat_test_helpers'

RSpec.describe 'Chat Moderation Integration', type: :integration do
  include ChatTestHelpers

  before(:all) do
    init_chat_client
    @shared_user_ids, _resp = create_test_users(4)
    @user1 = @shared_user_ids[0]
    @user2 = @shared_user_ids[1]
    @user3 = @shared_user_ids[2]
    @user4 = @shared_user_ids[3]
  end

  after(:all) do
    cleanup_chat_resources
  end

  # ---------------------------------------------------------------------------
  # Ban / Unban User
  # ---------------------------------------------------------------------------

  describe 'BanUnbanUser' do
    it 'bans a user from a channel, verifies, and unbans' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])
      cid = "messaging:#{channel_id}"

      # Ban user in channel
      @client.moderation.ban(
        GetStream::Generated::Models::BanRequest.new(
          target_user_id: @user2,
          banned_by_id: @user1,
          channel_cid: cid,
          reason: 'moderation test ban',
          timeout: 60
        )
      )

      # Verify via query banned users
      resp = @client.make_request(:get, '/api/v2/chat/query_banned_users', query_params: {
        'payload' => JSON.generate({
          filter_conditions: { 'channel_cid' => { '$eq' => cid } }
        })
      })
      bans = resp.bans || []
      expect(bans.length).to be >= 1

      banned_user_ids = bans.map do |b|
        h = b.is_a?(Hash) ? b : b.to_h
        target = h['user'] || {}
        target = target.is_a?(Hash) ? target : target.to_h
        target['id']
      end
      expect(banned_user_ids).to include(@user2)

      # Unban user
      @client.moderation.unban(
        GetStream::Generated::Models::UnbanRequest.new,
        @user2,
        cid
      )

      # Verify ban is removed
      resp2 = @client.make_request(:get, '/api/v2/chat/query_banned_users', query_params: {
        'payload' => JSON.generate({
          filter_conditions: { 'channel_cid' => { '$eq' => cid } }
        })
      })
      bans2 = resp2.bans || []
      banned_ids_after = bans2.map do |b|
        h = b.is_a?(Hash) ? b : b.to_h
        target = h['user'] || {}
        target = target.is_a?(Hash) ? target : target.to_h
        target['id']
      end
      expect(banned_ids_after).not_to include(@user2)
    end

    it 'bans a user app-wide, verifies, and unbans' do
      # Ban user app-wide (no channel_cid)
      @client.moderation.ban(
        GetStream::Generated::Models::BanRequest.new(
          target_user_id: @user3,
          banned_by_id: @user1,
          reason: 'app-wide moderation test ban',
          timeout: 60
        )
      )

      # Verify via query banned users (app-level)
      resp = @client.make_request(:get, '/api/v2/chat/query_banned_users', query_params: {
        'payload' => JSON.generate({
          filter_conditions: { 'user_id' => { '$eq' => @user3 } }
        })
      })
      bans = resp.bans || []
      expect(bans.length).to be >= 1

      # Unban user app-wide
      @client.moderation.unban(
        GetStream::Generated::Models::UnbanRequest.new,
        @user3
      )

      # Verify ban is removed
      resp2 = @client.make_request(:get, '/api/v2/chat/query_banned_users', query_params: {
        'payload' => JSON.generate({
          filter_conditions: { 'user_id' => { '$eq' => @user3 } }
        })
      })
      bans2 = resp2.bans || []
      expect(bans2.length).to eq(0), "App-wide ban should be removed after unban"
    end
  end

  # ---------------------------------------------------------------------------
  # Mute / Unmute User
  # ---------------------------------------------------------------------------

  describe 'MuteUnmuteUser' do
    it 'mutes a user, verifies via query, and unmutes' do
      # Mute user
      mute_resp = @client.moderation.mute(
        GetStream::Generated::Models::MuteRequest.new(
          target_ids: [@user4],
          user_id: @user1
        )
      )
      expect(mute_resp.mutes).not_to be_nil
      expect(mute_resp.mutes.length).to be >= 1

      mute_h = mute_resp.mutes[0].is_a?(Hash) ? mute_resp.mutes[0] : mute_resp.mutes[0].to_h
      target = mute_h['target'] || {}
      target = target.is_a?(Hash) ? target : target.to_h
      expect(target['id']).to eq(@user4)

      # Verify via QueryUsers that muter has mutes
      q_resp = @client.common.query_users(JSON.generate({
        filter_conditions: { 'id' => { '$eq' => @user1 } }
      }))
      expect(q_resp.users).not_to be_nil
      expect(q_resp.users.length).to be >= 1
      user_h = q_resp.users[0].is_a?(Hash) ? q_resp.users[0] : q_resp.users[0].to_h
      expect(user_h['mutes']).not_to be_nil
      expect(user_h['mutes'].length).to be >= 1

      muted_ids = user_h['mutes'].map do |m|
        t = m.is_a?(Hash) ? m : m.to_h
        tgt = t['target'] || {}
        tgt = tgt.is_a?(Hash) ? tgt : tgt.to_h
        tgt['id']
      end
      expect(muted_ids).to include(@user4)

      # Unmute user
      @client.moderation.unmute(
        GetStream::Generated::Models::UnmuteRequest.new(
          target_ids: [@user4],
          user_id: @user1
        )
      )

      # Verify mute is removed
      q_resp2 = @client.common.query_users(JSON.generate({
        filter_conditions: { 'id' => { '$eq' => @user1 } }
      }))
      user_h2 = q_resp2.users[0].is_a?(Hash) ? q_resp2.users[0] : q_resp2.users[0].to_h
      mutes_after = user_h2['mutes'] || []
      muted_ids_after = mutes_after.map do |m|
        t = m.is_a?(Hash) ? m : m.to_h
        tgt = t['target'] || {}
        tgt = tgt.is_a?(Hash) ? tgt : tgt.to_h
        tgt['id']
      end
      expect(muted_ids_after).not_to include(@user4)
    end
  end

  # ---------------------------------------------------------------------------
  # Flag Message and User
  # ---------------------------------------------------------------------------

  describe 'FlagMessageAndUser' do
    it 'flags a message and verifies response' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])
      msg_id = send_test_message('messaging', channel_id, @user1, "Flaggable message #{SecureRandom.hex(4)}")

      # Flag message
      flag_resp = @client.moderation.flag(
        GetStream::Generated::Models::FlagRequest.new(
          entity_type: 'stream:chat:v1:message',
          entity_id: msg_id,
          entity_creator_id: @user1,
          reason: 'inappropriate content',
          user_id: @user2
        )
      )
      expect(flag_resp).not_to be_nil
    end

    it 'flags a user and verifies response' do
      # Flag user
      flag_resp = @client.moderation.flag(
        GetStream::Generated::Models::FlagRequest.new(
          entity_type: 'stream:user',
          entity_id: @user3,
          entity_creator_id: @user3,
          reason: 'spam behavior',
          user_id: @user1
        )
      )
      expect(flag_resp).not_to be_nil
    end
  end
end
