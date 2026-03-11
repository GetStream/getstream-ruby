# Moderation

This guide shows how to migrate moderation operations from `stream-chat-ruby` to `getstream-ruby`.

## Add Moderators

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
chan.add_moderators(['jane-1'])
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.update_channel(
  'messaging',
  'general',
  GetStream::Generated::Models::UpdateChannelRequest.new(
    add_moderators: ['jane-1'],
  ),
)
```

**Key changes:**
- Old SDK has a dedicated `add_moderators` method on the `Channel` object
- New SDK uses `update_channel` with `add_moderators` as a parameter on `UpdateChannelRequest`

## Demote Moderators

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
chan.demote_moderators(['jane-1'])
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.chat.update_channel(
  'messaging',
  'general',
  GetStream::Generated::Models::UpdateChannelRequest.new(
    demote_moderators: ['jane-1'],
  ),
)
```

**Key changes:**
- Old SDK has `demote_moderators` on the `Channel` object
- New SDK passes `demote_moderators` as a parameter on `UpdateChannelRequest`

## Ban User (Channel Level)

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

chan = client.channel('messaging', channel_id: 'general')
chan.ban_user('bob-1', timeout: 3600, reason: 'spam')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.moderation.ban(
  GetStream::Generated::Models::BanRequest.new(
    target_user_id: 'bob-1',
    banned_by_id: 'admin-1',
    channel_cid: 'messaging:general',
    timeout: 3600,
    reason: 'spam',
  ),
)
```

**Key changes:**
- Old SDK calls `chan.ban_user(user_id, **options)` on the `Channel` object
- New SDK calls `client.moderation.ban(BanRequest)` with `channel_cid` in `type:id` format for channel-level bans
- New SDK requires `banned_by_id` (the moderator performing the ban)

## Ban User (App Level)

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.ban_user('bob-1', user_id: 'admin-1', reason: 'policy violation')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.moderation.ban(
  GetStream::Generated::Models::BanRequest.new(
    target_user_id: 'bob-1',
    banned_by_id: 'admin-1',
    reason: 'policy violation',
  ),
)
```

**Key changes:**
- Omit `channel_cid` from the `BanRequest` for an app-level ban
- Old SDK passes the moderator ID as `user_id:`; new SDK uses `banned_by_id`

## Unban User

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

# Channel-level unban
chan = client.channel('messaging', channel_id: 'general')
chan.unban_user('bob-1')

# App-level unban
client.unban_user('bob-1')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

# Channel-level unban
client.moderation.unban(
  GetStream::Generated::Models::UnbanRequest.new,
  'bob-1',                  # target_user_id
  'messaging:general',      # channel_cid
  'admin-1',                # created_by
)

# App-level unban (omit channel_cid)
client.moderation.unban(
  GetStream::Generated::Models::UnbanRequest.new,
  'bob-1',
  nil,
  'admin-1',
)
```

**Key changes:**
- Old SDK has `chan.unban_user` (channel) and `client.unban_user` (app)
- New SDK uses a single `client.moderation.unban` with positional arguments for target, channel CID, and moderator

## Shadow Ban

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

# Shadow ban
client.shadow_ban('bob-1', user_id: 'admin-1')

# Remove shadow ban
client.remove_shadow_ban('bob-1', user_id: 'admin-1')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

# Shadow ban (use ban with shadow: true)
client.moderation.ban(
  GetStream::Generated::Models::BanRequest.new(
    target_user_id: 'bob-1',
    banned_by_id: 'admin-1',
    shadow: true,
  ),
)

# Remove shadow ban (same as regular unban)
client.moderation.unban(
  GetStream::Generated::Models::UnbanRequest.new,
  'bob-1',
  nil,
  'admin-1',
)
```

**Key changes:**
- Old SDK has dedicated `shadow_ban` and `remove_shadow_ban` methods
- New SDK uses `ban` with `shadow: true` and regular `unban` to remove

## Mute User

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.mute_user('bob-1', 'admin-1')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.moderation.mute(
  GetStream::Generated::Models::MuteRequest.new(
    target_ids: ['bob-1'],
    user_id: 'admin-1',
    timeout: 60, # optional, in minutes
  ),
)
```

**Key changes:**
- Old SDK uses `mute_user(target_id, user_id)` with positional string arguments
- New SDK uses `MuteRequest` with `target_ids` (array, allowing batch muting) and optional `timeout` in minutes

## Unmute User

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.unmute_user('bob-1', 'admin-1')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.moderation.unmute(
  GetStream::Generated::Models::UnmuteRequest.new(
    target_ids: ['bob-1'],
    user_id: 'admin-1',
  ),
)
```

**Key changes:**
- Old SDK uses `unmute_user(target_id, user_id)` with positional string arguments
- New SDK uses `UnmuteRequest` with `target_ids` (array)

## Query Banned Users

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

response = client.query_banned_users(
  filter_conditions: { 'channel_cid' => 'messaging:general' },
  sort: { 'created_at' => -1 },
  limit: 10,
)
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'
require 'json'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.chat.query_banned_users(JSON.generate({
  filter_conditions: { channel_cid: 'messaging:general' },
  sort: [{ field: 'created_at', direction: -1 }],
  limit: 10,
}))
```

**Key changes:**
- Old SDK uses keyword arguments on `client.query_banned_users`
- New SDK uses `client.chat.query_banned_users` with a JSON-encoded body
- Sort format changes from a simple hash to an array of `{ field, direction }` objects

## Summary of Method Changes

| Operation | stream-chat-ruby | getstream-ruby |
|-----------|-----------------|---------------|
| Add moderators | `chan.add_moderators(ids)` | `client.chat.update_channel(type, id, UpdateChannelRequest(add_moderators:))` |
| Demote moderators | `chan.demote_moderators(ids)` | `client.chat.update_channel(type, id, UpdateChannelRequest(demote_moderators:))` |
| Ban (channel) | `chan.ban_user(uid, ...)` | `client.moderation.ban(BanRequest(channel_cid:))` |
| Ban (app) | `client.ban_user(uid, ...)` | `client.moderation.ban(BanRequest)` |
| Unban | `chan.unban_user(uid)` / `client.unban_user(uid)` | `client.moderation.unban(UnbanRequest, uid, cid, by)` |
| Shadow ban | `client.shadow_ban(uid, ...)` | `client.moderation.ban(BanRequest(shadow: true))` |
| Mute | `client.mute_user(target, uid)` | `client.moderation.mute(MuteRequest)` |
| Unmute | `client.unmute_user(target, uid)` | `client.moderation.unmute(UnmuteRequest)` |
| Query banned | `client.query_banned_users(...)` | `client.chat.query_banned_users(json_string)` |
