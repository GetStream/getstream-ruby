# Devices

This guide shows how to migrate push device management from `stream-chat-ruby` to `getstream-ruby`.

## Add a Device (APNs)

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.add_device(
  'apns-device-token',
  'apn',
  'jane-1',
  'my-apn-provider',
)
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.common.create_device(
  GetStream::Generated::Models::CreateDeviceRequest.new(
    id: 'apns-device-token',
    push_provider: 'apn',
    push_provider_name: 'my-apn-provider',
    user_id: 'jane-1',
  ),
)
```

**Key changes:**
- Old SDK uses `add_device(id, provider, user_id, provider_name)` with positional arguments
- New SDK uses `client.common.create_device(CreateDeviceRequest)` with named properties

## Add a Device (Firebase)

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.add_device(
  'fcm-device-token',
  'firebase',
  'bob-1',
  'my-firebase-provider',
)
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.common.create_device(
  GetStream::Generated::Models::CreateDeviceRequest.new(
    id: 'fcm-device-token',
    push_provider: 'firebase',
    push_provider_name: 'my-firebase-provider',
    user_id: 'bob-1',
  ),
)
```

## Add a VoIP Device

The new SDK adds explicit support for Apple VoIP push tokens.

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.common.create_device(
  GetStream::Generated::Models::CreateDeviceRequest.new(
    id: 'voip-device-token',
    push_provider: 'apn',
    push_provider_name: 'my-apn-provider',
    user_id: 'jane-1',
    voip_token: true,
  ),
)
```

**Key changes:**
- Old SDK has no dedicated VoIP token support
- New SDK adds `voip_token: true` on `CreateDeviceRequest`

## List Devices

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

response = client.get_devices('jane-1')
devices = response['devices']
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

response = client.common.list_devices(user_id: 'jane-1')
devices = response['devices']
```

**Key changes:**
- Old SDK uses `get_devices(user_id)` with a positional argument
- New SDK uses `list_devices(user_id:)` with a keyword argument

## Delete a Device

**Before (stream-chat-ruby):**

```ruby
require 'stream-chat'

client = StreamChat::Client.new('STREAM_KEY', 'STREAM_SECRET')

client.remove_device('apns-device-token', 'jane-1')
```

**After (getstream-ruby):**

```ruby
require 'getstream_ruby'

client = GetStreamRuby.manual(api_key: 'STREAM_KEY', api_secret: 'STREAM_SECRET')

client.common.delete_device('apns-device-token', user_id: 'jane-1')
```

**Key changes:**
- Old SDK uses `remove_device(id, user_id)` with positional arguments
- New SDK uses `delete_device(id, user_id:)` with `user_id` as a keyword argument

## Summary of Method Changes

| Operation | stream-chat-ruby | getstream-ruby |
|-----------|-----------------|---------------|
| Add device | `client.add_device(id, provider, uid, name)` | `client.common.create_device(CreateDeviceRequest)` |
| List devices | `client.get_devices(uid)` | `client.common.list_devices(user_id:)` |
| Delete device | `client.remove_device(id, uid)` | `client.common.delete_device(id, user_id:)` |
