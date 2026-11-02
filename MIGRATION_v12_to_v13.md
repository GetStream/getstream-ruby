# Migrating from v12 to v13

v13 regenerates the client from the current v2 serverside spec (FLU-1105). **HTTP JSON is unchanged.** Request and response fields stay strings. The breaks are method arguments.

Full diff: [v12.1.1...v13.0.0](https://github.com/GetStream/getstream-ruby/compare/v12.1.1...v13.0.0).

## Installation

```ruby
gem 'getstream-ruby', '~> 13.0'
```

## Methods that dropped a request argument

`stop_campaign` and `commit_message` no longer take a body. The id is the only argument. Passing the old request raises `ArgumentError`.

```ruby
# v12
client.chat.stop_campaign(id, stop_campaign_request)
client.chat.commit_message(id, commit_message_request)

# v13
client.chat.stop_campaign(id)
client.chat.commit_message(id)
```

## `get_activity` argument order

`skip_own_followings` is inserted before `user_id`. A positional `user_id` is now read as `skip_own_followings`.

```ruby
# v12
client.feeds.get_activity(id, nil, nil, user_id)

# v13
client.feeds.get_activity(id, nil, nil, nil, user_id)
```

`get_activity(id)` with no further arguments is unchanged.

These gained an optional argument at the end, so existing positional calls stay valid:

- `unread_counts(user_id = nil, include_large_channels = nil)`
- `get_poll_option(poll_id, option_id, user_id = nil)`
- `delete_collections(collection_refs, hard_delete = nil)`
- `get_comments(..., include_top_level_comment_count = nil)`

## AI video config

`AIVideoConfig` no longer has `provider`.

## Named enums

New types such as `PushLevel`, `ChannelModerationBehavior`, and `ActivityVisibility` are empty marker classes. The fields that use them are still plain strings, so existing assignments keep working. The server still accepts the same values (`"all"`, `"flag"`, `"public"`).

## When to stay on v12

Stay on **12.1.1** until you can fix the calls above. The server does not require v13.
