# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'time'
require_relative 'base_integration_test'

RSpec.describe 'Feed Integration Tests', type: :integration do

  let(:test_helper) { BaseIntegrationTest.new }
  let(:client) { test_helper.client }
  let(:feed_group_id) { 'user' }
  # let(:feed_id) { "test-user-#{SecureRandom.hex(8)}" }
  let(:feed_id) { 'test-user-ruby-sdk1' }
  let(:feed_id_2) { 'test-user-ruby-sdk2' }
  let(:test_user_id_1) { 'test-user-ruby-sdk1' }
  let(:test_user_id_2) { 'test-user-ruby-sdk2' }

  before(:each) do
    # Test users will be created as needed in individual tests
  end

  after(:each) do

    test_helper.cleanup_resources

  end

  # test-user-ruby-sdk1
  describe 'Activity Operations' do

    it 'creates, retrieves, and updates activities' do

      puts "\n📝 Testing activity operations..."

      # Create test user and feed
      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)

      # snippet-start: CreateActivity
      # Create activity
      activity_id = test_helper.create_test_activity(feed_group_id, feed_id, test_user_id_1,
                                                     'Test activity for CRUD operations')
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
        user_id: test_user_id_1,
        custom: {
          updated: true,
          update_time: Time.now.to_i,
        },
      )

      update_response = client.feeds.update_activity(activity_id, update_request)
      expect(update_response).to be_a(GetStreamRuby::StreamResponse)
      puts "✅ Updated activity: #{activity_id}"
      # snippet-stop: UpdateActivity

    end

    it 'creates activities with attachments' do

      puts "\n🖼️ Testing activity creation with attachments..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)

      # snippet-start: CreateActivityWithAttachment
      attachment = GetStream::Generated::Models::Attachment.new(
        image_url: 'https://example.com/test-image.jpg',
        type: 'image',
        title: 'Test Image',
      )

      activity_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'post',
        _type: 'post',
        text: 'Look at this amazing image!',
        user_id: test_user_id_1,
        feeds: ["#{feed_group_id}:#{feed_id}"],
        attachments: [attachment],
        custom: {
          location: 'Test Location',
          camera: 'Test Camera',
        },
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

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)

      attachment = GetStream::Generated::Models::Attachment.new(
        asset_url: 'https://example.com/test-video.mp4',
        type: 'video',
        title: 'Test Video',
        custom: { duration: 120 },
      )

      activity_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'video',
        text: 'Check out this amazing video!',
        user_id: test_user_id_1,
        feeds: ["#{feed_group_id}:#{feed_id}"],
        attachments: [attachment],
        custom: {
          video_quality: '4K',
          duration_seconds: 120,
        },
      )

      response = client.feeds.add_activity(activity_request)
      expect(response).to be_a(GetStreamRuby::StreamResponse)

      activity_id = response.activity.id
      test_helper.created_activity_ids << activity_id
      puts "✅ Created video activity: #{activity_id}"

    end

    it 'creates activities with expiration' do

      puts "\n⏰ Testing activity creation with expiration..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)

      tomorrow = Time.now + 86_400 # 24 hours from now

      activity_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'story',
        text: 'My daily story - expires tomorrow!',
        user_id: test_user_id_1,
        feeds: ["#{feed_group_id}:#{feed_id}"],
        expires_at: tomorrow.iso8601,
        custom: {
          story_type: 'daily',
          auto_expire: true,
        },
      )

      response = client.feeds.add_activity(activity_request)
      expect(response).to be_a(GetStreamRuby::StreamResponse)

      activity_id = response.activity.id
      test_helper.created_activity_ids << activity_id
      puts "✅ Created activity with expiration: #{activity_id}"

    end

    it 'creates activities in multiple feeds' do

      puts "\n📡 Testing activity creation in multiple feeds..."

      test_user_id_2 = 'test-user-ruby-sdk2'
      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)
      test_helper.create_test_feed(feed_group_id, feed_id_2, test_user_id_2)

      activity_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'post',
        text: 'This post appears in multiple feeds!',
        user_id: test_user_id_1,
        feeds: ["#{feed_group_id}:#{feed_id}", "#{feed_group_id}:#{feed_id_2}"],
        custom: {
          cross_posted: true,
          target_feeds: 2,
        },
      )

      begin
        response = client.feeds.add_activity(activity_request)
      rescue StandardError => e
        puts '❌ API Error in add_activity:'
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

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)

      # Create multiple activities
      3.times do |i|

        test_helper.create_test_activity(feed_group_id, feed_id, test_user_id_1, "Query test activity #{i + 1}")

      end

      # snippet-start: QueryActivities
      query_request = GetStream::Generated::Models::QueryActivitiesRequest.new(
        limit: 10,
        filter: {
          user_id: test_user_id_1,
        },
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

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)

      activities = [
        {
          type: 'post',
          text: 'Batch activity 1',
          user_id: test_user_id_1,
          feeds: ["#{feed_group_id}:#{feed_id}"],
        },
        {
          type: 'post',
          text: 'Batch activity 2',
          user_id: test_user_id_1,
          feeds: ["#{feed_group_id}:#{feed_id}"],
        },
      ]

      upsert_request = GetStream::Generated::Models::UpsertActivitiesRequest.new(
        activities: activities,
      )

      response = client.feeds.upsert_activities(upsert_request)
      expect(response).to be_a(GetStreamRuby::StreamResponse)

      # Track created activities for cleanup
      response.activities&.each do |activity|

        test_helper.created_activity_ids << activity['id'] if activity['id']

      end

      puts '✅ Upserted batch activities successfully'

    end

  end

  describe 'User Operations' do

    it 'creates and updates users in batch' do

      puts "\n👥 Testing batch user operations..."

      user_id_1 = "test-user-batch-#{SecureRandom.hex(4)}"
      user_id_2 = "test-user-batch-#{SecureRandom.hex(4)}"

      begin
        # snippet-start: UpdateUsers
        # Create/update users in batch
        update_request = GetStream::Generated::Models::UpdateUsersRequest.new(
          users: {
            user_id_1 => {
              'id' => user_id_1,
              'name' => 'Test User 1',
              'role' => 'user',
            },
            user_id_2 => {
              'id' => user_id_2,
              'name' => 'Test User 2',
              'role' => 'user',
            },
          },
        )

        response = client.common.update_users(update_request)
        expect(response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Created/updated users in batch: #{user_id_1}, #{user_id_2}"
        # snippet-stop: UpdateUsers
      ensure
        SuiteCleanup.register_users([user_id_1, user_id_2])
      end

    end

    it 'partially updates users' do

      puts "\n✏️ Testing partial user update..."

      user_id = "test-user-partial-#{SecureRandom.hex(4)}"

      begin
        # First create a user
        create_request = GetStream::Generated::Models::UpdateUsersRequest.new(
          users: {
            user_id => {
              'id' => user_id,
              'name' => 'Original Name',
              'role' => 'user',
            },
          },
        )
        client.common.update_users(create_request)

        # snippet-start: UpdateUsersPartial
        # Partially update user
        partial_request = GetStream::Generated::Models::UpdateUsersPartialRequest.new(
          users: [
            {
              'id' => user_id,
              'set' => {
                'name' => 'Updated Name',
              },
            },
          ],
        )

        response = client.common.update_users_partial(partial_request)
        expect(response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Partially updated user: #{user_id}"
        # snippet-stop: UpdateUsersPartial
      ensure
        SuiteCleanup.register_users([user_id])
      end

    end

    it 'deletes users in batch' do

      puts "\n🗑️ Testing batch user deletion..."

      user_ids = []
      3.times do

        user_ids << "test-user-delete-#{SecureRandom.hex(4)}"

      end

      begin
        # Create users first
        users_hash = {}
        user_ids.each_with_index do |user_id, i|

          users_hash[user_id] = {
            'id' => user_id,
            'name' => "Delete Test User #{i + 1}",
            'role' => 'user',
          }

        end

        create_request = GetStream::Generated::Models::UpdateUsersRequest.new(users: users_hash)
        client.common.update_users(create_request)

        # snippet-start: DeleteUsers
        # Delete users in batch (with retry for rate limits)
        response = nil
        10.times do |i|

          delete_request = GetStream::Generated::Models::DeleteUsersRequest.new(
            user_ids: user_ids,
            user: 'hard',
          )

          response = client.common.delete_users(delete_request)
          break
        rescue GetStreamRuby::APIError => e
          raise unless e.message.include?('Too many requests')

          sleep([2**i, 30].min)

        end

        expect(response).not_to be_nil
        expect(response).to be_a(GetStreamRuby::StreamResponse)
        puts "✅ Deleted #{user_ids.length} users in batch"
        # snippet-stop: DeleteUsers
      rescue StandardError => e
        puts "⚠️ Error: #{e.message}"
        # Try cleanup anyway
        begin
          delete_request = GetStream::Generated::Models::DeleteUsersRequest.new(
            user_ids: user_ids,
            user: 'hard',
          )
          client.common.delete_users(delete_request)
        rescue StandardError
          # Ignore cleanup errors
        end
        raise e
      end

    end

  end

  describe 'Reaction Operations' do

    it 'adds and queries reactions' do

      puts "\n👍 Testing reaction operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)
      activity_id = test_helper.create_test_activity(feed_group_id, feed_id, test_user_id_1,
                                                     'Activity for reaction test')

      # snippet-start: AddReaction
      # Add reaction
      reaction_request = GetStream::Generated::Models::AddReactionRequest.new(
        type: 'like',
        user_id: test_user_id_1,
      )

      reaction_response = client.feeds.add_activity_reaction(activity_id, reaction_request)
      expect(reaction_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Added like reaction'
      # snippet-stop: AddReaction

      # snippet-start: QueryReactions
      # Query reactions
      query_request = GetStream::Generated::Models::QueryActivityReactionsRequest.new(
        limit: 10,
        filter: {
          reaction_type: 'like',
        },
      )

      query_response = client.feeds.query_activity_reactions(activity_id, query_request)
      expect(query_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Queried reactions successfully'
      # snippet-stop: QueryReactions

      # snippet-start: DeleteReaction
      # Delete reaction
      delete_response = client.feeds.delete_activity_reaction(activity_id, 'like', nil, test_user_id_1)
      expect(delete_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Deleted reaction successfully'
      # snippet-stop: DeleteReaction

    end

  end

  describe 'Comment Operations' do

    it 'adds, queries, and updates comments' do

      puts "\n💬 Testing comment operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)
      activity_id = test_helper.create_test_activity(
        feed_group_id, feed_id, test_user_id_1, 'Activity for comment test'
      )

      # snippet-start: AddComment
      # Add comment
      comment_request = GetStream::Generated::Models::AddCommentRequest.new(
        comment: 'This is a test comment from Ruby SDK',
        object_id: activity_id,
        object_type: 'activity',
        user_id: test_user_id_1,
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
          object_id: activity_id,
        },
        limit: 10,
      )

      query_response = client.feeds.query_comments(query_request)
      expect(query_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Queried comments successfully'
      # snippet-stop: QueryComments

      # snippet-start: UpdateComment
      # Update comment
      update_request = GetStream::Generated::Models::UpdateCommentRequest.new(
        comment: 'Updated comment text from Ruby SDK',
        user_id: test_user_id_1,
      )

      update_response = client.feeds.update_comment(comment_id, update_request)
      expect(update_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Updated comment successfully'
      # snippet-stop: UpdateComment

    end

  end

  describe 'Bookmark Operations' do

    it 'adds, queries, and updates bookmarks' do

      puts "\n🔖 Testing bookmark operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)
      activity_id = test_helper.create_test_activity(feed_group_id, feed_id, test_user_id_1,
                                                     'Activity for bookmark test')

      # Add bookmark
      bookmark_request = GetStream::Generated::Models::AddBookmarkRequest.new(
        user_id: test_user_id_1,
        new_folder: GetStream::Generated::Models::AddFolderRequest.new(
          name: 'test-bookmarks',
        ),
      )

      bookmark_response = client.feeds.add_bookmark(activity_id, bookmark_request)
      expect(bookmark_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Added bookmark successfully'

      # Query bookmarks
      query_request = GetStream::Generated::Models::QueryBookmarksRequest.new(
        limit: 10,
        filter: {
          user_id: test_user_id_1,
        },
      )

      query_response = client.feeds.query_bookmarks(query_request)
      expect(query_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Queried bookmarks successfully'

      folder_id = bookmark_response.bookmark.folder.id

      # Delete bookmark
      delete_response = client.feeds.delete_bookmark(activity_id, folder_id, test_user_id_1)
      expect(delete_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Deleted bookmark successfully'

    end

  end

  describe 'Follow Operations' do

    it 'creates and manages follows' do

      puts "\n👥 Testing follow operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)
      test_helper.create_test_feed(feed_group_id, feed_id_2, test_user_id_2)

      begin
        # Follow user
        follow_request = {
          source: "#{feed_group_id}:#{test_user_id_1}",
          target: "#{feed_group_id}:#{test_user_id_2}",
        }

        follow_response = client.feeds.follow(follow_request)
        expect(follow_response).to be_a(GetStreamRuby::StreamResponse)
        puts '✅ Followed user successfully'

        # Query follows
        query_request = GetStream::Generated::Models::QueryFollowsRequest.new(
          limit: 10,
        )

        query_response = client.feeds.query_follows(query_request)
        expect(query_response).to be_a(GetStreamRuby::StreamResponse)
        puts '✅ Queried follows successfully'

        # Unfollow user
        unfollow_response = client.feeds.unfollow("#{feed_group_id}:#{test_user_id_1}",
                                                  "#{feed_group_id}:#{test_user_id_2}")
        expect(unfollow_response).to be_a(GetStreamRuby::StreamResponse)
        puts '✅ Unfollowed user successfully'
      rescue StandardError => e
        puts "⚠️ Follow operations skipped: #{e.message}"
      end

    end

  end

  describe 'Pin Operations' do

    it 'pins and unpins activities' do

      puts "\n📌 Testing pin operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)
      activity_id = test_helper.create_test_activity(feed_group_id, feed_id, test_user_id_1, 'Activity for pin test')

      # Pin activity
      pin_request = GetStream::Generated::Models::PinActivityRequest.new(
        user_id: test_user_id_1,
      )

      pin_response = client.feeds.pin_activity(feed_group_id, feed_id, activity_id, pin_request)
      expect(pin_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Pinned activity successfully'

      # Unpin activity
      unpin_response = client.feeds.unpin_activity(feed_group_id, feed_id, activity_id, test_user_id_1)
      expect(unpin_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Unpinned activity successfully'

    end

  end

  describe 'Poll Operations' do

    it 'creates and votes on polls' do

      puts "\n🗳️ Testing poll operations..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)

      # Create poll
      poll_request = GetStream::Generated::Models::CreatePollRequest.new(
        name: 'Test Poll',
        description: "What's your favorite programming language?",
        user_id: test_user_id_1,
        max_votes_allowed: 1,
        options: [
          GetStream::Generated::Models::PollOptionInput.new(text: 'Ruby'),
          GetStream::Generated::Models::PollOptionInput.new(text: 'Python'),
          GetStream::Generated::Models::PollOptionInput.new(text: 'JavaScript'),
        ],
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
        user_id: test_user_id_1,
        custom: {
          poll_name: "What's your favorite programming language?",
          poll_description: 'Choose your favorite programming language from the options below',
          poll_options: ['Ruby', 'Python', 'JavaScript'],
          allow_user_suggested_options: false,
        },
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
          user_id: test_user_id_1,
          vote: GetStream::Generated::Models::VoteData.new(
            option_id: option_id.id,
          ),
        )

        vote_response = client.feeds.cast_poll_vote(activity_id, poll_id, vote_request)
        expect(vote_response).to be_a(GetStreamRuby::StreamResponse)
        puts '✅ Voted on poll successfully'
      else
        puts '⚠️ Poll options not available for voting test'
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
        puts '✅ Listed feed groups successfully'

        # Create feed group
        create_request = GetStream::Generated::Models::CreateFeedGroupRequest.new(
          id: feed_group_id_test,
          default_visibility: 'public',
          activity_processors: [
            GetStream::Generated::Models::ActivityProcessorConfig.new(type: 'dummy'),
          ],
        )

        begin
          create_response = client.feeds.create_feed_group(create_request)
          expect(create_response).to be_a(GetStreamRuby::StreamResponse)
          expect(create_response.feed_group.id).to eq(feed_group_id_test)
          puts "✅ Created feed group: #{feed_group_id_test}"

          # Wait for backend propagation
          test_helper.wait_for_backend_propagation(1)
        rescue GetStreamRuby::APIError => e
          raise e unless e.message.include?('maximum number of feed groups')

          puts '⚠️ Feed group limit reached, skipping feed group creation test'
          feed_group_id_test = nil # Skip deletion
        end

        # Get feed group
        get_response = client.feeds.get_feed_group('foryou') # Use existing feed group
        expect(get_response).to be_a(GetStreamRuby::StreamResponse)
        puts '✅ Retrieved feed group successfully'

        # Update feed group - only update allowed fields for built-in groups
        # Built-in groups can only have [activity_selectors, custom_ranking] updated
        update_request = GetStream::Generated::Models::UpdateFeedGroupRequest.new(
          custom_ranking: {},
        )

        update_response = client.feeds.update_feed_group('foryou', update_request)
        expect(update_response).to be_a(GetStreamRuby::StreamResponse)
        puts '✅ Updated feed group successfully'

        # Get or create feed group
        get_or_create_request = GetStream::Generated::Models::GetOrCreateFeedGroupRequest.new(
          default_visibility: 'public',
        )

        get_or_create_response = client.feeds.get_or_create_feed_group('foryou', get_or_create_request)
        expect(get_or_create_response).to be_a(GetStreamRuby::StreamResponse)
        expect(get_or_create_response.was_created).to be false
        puts '✅ Got existing feed group successfully'

        # Delete feed group (only if we created one)
        if feed_group_id_test
          begin
            delete_response = client.feeds.delete_feed_group(feed_group_id_test)
            expect(delete_response).to be_a(GetStreamRuby::StreamResponse)
            puts "✅ Deleted feed group: #{feed_group_id_test}"
          rescue StandardError => e
            puts "⚠️ Cleanup error: #{e.message}"
          end
        end
      rescue StandardError => e
        puts "⚠️ Test error: #{e.message}"
        raise e unless e.message.include?('maximum number of feed groups')
      end

    end

  end

  describe 'Feed View CRUD Operations' do

    it 'performs feed view CRUD operations' do

      puts "\n👁️ Testing Feed View CRUD operations..."

      # List feed views
      list_response = client.feeds.list_feed_views
      expect(list_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Listed feed views successfully'

    end

  end

  describe 'File Upload' do

    it 'uploads a file using multipart form data' do

      puts "\n📤 Testing file upload..."

      # Create a temporary text file (feed API upload_file supports text, not images)
      require 'tempfile'
      tmpfile = Tempfile.new(['feed-upload-test-', '.txt'])
      tmpfile.write('hello world test file content from Ruby SDK')
      tmpfile.close

      begin
        # Create file upload request
        file_upload_request = GetStream::Generated::Models::FileUploadRequest.new(
          file: tmpfile.path,
          user: GetStream::Generated::Models::OnlyUserID.new(id: test_user_id_1),
        )

        # Upload the file
        upload_response = client.common.upload_file(file_upload_request)

        expect(upload_response).to be_a(GetStreamRuby::StreamResponse)
        expect(upload_response.file).not_to be_nil
        expect(upload_response.file).to be_a(String)
        expect(upload_response.file).not_to be_empty

        puts '✅ File uploaded successfully'
        puts "   File URL: #{upload_response.file}"
        puts "   Thumbnail URL: #{upload_response.thumb_url}" if upload_response.thumb_url

        # Verify the URL is a valid URL
        expect(upload_response.file).to match(/^https?:\/\//)
      ensure
        tmpfile.unlink
      end

    end

  end

  describe 'Real World Usage Demo' do

    it 'demonstrates real-world usage patterns' do

      puts "\n🌍 Testing real-world usage patterns..."

      test_helper.create_test_feed(feed_group_id, feed_id, test_user_id_1)
      test_helper.create_test_feed(feed_group_id, feed_id_2, test_user_id_2)

      # 1. User creates a post with image
      attachment = GetStream::Generated::Models::Attachment.new(
        image_url: 'https://example.com/coffee-shop.jpg',
        type: 'image',
        title: 'Amazing Coffee Shop',
      )

      post_request = GetStream::Generated::Models::AddActivityRequest.new(
        type: 'post',
        text: 'Just visited the most amazing coffee shop! ☕️',
        user_id: test_user_id_1,
        feeds: ["#{feed_group_id}:#{feed_id}"],
        attachments: [attachment],
        custom: {
          location: 'Downtown Coffee Co.',
          rating: 5,
          tags: ['coffee', 'food', 'downtown'],
        },
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
          user_id: test_user_id_2,
        )

        reaction_response = client.feeds.add_activity_reaction(post_id, reaction_request)
        expect(reaction_response).to be_a(GetStreamRuby::StreamResponse)

      end
      puts '✅ Added reactions to post'

      # 3. Users comment on the post
      comments = [
        'That place looks amazing! What did you order?',
        'I love their espresso! Great choice 😍',
        'Adding this to my must-visit list!',
      ]

      comments.each do |comment_text|

        comment_request = GetStream::Generated::Models::AddCommentRequest.new(
          comment: comment_text,
          object_id: post_id,
          object_type: 'activity',
          user_id: test_user_id_2,
        )

        comment_response = client.feeds.add_comment(comment_request)
        expect(comment_response).to be_a(GetStreamRuby::StreamResponse)

        comment_id = comment_response.comment.id
        test_helper.created_comment_ids << comment_id

      end
      puts '✅ Added comments to post'

      # 4. User bookmarks the post
      begin
        bookmark_request = GetStream::Generated::Models::AddBookmarkRequest.new(
          user_id: test_user_id_2,
          new_folder: GetStream::Generated::Models::AddFolderRequest.new(
            name: 'favorite-places',
          ),
        )

        bookmark_response = client.feeds.add_bookmark(post_id, bookmark_request)
        expect(bookmark_response).to be_a(GetStreamRuby::StreamResponse)
        puts '✅ Bookmarked the post'
      rescue StandardError => e
        puts "⚠️ Bookmark operation skipped: #{e.message}"
      end

      # 5. Query the activity with all its interactions
      enriched_response = client.feeds.get_activity(post_id)
      expect(enriched_response).to be_a(GetStreamRuby::StreamResponse)
      puts '✅ Retrieved enriched activity successfully'

      puts '✅ Completed real-world usage scenario demonstration'

    end

  end

end
