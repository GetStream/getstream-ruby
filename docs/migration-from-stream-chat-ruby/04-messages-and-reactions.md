# Messages and Reactions

This guide shows how to migrate message and reaction operations from `stream-chat-ruby` to `getstream-ruby`.

## Send a Message

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
response = chan.send_message({ text: 'Hello, world!' }, 'bob-1')
message_id = response['message']['id']
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

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
message_id = response['message']['id']
```

**Key changes:**
- Old SDK calls `chan.send_message(message_hash, user_id)` with user ID as a separate positional argument
- New SDK calls `client.chat.send_message(type, id, request)` with user ID inside the `MessageRequest`
- The request uses a two-level structure: `SendMessageRequest` wraps `MessageRequest`

## Send a Thread Reply

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
response = chan.send_message(
  { text: 'This is a reply', parent_id: parent_message_id },
  'bob-1',
)
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.chat.send_message(
  'messaging',
  'general',
  GetStream::Generated::Models::SendMessageRequest.new(
    message: GetStream::Generated::Models::MessageRequest.new(
      text: 'This is a reply',
      user_id: 'bob-1',
      parent_id: parent_message_id,
    ),
  ),
)
```

**Key changes:**
- Both SDKs use `parent_id` to create thread replies
- In the new SDK, `parent_id` is a named property on `MessageRequest`

## Get a Message

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

response = client.get_message(message_id)
message = response['message']
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.chat.get_message(message_id)
message = response['message']
```

**Key changes:**
- Method name is the same; access through `client.chat` instead of `client` directly

## Get Multiple Messages

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
response = chan.get_messages(['msg-1', 'msg-2', 'msg-3'])
messages = response['messages']
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.chat.get_many_messages('messaging', 'general', ['msg-1', 'msg-2', 'msg-3'])
messages = response['messages']
```

**Key changes:**
- Old SDK uses `chan.get_messages(ids)` on the `Channel` object
- New SDK uses `client.chat.get_many_messages(type, id, message_ids)`

## Update a Message (Full)

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.update_message({
  'id' => message_id,
  'text' => 'Updated text',
  'user_id' => 'bob-1',
})
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.update_message(
  message_id,
  GetStream::Generated::Models::UpdateMessageRequest.new(
    message: GetStream::Generated::Models::MessageRequest.new(
      text: 'Updated text',
      user_id: 'bob-1',
    ),
  ),
)
```

**Key changes:**
- Old SDK passes a flat hash with `id`, `text`, and `user_id` at the same level
- New SDK takes `message_id` as a positional argument and wraps the update in `UpdateMessageRequest` > `MessageRequest`

## Update a Message (Partial)

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.update_message_partial(
  message_id,
  { set: { text: 'Partially updated' }, unset: ['old_field'] },
  user_id: 'bob-1',
)
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.update_message_partial(
  message_id,
  GetStream::Generated::Models::UpdateMessagePartialRequest.new(
    set: { text: 'Partially updated' },
    unset: ['old_field'],
    user_id: 'bob-1',
  ),
)
```

**Key changes:**
- Old SDK passes set/unset as a nested hash with `user_id` as a keyword argument
- New SDK wraps everything in an `UpdateMessagePartialRequest` with `set`, `unset`, and `user_id` as named properties

## Delete a Message

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

# Soft delete
client.delete_message(message_id)

# Hard delete
client.hard_delete_message(message_id)
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

# Soft delete
client.chat.delete_message(message_id)

# Hard delete
client.chat.delete_message(message_id, hard: true)
```

**Key changes:**
- Old SDK has separate methods: `delete_message` (soft) and `hard_delete_message` (hard)
- New SDK uses a single `delete_message` method with an optional `hard:` parameter

## Send a Reaction

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
response = chan.send_reaction(message_id, { type: 'like' }, 'bob-1')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.chat.send_reaction(
  message_id,
  GetStream::Generated::Models::SendReactionRequest.new(
    reaction: GetStream::Generated::Models::ReactionRequest.new(
      type: 'like',
      user_id: 'bob-1',
    ),
  ),
)
```

**Key changes:**
- Old SDK calls `chan.send_reaction(message_id, reaction_hash, user_id)` on the `Channel` object
- New SDK calls `client.chat.send_reaction(message_id, request)` with a two-level nesting: `SendReactionRequest` > `ReactionRequest`
- User ID moves inside the `ReactionRequest`

## Get Reactions

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
response = chan.get_reactions(message_id, limit: 10, offset: 0)
reactions = response['reactions']
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.chat.get_reactions(message_id, limit: 10, offset: 0)
reactions = response['reactions']
```

**Key changes:**
- Old SDK calls `chan.get_reactions` on the `Channel` object
- New SDK calls `client.chat.get_reactions` directly with the same keyword arguments

## Delete a Reaction

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
response = chan.delete_reaction(message_id, 'like', 'bob-1')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.chat.delete_reaction(message_id, 'like', user_id: 'bob-1')
```

**Key changes:**
- Old SDK calls `chan.delete_reaction(message_id, type, user_id)` with all positional arguments
- New SDK calls `client.chat.delete_reaction(message_id, type, user_id:)` with `user_id` as a keyword argument

## Summary of Method Changes

| Operation | stream-chat-ruby | getstream-ruby |
|-----------|-----------------|---------------|
| Send message | `chan.send_message(hash, user_id)` | `client.chat.send_message(type, id, SendMessageRequest)` |
| Thread reply | `chan.send_message({parent_id: ...}, uid)` | `client.chat.send_message(type, id, SendMessageRequest(message: MessageRequest(parent_id:)))` |
| Get message | `client.get_message(id)` | `client.chat.get_message(id)` |
| Get many messages | `chan.get_messages(ids)` | `client.chat.get_many_messages(type, id, ids)` |
| Full update | `client.update_message(hash)` | `client.chat.update_message(id, UpdateMessageRequest)` |
| Partial update | `client.update_message_partial(id, hash)` | `client.chat.update_message_partial(id, UpdateMessagePartialRequest)` |
| Soft delete | `client.delete_message(id)` | `client.chat.delete_message(id)` |
| Hard delete | `client.hard_delete_message(id)` | `client.chat.delete_message(id, hard: true)` |
| Send reaction | `chan.send_reaction(msg_id, hash, uid)` | `client.chat.send_reaction(msg_id, SendReactionRequest)` |
| Get reactions | `chan.get_reactions(msg_id)` | `client.chat.get_reactions(msg_id)` |
| Delete reaction | `chan.delete_reaction(msg_id, type, uid)` | `client.chat.delete_reaction(msg_id, type, user_id:)` |
