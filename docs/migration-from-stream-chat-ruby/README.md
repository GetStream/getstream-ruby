# Migrating from stream-chat-ruby to getstream-ruby

## Why Migrate?

Stream has released **[getstream-ruby](https://github.com/GetStream/getstream-ruby)**, a new full-product Ruby SDK that covers Chat, Video, Moderation, and Feeds in a single gem. It is generated from OpenAPI specs, which means it stays up to date with the latest API features automatically.

**getstream-ruby** is the long-term-supported SDK going forward. **stream-chat-ruby** will enter maintenance mode and continue receiving critical bug fixes, but new features and API coverage will only be added to getstream-ruby.

If you are starting a new project, use **getstream-ruby**. If you have an existing project using stream-chat-ruby, we encourage you to migrate at your convenience. There is no rush, as stream-chat-ruby is not going away, but migrating gives you access to the latest features and the best developer experience.

## Key Differences

| | **stream-chat-ruby** | **getstream-ruby** |
|---|---|---|
| **Gem** | `stream-chat-ruby` | `getstream-ruby` |
| **Require** | `require 'stream-chat'` | `require 'getstream_ruby'` |
| **Client init** | `StreamChat::Client.new(key, secret)` | `GetStreamRuby.manual(api_key: key, api_secret: secret)` |
| **API style** | All methods on a single `Client` class | Methods split across `client.common`, `client.chat`, `client.moderation` |
| **Channel pattern** | `client.channel(type, channel_id:).method()` | `client.chat.method(type, id, request)` |
| **Models** | Plain hashes | Typed `GetStream::Generated::Models::*` classes |
| **Response access** | Hash keys | Hash keys (same) |
| **Product coverage** | Chat only | Chat, Video, Moderation, Feeds |

## Quick Before/After Example

The most common operation (initialize client and send a message):

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
chan.create('bob-1')
response = chan.send_message({ text: 'Hello, world!' }, 'bob-1')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.get_or_create_channel(
  'messaging',
  'general',
  GetStream::Generated::Models::ChannelGetOrCreateRequest.new(
    data: { created_by_id: 'bob-1' },
  ),
)

response = client.chat.send_message(
  'messaging',
  'general',
  GetStream::Generated::Models::SendMessageRequest.new(
    message: GetStream::Generated::Models::MessageRequest.new(
      text: 'Hello, world!',
      user_id: 'bob-1',
    ),
  ),
)
```

## Migration Guides by Topic

| # | Topic | Guide |
|---|-------|-------|
| 1 | Setup and Authentication | [01-setup-and-auth.md](./01-setup-and-auth.md) |
| 2 | Users | [02-users.md](./02-users.md) |
| 3 | Channels | [03-channels.md](./03-channels.md) |
| 4 | Messages and Reactions | [04-messages-and-reactions.md](./04-messages-and-reactions.md) |
| 5 | Moderation | [05-moderation.md](./05-moderation.md) |
| 6 | Devices | [06-devices.md](./06-devices.md) |

Each guide provides side-by-side "Before" and "After" code examples for every operation, along with notes on key differences.

## Continued Support for stream-chat-ruby

stream-chat-ruby is not being removed or abandoned. It will continue to receive:

- Critical bug fixes
- Security patches
- Requested features on a case-by-case basis

However, all new API features, generated model types, and multi-product support will only be available in getstream-ruby. We recommend migrating when it makes sense for your project timeline.

## Resources

- [getstream-ruby on GitHub](https://github.com/GetStream/getstream-ruby)
- [getstream-ruby on RubyGems](https://rubygems.org/gems/getstream-ruby)
- [Stream Chat documentation](https://getstream.io/chat/docs/)
