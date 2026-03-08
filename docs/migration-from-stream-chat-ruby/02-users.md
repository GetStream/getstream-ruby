# Users

This guide shows how to migrate user operations from `stream-chat-ruby` to `getstream-ruby`.

## Upsert a Single User

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.upsert_user({
  id: 'bob-1',
  role: 'admin',
  name: 'Robert Tables',
})
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.common.update_users(
  GetStream::Generated::Models::UpdateUsersRequest.new(
    users: {
      'bob-1' => GetStream::Generated::Models::UserRequest.new(
        id: 'bob-1',
        role: 'admin',
        name: 'Robert Tables',
      ),
    },
  ),
)
```

**Key changes:**
- Old SDK uses `upsert_user(hash)` directly on the client
- New SDK uses `client.common.update_users` with an `UpdateUsersRequest` wrapping a hash of `UserRequest` objects keyed by user ID

## Batch Upsert Users

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.upsert_users([
  { id: 'jane-1', name: 'Jane' },
  { id: 'june-1', name: 'June' },
])
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.common.update_users(
  GetStream::Generated::Models::UpdateUsersRequest.new(
    users: {
      'jane-1' => GetStream::Generated::Models::UserRequest.new(id: 'jane-1', name: 'Jane'),
      'june-1' => GetStream::Generated::Models::UserRequest.new(id: 'june-1', name: 'June'),
    },
  ),
)
```

**Key changes:**
- Old SDK accepts an array of hashes; new SDK uses a hash map keyed by user ID
- Both single and batch upserts use the same `update_users` method in the new SDK

## Query Users

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

response = client.query_users(
  { 'name' => { '$autocomplete' => 'rob' } },
  sort: { 'created_at' => -1 },
  limit: 10,
  offset: 0,
)
users = response['users']
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'
require 'json'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.common.query_users(JSON.generate({
  filter_conditions: { name: { '$autocomplete' => 'rob' } },
  sort: [{ field: 'created_at', direction: -1 }],
  limit: 10,
  offset: 0,
}))
users = response['users']
```

**Key changes:**
- Old SDK passes filter as a positional argument with separate keyword args for sort/limit/offset
- New SDK passes a single JSON-encoded body with `filter_conditions`, `sort` (array of `{ field, direction }` objects), `limit`, and `offset`

## Partial Update User

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.update_user_partial({
  id: 'bob-1',
  set: { role: 'admin', nickname: 'Bobby' },
  unset: ['obsolete_field'],
})
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.common.update_users_partial(
  GetStream::Generated::Models::UpdateUsersPartialRequest.new(
    users: [
      GetStream::Generated::Models::UpdateUserPartialRequest.new(
        id: 'bob-1',
        set: { role: 'admin', nickname: 'Bobby' },
        unset: ['obsolete_field'],
      ),
    ],
  ),
)
```

**Key changes:**
- Old SDK has a singular `update_user_partial` that takes one user hash
- New SDK uses `update_users_partial` (always plural) wrapping an array of `UpdateUserPartialRequest` objects

## Deactivate User

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

# Deactivate single user
client.deactivate_user('bob-1')

# Reactivate
client.reactivate_user('bob-1')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

# Deactivate single user
client.common.deactivate_user(
  'bob-1',
  GetStream::Generated::Models::DeactivateUserRequest.new,
)

# Reactivate
client.common.reactivate_user(
  'bob-1',
  GetStream::Generated::Models::ReactivateUserRequest.new,
)
```

**Key changes:**
- Old SDK passes only the user ID; new SDK requires a request object as the second argument (even if empty)
- Method names are the same: `deactivate_user` and `reactivate_user`

## Delete Users

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

# Soft delete single user
client.delete_user('bob-1')

# Hard delete with messages (async, returns task_id)
response = client.delete_users(
  ['bob-1', 'jane-1'],
  user: StreamChat::HARD_DELETE,
  messages: StreamChat::HARD_DELETE,
)
task_id = response['task_id']
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

# Delete users (always async, returns task_id)
response = client.common.delete_users(
  GetStream::Generated::Models::DeleteUsersRequest.new(
    user_ids: ['bob-1', 'jane-1'],
  ),
)
task_id = response['task_id']
```

**Key changes:**
- Old SDK has both `delete_user` (sync, single) and `delete_users` (async, batch)
- New SDK only has `delete_users` (always async) with a `DeleteUsersRequest` body

## Summary of Method Changes

| Operation | stream-chat-ruby | getstream-ruby |
|-----------|-----------------|---------------|
| Upsert user(s) | `client.upsert_user(hash)` / `client.upsert_users(array)` | `client.common.update_users(UpdateUsersRequest)` |
| Query users | `client.query_users(filter, sort:, limit:)` | `client.common.query_users(json_string)` |
| Partial update | `client.update_user_partial(hash)` | `client.common.update_users_partial(UpdateUsersPartialRequest)` |
| Deactivate | `client.deactivate_user(id)` | `client.common.deactivate_user(id, DeactivateUserRequest)` |
| Reactivate | `client.reactivate_user(id)` | `client.common.reactivate_user(id, ReactivateUserRequest)` |
| Delete | `client.delete_user(id)` / `client.delete_users(ids)` | `client.common.delete_users(DeleteUsersRequest)` |
