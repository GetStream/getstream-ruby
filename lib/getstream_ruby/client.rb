# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'
require 'faraday/multipart'
require 'json'
require 'jwt'
require_relative 'generated/base_model'
require_relative 'generated/common_client'
require_relative 'generated/feeds_client'
require_relative 'generated/moderation_client'
require_relative 'extensions/moderation_extensions'
require_relative 'generated/feed'
require_relative 'stream_response'

module GetStreamRuby

  class Client

    attr_reader :configuration

    def initialize(config = nil, api_key: nil, api_secret: nil, base_url: nil, timeout: nil)
      @configuration = config || GetStreamRuby.configuration

      # Create new configuration with overrides if any parameters provided
      if api_key || api_secret || base_url || timeout
        @configuration = Configuration.with_overrides(
          api_key: api_key,
          api_secret: api_secret,
          base_url: base_url,
          timeout: timeout,
        )
      end

      @configuration.validate!
      @connection = build_connection
    end

    def feed_resource
      @feed_resource ||= Resources::Feed.new(self)
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
        query_string = query_params.map { |k, v| "#{k}=#{v}" }.join('&')
        path = "#{path}?#{query_string}"
      end

      # Make the request
      request(method, path, body)
    end

    private

    def request(method, path, data = {})
      # Add API key to query parameters
      query_params = { api_key: @configuration.api_key }

      # Check if this is a file upload request that needs multipart
      return make_multipart_request(method, path, query_params, data) if multipart_request?(data)

      response = @connection.send(method) do |req|

        req.url path, query_params
        req.headers['Authorization'] = generate_auth_header
        req.headers['Content-Type'] = 'application/json'
        req.headers['stream-auth-type'] = 'jwt'
        req.headers['X-Stream-Client'] = user_agent
        req.body = data.to_json

      end

      handle_response(response)
    rescue Faraday::Error => e
      raise APIError, "Request failed: #{e.message}"
    end

    def build_connection
      Faraday.new(url: @configuration.base_url) do |conn|

        conn.request :multipart
        conn.request :retry, {
          max: 3,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2,
        }
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
        conn.options.timeout = @configuration.timeout

      end
    end

    def generate_auth_header
      JWT.encode(
        {
          iat: Time.now.to_i,
          server: true,
        },
        @configuration.api_secret,
        'HS256',
      )
    end

    def user_agent
      "getstream-ruby-#{GetStreamRuby::VERSION}"
    end

    def handle_response(response)
      case response.status
      when 200..299
        StreamResponse.new(response.body)
      else
        # Parse JSON response body if it's a string
        parsed_body = if response.body.is_a?(String)
                        begin
                          JSON.parse(response.body)
                        rescue JSON::ParserError
                          response.body
                        end
                      else
                        response.body
                      end

        error_message = if parsed_body.is_a?(Hash)
                          parsed_body['message'] || parsed_body['detail'] ||
                            "Request failed with status #{response.status}"
                        else
                          "Request failed with status #{response.status}"
                        end
        raise APIError, error_message
      end
    end

    def multipart_request?(data)
      return false if data.nil? || data == {}

      # Check if data is a FileUploadRequest or ImageUploadRequest
      data.is_a?(GetStream::Generated::Models::FileUploadRequest) ||
        data.is_a?(GetStream::Generated::Models::ImageUploadRequest)
    end

    def make_multipart_request(method, path, query_params, data)
      # Build multipart form data
      payload = {}

      # Handle file field
      raise APIError, 'file name must be provided' if data.file.nil? || data.file.empty?

      file_path = data.file
      raise APIError, "file not found: #{file_path}" unless File.exist?(file_path)

      # Determine content type
      content_type = detect_content_type(file_path)

      # Add file as multipart (FilePart handles file opening/closing)
      payload[:file] = Faraday::Multipart::FilePart.new(
        file_path,
        content_type,
        File.basename(file_path),
      )

      # Add user field if present (as JSON string)
      if data.user
        user_json = data.user.to_json
        payload[:user] = user_json
      end

      # Add upload_sizes field for ImageUploadRequest (as JSON string)
      if data.is_a?(GetStream::Generated::Models::ImageUploadRequest) && data.upload_sizes
        upload_sizes_json = data.upload_sizes.to_json
        payload[:upload_sizes] = upload_sizes_json
      end

      response = @connection.send(method) do |req|

        req.url path, query_params
        req.headers['Authorization'] = generate_auth_header
        req.headers['stream-auth-type'] = 'jwt'
        req.headers['X-Stream-Client'] = user_agent
        req.body = payload

      end

      handle_response(response)
    rescue Faraday::Error => e
      raise APIError, "Request failed: #{e.message}"
    end

    def detect_content_type(file_path)
      ext = File.extname(file_path).downcase
      case ext
      when '.png'
        'image/png'
      when '.jpg', '.jpeg'
        'image/jpeg'
      when '.gif'
        'image/gif'
      when '.pdf'
        'application/pdf'
      when '.txt'
        'text/plain'
      when '.json'
        'application/json'
      else
        'application/octet-stream'
      end
    end

  end

end
