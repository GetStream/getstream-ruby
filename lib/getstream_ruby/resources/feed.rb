# frozen_string_literal: true

require 'uri'

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
        encoded_slug = encode_path_segment(feed_slug, 'feed_slug')
        encoded_user_id = encode_path_segment(user_id, 'user_id')
        feed_id = "#{feed_slug}:#{user_id}"
        path = "/feed/#{encoded_slug}/#{encoded_user_id}/"

        feed_data = {
          id: feed_id,
          created_at: Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
          updated_at: Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
        }.merge(data)

        @client.post(path, feed_data)
      end

      private

      def encode_path_segment(value, name)
        str = value.to_s
        if value.nil? || str.empty? || str == '.' || str == '..'
          raise ArgumentError, "Invalid path parameter '#{name}': must not be empty or a dot-segment"
        end

        URI.encode_www_form_component(str).gsub('+', '%20')
      end

    end

  end

end
