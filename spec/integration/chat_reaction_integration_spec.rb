# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'chat_test_helpers'

RSpec.describe 'Chat Reaction Integration', type: :integration do

  include ChatTestHelpers

  before(:all) do

    init_chat_client
    @shared_user_ids, _resp = create_test_users(2)
    @user_1 = @shared_user_ids[0]
    @user_2 = @shared_user_ids[1]

  end

  after(:all) do

    cleanup_chat_resources

  end

  # ---------------------------------------------------------------------------
  # Reaction API wrappers
  # ---------------------------------------------------------------------------

  def send_reaction(message_id, reaction_type, user_id, enforce_unique: false)
    body = {
      reaction: { type: reaction_type, user_id: user_id },
    }
    body[:enforce_unique] = true if enforce_unique
    @client.make_request(:post, "/api/v2/chat/messages/#{message_id}/reaction", body: body)
  end

  def get_reactions(message_id)
    @client.make_request(:get, "/api/v2/chat/messages/#{message_id}/reactions")
  end

  def delete_reaction(message_id, reaction_type, user_id)
    @client.make_request(
      :delete,
      "/api/v2/chat/messages/#{message_id}/reaction/#{reaction_type}",
      query_params: { 'user_id' => user_id },
    )
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe 'SendAndGetReactions' do

    it 'sends reactions and gets them back' do

      _type, channel_id, _resp = create_test_channel_with_members(@user_1, [@user_1, @user_2])
      msg_id = send_test_message('messaging', channel_id, @user_1, "React to this #{SecureRandom.hex(8)}")

      # Send two reactions from different users
      resp_1 = send_reaction(msg_id, 'like', @user_1)
      expect(resp_1.reaction).not_to be_nil
      expect(resp_1.reaction.to_h['type']).to eq('like')
      expect(resp_1.reaction.to_h['user_id']).to eq(@user_1)

      resp_2 = send_reaction(msg_id, 'love', @user_2)
      expect(resp_2.reaction).not_to be_nil
      expect(resp_2.reaction.to_h['type']).to eq('love')
      expect(resp_2.reaction.to_h['user_id']).to eq(@user_2)

      # Get reactions
      get_resp = get_reactions(msg_id)
      expect(get_resp.reactions).not_to be_nil
      expect(get_resp.reactions.length).to be >= 2

    end

  end

  describe 'DeleteReaction' do

    it 'sends a reaction, deletes it, and verifies removal' do

      _type, channel_id, _resp = create_test_channel_with_members(@user_1, [@user_1])
      msg_id = send_test_message('messaging', channel_id, @user_1, "Delete reaction test #{SecureRandom.hex(8)}")

      # Send reaction
      send_reaction(msg_id, 'like', @user_1)

      # Delete reaction
      del_resp = delete_reaction(msg_id, 'like', @user_1)
      expect(del_resp).not_to be_nil

      # Verify reaction is gone
      get_resp = get_reactions(msg_id)
      user_likes = (get_resp.reactions || []).select do |r|

        h = r.is_a?(Hash) ? r : r.to_h
        h['user_id'] == @user_1 && h['type'] == 'like'

      end
      expect(user_likes.length).to eq(0)

    end

  end

  describe 'EnforceUniqueReaction' do

    it 'enforces only one reaction per user when enforce_unique is set' do

      _type, channel_id, _resp = create_test_channel_with_members(@user_1, [@user_1])
      msg_id = send_test_message('messaging', channel_id, @user_1, "Unique reaction test #{SecureRandom.hex(8)}")

      # Send first reaction with enforce_unique
      send_reaction(msg_id, 'like', @user_1, enforce_unique: true)

      # Send second reaction with enforce_unique — should replace, not duplicate
      send_reaction(msg_id, 'love', @user_1, enforce_unique: true)

      # Verify user has only one reaction
      get_resp = get_reactions(msg_id)
      user_reactions = (get_resp.reactions || []).select do |r|

        h = r.is_a?(Hash) ? r : r.to_h
        h['user_id'] == @user_1

      end
      expect(user_reactions.length).to eq(1)

    end

  end

end
