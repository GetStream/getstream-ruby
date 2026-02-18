# frozen_string_literal: true

module GetStream

  module Generated

    class ModerationClient

      # Experimental: Check user profile
      #
      # Warning: This is an experimental feature and the API is subject to change.
      #
      # This function is used to check a user profile for moderation.
      # This will not create any review queue items for the user profile.
      # You can just use this to check whether to allow a certain user profile
      # to be created or not.
      #
      # @param user_id [String] User ID to be checked
      # @param profile [Hash] Profile data to be checked
      # @option profile [String] :username Username to be checked
      # @option profile [String] :image Image URL to be checked
      # @return [Models::CheckResponse]
      #
      # @example
      #   client.moderation.check_user_profile('user-id',
      #     { username: 'bad_username', image: 'https://example.com/profile.jpg' })
      def check_user_profile(user_id, profile)
        if profile[:username].nil? && profile[:image].nil?
          raise ArgumentError, 'Either username or image must be provided'
        end

        moderation_payload = Models::ModerationPayload.new
        moderation_payload.texts = [profile[:username]] if profile[:username]
        moderation_payload.images = [profile[:image]] if profile[:image]

        check_request = Models::CheckRequest.new(
          entity_type: 'userprofile',
          entity_id: user_id,
          entity_creator_id: user_id,
          moderation_payload: moderation_payload,
          config_key: 'user_profile:default',
          options: { force_sync: true, test_mode: true },
        )

        check(check_request)
      end

    end

  end

end
