# Channels

This guide shows how to migrate channel operations from `stream-chat-ruby` to `getstream-ruby`.

## Create a Channel

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general', data: { members: ['bob-1', 'jane-1'] })
chan.create('bob-1')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.get_or_create_channel(
  'messaging',
  'general',
  GetStream::Generated::Models::ChannelGetOrCreateRequest.new(
    data: {
      created_by_id: 'bob-1',
      members: [{ user_id: 'bob-1' }, { user_id: 'jane-1' }],
    },
  ),
)
```

**Key changes:**
- Old SDK uses a two-step pattern: `client.channel(...)` returns a `Channel` object, then `chan.create(user_id)` sends the request
- New SDK calls `client.chat.get_or_create_channel` directly with channel type, ID, and a request body
- Members in the new SDK are hashes with `user_id` keys instead of plain string arrays

## Query Channels

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

response = client.query_channels(
  { 'type' => 'messaging', 'members' => { '$in' => ['bob-1'] } },
  sort: { 'last_message_at' => -1 },
  limit: 10,
)
channels = response['channels']
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.chat.query_channels(
  GetStream::Generated::Models::QueryChannelsRequest.new(
    filter_conditions: { type: 'messaging', members: { '$in' => ['bob-1'] } },
    sort: [{ field: 'last_message_at', direction: -1 }],
    limit: 10,
  ),
)
channels = response['channels']
```

**Key changes:**
- Old SDK uses positional filter argument with keyword args for sort/limit
- New SDK wraps everything in a `QueryChannelsRequest` with `filter_conditions`, `sort` (array of hashes), and `limit`

## Add Members

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
chan.add_members(['bob-1', 'jane-1'])
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.update_channel(
  'messaging',
  'general',
  GetStream::Generated::Models::UpdateChannelRequest.new(
    add_members: [{ user_id: 'bob-1' }, { user_id: 'jane-1' }],
  ),
)
```

**Key changes:**
- Old SDK has a dedicated `add_members` method on the `Channel` object
- New SDK uses `update_channel` with `add_members` as a parameter on `UpdateChannelRequest`

## Remove Members

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
chan.remove_members(['bob-1'])
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.update_channel(
  'messaging',
  'general',
  GetStream::Generated::Models::UpdateChannelRequest.new(
    remove_members: ['bob-1'],
  ),
)
```

**Key changes:**
- Old SDK has `remove_members` on the `Channel` object taking an array of user IDs
- New SDK passes `remove_members` as a parameter on `UpdateChannelRequest`

## Update Channel (Full)

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
chan.update({ 'name' => 'General Chat', 'description' => 'Main channel' })
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.update_channel(
  'messaging',
  'general',
  GetStream::Generated::Models::UpdateChannelRequest.new(
    data: { name: 'General Chat', description: 'Main channel' },
  ),
)
```

**Key changes:**
- Old SDK calls `chan.update(data_hash)` on the `Channel` object
- New SDK calls `client.chat.update_channel` with channel type, ID, and an `UpdateChannelRequest`

## Update Channel (Partial)

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
chan.update_partial(
  set: { color: 'blue', description: 'Updated' },
  unset: ['old_field'],
)
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.update_channel_partial(
  'messaging',
  'general',
  GetStream::Generated::Models::UpdateChannelPartialRequest.new(
    set: { color: 'blue', description: 'Updated' },
    unset: ['old_field'],
  ),
)
```

**Key changes:**
- Old SDK calls `chan.update_partial(set:, unset:)` on the `Channel` object
- New SDK calls `client.chat.update_channel_partial` with an `UpdateChannelPartialRequest`

## Delete a Channel

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
chan.delete
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.delete_channel('messaging', 'general', false)
```

**Key changes:**
- Old SDK calls `chan.delete` on the `Channel` object
- New SDK calls `client.chat.delete_channel` with channel type, ID, and an optional `hard_delete` positional parameter

## Delete Multiple Channels

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

response = client.delete_channels(
  ['messaging:general', 'messaging:random'],
  hard_delete: false,
)
task_id = response['task_id']
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.chat.delete_channels(
  GetStream::Generated::Models::DeleteChannelsRequest.new(
    cids: ['messaging:general', 'messaging:random'],
    hard_delete: false,
  ),
)
task_id = response['task_id']
```

**Key changes:**
- Both SDKs use CID format (`type:id`) for batch deletion
- New SDK wraps the parameters in a `DeleteChannelsRequest` object

## Summary of Method Changes

| Operation | stream-chat-ruby | getstream-ruby |
|-----------|-----------------|---------------|
| Create channel | `client.channel(type, channel_id:, data:).create(uid)` | `client.chat.get_or_create_channel(type, id, request)` |
| Query channels | `client.query_channels(filter, sort:, limit:)` | `client.chat.query_channels(QueryChannelsRequest)` |
| Add members | `chan.add_members(user_ids)` | `client.chat.update_channel(type, id, UpdateChannelRequest(add_members:))` |
| Remove members | `chan.remove_members(user_ids)` | `client.chat.update_channel(type, id, UpdateChannelRequest(remove_members:))` |
| Full update | `chan.update(data)` | `client.chat.update_channel(type, id, UpdateChannelRequest)` |
| Partial update | `chan.update_partial(set:, unset:)` | `client.chat.update_channel_partial(type, id, UpdateChannelPartialRequest)` |
| Delete channel | `chan.delete` | `client.chat.delete_channel(type, id, hard_delete)` |
| Delete batch | `client.delete_channels(cids)` | `client.chat.delete_channels(DeleteChannelsRequest)` |
