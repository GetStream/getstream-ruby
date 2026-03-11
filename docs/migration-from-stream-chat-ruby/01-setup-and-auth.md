# Setup and Authentication

This guide covers migrating client setup, configuration, and token generation from `stream-chat-ruby` to `getstream-ruby`.

## Installation

**Before (stream-chat-ruby):**

```bash
gem install stream-chat-ruby
```

**After (getstream-ruby):**

```bash
gem install getstream-ruby
```

## Client Instantiation

### Direct Constructor

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

# With optional timeout (seconds)
client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET', 10.0)
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(
  api_key: 'STREAM_KEY',
  api_secret: 'STREAM_SECRET',
)
```

**Key changes:**
- Require path changed from `stream-chat` to `getstream_ruby`
- Constructor uses named keyword arguments instead of positional arguments

### From Environment Variables

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

# Reads STREAM_KEY, STREAM_SECRET, STREAM_CHAT_TIMEOUT, STREAM_CHAT_URL
client = StreamChat::Client.from_env
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

# From .env file (reads STREAM_API_KEY, STREAM_API_SECRET)
client = GetStreamRuby.env

# From shell environment variables
client = GetStreamRuby.env_vars

# Default (uses .env file)
client = GetStreamRuby.client
```

**Key changes:**
- Environment variable names changed from `STREAM_KEY` / `STREAM_SECRET` to `STREAM_API_KEY` / `STREAM_API_SECRET`
- Multiple initialization methods available: `.env` (dotenv file), `.env_vars` (shell), `.client` (default)

### Environment Variables

| Purpose | stream-chat-ruby | getstream-ruby |
|---------|-----------------|---------------|
| API Key | `STREAM_KEY` | `STREAM_API_KEY` |
| API Secret | `STREAM_SECRET` | `STREAM_API_SECRET` |
| Base URL | `STREAM_CHAT_URL` | `STREAM_BASE_URL` |
| Timeout | `STREAM_CHAT_TIMEOUT` | _(configure via options)_ |

## API Access Pattern

The new SDK splits functionality across product-specific sub-clients.

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

# All methods are directly on the client
client.upsert_user({ id: 'bob-1' })
client.query_users({ id: { '$in' => ['bob-1'] } })
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

# Methods are accessed through sub-clients
client.common.update_users(request)   # user operations
client.chat.send_message(...)         # chat operations
client.moderation.ban(request)        # moderation operations
```

**Key changes:**
- Old SDK has all methods on a single `Client` object
- New SDK organizes methods into `client.common`, `client.chat`, `client.moderation`, `client.video`, and `client.feeds`

## User Token Generation

The new SDK does not yet include a built-in `create_token` method. You can generate user tokens directly using the `jwt` gem (which is already a dependency of `getstream-ruby`):

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')
token = client.create_token('bob-1')

# With expiration
token = client.create_token(
  'bob-1',
  exp: (Time.now + 3600).to_i,
  iat: Time.now.to_i,
)
```

**After (getstream-ruby):**

```ruby
require 'jwt'

api_secret = 'STREAM_SECRET'

# Token without expiration
token = JWT.encode({ user_id: 'bob-1', iat: Time.now.to_i }, api_secret, 'HS256')

# Token with expiration (1 hour)
token = JWT.encode(
  { user_id: 'bob-1', iat: Time.now.to_i, exp: (Time.now + 3600).to_i },
  api_secret,
  'HS256',
)
```

**Key changes:**
- Old SDK has a built-in `create_token` method on the client
- New SDK requires generating tokens directly with the `jwt` gem using `JWT.encode`
- The payload must include `user_id` and should include `iat`; `exp` is optional

## Summary of Method Changes

| Operation | stream-chat-ruby | getstream-ruby |
|-----------|-----------------|---------------|
| Create client | `StreamChat::Client.new(key, secret)` | `GetStreamRuby.manual(api_key: key, api_secret: secret)` |
| Client from env | `StreamChat::Client.from_env` | `GetStreamRuby.env` or `GetStreamRuby.env_vars` |
| Generate token | `client.create_token(user_id)` | `JWT.encode({ user_id: uid, iat: ... }, secret, 'HS256')` |
| Token with expiry | `client.create_token(uid, exp: timestamp)` | `JWT.encode({ user_id: uid, iat: ..., exp: ... }, secret, 'HS256')` |
