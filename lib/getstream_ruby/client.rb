require "faraday"
require "faraday/retry"
require "json"
require "jwt"

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
      response = @connection.send(method) do |req|
        req.url path
        req.headers["Authorization"] = generate_auth_header
        req.headers["Content-Type"] = "application/json"
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
          iss: @configuration.app_id,
          iat: Time.now.to_i,
          exp: Time.now.to_i + 3600
        },
        @configuration.api_secret,
        "HS256"
      )
      "Bearer #{token}"
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      else
        error_message = response.body.is_a?(Hash) && response.body["detail"] ? response.body["detail"] : "Request failed with status #{response.status}"
        raise APIError, error_message
      end
    end
  end
end
