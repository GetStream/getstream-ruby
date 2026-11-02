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

The spec now names these values instead of leaving them as anonymous strings. **Keep assigning and comparing strings.** Ruby has no constants for them, and the generated classes are empty markers. YARD `@return` changed from `String` to the marker (`PushLevel`, `ActivityVisibility`, …). The value you get back is still `"all"` or `"public"`.

```ruby
# v12 and v13 — same code
request.push_level = 'all'
request.automod_behavior = 'flag'
request.visibility = 'public'

if channel.push_level == 'none'
end
```

`ChannelOwnCapability`, `FeedOwnCapability`, and `OwnCapability` stay empty subclasses of `BaseModel`. Capability lists are still arrays of strings (`"send-message"`, `"join-call"`).

On `CampaignResponse`, `sender_mode` and `sender_visibility` are documented as `CampaignSenderMode` and `CampaignSenderVisibility`. A campaign that omits those keys still loads them as `nil`, not `""`.

### New marker types

`ActivitySelectorType`, `ActivityVisibility`, `AudioDefaultDevice`, `AutomodMode`, `BlocklistBehavior`, `CallLifecycleMode`, `CameraFacing`, `CampaignSenderMode`, `CampaignSenderVisibility`, `ChannelModerationBehavior`, `ChannelOwnCapability`, `CollectionStatus`, `CommentStatus`, `DeleteMessages`, `FeatureActivationMode`, `FeedMemberStatus`, `FeedOwnCapability`, `FeedVisibility`, `FollowPushPreference`, `FollowStatus`, `FriendReactionType`, `LayoutName`, `ModerationAction`, `OwnCapability`, `PushLevel`, `PushProviderName`, `RecordingType`, `RestrictReplies`, `RetentionPolicyType`, `ScheduledMessageFailureReason`, `ScheduledMessageQueryStatus`, `ScheduledMessageStatus`, `SetupStatus`, `SetupStep`, `SortParamType`, `TranscriptionLanguage`, `VideoCodec`, `VotingVisibility`.

| Field | v12 YARD | v13 YARD | Runtime value |
|---|---|---|---|
| `push_level` | `String` | `PushLevel` | `"all"`, `"none"`, … |
| `automod_behavior` | `String` | `ChannelModerationBehavior` | `"flag"`, `"block"`, `"shadow_block"` |
| `blocklist_behavior` | `String` | `BlocklistBehavior` | `"flag"`, `"block"` |
| feeds `visibility` | `String` | `FeedVisibility` or `ActivityVisibility` | `"public"`, `"private"`, … |
| `voting_visibility` | `String` | `VotingVisibility` | `"public"`, `"anonymous"` |
| push provider name | `String` | `PushProviderName` | `"firebase"`, `"apn"`, `"huawei"`, `"xiaomi"` |
| `sender_mode`, `sender_visibility` | `String` | `CampaignSenderMode`, `CampaignSenderVisibility` | `"exclude"` / `"include"`, `"hidden"` / `"archived"`, or `nil` |

## When to stay on v12

Stay on **12.1.1** until you can fix the calls above. The server does not require v13.
