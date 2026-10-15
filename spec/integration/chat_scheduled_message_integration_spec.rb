# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'chat_test_helpers'

RSpec.describe 'Chat Scheduled Message Integration', type: :integration do

  include ChatTestHelpers

  before(:all) do

    init_chat_client
    @shared_user_ids, _resp = create_test_users(1)
    @user_id = @shared_user_ids[0]
    @channel_type, @channel_id, _resp = create_test_channel_with_members(@user_id, [@user_id])
    @cid = "#{@channel_type}:#{@channel_id}"

  end

  after(:all) do

    cleanup_chat_resources

  end

  # Error code the API returns when scheduled messages are off for the app.
  def scheduled_messages_disabled_code
    114
  end

  def in_one_hour
    (Time.now + 3600).utc.strftime('%Y-%m-%dT%H:%M:%S.%3NZ')
  end

  # Schedules a message, or skips the example when the app cannot: the feature
  # is opt-in per app, and backends without it ignore scheduled_at and send the
  # message right away.
  def schedule_message(text)
    resp = @client.chat.send_message(
      @channel_type, @channel_id,
      GetStream::Generated::Models::SendMessageRequest.new(
        message: GetStream::Generated::Models::MessageRequest.new(text: text, user_id: @user_id),
        scheduled_at: in_one_hour,
      )
    )
    skip('Backend does not support scheduled messages') if resp.scheduled_message.nil?
    resp.scheduled_message
  rescue GetStreamRuby::ApiError => e
    skip('Scheduled messages not enabled for this app') if e.code == scheduled_messages_disabled_code
    raise
  end

  def query_scheduled_messages
    @client.chat.query_scheduled_messages(
      GetStream::Generated::Models::QueryScheduledMessagesRequest.new(
        user_id: @user_id,
        filter: GetStream::Generated::Models::ScheduledMessagesFilter.new(cid: @cid),
      ),
    ).scheduled_messages
  end

  describe 'ScheduledMessages' do

    it 'schedules, queries, updates and sends a message now' do

      scheduled = schedule_message('Scheduled from Ruby SDK')
      expect(scheduled.status).to eq('scheduled')
      expect(scheduled.cid).to eq(@cid)

      found = query_scheduled_messages.find { |m| m.id == scheduled.id }
      expect(found).not_to be_nil
      expect(found.message.text).to eq('Scheduled from Ruby SDK')

      update_resp = @client.chat.update_scheduled_message(
        scheduled.id,
        GetStream::Generated::Models::UpdateScheduledMessageRequest.new(
          scheduled_at: in_one_hour,
          message: GetStream::Generated::Models::MessageRequest.new(text: 'Rescheduled from Ruby SDK'),
        ),
      )
      expect(update_resp.scheduled_message.message.text).to eq('Rescheduled from Ruby SDK')

      send_now_resp = @client.chat.send_scheduled_message_now(
        scheduled.id,
        GetStream::Generated::Models::SendScheduledMessageNowRequest.new,
      )
      expect(send_now_resp.scheduled_message.id).to eq(scheduled.id)

    end

    it 'deletes a scheduled message' do

      scheduled = schedule_message('Deleted before sending')

      delete_resp = @client.chat.delete_scheduled_message(scheduled.id)
      expect(delete_resp.scheduled_message.id).to eq(scheduled.id)
      expect(delete_resp.scheduled_message.status).to eq('canceled')

      expect(query_scheduled_messages.map(&:id)).not_to include(scheduled.id)

    end

  end

end
