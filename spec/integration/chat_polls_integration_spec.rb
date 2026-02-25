# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'chat_test_helpers'

RSpec.describe 'Chat Polls Integration', type: :integration do
  include ChatTestHelpers

  before(:all) do
    init_chat_client
    @shared_user_ids, _resp = create_test_users(2)
    @user1 = @shared_user_ids[0]
    @user2 = @shared_user_ids[1]
    @created_poll_ids = []
  end

  after(:all) do
    # Delete polls before channels/users (polls reference users)
    @created_poll_ids&.each do |poll_id|
      @client.common.delete_poll(poll_id, @user1)
    rescue StandardError => e
      puts "Warning: Failed to delete poll #{poll_id}: #{e.message}"
    end

    cleanup_chat_resources
  end

  # ---------------------------------------------------------------------------
  # Poll API wrappers
  # ---------------------------------------------------------------------------

  def create_poll(name, user_id, options: [], enforce_unique_vote: nil, description: nil)
    poll_options = options.map do |text|
      GetStream::Generated::Models::PollOptionInput.new(text: text)
    end

    req = GetStream::Generated::Models::CreatePollRequest.new(
      name: name,
      user_id: user_id,
      options: poll_options,
      enforce_unique_vote: enforce_unique_vote,
      description: description
    )

    resp = @client.common.create_poll(req)
    poll_id = resp.poll.id
    @created_poll_ids << poll_id
    resp
  end

  def get_poll(poll_id)
    @client.common.get_poll(poll_id)
  end

  def query_polls(filter, user_id)
    req = GetStream::Generated::Models::QueryPollsRequest.new(filter: filter)
    @client.common.query_polls(req, user_id)
  end

  def delete_poll(poll_id, user_id)
    @client.common.delete_poll(poll_id, user_id)
  end

  def cast_poll_vote(message_id, poll_id, user_id, option_id)
    body = {
      user_id: user_id,
      vote: { option_id: option_id }
    }
    @client.make_request(
      :post,
      "/api/v2/chat/messages/#{message_id}/polls/#{poll_id}/vote",
      body: body
    )
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe 'CreateAndQueryPoll' do
    it 'creates a poll with options, gets it, and queries it' do
      poll_name = "Favorite color? #{SecureRandom.hex(4)}"

      # Create poll with options
      create_resp = create_poll(
        poll_name,
        @user1,
        options: %w[Red Blue Green],
        enforce_unique_vote: true,
        description: 'Pick your favorite color'
      )
      expect(create_resp.poll).not_to be_nil
      poll_id = create_resp.poll.id
      expect(poll_id).not_to be_nil
      expect(create_resp.poll.name).to eq(poll_name)
      expect(create_resp.poll.enforce_unique_vote).to eq(true)

      poll_h = create_resp.poll.to_h
      expect(poll_h['options'].length).to eq(3)

      # Get poll by ID
      get_resp = get_poll(poll_id)
      expect(get_resp.poll).not_to be_nil
      expect(get_resp.poll.id).to eq(poll_id)
      expect(get_resp.poll.name).to eq(poll_name)

      # Query polls with filter
      query_resp = query_polls({ 'id' => poll_id }, @user1)
      expect(query_resp.polls).not_to be_nil
      expect(query_resp.polls.length).to be >= 1

      found = query_resp.polls.any? do |p|
        h = p.is_a?(Hash) ? p : p.to_h
        h['id'] == poll_id
      end
      expect(found).to be true
    rescue StandardError => e
      skip('Polls not enabled for this app') if e.message.include?('Polls') || e.message.include?('polls')
      raise
    end
  end

  describe 'CastPollVote' do
    it 'creates a poll, attaches to message, casts vote, and verifies' do
      # Create poll
      poll_name = "Vote test #{SecureRandom.hex(4)}"
      create_resp = create_poll(
        poll_name,
        @user1,
        options: %w[Yes No],
        enforce_unique_vote: true
      )
      poll_id = create_resp.poll.id
      poll_h = create_resp.poll.to_h
      option_id = poll_h['options'][0]['id']
      expect(option_id).not_to be_nil

      # Create channel with both users as members
      _type, channel_id, _resp = create_test_channel_with_members(@user1, [@user1, @user2])

      # Send message with poll attached
      body = {
        message: {
          text: 'Please vote!',
          user_id: @user1,
          poll_id: poll_id
        }
      }
      msg_resp = send_message('messaging', channel_id, body)
      msg_id = msg_resp.message.id
      expect(msg_id).not_to be_nil

      # Cast a vote as user2
      vote_resp = cast_poll_vote(msg_id, poll_id, @user2, option_id)
      expect(vote_resp.vote).not_to be_nil
      vote_h = vote_resp.vote.to_h
      expect(vote_h['option_id']).to eq(option_id)

      # Verify poll has votes
      get_resp = get_poll(poll_id)
      expect(get_resp.poll.vote_count).to eq(1)
    rescue StandardError => e
      skip('Polls not enabled for this app') if e.message.include?('Polls') || e.message.include?('polls')
      raise
    end
  end
end
