# GetStream Ruby SDK this

Official Ruby SDK for GetStream's activity feeds and chat APIs.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'getstream-ruby'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install getstream-ruby
```

## Configuration

### Method 1: Manual (Highest Priority)

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(
  api_key: "your_api_key",
  api_secret: "your_api_secret",
)
```

### Method 2: .env File

Create a `.env` file in your project root:

```bash
# Copy the example file
cp env.example .env

# Edit .env with your actual credentials
STREAM_API_KEY=your_api_key
STREAM_API_SECRET=your_api_secret
```

```ruby
require 'getstream_ruby'

# Uses .env file automatically
client = GetStreamRuby.env
# or
client = GetStreamRuby.client  # defaults to .env
```

### Method 3: Environment Variables

```bash
export STREAM_API_KEY=your_api_key
export STREAM_API_SECRET=your_api_secret
```

```ruby
require 'getstream_ruby'

client = GetStreamRuby.env_vars
```

## Usage

### Basic Setup

```ruby
# Create a client instance
client = GetStreamRuby.client

# Or create with custom configuration
client = GetStreamRuby::Client.new(config)
```

### Feed Operations

#### Create a Feed

```ruby
# Create a user feed
feed_response = client.feed.create("user", "123", {
  name: "John Doe",
  email: "john@example.com"
})
```

#### Add Activity to Feed

```ruby
# Add an activity
activity_response = client.feed.add_activity("user", "123", {
  actor: "user:123",
  verb: "post",
  object: "post:456",
  message: "Hello, world!",
  published: Time.now.iso8601
})
```

#### Get Feed Activities

```ruby
# Get activities from a feed
activities = client.feed.get_activities("user", "123", {
  limit: 10,
  offset: 0
})
```

#### Follow/Unfollow Feeds

```ruby
# Follow another user
follow_response = client.feed.follow("user:123", "user:456", {
  activity_copy_limit: 5
})

# Unfollow a user
unfollow_response = client.feed.unfollow("user:123", "user:456")
```

## Error Handling

The SDK provides specific error classes for different types of errors:

```ruby
begin
  client.feed.create("user", "123")
rescue GetStreamRuby::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue GetStreamRuby::ValidationError => e
  puts "Validation error: #{e.message}"
rescue GetStreamRuby::APIError => e
  puts "API error: #{e.message}"
end
```

## Development

### Quick Start

```bash
# Clone the repository
git clone https://github.com/getstream/getstream-ruby.git
cd getstream-ruby

# Setup development environment
make dev-setup

# Run all checks
make dev-check
```

### Project Structure

```
getstream-ruby/
├── lib/getstream_ruby/          # Main SDK code
├── spec/                        # Test files
│   ├── integration/             # Integration tests
│   └── *.rb                     # Unit tests
├── .github/workflows/           # CI/CD workflows
├── .rubocop.yml                 # Code style configuration
├── .env.example                 # Environment template
├── Makefile                     # Development commands
├── Rakefile                     # Ruby task runner
└── Gemfile                      # Dependencies
```

### Development Commands

This project includes a simple Makefile with essential commands:

#### Setup & Installation
```bash
make install          # Install dependencies
make setup            # Setup development environment
make dev-setup        # Complete development setup
```

#### Testing
```bash
make test             # Run unit tests only
make test-integration # Run integration tests only
make test-all         # Run all tests (unit + integration)
```

#### Code Quality
```bash
make format           # Auto-format code with RuboCop
make format-check     # Check formatting (CI-friendly)
make lint             # Run RuboCop linter
make security         # Run security audit
make dev-check        # Run all development checks
```

#### Utilities
```bash
make clean            # Clean up generated files
make console          # Start IRB console with SDK loaded
make version          # Show current version
make help             # Show all available commands
```

### Environment Setup

1. **Copy environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your GetStream credentials:**
   ```bash
   STREAM_API_KEY=your_api_key
   STREAM_API_SECRET=your_api_secret
   ```

3. **Run tests:**
   ```bash
   make test-all
   ```

### Ruby & Bundler Compatibility

This project supports Ruby 2.6+ and uses the default bundler version for simplicity.

**Requirements:**
- Ruby 2.6.0+ (see `.ruby-version`)
- Bundler (latest compatible version)

### Code Style

This project uses RuboCop for code style enforcement. The configuration is in `.rubocop.yml`.

- **Auto-fix issues:** `make format-fix`
- **Check style:** `make format-check`
- **View all issues:** `make lint`

### Development Tools

The project includes several development tools configured and ready to use:

- **RuboCop** - Code style and quality enforcement
- **RSpec** - Testing framework
- **SimpleCov** - Code coverage reporting
- **YARD** - Documentation generation
- **Bundler Audit** - Security vulnerability scanning
- **WebMock** - HTTP request mocking (disabled for integration tests)

### Available Makefile Commands

Run `make help` to see all available commands, or check the sections above for categorized commands.

### Integration Tests

Integration tests require valid GetStream API credentials. They test real API interactions:

```bash
# Run integration tests (requires .env file)
make test-integration

# Run specific integration test
bundle exec rspec spec/integration/feed_integration_spec.rb
bundle exec rspec spec/integration/moderation_integration_spec.rb
```

### CI/CD

The project includes simple GitHub Actions workflows:

- **CI Pipeline:** Runs on every push and pull request
  - Unit tests
  - Code formatting checks
  - Security audit
  - Integration tests (on master/main branches only)

- **Release Pipeline:** Manual releases via git tags
  - Create a tag: `git tag v1.0.0 && git push origin v1.0.0`
  - Automated gem build and release

#### GitHub Environment Variables

To enable integration tests in CI, configure these GitHub repository settings:

1. **Create a "ci" environment:**
   - Go to Settings → Environments
   - Click "New environment"
   - Name it "ci"

2. **Configure environment variables:**
   - In the "ci" environment, go to Environment variables
   - Add: `STREAM_API_KEY` = your GetStream API key

3. **Configure environment secrets:**
   - In the "ci" environment, go to Environment secrets
   - Add: `STREAM_API_SECRET` = your GetStream API secret

### Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run tests: `make dev-check`
5. Commit with conventional messages: `git commit -m "feat: add new feature"`
6. Push and create a pull request

**Commit Message Format:**
- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `style:` - Code style changes
- `refactor:` - Code refactoring
- `test:` - Test changes
- `chore:` - Maintenance tasks

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/getstream/getstream-ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
