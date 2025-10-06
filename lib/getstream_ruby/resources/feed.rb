# frozen_string_literal: true

module GetStreamRuby

  module Resources

    class Feed

      def initialize(client)
        @client = client
      end

      # Create a new feed
      # @param feed_slug [String] The feed slug (e.g., "user", "timeline")
      # @param user_id [String] The user ID
      # @param data [Hash] Additional feed data
      # @return [Hash] The created feed response
      def create(feed_slug, user_id, data = {})
        feed_id = "#{feed_slug}:#{user_id}"
        path = "/feed/#{feed_slug}/#{user_id}/"

        feed_data = {
          id: feed_id,
          created_at: Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
          updated_at: Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
        }.merge(data)

        @client.post(path, feed_data)
      end

    end

  end

end
