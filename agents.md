# GetStream Ruby SDK - Agent Guide

This document provides essential context for AI agents working with the GetStream Ruby SDK codebase.

## Project Overview

The GetStream Ruby SDK is an official Ruby gem for interacting with GetStream's activity feeds and chat APIs.

**Key Characteristics:**
- Ruby version requirement: >= 2.6.0
- Main entry point: [`lib/getstream_ruby.rb`](lib/getstream_ruby.rb)
- License: MIT
- Architecture: Client-based with resource pattern

## Architecture

### Client-Based Architecture

All SDK operations flow through the `GetStreamRuby::Client` class. The client handles:
- HTTP requests via Faraday
- JWT authentication
- Request/response handling
- File uploads (multipart)
- Error handling

### Three Configuration Methods

The SDK supports three configuration methods with clear priority:

1. **Manual (Highest Priority)** - `GetStreamRuby.manual(api_key:, api_secret:, base_url:, timeout:)`
   - Explicit configuration, no environment variable fallback
   - Default base URL: `https://api.getstream.io/api/v1.0`

2. **.env File** - `GetStreamRuby.env` or `GetStreamRuby.client`
   - Loads from `.env` file using `dotenv` gem
   - Falls back to environment variables if `.env` doesn't exist
   - Default base URL: `https://chat.stream-io-api.com`

3. **Environment Variables** - `GetStreamRuby.env_vars`
   - Direct system environment variables
   - No `.env` file loading
   - Default base URL: `https://chat.stream-io-api.com`

**Configuration Priority:** Manual > .env file > Environment variables

### Code Structure

**API Clients and Models:**
- Location: `lib/getstream_ruby/generated/`
- Contains: API clients, models, and base classes
- Files: `common_client.rb`, `feeds_client.rb`, `moderation_client.rb`, `feed.rb`, `base_model.rb`, and 1108+ model files
- Namespace: `GetStream::Generated`

**Core SDK Infrastructure:**
- Location: `lib/getstream_ruby/` (excluding `generated/`)
- Contains: Client, configuration, error handling, and response wrappers
- Files: `client.rb`, `configuration.rb`, `errors.rb`, `stream_response.rb`

## Key Components

### Client (`lib/getstream_ruby/client.rb`)

The main HTTP client that handles all API interactions:

```ruby
client = GetStreamRuby.client
client.feeds      # GetStream::Generated::FeedsClient - for general feed operations
client.common     # GetStream::Generated::CommonClient - for common API operations
client.moderation # GetStream::Generated::ModerationClient - for moderation operations
client.feed("user", "123") # GetStream::Generated::Feed instance - for specific feed operations
```

**Key Features:**
- JWT authentication using `api_secret`
- Automatic retry logic (max 3 retries, exponential backoff)
- Multipart file upload support
- StreamResponse wrapper for all responses
- User agent header: `getstream-ruby-{VERSION}`
- Single Faraday connection per client instance (reused for all requests)
- Thread-safe: Each client instance maintains its own connection

**Important Distinction:**
- `client.feeds` - Use for general feed operations (add activities, query activities, etc.)
- `client.feed(feed_group_id, feed_id)` - Use for operations on a specific feed instance (get/create feed, pin/unpin activities, mark as read, etc.)

### Configuration (`lib/getstream_ruby/configuration.rb`)

Centralized configuration management:

**Required Fields:**
- `api_key` - GetStream API key
- `api_secret` - GetStream API secret

**Optional Fields:**
- `base_url` - API base URL (has defaults based on config method)
- `timeout` - Request timeout in seconds (default: 30)
- `logger` - Optional logger instance

**Environment Variables:**
- `STREAM_API_KEY` - API key
- `STREAM_API_SECRET` - API secret
- `STREAM_BASE_URL` - Base URL override
- `STREAM_TIMEOUT` - Timeout override

### Generated Clients

Three main API clients are available:

1. **FeedsClient** - Feed operations
   - Access via: `client.feeds`
   - Namespace: `GetStream::Generated::FeedsClient`

2. **CommonClient** - Common API operations
   - Access via: `client.common`
   - Namespace: `GetStream::Generated::CommonClient`

3. **ModerationClient** - Moderation operations
   - Access via: `client.moderation`
   - Namespace: `GetStream::Generated::ModerationClient`

### Feed Instances

Individual feed instances are created via:

```ruby
feed = client.feed(feed_group_id, feed_id)
# Returns: GetStream::Generated::Feed
```

**When to use `client.feeds` vs `client.feed()`:**
- **`client.feeds`** - For general feed operations:
  - Adding activities to multiple feeds
  - Querying activities across feeds
  - Batch operations
  - Reactions, comments, bookmarks
  - Follow/unfollow operations
  
- **`client.feed(feed_group_id, feed_id)`** - For operations on a specific feed:
  - Get or create a specific feed
  - Update a specific feed
  - Delete a specific feed
  - Pin/unpin activities in a feed
  - Mark activities as read/seen in a feed
  - Get feed activities for a specific feed

**Note:** `client.feed_resource` exists but is legacy code (not used in integration tests). Use `client.feeds` or `client.feed()` instead.

### StreamResponse (`lib/getstream_ruby/stream_response.rb`)

All API responses are wrapped in `StreamResponse` objects that provide:
- Method-style access to response data: `response.field_name`
- Recursive wrapping of nested hashes
- Array handling for nested arrays
- `to_h` method for raw hash access
- `to_json` method for JSON serialization

**Important Behavior:**
- Returns `nil` for non-existent fields (does not raise errors)
- Supports both string and symbol keys from the API response
- Nested hashes are automatically wrapped in `StreamResponse` objects
- Arrays containing hashes have those hashes wrapped in `StreamResponse` objects
- Use `to_h` when you need the raw hash structure

### Error Classes (`lib/getstream_ruby/errors.rb`)

Custom error hierarchy:
- `GetStreamRuby::Error` - Base error class
- `GetStreamRuby::ConfigurationError` - Configuration issues (missing API key/secret)
- `GetStreamRuby::APIError` - API request failures

**Error Details:**
- `APIError` messages are extracted from API responses:
  - Looks for `message` or `detail` fields in error response
  - Falls back to generic message with HTTP status code if no details available
- HTTP status codes outside 200-299 range raise `APIError`
- Configuration validation failures raise `ConfigurationError` with specific field information
- Network/connection errors (Faraday errors) are wrapped in `APIError` with descriptive messages

### Models

All models:
- Inherit from `GetStream::Generated::BaseModel`
- Support `to_h` and `to_json` methods
- Automatically omit `nil` values in JSON serialization
- Located in: `lib/getstream_ruby/generated/models/`
- Namespace: `GetStream::Generated::Models`

**Special Model Types:**
- `FileUploadRequest` - For file uploads
- `ImageUploadRequest` - For image uploads with size options

## Code Organization

```
lib/getstream_ruby/
├── client.rb              # Main HTTP client
├── configuration.rb       # Configuration management
├── errors.rb              # Error classes
├── stream_response.rb     # Response wrapper
├── version.rb             # Version constant
├── generated/             # API clients and models
│   ├── base_model.rb
│   ├── common_client.rb
│   ├── feeds_client.rb
│   ├── moderation_client.rb
│   ├── feed.rb
│   └── models/            # 1108+ model files
└── resources/             # High-level resource wrappers
    └── feed.rb            # Feed resource (legacy/example - not used in integration tests)

spec/
├── integration/           # Integration tests (require API credentials)
├── generated/             # Tests for generated code
└── *.rb                   # Unit tests
```

## Important Patterns

### JWT Authentication

The SDK uses JWT tokens for authentication:

```ruby
# Token payload includes:
{
  iat: Time.now.to_i,
  server: true
}
# Signed with api_secret using HS256 algorithm
```

Header format: `Authorization: Bearer {token}`

### HTTP Client Setup

Faraday configuration includes:
- Multipart support for file uploads
- Retry logic (max 3 retries, exponential backoff with randomness)
- JSON response parsing
- Timeout configuration (default: 30 seconds)
- Query parameter: `api_key` added to all requests

**Connection Management:**
- Single Faraday connection created per `Client` instance
- Connection is reused for all requests from that client
- Connection is created lazily when first request is made
- Each client instance maintains its own connection (not shared across instances)
- Thread-safe: Each thread should use its own client instance for safety

### File Uploads

Special handling for file uploads:

1. Check if request data is `FileUploadRequest` or `ImageUploadRequest`
2. Validate file exists on filesystem
3. Detect content type from file extension
4. Build multipart form data with:
   - `file` - FilePart with detected content type
   - `user` - JSON string (if present)
   - `upload_sizes` - JSON string (for ImageUploadRequest)

### Response Handling

All successful responses (200-299) are wrapped in `StreamResponse`:
- Provides method-style access: `response.field_name`
- Handles nested hashes and arrays recursively
- Preserves original data via `to_h`

Error responses raise `GetStreamRuby::APIError` with message from API.

## Development Workflow

### Testing

```bash
make test-unit          # Run unit tests only (excludes integration)
make test-integration   # Run integration tests (requires .env with credentials)
make test-all          # Run all tests
```

**Integration Tests:**
- Location: `spec/integration/`
- Require valid GetStream API credentials in `.env` file
- Test real API interactions
- Files: `feed_integration_spec.rb`, `moderation_integration_spec.rb`

### Code Quality

```bash
make lint              # Run RuboCop linter
make format            # Auto-fix formatting issues
make format-check      # Check formatting (CI-friendly)
make security          # Run bundler-audit security check
make dev-check         # Run lint + test
```

### Development Setup

```bash
make setup             # Initial setup (creates .env from .env.example)
make install           # Install dependencies
make console           # Start IRB with SDK loaded
make version           # Show current version
```

### Version Management

```bash
make patch             # Bump patch version (0.0.1 -> 0.0.2)
make minor             # Bump minor version (0.0.1 -> 0.1.0)
make major             # Bump major version (0.0.1 -> 1.0.0)
```

Scripts located in `scripts/` directory.

## Common Tasks

### Working with API Clients and Models

**Accessing Generated Clients:**
```ruby
client = GetStreamRuby.client
feeds_client = client.feeds
common_client = client.common
moderation_client = client.moderation
```

**Creating Feed Instances:**
```ruby
feed = client.feed("user", "123")
# Use feed methods from generated Feed class
```

**Using Models:**
```ruby
# Always use generated model classes for requests (not raw hashes)
# Models are in GetStream::Generated::Models namespace
request = GetStream::Generated::Models::AddActivityRequest.new(
  type: "post",
  text: "Hello, world!",
  user_id: "user123",
  feeds: ["user:user123"]
)

# Models can be initialized with a hash
attributes = { type: "post", text: "Hello" }
request = GetStream::Generated::Models::AddActivityRequest.new(attributes)

# Models automatically omit nil values in to_json
# Models support to_h for hash conversion
# Models support == for equality comparison
```

### File Uploads

```ruby
# Create upload request model
upload_request = GetStream::Generated::Models::FileUploadRequest.new(
  file: "/path/to/file.png",
  user: { id: "user123" }
)

# Make request (client handles multipart automatically)
response = client.common.upload_file(upload_request)
```

### Error Handling

```ruby
begin
  response = client.feeds.some_method
rescue GetStreamRuby::ConfigurationError => e
  # Configuration issue
rescue GetStreamRuby::APIError => e
  # API request failed
rescue => e
  # Other errors
end
```

### Common Usage Patterns

**Creating Request Models:**
```ruby
# Always use generated model classes for requests
activity_request = GetStream::Generated::Models::AddActivityRequest.new(
  type: 'post',
  text: 'Hello, world!',
  user_id: 'user123',
  feeds: ['user:user123'],
  custom: {
    location: 'San Francisco',
    tags: ['ruby', 'sdk']
  }
)

response = client.feeds.add_activity(activity_request)
```

**Working with StreamResponse:**
```ruby
# All responses are StreamResponse objects
response = client.feeds.get_activity(activity_id)

# Access fields using method-style syntax
activity_id = response.activity.id
text = response.activity.text
custom_data = response.activity.custom

# Access nested arrays
reactions = response.reactions  # Returns array, may contain StreamResponse objects

# Convert to hash if needed
raw_data = response.to_h
```

**Creating Feed Instances and Operations:**
```ruby
# Create feed instance
feed = client.feed('user', 'user123')

# Use feed methods
feed_request = GetStream::Generated::Models::GetOrCreateFeedRequest.new(
  user_id: 'user123'
)
response = feed.get_or_create_feed(feed_request)
```

**Batch Operations:**
```ruby
# Batch user updates
users_hash = {
  'user1' => { 'id' => 'user1', 'name' => 'User 1' },
  'user2' => { 'id' => 'user2', 'name' => 'User 2' }
}
update_request = GetStream::Generated::Models::UpdateUsersRequest.new(users: users_hash)
response = client.common.update_users(update_request)
```

**Query Operations:**
```ruby
# Query with filters
query_request = GetStream::Generated::Models::QueryActivitiesRequest.new(
  limit: 10,
  filter: {
    user_id: 'user123'
  }
)
response = client.feeds.query_activities(query_request)
activities = response.activities  # Array of activities
```

### Debugging

```bash
# Start console with SDK loaded
make console

# In console:
require 'getstream_ruby'
client = GetStreamRuby.client
# Test operations...
```

## Dependencies

**Runtime Dependencies:**
- `faraday` (~> 2.0) - HTTP client
- `faraday-multipart` (~> 1.0) - Multipart file uploads
- `faraday-retry` (~> 2.0) - Request retry logic
- `jwt` (~> 2.0) - JWT token generation
- `dotenv` (~> 2.0) - .env file loading
- `json` (~> 2.0) - JSON parsing

**Development Dependencies:**
- `rspec` - Testing framework
- `rubocop` - Code style enforcement
- `simplecov` - Code coverage
- `webmock` - HTTP request mocking
- `bundler-audit` - Security auditing

## Important Files Reference

### Core SDK Files

- [`lib/getstream_ruby.rb`](lib/getstream_ruby.rb) - Main entry point, factory methods
- [`lib/getstream_ruby/client.rb`](lib/getstream_ruby/client.rb) - HTTP client implementation
- [`lib/getstream_ruby/configuration.rb`](lib/getstream_ruby/configuration.rb) - Configuration management
- [`lib/getstream_ruby/errors.rb`](lib/getstream_ruby/errors.rb) - Error class definitions
- [`lib/getstream_ruby/stream_response.rb`](lib/getstream_ruby/stream_response.rb) - Response wrapper
- [`lib/getstream_ruby/resources/feed.rb`](lib/getstream_ruby/resources/feed.rb) - Feed resource (legacy/example - not used in integration tests)

### API Clients and Models

- [`lib/getstream_ruby/generated/base_model.rb`](lib/getstream_ruby/generated/base_model.rb) - Base class for all models
- [`lib/getstream_ruby/generated/common_client.rb`](lib/getstream_ruby/generated/common_client.rb) - Common API client
- [`lib/getstream_ruby/generated/feeds_client.rb`](lib/getstream_ruby/generated/feeds_client.rb) - Feeds API client
- [`lib/getstream_ruby/generated/moderation_client.rb`](lib/getstream_ruby/generated/moderation_client.rb) - Moderation API client
- [`lib/getstream_ruby/generated/feed.rb`](lib/getstream_ruby/generated/feed.rb) - Feed instance class
- [`lib/getstream_ruby/generated/models/`](lib/getstream_ruby/generated/models/) - 1108+ model files

### Configuration Files

- [`getstream-ruby.gemspec`](getstream-ruby.gemspec) - Gem specification
- [`Gemfile`](Gemfile) - Dependency management
- [`Makefile`](Makefile) - Development commands
- [`env.example`](env.example) - Environment variable template

### Documentation

- [`README.md`](README.md) - User-facing documentation
- [`CHAT_CONTEXT.md`](CHAT_CONTEXT.md) - Additional context (may be outdated)
- [`CHANGELOG.md`](CHANGELOG.md) - Version history

## Warnings and Best Practices

### ⚠️ Critical Warnings

1. **Configuration Priority**: Understand the three configuration methods and their priority to avoid unexpected behavior.

2. **API Credentials**: Never commit `.env` file with real credentials. Use environment variables or secure credential management in production.

### Best Practices

1. **Error Handling**: Always wrap API calls in begin/rescue blocks to handle `APIError` and `ConfigurationError`.

2. **Response Access**: Use `StreamResponse` method-style access for cleaner code: `response.field_name` instead of `response.to_h[:field_name]`.

3. **File Uploads**: Always validate file existence before creating upload request models.

4. **Testing**: Write integration tests for API interactions to verify your implementation works correctly.

6. **Model Usage**: Always use generated model classes for requests, not raw hashes. Models provide type safety and proper serialization.

7. **Response Access**: Accessing non-existent fields on `StreamResponse` returns `nil` (does not raise errors). Check for `nil` when accessing optional fields.

8. **Client Reuse**: Reuse client instances when possible. Each client maintains its own connection that is reused for all requests.

9. **Batch Operations**: Use batch operations (`upsert_activities`, `update_users`, etc.) when working with multiple items for better performance.

10. **Error Handling**: Always handle `APIError` and `ConfigurationError` explicitly. Check error messages for specific API error details.

## Integration Test Patterns

The integration tests in `spec/integration/` demonstrate real-world usage patterns:

- **BaseIntegrationTest**: Helper class for test setup/cleanup (`spec/integration/base_integration_test.rb`)
- **Test Helpers**: Methods for creating test users, feeds, activities, and cleanup
- **Real API Calls**: All integration tests make actual API calls (require valid credentials)
- **Resource Tracking**: Tests track created resources for automatic cleanup
- **Error Handling**: Comprehensive error handling and reporting in test scenarios

**Key Patterns from Integration Tests:**
- Always use generated model classes (`GetStream::Generated::Models::*`)
- Use `StreamResponse` method-style access for all responses
- Track created resources for cleanup (users, activities, comments, banned users, muted users)
- Use `BaseIntegrationTest` helper methods for common operations:
  - `create_test_feed(feed_group_id, feed_id, user_id)` - Creates a test feed
  - `create_test_activity(feed_group_id, feed_id, user_id, text)` - Creates a test activity
  - `wait_for_backend_propagation(seconds)` - Waits for backend to process changes
  - `cleanup_resources` - Automatically cleans up all tracked resources
  - `assert_response_success(response, operation)` - Validates response type
- Always wrap API calls in begin/rescue blocks for error handling
- Use hard deletes (`true` parameter) for cleanup operations
- Wait for backend propagation after creating/updating resources that need to be immediately queried

## Common Pitfalls and Gotchas

### Configuration Issues
- **Wrong base URL**: Manual config uses `https://api.getstream.io/api/v1.0`, while env methods use `https://chat.stream-io-api.com`. Ensure you're using the correct base URL for your use case.
- **Missing credentials**: Configuration validation happens at client initialization. Missing `api_key` or `api_secret` raises `ConfigurationError` immediately.
- **Environment variable precedence**: `.env` file takes precedence over system environment variables when using `GetStreamRuby.env`.

### Model Usage
- **Using hashes instead of models**: Always use generated model classes. Raw hashes won't work for requests - models handle serialization and validation.
- **Nil values**: Models automatically omit `nil` values in JSON serialization. This is expected behavior.
- **Required fields**: Check model documentation or API spec for required fields. Missing required fields may cause API errors.

### Response Handling
- **Non-existent fields**: Accessing non-existent fields on `StreamResponse` returns `nil`, not an error. Always check for `nil` when accessing optional fields.
- **Nested access**: Use method chaining for nested fields: `response.activity.user.name` (not `response['activity']['user']['name']`).
- **Array elements**: Array elements that are hashes are automatically wrapped in `StreamResponse` objects.

### Feed Operations
- **client.feeds vs client.feed()**: Use `client.feeds` for general operations, `client.feed(feed_group_id, feed_id)` for specific feed operations. Don't confuse them.
- **Feed ID format**: Feed IDs should be in format `feed_group_id:feed_id` when used in arrays (e.g., `feeds: ["user:123"]`).

### File Uploads
- **File path validation**: File must exist on filesystem before creating upload request. SDK validates file existence and raises `APIError` if not found.
- **Content type detection**: SDK automatically detects content type from file extension. Unknown extensions default to `application/octet-stream`.
- **User field**: `user` field in upload requests must be a model instance (e.g., `OnlyUserID`), not a raw hash.

### Thread Safety
- **Client instances**: Each client instance maintains its own connection. For thread safety, use separate client instances per thread, or ensure proper synchronization.
- **Connection reuse**: Connections are reused within a client instance. This is efficient but means you shouldn't share client instances across threads without synchronization.

### Performance Considerations
- **Connection reuse**: Single connection per client is reused for all requests. Reuse client instances when possible.
- **Batch operations**: Use batch operations (`upsert_activities`, `update_users`, etc.) instead of individual requests for better performance.
- **Retry logic**: Automatic retries (max 3) with exponential backoff. Be aware this may increase request time for failed requests.
- **Timeout**: Default timeout is 30 seconds. Adjust via configuration if needed for long-running operations.

## Additional Resources

- GetStream API Documentation: https://getstream.io/docs
- Ruby SDK Repository: Check GitHub for latest updates
- Integration Test Examples: See `spec/integration/` for comprehensive usage patterns
- Integration Test Helper: See `spec/integration/base_integration_test.rb` for test utilities

## Notes for AI Agents

When working with this SDK:

1. **Configuration**: Always consider which configuration method the user is using when suggesting code changes.

2. **Error Messages**: Use the custom error classes (`ConfigurationError`, `APIError`) rather than generic exceptions.

3. **Response Handling**: Remember that all API responses are `StreamResponse` objects, not raw hashes.

4. **Model Usage**: Always use model classes from `GetStream::Generated::Models` namespace for requests, not raw hashes.

5. **Client Methods**: Understand the difference between `client.feeds` (general operations) and `client.feed(feed_group_id, feed_id)` (specific feed operations).

6. **File Paths**: Use absolute paths when referencing files in suggestions, as shown in this document.

