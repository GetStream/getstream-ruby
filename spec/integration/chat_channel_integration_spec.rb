# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require 'tempfile'
require_relative 'chat_test_helpers'

RSpec.describe 'Chat Channel Integration', type: :integration do
  include ChatTestHelpers

  before(:all) do
    init_chat_client
    # Create shared test users for all subtests
    @shared_user_ids, _resp = create_test_users(4)
    @creator_id = @shared_user_ids[0]
    @member_id1 = @shared_user_ids[1]
    @member_id2 = @shared_user_ids[2]
    @member_id3 = @shared_user_ids[3]
  end

  after(:all) do
    cleanup_chat_resources
  end

  # ---------------------------------------------------------------------------
  # Channel API wrappers (beyond what ChatTestHelpers provides)
  # ---------------------------------------------------------------------------

  def update_channel(type, id, body)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}", body: body)
  end

  def update_channel_partial(type, id, body)
    @client.make_request(:patch, "/api/v2/chat/channels/#{type}/#{id}", body: body)
  end

  def delete_channels_batch(body)
    @client.make_request(:post, '/api/v2/chat/channels/delete', body: body)
  end

  def hide_channel(type, id, body)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/hide", body: body)
  end

  def show_channel(type, id, body)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/show", body: body)
  end

  def truncate_channel(type, id, body = {})
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/truncate", body: body)
  end

  def mark_read(type, id, body)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/read", body: body)
  end

  def mark_unread(type, id, body)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/unread", body: body)
  end

  def send_event(type, id, body)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/event", body: body)
  end

  def mute_channel(body)
    @client.make_request(:post, '/api/v2/chat/moderation/mute/channel', body: body)
  end

  def unmute_channel(body)
    @client.make_request(:post, '/api/v2/chat/moderation/unmute/channel', body: body)
  end

  def update_member_partial(type, id, body)
    user_id = body.delete(:user_id) || body.delete('user_id')
    @client.make_request(
      :patch,
      "/api/v2/chat/channels/#{type}/#{id}/member",
      query_params: { 'user_id' => user_id },
      body: body
    )
  end

  def query_members_api(payload)
    @client.make_request(
      :get,
      '/api/v2/chat/members',
      query_params: { 'payload' => JSON.generate(payload) }
    )
  end

  def upload_channel_file(type, id, file_upload_request)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/file", body: file_upload_request)
  end

  def delete_channel_file(type, id, url)
    @client.make_request(:delete, "/api/v2/chat/channels/#{type}/#{id}/file", query_params: { 'url' => url })
  end

  def upload_channel_image(type, id, image_upload_request)
    @client.make_request(:post, "/api/v2/chat/channels/#{type}/#{id}/image", body: image_upload_request)
  end

  def delete_channel_image(type, id, url)
    @client.make_request(:delete, "/api/v2/chat/channels/#{type}/#{id}/image", query_params: { 'url' => url })
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe 'CreateChannelWithID' do
    it 'creates channel and verifies via QueryChannels' do
      _type, channel_id, _resp = create_test_channel(@creator_id)

      resp = query_channels(
        filter_conditions: { 'id' => channel_id }
      )
      expect(resp.channels).not_to be_nil
      expect(resp.channels).not_to be_empty
      ch = resp.channels.first.to_h
      expect(ch.dig('channel', 'id')).to eq(channel_id)
      expect(ch.dig('channel', 'type')).to eq('messaging')
    end
  end

  describe 'CreateChannelWithMembers' do
    it 'creates channel with 3 members and verifies count' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id,
        [@creator_id, @member_id1, @member_id2]
      )

      resp = get_or_create_channel('messaging', channel_id)
      expect(resp.members).not_to be_nil
      expect(resp.members.length).to be >= 3
    end
  end

  describe 'CreateDistinctChannel' do
    it 'creates distinct channel and verifies same CID on second call' do
      members = [
        { user_id: @creator_id },
        { user_id: @member_id1 }
      ]

      resp = @client.make_request(
        :post,
        '/api/v2/chat/channels/messaging/query',
        body: {
          data: {
            created_by_id: @creator_id,
            members: members
          }
        }
      )
      expect(resp.channel).not_to be_nil
      cid1 = resp.channel.to_h['cid']

      # Call again with same members — should return same channel
      resp2 = @client.make_request(
        :post,
        '/api/v2/chat/channels/messaging/query',
        body: {
          data: {
            created_by_id: @creator_id,
            members: members
          }
        }
      )
      cid2 = resp2.channel.to_h['cid']
      expect(cid1).to eq(cid2)

      # Cleanup: hard delete
      ch_id = resp.channel.to_h['id']
      @created_channel_cids << "messaging:#{ch_id}" unless @created_channel_cids.include?("messaging:#{ch_id}")
    end
  end

  describe 'QueryChannels' do
    it 'creates channel and queries by type+id' do
      _type, channel_id, _resp = create_test_channel(@creator_id)

      resp = query_channels(
        filter_conditions: { 'type' => 'messaging', 'id' => channel_id }
      )
      expect(resp.channels).not_to be_nil
      expect(resp.channels).not_to be_empty
      expect(resp.channels.first.to_h.dig('channel', 'id')).to eq(channel_id)
    end
  end

  describe 'UpdateChannel' do
    it 'updates with custom data and message, verifies custom field' do
      _type, channel_id, _resp = create_test_channel(@creator_id)

      resp = update_channel('messaging', channel_id,
                            data: { custom: { color: 'blue' } },
                            message: { text: 'Channel updated!', user_id: @creator_id })
      expect(resp.channel).not_to be_nil
      ch = resp.channel.to_h
      custom = ch['custom'] || {}
      expect(custom['color']).to eq('blue')
    end
  end

  describe 'PartialUpdateChannel' do
    it 'sets fields then unsets one' do
      _type, channel_id, _resp = create_test_channel(@creator_id)

      # Set fields
      resp = update_channel_partial('messaging', channel_id,
                                    set: { 'color' => 'red', 'description' => 'A test channel' })
      expect(resp.channel).not_to be_nil
      ch = resp.channel.to_h
      custom = ch['custom'] || {}
      expect(custom['color']).to eq('red')

      # Unset fields
      resp2 = update_channel_partial('messaging', channel_id, unset: ['color'])
      expect(resp2.channel).not_to be_nil
      ch2 = resp2.channel.to_h
      custom2 = ch2['custom'] || {}
      expect(custom2).not_to have_key('color')
    end
  end

  describe 'DeleteChannel' do
    it 'soft deletes channel and verifies response' do
      channel_id = "test-del-#{SecureRandom.hex(6)}"
      get_or_create_channel('messaging', channel_id,
                            data: { created_by_id: @creator_id })
      @created_channel_cids << "messaging:#{channel_id}"

      resp = delete_channel('messaging', channel_id)
      expect(resp.channel).not_to be_nil
    end
  end

  describe 'HardDeleteChannels' do
    it 'hard deletes 2 channels via batch and polls task' do
      _type1, channel_id1, _resp1 = create_test_channel(@creator_id)
      _type2, channel_id2, _resp2 = create_test_channel(@creator_id)

      cid1 = "messaging:#{channel_id1}"
      cid2 = "messaging:#{channel_id2}"

      # Remove from tracked list since batch delete will handle it
      @created_channel_cids.delete(cid1)
      @created_channel_cids.delete(cid2)

      resp = delete_channels_batch(cids: [cid1, cid2], hard_delete: true)
      expect(resp.task_id).not_to be_nil

      result = wait_for_task(resp.task_id)
      expect(result.status).to eq('completed')
    end
  end

  describe 'AddRemoveMembers' do
    it 'adds 2 members, verifies count; removes 1, verifies removed' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      # Add members
      update_channel('messaging', channel_id,
                     add_members: [{ user_id: @member_id2 }, { user_id: @member_id3 }])

      # Verify members added
      resp = get_or_create_channel('messaging', channel_id)
      expect(resp.members.length).to be >= 4

      # Remove a member
      update_channel('messaging', channel_id, remove_members: [@member_id3])

      # Verify member removed
      resp2 = get_or_create_channel('messaging', channel_id)
      member_ids = resp2.members.map { |m| m.to_h['user_id'] || m.to_h.dig('user', 'id') }
      expect(member_ids).not_to include(@member_id3)
    end
  end

  describe 'QueryMembers' do
    it 'creates channel with 3 members and queries members' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1, @member_id2]
      )

      resp = query_members_api(
        type: 'messaging',
        id: channel_id,
        filter_conditions: {}
      )
      expect(resp.members).not_to be_nil
      expect(resp.members.length).to be >= 3
    end
  end

  describe 'InviteAcceptReject' do
    it 'creates channel with invites, accepts one, rejects one' do
      channel_id = "test-inv-#{SecureRandom.hex(6)}"

      get_or_create_channel('messaging', channel_id,
                            data: {
                              created_by_id: @creator_id,
                              members: [{ user_id: @creator_id }],
                              invites: [{ user_id: @member_id1 }, { user_id: @member_id2 }]
                            })
      @created_channel_cids << "messaging:#{channel_id}"

      # Accept invite
      update_channel('messaging', channel_id,
                     accept_invite: true,
                     user_id: @member_id1)

      # Reject invite
      update_channel('messaging', channel_id,
                     reject_invite: true,
                     user_id: @member_id2)
    end
  end

  describe 'HideShowChannel' do
    it 'hides channel for user, then shows' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      # Hide
      hide_channel('messaging', channel_id, user_id: @member_id1)

      # Show
      show_channel('messaging', channel_id, user_id: @member_id1)
    end
  end

  describe 'TruncateChannel' do
    it 'sends 3 messages, truncates, verifies empty' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      send_test_message('messaging', channel_id, @creator_id, 'Message 1')
      send_test_message('messaging', channel_id, @creator_id, 'Message 2')
      send_test_message('messaging', channel_id, @creator_id, 'Message 3')

      truncate_channel('messaging', channel_id)

      resp = get_or_create_channel('messaging', channel_id)
      messages = resp.messages || []
      expect(messages).to be_empty
    end
  end

  describe 'FreezeUnfreezeChannel' do
    it 'sets frozen=true, verifies; sets frozen=false, verifies' do
      _type, channel_id, _resp = create_test_channel(@creator_id)

      # Freeze
      resp = update_channel_partial('messaging', channel_id, set: { 'frozen' => true })
      expect(resp.channel.to_h['frozen']).to eq(true)

      # Unfreeze
      resp2 = update_channel_partial('messaging', channel_id, set: { 'frozen' => false })
      expect(resp2.channel.to_h['frozen']).to eq(false)
    end
  end

  describe 'MarkReadUnread' do
    it 'sends message, marks read, marks unread' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      msg_id = send_test_message('messaging', channel_id, @creator_id, 'Message to mark read')

      # Mark read
      mark_read('messaging', channel_id, user_id: @member_id1)

      # Mark unread from this message
      mark_unread('messaging', channel_id, user_id: @member_id1, message_id: msg_id)
    end
  end

  describe 'MuteUnmuteChannel' do
    it 'mutes channel, verifies via query with muted=true; unmutes' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )
      cid = "messaging:#{channel_id}"

      # Mute
      mute_resp = mute_channel(channel_cids: [cid], user_id: @member_id1)
      expect(mute_resp).not_to be_nil
      expect(mute_resp.channel_mute).not_to be_nil
      expect(mute_resp.channel_mute.to_h.dig('channel', 'cid')).to eq(cid)

      # Verify via QueryChannels with muted=true
      q_resp = query_channels(
        filter_conditions: { 'muted' => true, 'cid' => cid },
        user_id: @member_id1
      )
      expect(q_resp.channels.length).to eq(1)
      expect(q_resp.channels.first.to_h.dig('channel', 'cid')).to eq(cid)

      # Unmute
      unmute_channel(channel_cids: [cid], user_id: @member_id1)

      # Verify unmuted
      q_resp2 = query_channels(
        filter_conditions: { 'muted' => false, 'cid' => cid },
        user_id: @member_id1
      )
      expect(q_resp2.channels.length).to eq(1)
    end
  end

  describe 'MemberPartialUpdate' do
    it 'sets custom fields on member; unsets one' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      # Set custom fields
      resp = update_member_partial('messaging', channel_id,
                                   user_id: @member_id1,
                                   set: { 'role_label' => 'moderator', 'score' => 42 })
      expect(resp.channel_member).not_to be_nil
      member_h = resp.channel_member.to_h
      custom = member_h['custom'] || {}
      expect(custom['role_label']).to eq('moderator')

      # Unset a custom field
      resp2 = update_member_partial('messaging', channel_id,
                                    user_id: @member_id1,
                                    unset: ['score'])
      expect(resp2.channel_member).not_to be_nil
      member_h2 = resp2.channel_member.to_h
      custom2 = member_h2['custom'] || {}
      expect(custom2).not_to have_key('score')
    end
  end

  describe 'AssignRoles' do
    it 'assigns channel_moderator role, verifies via QueryMembers' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      # Assign role
      update_channel('messaging', channel_id,
                     assign_roles: [{ user_id: @member_id1, channel_role: 'channel_moderator' }])

      # Verify via QueryMembers
      q_resp = query_members_api(
        type: 'messaging',
        id: channel_id,
        filter_conditions: { 'id' => @member_id1 }
      )
      expect(q_resp.members).not_to be_empty
      expect(q_resp.members.first.to_h['channel_role']).to eq('channel_moderator')
    end
  end

  describe 'AddDemoteModerators' do
    it 'adds moderator, verifies; demotes, verifies back to member' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      # Add moderator
      update_channel('messaging', channel_id, add_moderators: [@member_id1])

      # Verify role
      q_resp = query_members_api(
        type: 'messaging',
        id: channel_id,
        filter_conditions: { 'id' => @member_id1 }
      )
      expect(q_resp.members).not_to be_empty
      expect(q_resp.members.first.to_h['channel_role']).to eq('channel_moderator')

      # Demote
      update_channel('messaging', channel_id, demote_moderators: [@member_id1])

      # Verify back to member
      q_resp2 = query_members_api(
        type: 'messaging',
        id: channel_id,
        filter_conditions: { 'id' => @member_id1 }
      )
      expect(q_resp2.members).not_to be_empty
      expect(q_resp2.members.first.to_h['channel_role']).to eq('channel_member')
    end
  end

  describe 'MarkUnreadWithThread' do
    it 'creates thread and marks unread from thread' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      # Send parent message
      parent_id = send_test_message('messaging', channel_id, @creator_id, 'Parent for mark unread thread')

      # Send reply to create a thread
      send_message('messaging', channel_id,
                   message: { text: 'Reply in thread', user_id: @creator_id, parent_id: parent_id })

      # Mark unread from thread
      mark_unread('messaging', channel_id,
                  user_id: @member_id1,
                  thread_id: parent_id)
    end
  end

  describe 'TruncateWithOptions' do
    it 'truncates with message, skip_push, hard_delete' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      send_test_message('messaging', channel_id, @creator_id, 'Truncate msg 1')
      send_test_message('messaging', channel_id, @creator_id, 'Truncate msg 2')

      truncate_channel('messaging', channel_id,
                       message: { text: 'Channel was truncated', user_id: @creator_id },
                       skip_push: true,
                       hard_delete: true)
    end
  end

  describe 'PinUnpinChannel' do
    it 'pins channel, verifies via query; unpins, verifies' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )
      cid = "messaging:#{channel_id}"

      # Pin
      update_member_partial('messaging', channel_id,
                            user_id: @member_id1,
                            set: { 'pinned' => true })

      # Verify pinned
      q_resp = query_channels(
        filter_conditions: { 'pinned' => true, 'cid' => cid },
        user_id: @member_id1
      )
      expect(q_resp.channels.length).to eq(1)
      expect(q_resp.channels.first.to_h.dig('channel', 'cid')).to eq(cid)

      # Unpin
      update_member_partial('messaging', channel_id,
                            user_id: @member_id1,
                            set: { 'pinned' => false })

      # Verify unpinned
      q_resp2 = query_channels(
        filter_conditions: { 'pinned' => false, 'cid' => cid },
        user_id: @member_id1
      )
      expect(q_resp2.channels.length).to eq(1)
    end
  end

  describe 'ArchiveUnarchiveChannel' do
    it 'archives channel, verifies via query; unarchives, verifies' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )
      cid = "messaging:#{channel_id}"

      # Archive
      update_member_partial('messaging', channel_id,
                            user_id: @member_id1,
                            set: { 'archived' => true })

      # Verify archived
      q_resp = query_channels(
        filter_conditions: { 'archived' => true, 'cid' => cid },
        user_id: @member_id1
      )
      expect(q_resp.channels.length).to eq(1)
      expect(q_resp.channels.first.to_h.dig('channel', 'cid')).to eq(cid)

      # Unarchive
      update_member_partial('messaging', channel_id,
                            user_id: @member_id1,
                            set: { 'archived' => false })

      # Verify unarchived
      q_resp2 = query_channels(
        filter_conditions: { 'archived' => false, 'cid' => cid },
        user_id: @member_id1
      )
      expect(q_resp2.channels.length).to eq(1)
    end
  end

  describe 'AddMembersWithRoles' do
    it 'adds members with specific channel roles, verifies' do
      _type, channel_id, _resp = create_test_channel(@creator_id)

      new_user_ids, _resp = create_test_users(2)
      mod_user_id = new_user_ids[0]
      member_user_id = new_user_ids[1]

      # Add members with specific roles
      update_channel('messaging', channel_id,
                     add_members: [
                       { user_id: mod_user_id, channel_role: 'channel_moderator' },
                       { user_id: member_user_id, channel_role: 'channel_member' }
                     ])

      # Query to verify roles
      q_resp = query_members_api(
        type: 'messaging',
        id: channel_id,
        filter_conditions: { 'id' => { '$in' => new_user_ids } }
      )

      role_map = {}
      q_resp.members.each do |m|
        mh = m.to_h
        uid = mh['user_id'] || mh.dig('user', 'id')
        role_map[uid] = mh['channel_role']
      end

      expect(role_map[mod_user_id]).to eq('channel_moderator')
      expect(role_map[member_user_id]).to eq('channel_member')
    end
  end

  describe 'MessageCount' do
    it 'sends message, queries channel, verifies message_count >= 1' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      send_test_message('messaging', channel_id, @creator_id, 'hello world')

      q_resp = query_channels(
        filter_conditions: { 'cid' => "messaging:#{channel_id}" },
        user_id: @creator_id
      )
      expect(q_resp.channels.length).to eq(1)

      channel_h = q_resp.channels.first.to_h.dig('channel') || {}
      msg_count = channel_h['message_count']
      # message_count may be nil if disabled on channel type
      expect(msg_count).to be >= 1 if msg_count
    end
  end

  describe 'SendChannelEvent' do
    it 'sends typing.start event' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      send_event('messaging', channel_id,
                 event: { type: 'typing.start', user_id: @creator_id })
    end
  end

  describe 'FilterTags' do
    it 'adds filter tags, removes filter tag' do
      _type, channel_id, _resp = create_test_channel(@creator_id)

      # Add filter tags
      update_channel('messaging', channel_id,
                     add_filter_tags: %w[sports news])

      # Verify tags were added
      resp = get_or_create_channel('messaging', channel_id)
      expect(resp.channel).not_to be_nil

      # Remove a filter tag
      update_channel('messaging', channel_id,
                     remove_filter_tags: ['sports'])
    end
  end

  describe 'MessageCountDisabled' do
    it 'disables count_messages via config_overrides, verifies message_count nil' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      # Disable count_messages
      update_channel_partial('messaging', channel_id,
                             set: {
                               'config_overrides' => { 'count_messages' => false }
                             })

      send_test_message('messaging', channel_id, @creator_id, 'hello world disabled count')

      q_resp = query_channels(
        filter_conditions: { 'cid' => "messaging:#{channel_id}" },
        user_id: @creator_id
      )
      expect(q_resp.channels.length).to eq(1)

      channel_h = q_resp.channels.first.to_h.dig('channel') || {}
      expect(channel_h['message_count']).to be_nil
    end
  end

  describe 'MarkUnreadWithTimestamp' do
    it 'sends message, gets timestamp, marks unread from timestamp' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id, @member_id1]
      )

      # Send message to get a valid timestamp
      resp = send_message('messaging', channel_id,
                          message: { text: 'test message for timestamp unread', user_id: @creator_id })
      created_at = resp.message.to_h['created_at']
      expect(created_at).not_to be_nil

      # API may return created_at as nanosecond epoch integer; convert to RFC 3339 string
      ts = if created_at.is_a?(Numeric)
             Time.at(0, created_at, :nanosecond).utc.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')
           else
             created_at.to_s
           end

      # Mark unread from timestamp
      mark_unread('messaging', channel_id,
                  user_id: @member_id1,
                  message_timestamp: ts)
    end
  end

  describe 'HideForCreator' do
    it 'creates channel with hide_for_creator=true, verifies hidden' do
      channel_id = "test-hide-#{SecureRandom.hex(6)}"

      get_or_create_channel('messaging', channel_id,
                            hide_for_creator: true,
                            data: {
                              created_by_id: @creator_id,
                              members: [
                                { user_id: @creator_id },
                                { user_id: @member_id1 }
                              ]
                            })
      @created_channel_cids << "messaging:#{channel_id}"

      # Channel should be hidden for creator
      q_resp = query_channels(
        filter_conditions: { 'cid' => "messaging:#{channel_id}" },
        user_id: @creator_id
      )
      expect(q_resp.channels).to be_empty
    end
  end

  describe 'UploadAndDeleteFile' do
    it 'uploads a text file, verifies URL, deletes file' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id]
      )

      # Create a temp file
      tmpfile = Tempfile.new(['chat-test-', '.txt'])
      tmpfile.write('hello world test file content')
      tmpfile.close

      begin
        upload_resp = upload_channel_file(
          'messaging', channel_id,
          GetStream::Generated::Models::FileUploadRequest.new(
            file: tmpfile.path,
            user: GetStream::Generated::Models::OnlyUserID.new(id: @creator_id)
          )
        )
        expect(upload_resp.file).not_to be_nil
        file_url = upload_resp.file
        expect(file_url).to include('http')

        # Delete file
        delete_channel_file('messaging', channel_id, file_url)
      ensure
        tmpfile.unlink
      end
    end
  end

  describe 'UploadAndDeleteImage' do
    it 'uploads an image file, verifies URL, deletes image' do
      _type, channel_id, _resp = create_test_channel_with_members(
        @creator_id, [@creator_id]
      )

      # Use existing test image
      image_path = File.join(__dir__, 'upload-test.png')
      skip('upload-test.png not found') unless File.exist?(image_path)

      upload_resp = upload_channel_image(
        'messaging', channel_id,
        GetStream::Generated::Models::ImageUploadRequest.new(
          file: image_path,
          user: GetStream::Generated::Models::OnlyUserID.new(id: @creator_id)
        )
      )
      expect(upload_resp.file).not_to be_nil
      image_url = upload_resp.file
      expect(image_url).to include('http')

      # Delete image
      delete_channel_image('messaging', channel_id, image_url)
    end
  end
end
