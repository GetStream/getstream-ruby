# frozen_string_literal: true

require 'bundler/setup'
require 'getstream_ruby'
require 'webmock/rspec'

RSpec.configure do |config|

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|

    c.syntax = :expect

  end

  # Include integration test directory in default path
  config.default_path = 'spec'

  config.before(:each) do

    # Reset configuration before each test
    GetStreamRuby.instance_variable_set(:@configuration, nil)
    GetStreamRuby.instance_variable_set(:@client, nil)

  end

  # Disable WebMock for integration tests
  config.before(:each, type: :integration) do

    WebMock.allow_net_connect! if defined?(WebMock)

  end

  config.after(:each, type: :integration) do

    WebMock.disable_net_connect! if defined?(WebMock)

  end

end
