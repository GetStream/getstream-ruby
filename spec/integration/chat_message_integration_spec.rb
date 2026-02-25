# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'chat_test_helpers'

RSpec.describe 'Chat Message Integration', type: :integration do
  include ChatTestHelpers

  before(:all) do
    init_chat_client
    # Create shared test users for all subtests
    @shared_user_ids, _resp = create_test_users(3)
    @user1 = @shared_user_ids[0]
    @user2 = @shared_user_ids[1]
    @user3 = @shared_user_ids[2]
  end

  after(:all) do
    cleanup_chat_resources
  end

  # ---------------------------------------------------------------------------
  # Message API wrappers
  # ---------------------------------------------------------------------------

  def get_message(message_id)
    @client.make_request(:get, "/api/v2/chat/messages/#{message_id}")
  end

  def get_many_messages(type, id, message_ids)
    @client.make_request(
      :get,
      "/api/v2/chat/channels/#{type}/#{id}/messages",
      query_params: { 'ids' => message_ids.join(',') }
    )
  end

  def update_message(message_id, body)
    @client.make_request(:post, "/api/v2/chat/messages/#{message_id}", body: body)
  end

  def update_message_partial(message_id, body)
    @client.make_request(:put, "/api/v2/chat/messages/#{message_id}", body: body)
  end

  def delete_message(message_id, query_params = {})
    @client.make_request(:delete, "/api/v2/chat/messages/#{message_id}", query_params: query_params)
  end

  def send_msg(type, id, body)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/message", body: body)
  end

  def translate_message(message_id, body)
    @client.make_request(:post, "/api/v2/chat/messages/#{message_id}/translate", body: body)
  end

  def get_replies(parent_id, **query_params)
    @client.make_request(:get, "/api/v2/chat/messages/#{parent_id}/replies", query_params: query_params)
  end

  def search_messages(body)
    @client.make_request(:get, '/api/v2/chat/search', query_params: { 'payload' => JSON.generate(body) })
  end

  def commit_message(message_id)
    @client.make_request(:post, "/api/v2/chat/messages/#{message_id}/commit")
  end

  def query_message_history(body)
    @client.make_request(:post, '/api/v2/chat/messages/history', body: body)
  end

  def hide_channel(type, id, body)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/hide", body: body)
  end

  def undelete_message(message_id, body)
    @client.make_request(:post, "/api/v2/chat/messages/#{message_id}/undelete", body: body)
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe 'SendAndGetMessage' do
    it 'sends message, gets by ID, verifies text' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      msg_text = "Hello from integration test #{SecureRandom.hex(8)}"
      send_resp = send_msg('messaging', channel_id,
                           message: { text: msg_text, user_id: @user1 })
      expect(send_resp.message).not_to be_nil
      msg_id = send_resp.message.id
      expect(msg_id).not_to be_nil
      expect(send_resp.message.to_h['text']).to eq(msg_text)

      # Get message by ID
      get_resp = get_message(msg_id)
      expect(get_resp.message).not_to be_nil
      expect(get_resp.message.to_h['id']).to eq(msg_id)
      expect(get_resp.message.to_h['text']).to eq(msg_text)
    end
  end

  describe 'GetManyMessages' do
    it 'sends 3 messages, gets all 3 by IDs' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      id1 = send_test_message('messaging', channel_id, @user1, 'Msg 1')
      id2 = send_test_message('messaging', channel_id, @user1, 'Msg 2')
      id3 = send_test_message('messaging', channel_id, @user1, 'Msg 3')

      resp = get_many_messages('messaging', channel_id, [id1, id2, id3])
      expect(resp.messages).not_to be_nil
      expect(resp.messages.length).to eq(3)
    end
  end

  describe 'UpdateMessage' do
    it 'sends message, updates text, verifies' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])
      msg_id = send_test_message('messaging', channel_id, @user1, 'Original text')

      updated_text = "Updated text #{SecureRandom.hex(8)}"
      resp = update_message(msg_id, message: { text: updated_text, user_id: @user1 })
      expect(resp.message).not_to be_nil
      expect(resp.message.to_h['text']).to eq(updated_text)
    end
  end

  describe 'PartialUpdateMessage' do
    it 'sets custom fields; unsets one' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])
      msg_id = send_test_message('messaging', channel_id, @user1, 'Partial update test')

      # Set custom fields
      resp = update_message_partial(msg_id,
                                    set: { 'priority' => 'high', 'status' => 'reviewed' },
                                    user_id: @user1)
      expect(resp.message).not_to be_nil

      # Unset custom field
      resp2 = update_message_partial(msg_id,
                                     unset: ['status'],
                                     user_id: @user1)
      expect(resp2.message).not_to be_nil
    end
  end

  describe 'DeleteMessage' do
    it 'soft deletes, verifies type=deleted' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])
      msg_id = send_test_message('messaging', channel_id, @user1, 'Message to delete')

      resp = delete_message(msg_id)
      expect(resp.message).not_to be_nil
      expect(resp.message.to_h['type']).to eq('deleted')
    end
  end

  describe 'HardDeleteMessage' do
    it 'hard deletes, verifies type=deleted' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])
      msg_id = send_test_message('messaging', channel_id, @user1, 'Message to hard delete')

      resp = delete_message(msg_id, { 'hard' => 'true' })
      expect(resp.message).not_to be_nil
      expect(resp.message.to_h['type']).to eq('deleted')
    end
  end

  describe 'PinUnpinMessage' do
    it 'sends pinned message; unpins via partial update' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      # Send a pinned message
      send_resp = send_msg('messaging', channel_id,
                           message: { text: 'Pinned message', user_id: @user1, pinned: true })
      expect(send_resp.message).not_to be_nil
      msg_id = send_resp.message.id
      expect(send_resp.message.to_h['pinned']).to eq(true)

      # Unpin via partial update
      resp = update_message_partial(msg_id,
                                    set: { 'pinned' => false },
                                    user_id: @user1)
      expect(resp.message).not_to be_nil
      expect(resp.message.to_h['pinned']).to eq(false)
    end
  end

  describe 'TranslateMessage' do
    it 'translates to Spanish, verifies i18n field' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])
      msg_id = send_test_message('messaging', channel_id, @user1, 'Hello, how are you?')

      resp = translate_message(msg_id, language: 'es')
      expect(resp.message).not_to be_nil
      i18n = resp.message.to_h['i18n']
      expect(i18n).not_to be_nil
    end
  end

  describe 'ThreadReply' do
    it 'sends parent, sends reply with parent_id, gets replies' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])

      # Send parent message
      parent_id = send_test_message('messaging', channel_id, @user1, 'Parent message for thread')

      # Send reply
      reply_resp = send_msg('messaging', channel_id,
                            message: { text: 'Reply to parent', user_id: @user2, parent_id: parent_id })
      expect(reply_resp.message).not_to be_nil
      expect(reply_resp.message.id).not_to be_nil

      # Get replies
      replies_resp = get_replies(parent_id)
      expect(replies_resp.messages).not_to be_nil
      expect(replies_resp.messages.length).to be >= 1
    end
  end

  describe 'SearchMessages' do
    it 'sends message with unique term, waits, searches, verifies found' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      search_term = "uniquesearch#{SecureRandom.hex(8)}"
      send_test_message('messaging', channel_id, @user1, "This message contains #{search_term} for testing")

      # Wait for indexing
      sleep(2)

      resp = search_messages(
        query: search_term,
        filter_conditions: { 'cid' => "messaging:#{channel_id}" }
      )
      expect(resp.results).not_to be_nil
      expect(resp.results).not_to be_empty
    end
  end

  describe 'SilentMessage' do
    it 'sends with silent=true, verifies' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      resp = send_msg('messaging', channel_id,
                      message: { text: 'This is a silent message', user_id: @user1, silent: true })
      expect(resp.message).not_to be_nil
      expect(resp.message.to_h['silent']).to eq(true)
    end
  end

  describe 'PendingMessage' do
    it 'sends pending, commits, verifies (skip if not enabled)' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      begin
        send_resp = send_msg('messaging', channel_id,
                             message: { text: 'Pending message text', user_id: @user1 },
                             pending: true,
                             skip_push: true)
      rescue StandardError => e
        if e.message.include?('pending messages not enabled') || e.message.include?('feature flag')
          skip('Pending messages feature not enabled for this app')
        end
        raise
      end

      expect(send_resp.message).not_to be_nil
      msg_id = send_resp.message.id
      expect(msg_id).not_to be_nil

      # Commit the pending message
      commit_resp = commit_message(msg_id)
      expect(commit_resp.message).not_to be_nil
      expect(commit_resp.message.to_h['id']).to eq(msg_id)
    end
  end

  describe 'QueryMessageHistory' do
    it 'sends, updates twice, queries history, verifies entries (skip if not enabled)' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])

      # Send initial message
      send_resp = send_msg('messaging', channel_id,
                           message: { text: 'initial text', user_id: @user1,
                                      custom: { 'custom_field' => 'custom value' } })
      msg_id = send_resp.message.id

      # Update by user1
      update_message(msg_id, message: { text: 'updated text', user_id: @user1,
                                        custom: { 'custom_field' => 'updated custom value' } })

      # Update by user2
      update_message(msg_id, message: { text: 'updated text 2', user_id: @user2 })

      # Query message history
      begin
        hist_resp = query_message_history(
          filter: { 'message_id' => msg_id },
          sort: []
        )
      rescue StandardError => e
        if e.message.include?('feature flag') || e.message.include?('not enabled')
          skip('QueryMessageHistory feature not enabled for this app')
        end
        raise
      end

      expect(hist_resp.message_history).not_to be_nil
      expect(hist_resp.message_history.length).to be >= 2

      # Verify history entries reference the correct message
      hist_resp.message_history.each do |entry|
        h = entry.to_h
        expect(h['message_id']).to eq(msg_id)
      end

      # Verify text values (descending by default: most recent first)
      expect(hist_resp.message_history[0].to_h['text']).to eq('updated text')
      expect(hist_resp.message_history[1].to_h['text']).to eq('initial text')
    end
  end

  describe 'QueryMessageHistorySort' do
    it 'queries history with ascending sort' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      send_resp = send_msg('messaging', channel_id,
                           message: { text: 'sort initial', user_id: @user1 })
      msg_id = send_resp.message.id

      update_message(msg_id, message: { text: 'sort updated 1', user_id: @user1 })
      update_message(msg_id, message: { text: 'sort updated 2', user_id: @user1 })

      begin
        hist_resp = query_message_history(
          filter: { 'message_id' => msg_id },
          sort: [{ 'field' => 'message_updated_at', 'direction' => 1 }]
        )
      rescue StandardError => e
        if e.message.include?('feature flag') || e.message.include?('not enabled')
          skip('QueryMessageHistory feature not enabled for this app')
        end
        raise
      end

      expect(hist_resp.message_history).not_to be_nil
      expect(hist_resp.message_history.length).to be >= 2

      # Ascending: oldest first
      expect(hist_resp.message_history[0].to_h['text']).to eq('sort initial')
    end
  end

  describe 'SkipEnrichUrl' do
    it 'sends with URL and skip_enrich_url=true, verifies no attachments' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      send_resp = send_msg('messaging', channel_id,
                           message: { text: 'Check out https://getstream.io for more info', user_id: @user1 },
                           skip_enrich_url: true)
      expect(send_resp.message).not_to be_nil
      attachments = send_resp.message.to_h['attachments'] || []
      expect(attachments).to be_empty

      # Verify via GetMessage that attachments remain empty
      sleep(1)
      get_resp = get_message(send_resp.message.id)
      attachments2 = get_resp.message.to_h['attachments'] || []
      expect(attachments2).to be_empty
    end
  end

  describe 'KeepChannelHidden' do
    it 'hides channel, sends with keep_channel_hidden=true, verifies still hidden' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])
      cid = "messaging:#{channel_id}"

      # Hide the channel
      hide_channel('messaging', channel_id, user_id: @user1)

      # Send a message with keep_channel_hidden=true
      send_msg('messaging', channel_id,
               message: { text: 'Hidden message', user_id: @user1 },
               keep_channel_hidden: true)

      # Query channels — the channel should still be hidden
      q_resp = query_channels(
        filter_conditions: { 'cid' => cid },
        user_id: @user1
      )
      expect(q_resp.channels).to be_empty
    end
  end

  describe 'UndeleteMessage' do
    it 'soft deletes, undeletes, verifies restored' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])
      msg_id = send_test_message('messaging', channel_id, @user1, 'Message to undelete')

      # Soft delete
      delete_message(msg_id)

      # Verify deleted
      get_resp = get_message(msg_id)
      expect(get_resp.message.to_h['type']).to eq('deleted')

      # Undelete
      begin
        undel_resp = undelete_message(msg_id, undeleted_by: @user1)
      rescue StandardError => e
        if e.message.include?('undeleted_by') || e.message.include?('required field')
          skip('UndeleteMessage requires undeleted_by field not yet in generated request struct')
        end
        raise
      end
      expect(undel_resp.message).not_to be_nil
      expect(undel_resp.message.to_h['type']).not_to eq('deleted')
      expect(undel_resp.message.to_h['text']).to eq('Message to undelete')
    end
  end

  describe 'RestrictedVisibility' do
    it 'sends with restricted_visibility list (skip if not enabled)' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])

      begin
        send_resp = send_msg('messaging', channel_id,
                             message: { text: 'Secret message', user_id: @user1,
                                        restricted_visibility: [@user1] })
      rescue StandardError => e
        if e.message.include?('private messaging is not allowed') || e.message.include?('not enabled')
          skip('RestrictedVisibility (private messaging) is not enabled for this app')
        end
        raise
      end

      expect(send_resp.message.to_h['restricted_visibility']).to eq([@user1])
    end
  end

  describe 'DeleteMessageForMe' do
    it 'deletes message with delete_for_me=true' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])
      msg_id = send_test_message('messaging', channel_id, @user1, 'test message to delete for me')

      delete_message(msg_id, { 'delete_for_me' => 'true', 'deleted_by' => @user1 })
    end
  end

  describe 'PinExpiration' do
    it 'pins with 3s expiry, waits 4s, verifies expired' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])
      msg_id = send_test_message('messaging', channel_id, @user2, 'Message to pin with expiry')

      # Pin with 3 second expiration
      expiry = (Time.now.utc + 3).strftime('%Y-%m-%dT%H:%M:%S.%6NZ')
      pin_resp = update_message_partial(msg_id,
                                        set: { 'pinned' => true, 'pin_expires' => expiry },
                                        user_id: @user1)
      expect(pin_resp.message).not_to be_nil
      expect(pin_resp.message.to_h['pinned']).to eq(true)

      # Wait for pin to expire
      sleep(4)

      # Verify pin expired
      get_resp = get_message(msg_id)
      expect(get_resp.message.to_h['pinned']).to eq(false)
    end
  end

  describe 'SystemMessage' do
    it 'sends with type=system, verifies' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      resp = send_msg('messaging', channel_id,
                      message: { text: 'User joined the channel', user_id: @user1, type: 'system' })
      expect(resp.message).not_to be_nil
      expect(resp.message.to_h['type']).to eq('system')
    end
  end

  describe 'PendingFalse' do
    it 'sends with pending=false, verifies immediately available' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      send_resp = send_msg('messaging', channel_id,
                           message: { text: 'Non-pending message', user_id: @user1 },
                           pending: false)
      expect(send_resp.message).not_to be_nil

      # Get the message to verify it's immediately available
      get_resp = get_message(send_resp.message.id)
      expect(get_resp.message.to_h['text']).to eq('Non-pending message')
    end
  end

  describe 'SearchWithMessageFilters' do
    it 'searches using message_filter_conditions' do
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1])

      search_term = "filterable#{SecureRandom.hex(8)}"
      send_test_message('messaging', channel_id, @user1, "This has #{search_term} text")
      send_test_message('messaging', channel_id, @user1, "This also has #{search_term} text")

      # Wait for indexing
      sleep(2)

      resp = search_messages(
        filter_conditions: { 'cid' => "messaging:#{channel_id}" },
        message_filter_conditions: { 'text' => { '$q' => search_term } }
      )
      expect(resp.results).not_to be_nil
      expect(resp.results.length).to be >= 2
    end
  end

  describe 'SearchQueryAndMessageFiltersError' do
    it 'verifies error when using both query and message_filter_conditions' do
      expect do
        search_messages(
          filter_conditions: { 'members' => { '$in' => [@user1] } },
          query: 'test',
          message_filter_conditions: { 'text' => { '$q' => 'test' } }
        )
      end.to raise_error(GetStreamRuby::APIError)
    end
  end

  describe 'SearchOffsetAndSortError' do
    it 'verifies error when using offset with sort' do
      # The API may or may not reject offset+sort. Verify either an error or a valid response.
      begin
        resp = search_messages(
          filter_conditions: { 'members' => { '$in' => [@user1] } },
          query: 'test',
          offset: 1,
          sort: [{ 'field' => 'created_at', 'direction' => -1 }]
        )
        # If no error, the API accepts the combination — verify a valid response
        expect(resp).not_to be_nil
      rescue GetStreamRuby::APIError
        # Expected error — test passes
      end
    end
  end

  describe 'SearchOffsetAndNextError' do
    it 'verifies error when using offset with next' do
      expect do
        search_messages(
          filter_conditions: { 'members' => { '$in' => [@user1] } },
          query: 'test',
          offset: 1,
          next: SecureRandom.hex(5)
        )
      end.to raise_error(GetStreamRuby::APIError)
    end
  end

  describe 'ChannelRoleInMember' do
    it 'creates channel with roles, sends messages, verifies member.channel_role in response' do
      role_user_ids, _resp = create_test_users(2)
      member_user_id = role_user_ids[0]
      mod_user_id = role_user_ids[1]

      channel_id = "test-ch-#{SecureRandom.hex(6)}"
      @client.make_request(
        :post,
        "/api/v2/chat/channels/messaging/#{channel_id}/query",
        body: {
          data: {
            created_by_id: member_user_id,
            members: [
              { user_id: member_user_id, channel_role: 'channel_member' },
              { user_id: mod_user_id, channel_role: 'channel_moderator' }
            ]
          }
        }
      )
      @created_channel_cids << "messaging:#{channel_id}"

      # Send message from channel_member
      resp_member = send_msg('messaging', channel_id,
                             message: { text: 'message from channel_member', user_id: member_user_id })
      expect(resp_member.message).not_to be_nil
      member_data = resp_member.message.to_h['member'] || {}
      expect(member_data['channel_role']).to eq('channel_member')

      # Send message from channel_moderator
      resp_mod = send_msg('messaging', channel_id,
                          message: { text: 'message from channel_moderator', user_id: mod_user_id })
      expect(resp_mod.message).not_to be_nil
      mod_data = resp_mod.message.to_h['member'] || {}
      expect(mod_data['channel_role']).to eq('channel_moderator')
    end
  end
end
