# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'chat_test_helpers'

RSpec.describe 'Chat Client Integration', type: :integration do

  include ChatTestHelpers

  before(:all) do

    init_chat_client
    @shared_user_ids, _resp = create_test_users(3)
    @creator_id = @shared_user_ids[0]
    @member_a = @shared_user_ids[1]
    @member_b = @shared_user_ids[2]

  end

  after(:all) do

    cleanup_chat_resources

  end

  # ---------------------------------------------------------------------------
  # QueryChannels via generated client
  # ---------------------------------------------------------------------------

  describe 'QueryChannels' do

    it 'queries channels using the generated chat client' do

      _type, channel_id, _resp = create_test_channel(@creator_id)

      resp = @client.chat.query_channels(
        GetStream::Generated::Models::QueryChannelsRequest.new(
          filter_conditions: { 'id' => channel_id },
        ),
      )
      expect(resp.channels).not_to be_nil
      expect(resp.channels).not_to be_empty
      ch = resp.channels.first.to_h
      expect(ch.dig('channel', 'id')).to eq(channel_id)

    end

  end

  # ---------------------------------------------------------------------------
  # GetOrCreateChannel via generated client
  # ---------------------------------------------------------------------------

  describe 'GetOrCreateChannel' do

    it 'creates and retrieves a channel using the generated chat client' do

      channel_id = "test-ch-#{SecureRandom.hex(6)}"
      @created_channel_cids << "messaging:#{channel_id}"

      resp = @client.chat.get_or_create_channel(
        'messaging', channel_id,
        GetStream::Generated::Models::ChannelGetOrCreateRequest.new(
          data: { created_by_id: @creator_id },
        )
      )
      expect(resp.channel).not_to be_nil
      expect(resp.channel.to_h['id']).to eq(channel_id)

    end

  end

  # ---------------------------------------------------------------------------
  # UpdateChannel via generated client
  # ---------------------------------------------------------------------------

  describe 'UpdateChannel' do

    it 'updates channel with members and custom data' do

      _type, channel_id, _resp = create_test_channel(@creator_id)

      resp = @client.chat.update_channel(
        'messaging', channel_id,
        GetStream::Generated::Models::UpdateChannelRequest.new(
          add_members: [{ user_id: @member_a }, { user_id: @member_b }],
          data: { custom: { color: 'green' } },
        )
      )
      expect(resp.channel).not_to be_nil
      expect(resp.members.length).to be >= 2

    end

  end

  # ---------------------------------------------------------------------------
  # UpdateChannelPartial via generated client
  # ---------------------------------------------------------------------------

  describe 'UpdateChannelPartial' do

    it 'sets and unsets channel fields' do

      _type, channel_id, _resp = create_test_channel(@creator_id)

      resp = @client.chat.update_channel_partial(
        'messaging', channel_id,
        GetStream::Generated::Models::UpdateChannelPartialRequest.new(
          set: { 'color' => 'blue', 'topic' => 'testing' },
        )
      )
      ch = resp.channel.to_h
      custom = ch['custom'] || {}
      expect(custom['color']).to eq('blue')

      resp_b = @client.chat.update_channel_partial(
        'messaging', channel_id,
        GetStream::Generated::Models::UpdateChannelPartialRequest.new(
          unset: ['color'],
        )
      )
      ch_b = resp_b.channel.to_h
      custom_b = ch_b['custom'] || {}
      expect(custom_b).not_to have_key('color')

    end

  end

  # ---------------------------------------------------------------------------
  # SendMessage via generated client
  # ---------------------------------------------------------------------------

  describe 'SendMessage' do

    it 'sends a message using the generated chat client' do

      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_a]
      )

      resp = @client.chat.send_message(
        'messaging', channel_id,
        GetStream::Generated::Models::SendMessageRequest.new(
          message: { text: 'Hello from generated client', user_id: @creator_id },
        )
      )
      expect(resp.message).not_to be_nil
      expect(resp.message.to_h['text']).to eq('Hello from generated client')

    end

  end

  # ---------------------------------------------------------------------------
  # HideChannel and ShowChannel via generated client
  # ---------------------------------------------------------------------------

  describe 'HideShowChannel' do

    it 'hides and shows a channel using the generated chat client' do

      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_a]
      )

      @client.chat.hide_channel(
        'messaging', channel_id,
        GetStream::Generated::Models::HideChannelRequest.new(user_id: @member_a)
      )

      @client.chat.show_channel(
        'messaging', channel_id,
        GetStream::Generated::Models::ShowChannelRequest.new(user_id: @member_a)
      )

    end

  end

  # ---------------------------------------------------------------------------
  # TruncateChannel via generated client
  # ---------------------------------------------------------------------------

  describe 'TruncateChannel' do

    it 'truncates a channel using the generated chat client' do

      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_a]
      )

      send_test_message('messaging', channel_id, @creator_id, 'Message to truncate')

      @client.chat.truncate_channel(
        'messaging', channel_id,
        GetStream::Generated::Models::TruncateChannelRequest.new(hard_delete: true)
      )

      resp = @client.chat.get_or_create_channel(
        'messaging', channel_id,
        GetStream::Generated::Models::ChannelGetOrCreateRequest.new
      )
      messages = resp.messages || []
      expect(messages).to be_empty

    end

  end

  # ---------------------------------------------------------------------------
  # SendEvent via generated client
  # ---------------------------------------------------------------------------

  describe 'SendEvent' do

    it 'sends a typing event using the generated chat client' do

      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_a]
      )

      resp = @client.chat.send_event(
        'messaging', channel_id,
        GetStream::Generated::Models::SendEventRequest.new(
          event: { type: 'typing.start', user_id: @creator_id },
        )
      )
      expect(resp).not_to be_nil

    end

  end

  # ---------------------------------------------------------------------------
  # DeleteChannel via generated client
  # ---------------------------------------------------------------------------

  describe 'DeleteChannel' do

    it 'soft deletes a channel using the generated chat client' do

      channel_id = "test-del-#{SecureRandom.hex(6)}"
      @client.chat.get_or_create_channel(
        'messaging', channel_id,
        GetStream::Generated::Models::ChannelGetOrCreateRequest.new(
          data: { created_by_id: @creator_id },
        )
      )
      # Don't track since we are deleting it
      resp = @client.chat.delete_channel('messaging', channel_id)
      expect(resp.channel).not_to be_nil

    end

  end

  # ---------------------------------------------------------------------------
  # DeleteChannels (batch) via generated client
  # ---------------------------------------------------------------------------

  describe 'DeleteChannels' do

    it 'batch hard deletes channels using the generated chat client' do

      _type_a, channel_id_a, _resp_a = create_test_channel(@creator_id)
      _type_b, channel_id_b, _resp_b = create_test_channel(@creator_id)

      cid_a = "messaging:#{channel_id_a}"
      cid_b = "messaging:#{channel_id_b}"

      @created_channel_cids.delete(cid_a)
      @created_channel_cids.delete(cid_b)

      resp = @client.chat.delete_channels(
        GetStream::Generated::Models::DeleteChannelsRequest.new(
          cids: [cid_a, cid_b],
          hard_delete: true,
        ),
      )
      expect(resp.task_id).not_to be_nil

      result = wait_for_task(resp.task_id)
      expect(result.status).to eq('completed')

    end

  end

  # ---------------------------------------------------------------------------
  # ListChannelTypes via generated client
  # ---------------------------------------------------------------------------

  describe 'ListChannelTypes' do

    it 'lists channel types using the generated chat client' do

      resp = @client.chat.list_channel_types
      resp_h = resp.to_h
      expect(resp_h['channel_types']).not_to be_nil
      expect(resp_h['channel_types']).not_to be_empty

    end

  end

  # ---------------------------------------------------------------------------
  # GetChannelType via generated client
  # ---------------------------------------------------------------------------

  describe 'GetChannelType' do

    it 'gets the messaging channel type using the generated chat client' do

      resp = @client.chat.get_channel_type('messaging')
      expect(resp.name).to eq('messaging')

    end

  end

  # ---------------------------------------------------------------------------
  # MarkRead via generated client
  # ---------------------------------------------------------------------------

  describe 'MarkRead' do

    it 'marks a channel as read using the generated chat client' do

      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_a]
      )

      send_test_message('messaging', channel_id, @creator_id, 'Read me')

      resp = @client.chat.mark_read(
        'messaging', channel_id,
        GetStream::Generated::Models::MarkReadRequest.new(user_id: @member_a)
      )
      expect(resp).not_to be_nil

    end

  end

end
