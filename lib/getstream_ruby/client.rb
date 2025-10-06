require "faraday"
require "faraday/retry"
require "json"
require "jwt"
require_relative "generated/base_model"
require_relative "generated/common_client"
require_relative "generated/feeds_client"
require_relative "generated/moderation_client"
require_relative "generated/feed"
require_relative "stream_response"

module GetStreamRuby
  class Client
    attr_reader :configuration

    def initialize(config = nil, api_key: nil, api_secret: nil, app_id: nil, base_url: nil, timeout: nil)
      @configuration = config || GetStreamRuby.configuration
      
      # Create new configuration with overrides if any parameters provided
      if api_key || api_secret || app_id || base_url || timeout
        @configuration = Configuration.with_overrides(
          api_key: api_key,
          api_secret: api_secret,
          app_id: app_id,
          base_url: base_url,
          timeout: timeout
        )
      end
      
      @configuration.validate!
      @connection = build_connection
    end

    def feed
      @feed ||= Resources::Feed.new(self)
    end

    # Generated API clients
    
    # @return [GetStream::Generated::CommonClient] The common API client
    def common
      @common ||= GetStream::Generated::CommonClient.new(self)
    end

    # @return [GetStream::Generated::FeedsClient] The feeds API client
    def feeds
      @feeds ||= GetStream::Generated::FeedsClient.new(self)
    end

    # @return [GetStream::Generated::ModerationClient] The moderation API client
    def moderation
      @moderation ||= GetStream::Generated::ModerationClient.new(self)
    end

    # Create an individual feed instance
    # @param feed_group_id [String] The feed group ID
    # @param feed_id [String] The feed ID
    # @return [GetStream::Generated::Feed] A feed instance
    def feed(feed_group_id, feed_id)
      GetStream::Generated::Feed.new(self, feed_group_id, feed_id)
    end

    # @param path [String] The API path
    # @param body [Hash] The request body
    # @return [GetStreamRuby::StreamResponse] The API response
    def post(path, body = {})
      request(:post, path, body)
    end

    def make_request(method, path, query_params: nil, body: nil)
      # Handle query parameters
      if query_params && !query_params.empty?
        query_string = query_params.map { |k, v| "#{k}=#{v}" }.join("&")
        path = "#{path}?#{query_string}"
      end
      
      # Make the request
      request(method, path, body)
    end

    private

    def request(method, path, data = {})

      # Add API key to query parameters
      query_params = { api_key: @configuration.api_key }
      response = @connection.send(method) do |req|
        req.url path, query_params
        req.headers["Authorization"] = generate_auth_header
        req.headers["Content-Type"] = "application/json"
        req.headers["stream-auth-type"] = "jwt"
        req.headers["X-Stream-Client"] = get_user_agent
        req.body = data.to_json
      end

      handle_response(response)
    rescue Faraday::Error => e
      raise APIError, "Request failed: #{e.message}"
    end

    def build_connection
      Faraday.new(url: @configuration.base_url) do |conn|
        conn.request :retry, {
          max: 3,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        }
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
        conn.options.timeout = @configuration.timeout
      end
    end

    def generate_auth_header
      token = JWT.encode(
        {
          iat: Time.now.to_i,
          server: true
        },
        @configuration.api_secret,
        "HS256"
      )
      token
    end

    def get_user_agent
      "getstream-ruby-#{GetStreamRuby::VERSION}"
    end

    def handle_response(response)
      case response.status
      when 200..299
        StreamResponse.new(response.body)
      else
        error_message = response.body.is_a?(Hash) && response.body["detail"] ? response.body["detail"] : "Request failed with status #{response.status}"
        raise APIError, error_message
      end
    end
  end
end
