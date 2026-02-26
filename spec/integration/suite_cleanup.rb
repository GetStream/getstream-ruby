# frozen_string_literal: true

require 'dotenv'

# Global registry that collects test user IDs across all spec files and
# deletes them in a single batched call after the full suite completes.
#
# Why: the delete_users endpoint is rate-limited. Calling it once per spec
# file (8+ calls per run) exhausts the quota and causes the DeleteUsers
# integration test to fail. Batching everything into one call at suite end
# reduces pressure to 1–2 API calls per run and keeps the test data clean.
#
# Usage:
#   SuiteCleanup.register_users(user_ids)  # call from any spec/helper
#
# The after(:suite) hook below triggers the actual deletion automatically.
module SuiteCleanup

  @user_ids = []

  class << self

    def register_users(ids)
      @user_ids.concat(Array(ids).compact)
    end

    def run
      return if @user_ids.empty?

      Dotenv.load('.env') if File.exist?('.env')

      # Require the library; it may already be loaded, require is idempotent.
      require_relative '../../lib/getstream_ruby'

      # Allow network access in case WebMock disabled it after the last test.
      WebMock.allow_net_connect! if defined?(WebMock)

      client = GetStreamRuby.client
      uniq_ids = @user_ids.uniq
      puts "\n🧹 Suite cleanup: deleting #{uniq_ids.length} test users..."

      # The delete_users endpoint accepts up to 100 user IDs per request.
      uniq_ids.each_slice(100) do |batch|

        3.times do |i|

          client.common.delete_users(
            GetStream::Generated::Models::DeleteUsersRequest.new(
              user_ids: batch,
              user: 'hard',
              messages: 'hard',
              conversations: 'hard',
            ),
          )
          break

        rescue GetStreamRuby::APIError => e

          raise unless e.message.include?('Too many requests')

          wait = [30 * (2**i), 120].min
          puts "⏳ Rate-limited during suite cleanup, retrying in #{wait}s..."
          sleep(wait)

        end

      end

      puts '✅ Suite cleanup complete'
    end

  end

end

RSpec.configure do |config|

  config.after(:suite) do
    SuiteCleanup.run
  end

end
