# Only load dotenv for .env method, not for system env method
require "getstream_ruby/version"
require "getstream_ruby/client"
require "getstream_ruby/configuration"
require "getstream_ruby/errors"
require "getstream_ruby/resources/feed"

module GetStreamRuby
  class << self
    # Method 1: Manual configuration (highest priority)
    def manual(api_key:, api_secret:, app_id:, base_url: nil, timeout: nil)
      config = Configuration.manual(
        api_key: api_key, 
        api_secret: api_secret, 
        app_id: app_id, 
        base_url: base_url, 
        timeout: timeout
      )
      Client.new(config)
    end

    # Method 2: .env file
    def env
      @env_client ||= Client.new(Configuration.from_env)
    end

    # Method 3: Environment variables
    def env_vars
      @env_vars_client ||= Client.new(Configuration.from_system_env)
    end

    # Default: tries .env first, then env vars
    def client
      env
    end
  end
end
