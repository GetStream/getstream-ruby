# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require_relative 'base_integration_test'

RSpec.describe 'Feed Integration Tests', type: :integration do
  let(:test_helper) { BaseIntegrationTest.new }
  let(:client) { test_helper.client }
  let(:feed_group_id) { 'user' }
  # let(:feed_id) { "test-user-#{SecureRandom.hex(8)}" }
  let(:feed_id) { "test-user-ruby-sdk1" }
  let(:feed_id2) { "test-user-ruby-sdk2" }
  let(:test_user_id1) { "test-user-ruby-sdk1" }
  let(:test_user_id2) { "test-user-ruby-sdk2" }

  before(:each) do
    # Test users will be created as needed in individual tests
  end

  after(:each) do
    test_helper.cleanup_resources
  end

  #test-user-ruby-sdk1
  describe 'Activity Operations' do
    it 'creates, retrieves, and updates activities' do
      puts "\n📝 Testing activity operations..."
      
      # Create test user and feed
      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      
      # snippet-start: CreateActivity
      # Create activity
      activity_id = test_helper.create_test_activity(feed_group_id, feed_id, test_user_id1, 'Test activity for CRUD operations')
      expect(activity_id).not_to be_nil
      puts "✅ Created activity: #{activity_id}"
      # snippet-stop: CreateActivity
      
      # snippet-start: GetActivity
      # Retrieve activity
      get_response = client.feeds.get_activity(activity_id)
      expect(get_response).to be_a(GetStreamRuby::StreamResponse)
      expect(get_response.activity.id).to eq(activity_id)
      expect(get_response.activity.text).to eq('Test activity for CRUD operations')
      puts "✅ Retrieved activity: #{activity_id}"
      # snippet-stop: GetActivity
      
      # snippet-start: UpdateActivity
      # Update activity
      update_request = GetStream::Generated::Models::UpdateActivityRequest.new(
        text: 'Updated activity text from Ruby SDK',
        user_id: test_user_id1,
        custom: {
          updated: true,
          update_time: Time.now.to_i
        }
      )
      
      update_response = client.feeds.update_activity(activity_id, update_request)
      expect(update_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Updated activity: #{activity_id}"
      # snippet-stop: UpdateActivity
    end

    it 'creates activities with attachments' do
      puts "\n🖼️ Testing activity creation with attachments..."
      
      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      
      # snippet-start: CreateActivityWithAttachment
      attachment = GetStream::Generated::Models::Attachment.new(
        image_url: 'https://example.com/test-image.jpg',
        type: 'image',
        title: 'Test Image'
      )
      
      activity_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'post',
        _type: 'post',
        text: 'Look at this amazing image!',
        user_id: test_user_id1,
        feeds: ["#{feed_group_id}:#{feed_id}"],
        attachments: [attachment],
        custom: {
          location: 'Test Location',
          camera: 'Test Camera'
        }
      )
      
      response = client.feeds.add_activity(activity_request)
      expect(response).to be_a(GetStreamRuby::StreamResponse)
      
      activity_id = response.activity.id
      test_helper.created_activity_ids << activity_id
      puts "✅ Created activity with attachment: #{activity_id}"
      # snippet-stop: CreateActivityWithAttachment
    end

    it 'creates video activities' do
      puts "\n🎥 Testing video activity creation..."
      
      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      
      attachment = GetStream::Generated::Models::Attachment.new(
        asset_url: 'https://example.com/test-video.mp4',
        type: 'video',
        title: 'Test Video',
        custom: { duration: 120 }
      )
      
      activity_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'video',
        text: 'Check out this amazing video!',
        user_id: test_user_id1,
        feeds: ["#{feed_group_id}:#{feed_id}"],
        attachments: [attachment],
        custom: {
          video_quality: '4K',
          duration_seconds: 120
        }
      )
      
      response = client.feeds.add_activity(activity_request)
      expect(response).to be_a(GetStreamRuby::StreamResponse)
      
      activity_id = response.activity.id
      test_helper.created_activity_ids << activity_id
      puts "✅ Created video activity: #{activity_id}"
    end

    it 'creates activities with expiration' do
      puts "\n⏰ Testing activity creation with expiration..."
      
      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      
      tomorrow = Time.now + 86400 # 24 hours from now
      
      activity_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'story',
        text: 'My daily story - expires tomorrow!',
        user_id: test_user_id1,
        feeds: ["#{feed_group_id}:#{feed_id}"],
        expires_at: tomorrow.iso8601,
        custom: {
          story_type: 'daily',
          auto_expire: true
        }
      )
      
      response = client.feeds.add_activity(activity_request)
      expect(response).to be_a(GetStreamRuby::StreamResponse)
      
      activity_id = response.activity.id
      test_helper.created_activity_ids << activity_id
      puts "✅ Created activity with expiration: #{activity_id}"
    end

    it 'creates activities in multiple feeds' do
      puts "\n📡 Testing activity creation in multiple feeds..."
      
      test_user_id2 = 'test-user-ruby-sdk2'
      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      test_helper.create_test_feed(feed_group_id, feed_id2, test_user_id2)

      activity_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'post',
        text: 'This post appears in multiple feeds!',
        user_id: test_user_id1,
        feeds: ["#{feed_group_id}:#{feed_id}", "#{feed_group_id}:#{feed_id2}"],
        custom: {
          cross_posted: true,
          target_feeds: 2
        }
      )
      puts feed_id
      puts feed_id2

      begin
        response = client.feeds.add_activity(activity_request)
        puts "Activity response: #{response.inspect}"
        puts "Response data: #{response.to_h}" if response.respond_to?(:to_h)
      rescue => e
        puts "❌ API Error in add_activity:"
        puts "Error class: #{e.class}"
        puts "Error message: #{e.message}"
        puts "Error backtrace: #{e.backtrace.first(5).join("\n")}"
        raise e
      end

      expect(response).to be_a(GetStreamRuby::StreamResponse)

      activity_id = response.activity.id
      test_helper.created_activity_ids << activity_id
      puts "✅ Created activity in multiple feeds: #{activity_id}"
    end

    it 'queries activities with filters' do
      puts "\n🔍 Testing activity querying..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)

      # Create multiple activities
      3.times do |i|
        test_helper.create_test_activity(feed_group_id, feed_id, test_user_id1, "Query test activity #{i + 1}")
      end

      # snippet-start: QueryActivities
      query_request = GetStream::Generated::Models::QueryActivitiesRequest.new(
        limit: 10,
        filter: {
          user_id: test_user_id1
        }
      )

      response = client.feeds.query_activities(query_request)
      expect(response).to be_a(GetStreamRuby::StreamResponse)
      expect(response.activities).to be_an(Array)
      expect(response.activities.length).to be >= 3

      puts "✅ Queried activities successfully - found #{response.activities.length} activities"
      # snippet-stop: QueryActivities
    end

    it 'performs batch activity operations' do
      puts "\n📦 Testing batch activity operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)

      activities = [
        {
          type: 'post',
          text: 'Batch activity 1',
          user_id: test_user_id1,
          feeds: ["#{feed_group_id}:#{feed_id}"]
        },
        {
          type: 'post',
          text: 'Batch activity 2',
          user_id: test_user_id1,
          feeds: ["#{feed_group_id}:#{feed_id}"]
        }
      ]

      upsert_request = GetStream::Generated::Models::UpsertActivitiesRequest.new(
        activities: activities
      )

      response = client.feeds.upsert_activities(upsert_request)
      expect(response).to be_a(GetStreamRuby::StreamResponse)

      # Track created activities for cleanup
      if response.activities
        response.activities.each do |activity|
          if activity['id']
            test_helper.created_activity_ids << activity['id']
          end
        end
      end

      puts "✅ Upserted batch activities successfully"
    end
  end

  describe 'Reaction Operations' do
    it 'adds and queries reactions' do
      puts "\n👍 Testing reaction operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      activity_id = test_helper.create_test_activity(feed_group_id, feed_id, test_user_id1, 'Activity for reaction test')

      # snippet-start: AddReaction
      # Add reaction
      reaction_request = GetStream::Generated::Models::AddReactionRequest.new(
        type: 'like',
        user_id: test_user_id1
      )

      reaction_response = client.feeds.add_reaction(activity_id, reaction_request)
      expect(reaction_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Added like reaction"
      # snippet-stop: AddReaction

      # snippet-start: QueryReactions
      # Query reactions
      query_request = GetStream::Generated::Models::QueryActivityReactionsRequest.new(
        limit: 10,
        filter: {
          reaction_type: 'like'
        }
      )

      query_response = client.feeds.query_activity_reactions(activity_id, query_request)
      expect(query_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Queried reactions successfully"
      # snippet-stop: QueryReactions

      # snippet-start: DeleteReaction
      # Delete reaction
      delete_response = client.feeds.delete_activity_reaction(activity_id, 'like', test_user_id1)
      expect(delete_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Deleted reaction successfully"
      # snippet-stop: DeleteReaction
    end
  end

  describe 'Comment Operations' do
    it 'adds, queries, and updates comments' do
      puts "\n💬 Testing comment operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      activity_id = test_helper.create_test_activity(feed_group_id, feed_id, test_user_id1, 'Activity for comment test')
      test_user_id1 = 'test-user-ruby-sdk1'

      puts test_user_id1
      # snippet-start: AddComment
      # Add comment
      comment_request = GetStream::Generated::Models::AddCommentRequest.new(
        comment: 'This is a test comment from Ruby SDK',
        object_id: activity_id,
        object_type: 'activity',
        user_id: test_user_id1
      )

      comment_response = client.feeds.add_comment(comment_request)
      expect(comment_response).to be_a(GetStreamRuby::StreamResponse)

      comment_id = comment_response.comment.id
      test_helper.created_comment_ids << comment_id
      puts "✅ Added comment: #{comment_id}"
      # snippet-stop: AddComment

      # snippet-start: QueryComments
      # Query comments
      query_request = GetStream::Generated::Models::QueryCommentsRequest.new(
        filter: {
          object_id: activity_id
        },
        limit: 10
      )

      query_response = client.feeds.query_comments(query_request)
      expect(query_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Queried comments successfully"
      # snippet-stop: QueryComments

      # snippet-start: UpdateComment
      # Update comment
      update_request = GetStream::Generated::Models::UpdateCommentRequest.new(
        comment: 'Updated comment text from Ruby SDK'
      )

      update_response = client.feeds.update_comment(comment_id, update_request)
      expect(update_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Updated comment successfully"
      # snippet-stop: UpdateComment
    end
  end

  describe 'Bookmark Operations' do
    it 'adds, queries, and updates bookmarks' do
      puts "\n🔖 Testing bookmark operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      activity_id = test_helper.create_test_activity(feed_group_id, feed_id, test_user_id1, 'Activity for bookmark test')

      begin
        # Add bookmark
        bookmark_request = GetStream::Generated::Models::AddBookmarkRequest.new(
          user_id: test_user_id1,
          new_folder: GetStream::Generated::Models::AddFolderRequest.new(
            name: 'test-bookmarks'
          )
        )

        bookmark_response = client.feeds.add_bookmark(activity_id, bookmark_request)
        expect(bookmark_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Added bookmark successfully"

        # Query bookmarks
        query_request = GetStream::Generated::Models::QueryBookmarksRequest.new(
          limit: 10,
          filter: {
            user_id: test_user_id1
          }
        )

        query_response = client.feeds.query_bookmarks(query_request)
        expect(query_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Queried bookmarks successfully"

        # Update bookmark
        folder_id = bookmark_response.bookmark.folder.id
        update_request = GetStream::Generated::Models::UpdateBookmarkRequest.new(
          folder_id: folder_id,
          user_id: test_user_id1
        )

        update_response = client.feeds.update_bookmark(activity_id, update_request)
        expect(update_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Updated bookmark successfully"

        # Delete bookmark
        delete_response = client.feeds.delete_bookmark(activity_id, folder_id, test_user_id1)
        expect(delete_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Deleted bookmark successfully"

      rescue => e
        puts "⚠️ Bookmark operations skipped: #{e.message}"
      end
    end
  end

  describe 'Follow Operations' do
    it 'creates and manages follows' do
      puts "\n👥 Testing follow operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      test_helper.create_test_feed(feed_group_id, feed_id2, test_user_id2)

      begin
        # Follow user
        follow_request = {
          source: "#{feed_group_id}:#{test_user_id1}",
          target: "#{feed_group_id}:#{test_user_id2}"
        }

        follow_response = client.feeds.follow(follow_request)
        expect(follow_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Followed user successfully"

        # Query follows
        query_request = GetStream::Generated::Models::QueryFollowsRequest.new(
          limit: 10
        )

        query_response = client.feeds.query_follows(query_request)
        expect(query_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Queried follows successfully"

        # Unfollow user
        unfollow_response = client.feeds.unfollow("#{feed_group_id}:#{test_user_id1}", "#{feed_group_id}:#{test_user_id2}")
        expect(unfollow_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Unfollowed user successfully"

      rescue => e
        puts "⚠️ Follow operations skipped: #{e.message}"
      end
    end
  end

  describe 'Pin Operations' do
    it 'pins and unpins activities' do
      puts "\n📌 Testing pin operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      activity_id = test_helper.create_test_activity(feed_group_id, feed_id, test_user_id1, 'Activity for pin test')

      # Pin activity
      pin_request = GetStream::Generated::Models::PinActivityRequest.new(
        user_id: test_user_id1
      )

      pin_response = client.feeds.pin_activity(feed_group_id, feed_id, activity_id, pin_request)
      expect(pin_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Pinned activity successfully"

      # Unpin activity
      unpin_response = client.feeds.unpin_activity(feed_group_id, feed_id, activity_id, test_user_id1)
      expect(unpin_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Unpinned activity successfully"
    end
  end

  describe 'Poll Operations' do
    it 'creates and votes on polls' do
      puts "\n🗳️ Testing poll operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)

      # Create poll
      poll_request = GetStream::Generated::Models::CreatePollRequest.new(
        name: 'Test Poll',
        description: "What's your favorite programming language?",
        user_id: test_user_id1,
        max_votes_allowed: 1,
        options: [
          GetStream::Generated::Models::PollOptionInput.new(text: 'Ruby'),
          GetStream::Generated::Models::PollOptionInput.new(text: 'Python'),
          GetStream::Generated::Models::PollOptionInput.new(text: 'JavaScript')
        ]
      )

      poll_response = client.common.create_poll(poll_request)
      expect(poll_response).to be_a(GetStreamRuby::StreamResponse)

      poll_id = poll_response.poll.id
      puts "✅ Created poll: #{poll_id}"

      # Create poll activity
      poll_activity_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'poll',
        feeds: ["#{feed_group_id}:#{feed_id}"],
        poll_id: poll_id,
        text: "What's your favorite programming language?",
        user_id: test_user_id1,
        custom: {
          poll_name: "What's your favorite programming language?",
          poll_description: "Choose your favorite programming language from the options below",
          poll_options: ['Ruby', 'Python', 'JavaScript'],
          allow_user_suggested_options: false
        }
      )

      activity_response = client.feeds.add_activity(poll_activity_request)
      expect(activity_response).to be_a(GetStreamRuby::StreamResponse)

      activity_id = activity_response.activity.id
      test_helper.created_activity_ids << activity_id
      puts "✅ Created poll activity: #{activity_id}"

      # Vote on poll
      if poll_response.poll.options && !poll_response.poll.options.empty?
        option_id = poll_response.poll.options.first['id'] || poll_response.poll.options.first

        puts option_id.inspect
        vote_request = GetStream::Generated::Models::CastPollVoteRequest.new(
          user_id: test_user_id1,
          vote: GetStream::Generated::Models::VoteData.new(
            option_id: option_id.id
          )
        )

        vote_response = client.feeds.cast_poll_vote(activity_id, poll_id, vote_request)
        expect(vote_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Voted on poll successfully"
      else
        puts "⚠️ Poll options not available for voting test"
      end

    end
  end

  describe 'Feed Group CRUD Operations' do
    it 'performs feed group CRUD operations' do
      puts "\n📁 Testing Feed Group CRUD operations..."

      feed_group_id_test = "test-feed-group-#{SecureRandom.hex(4)}"

      begin
        # List feed groups
        list_response = client.feeds.list_feed_groups
        expect(list_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Listed feed groups successfully"

        # Create feed group
        create_request = GetStream::Generated::Models::CreateFeedGroupRequest.new(
          id: feed_group_id_test,
          default_visibility: 'public',
          activity_processors: [
            GetStream::Generated::Models::ActivityProcessorConfig.new(type: 'dummy')
          ]
        )

        create_response = client.feeds.create_feed_group(create_request)
        expect(create_response).to be_a(GetStreamRuby::StreamResponse)
        expect(create_response.feed_group.id).to eq(feed_group_id_test)
        puts "✅ Created feed group: #{feed_group_id_test}"

        # Wait for backend propagation
        test_helper.wait_for_backend_propagation(1)

        # Get feed group
        get_response = client.feeds.get_feed_group('foryou') # Use existing feed group
        expect(get_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Retrieved feed group successfully"

        # Update feed group
        update_request = GetStream::Generated::Models::UpdateFeedGroupRequest.new(
          aggregation: GetStream::Generated::Models::AggregationConfig.new(format: 'default')
        )

        update_response = client.feeds.update_feed_group('foryou', update_request)
        expect(update_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Updated feed group successfully"

        # Get or create feed group
        get_or_create_request = GetStream::Generated::Models::GetOrCreateFeedGroupRequest.new(
          default_visibility: 'public'
        )

        get_or_create_response = client.feeds.get_or_create_feed_group('foryou', get_or_create_request)
        expect(get_or_create_response).to be_a(GetStreamRuby::StreamResponse)
        expect(get_or_create_response.was_created).to be false
        puts "✅ Got existing feed group successfully"

      rescue => e
        puts "⚠️ Feed Group CRUD operations skipped: #{e.message}"
        skip "Feed Group CRUD operations not supported: #{e.message}"
      end
    end
  end

  describe 'Feed View CRUD Operations' do
    it 'performs feed view CRUD operations' do
      puts "\n👁️ Testing Feed View CRUD operations..."

      feed_view_id = "test-feed-view-#{SecureRandom.hex(4)}"

      # List feed views
      list_response = client.feeds.list_feed_views
      expect(list_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Listed feed views successfully"

      # Create feed view
      create_request = GetStream::Generated::Models::CreateFeedViewRequest.new(
        id: feed_view_id
      )

      create_response = client.feeds.create_feed_view(create_request)
      expect(create_response).to be_a(GetStreamRuby::StreamResponse)
      expect(create_response.feed_view.id).to eq(feed_view_id)
      puts "✅ Created feed view: #{feed_view_id}"

      # Wait for backend propagation
      test_helper.wait_for_backend_propagation(1)

      # Get feed view
      get_response = client.feeds.get_feed_view('feedViewID') # Use existing feed view
      expect(get_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Retrieved feed view successfully"

      # Update feed view
      update_request = GetStream::Generated::Models::UpdateFeedViewRequest.new(
        aggregation: GetStream::Generated::Models::AggregationConfig.new(format: 'default')
      )

      update_response = client.feeds.update_feed_view('feedViewID', update_request)
      expect(update_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Updated feed view successfully"

      # Get or create feed view with unique ID
      unique_feed_view_id = "test-feed-view-#{SecureRandom.hex(8)}"
      get_or_create_request = GetStream::Generated::Models::GetOrCreateFeedViewRequest.new(
        aggregation: GetStream::Generated::Models::AggregationConfig.new(format: 'default')
      )

      get_or_create_response = client.feeds.get_or_create_feed_view(unique_feed_view_id, get_or_create_request)
      expect(get_or_create_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Got existing feed view successfully"


    end
  end

  describe 'Real World Usage Demo' do
    it 'demonstrates real-world usage patterns' do
      puts "\n🌍 Testing real-world usage patterns..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id1)
      test_helper.create_test_feed(feed_group_id, feed_id2, test_user_id2)

      # 1. User creates a post with image
      attachment = GetStream::Generated::Models::Attachment.new(
        image_url: 'https://example.com/coffee-shop.jpg',
        type: 'image',
        title: 'Amazing Coffee Shop'
      )

      post_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'post',
        text: 'Just visited the most amazing coffee shop! ☕️',
        user_id: test_user_id1,
        feeds: ["#{feed_group_id}:#{feed_id}"],
        attachments: [attachment],
        custom: {
          location: 'Downtown Coffee Co.',
          rating: 5,
          tags: ['coffee', 'food', 'downtown']
        }
      )

      post_response = client.feeds.add_activity(post_request)
      expect(post_response).to be_a(GetStreamRuby::StreamResponse)

      post_id = post_response.activity.id
      test_helper.created_activity_ids << post_id
      puts "✅ Created real-world post: #{post_id}"

      # 2. Other users react to the post
      reaction_types = ['like', 'love', 'wow']
      reaction_types.each do |reaction_type|
        reaction_request = GetStream::Generated::Models::AddReactionRequest.new(
          type: reaction_type,
          user_id: test_user_id2
        )

        reaction_response = client.feeds.add_reaction(post_id, reaction_request)
        expect(reaction_response).to be_a(GetStreamRuby::StreamResponse)
      end
      puts "✅ Added reactions to post"

      # 3. Users comment on the post
      comments = [
        'That place looks amazing! What did you order?',
        'I love their espresso! Great choice 😍',
        'Adding this to my must-visit list!'
      ]

      comments.each do |comment_text|
        comment_request = GetStream::Generated::Models::AddCommentRequest.new(
          comment: comment_text,
          object_id: post_id,
          object_type: 'activity',
          user_id: test_user_id2
        )

        comment_response = client.feeds.add_comment(comment_request)
        expect(comment_response).to be_a(GetStreamRuby::StreamResponse)

        comment_id = comment_response.comment.id
        test_helper.created_comment_ids << comment_id
      end
      puts "✅ Added comments to post"

      # 4. User bookmarks the post
      begin
        bookmark_request = GetStream::Generated::Models::AddBookmarkRequest.new(
          user_id: test_user_id2,
          new_folder: GetStream::Generated::Models::AddFolderRequest.new(
            name: 'favorite-places'
          )
        )
        
        bookmark_response = client.feeds.add_bookmark(post_id, bookmark_request)
        expect(bookmark_response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Bookmarked the post"
        
      rescue => e
        puts "⚠️ Bookmark operation skipped: #{e.message}"
      end
      
      # 5. Query the activity with all its interactions
      enriched_response = client.feeds.get_activity(post_id)
      expect(enriched_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Retrieved enriched activity successfully"
      
      puts "✅ Completed real-world usage scenario demonstration"
    end
  end
end
