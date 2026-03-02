# Migration Guide: v2 → v3

This guide covers all breaking changes when upgrading from `getstream-ruby` v2 to v3.

## Overview

v3 is a full OpenAPI-aligned release. The primary change is a **systematic type renaming**: types that appear in API responses now have a `Response` suffix, and input types have a `Request` suffix. There are no removed features — all functionality from v2 is available in v3. Additionally, v3 adds complete coverage of the **Feeds**, **Video**, and **Moderation** product APIs.

## Installation

Update your `Gemfile`:

```ruby
gem 'getstream-ruby', '~> 3.0'
```

Then run:

```bash
bundle install
```

## Naming Conventions

All classes use `PascalCase` (standard Ruby convention). The general rules:

- Classes returned in API responses: `Foo` → `FooResponse`
- Classes used as API inputs: `Foo` → `FooRequest`
- Some moderation action payloads: `FooRequest` → `FooRequestPayload`

## Breaking Changes

### Common / Shared Types

| v2 | v3 | Notes |
| --- | --- | --- |
| `ApplicationConfig` | `AppResponseFields` | App configuration in responses |
| `ChannelPushPreferences` | `ChannelPushPreferencesResponse` | Per-channel push settings |
| `Device` | `DeviceResponse` | Device data (push, voip) |
| `Event` | `WSEvent` | WebSocket event envelope |
| `FeedsPreferences` | `FeedsPreferencesResponse` | Feeds push preferences |
| `ImportV2Task` | `ImportV2TaskItem` | V2 import task |
| `OwnUser` | `OwnUserResponse` | Authenticated user data |
| `Pager` | `PagerResponse` | Now cursor-based (`next`/`prev`) |
| `PushPreferences` | `PushPreferencesResponse` | Push preferences |
| `PushTemplate` | `PushTemplateResponse` | Push template |
| `PrivacySettings` | `PrivacySettingsResponse` | Typing indicators, read receipts |
| `RateLimitInfo` | `LimitInfoResponse` | Rate limit info |
| `SortParam` | `SortParamRequest` | Sort parameter for queries |
| `User` | `UserResponse` | Full user in responses |
| `UserBlock` | `BlockedUserResponse` | Blocked user details |
| `UserCustomEvent` | `CustomEvent` | Custom user event |
| `UserMute` | `UserMuteResponse` | User mute details |

### Event System

| Before (v2) | After (v3) | Notes |
| --- | --- | --- |
| `BaseEvent` (field `T`) | `Event` (field `type`) | Base event type |
| `Event` (WS envelope) | `WSEvent` | WebSocket event wrapper |
| `*Preset` embeds | `Has*` composition types | e.g., `HasChannel`, `HasMessage` |
| — | `WHEvent` | New webhook envelope type |

New composition types: `HasOwnUser`, `HasUserCommonFields`, `HasUserPrivacyFields`, `HasOptionalUserCommonFields`, `HasChannel`, `HasOptionalChannel`, `HasMessage`, `HasOptionalMessage`, `HasThreadParticipants`, `HasChannelTypeAndID`.

### Chat Types

| v2 | v3 | Notes |
| --- | --- | --- |
| `Campaign` | `CampaignResponse` | |
| `CampaignStats` | `CampaignStatsResponse` | |
| `Channel` | `ChannelResponse` | |
| `ChannelConfigFields` | `ChannelConfigWithInfo` | Channel config + commands/grants |
| `ChannelMember` | `ChannelMemberResponse` | |
| `ChannelTypeConfigWithInfo` | `ChannelTypeConfig` | |
| `ConfigOverrides` | `ConfigOverridesRequest` | |
| `DraftMessage` / `DraftMessagePayload` | `DraftResponse` | Two classes merged into one |
| `Message` | `MessageResponse` | |
| `MessageReminder` | `ReminderResponseData` | |
| `PendingMessage` | `PendingMessageResponse` | |
| `Poll` | `PollResponse` | |
| `PollOption` | `PollOptionResponse` | |
| `PollVote` | `PollVoteResponse` | |
| `Reaction` | `ReactionResponse` | |
| `ReadState` | `ReadStateResponse` | |
| `Thread` | `ThreadResponse` | |

### Video Types

| v2 | v3 | Notes |
| --- | --- | --- |
| `AudioSettings` | `AudioSettingsResponse` | |
| `BackstageSettings` | `BackstageSettingsResponse` | |
| `BroadcastSettings` | `BroadcastSettingsResponse` | |
| `Call` | `CallResponse` | |
| `CallEgress` | `EgressResponse` | |
| `CallMember` | `MemberResponse` | Note: not `CallMemberResponse` |
| `CallParticipant` | `CallParticipantResponse` | |
| `CallParticipantFeedback` | *(removed)* | Use `CollectUserFeedbackRequest` |
| `CallSession` | `CallSessionResponse` | |
| `CallSettings` | `CallSettingsResponse` | |
| `CallType` | `CallTypeResponse` | |
| `EventNotificationSettings` | `EventNotificationSettingsResponse` | |
| `FrameRecordSettings` | `FrameRecordingSettingsResponse` | `Recording` inserted in name |
| `GeofenceSettings` | `GeofenceSettingsResponse` | |
| `HLSSettings` | `HLSSettingsResponse` | |
| `IndividualRecordSettings` | `IndividualRecordingSettingsResponse` | `Recording` inserted in name |
| `IngressSettings` | `IngressSettingsResponse` | |
| `IngressSource` | `IngressSourceResponse` | |
| `IngressAudioEncodingOptions` | `IngressAudioEncodingResponse` | Shortened name |
| `IngressVideoEncodingOptions` | `IngressVideoEncodingResponse` | Shortened name |
| `IngressVideoLayer` | `IngressVideoLayerResponse` | |
| `LimitsSettings` | `LimitsSettingsResponse` | |
| `NotificationSettings` | `NotificationSettingsResponse` | |
| `RawRecordSettings` | `RawRecordingSettingsResponse` | `Recording` inserted in name |
| `RecordSettings` | `RecordSettingsResponse` | |
| `RingSettings` | `RingSettingsResponse` | |
| `RTMPSettings` | `RTMPSettingsResponse` | |
| `ScreensharingSettings` | `ScreensharingSettingsResponse` | |
| `SessionSettings` | `SessionSettingsResponse` | |
| `SIPCallConfigs` | `SIPCallConfigsResponse` | |
| `SIPCallerConfigs` | `SIPCallerConfigsResponse` | |
| `SIPDirectRoutingRuleCallConfigs` | `SIPDirectRoutingRuleCallConfigsResponse` | |
| `SIPInboundRoutingRules` | `SIPInboundRoutingRuleResponse` | Plural → singular |
| `SIPPinProtectionConfigs` | `SIPPinProtectionConfigsResponse` | |
| `SIPTrunk` | `SIPTrunkResponse` | |
| `ThumbnailsSettings` | `ThumbnailsSettingsResponse` | |
| `TranscriptionSettings` | `TranscriptionSettingsResponse` | |
| `VideoSettings` | `VideoSettingsResponse` | |

### Moderation Types

| v2 | v3 | Notes |
| --- | --- | --- |
| `ActionLog` | `ActionLogResponse` | |
| `Appeal` | `AppealItemResponse` | |
| `AutomodDetails` | `AutomodDetailsResponse` | |
| `Ban` | `BanInfoResponse` | |
| `BanOptions` | *(removed)* | Merged into `BanActionRequestPayload` |
| `BanActionRequest` | `BanActionRequestPayload` | |
| `BlockActionRequest` | `BlockActionRequestPayload` | |
| `BlockedMessage` | *(removed)* | Internal only |
| `CustomActionRequest` | `CustomActionRequestPayload` | |
| `DeleteMessageRequest` | `DeleteMessageRequestPayload` | |
| `DeleteUserRequest` | `DeleteUserRequestPayload` | |
| `EntityCreator` | `EntityCreatorResponse` | |
| `Evaluation` | `EvaluationResponse` | |
| `FeedsModerationTemplate` | `QueryFeedModerationTemplate` | No `Response` suffix |
| `FeedsModerationTemplateConfig` | `FeedsModerationTemplateConfigPayload` | |
| `Flag` | *(removed)* | Use `ModerationFlagResponse` |
| `Flag2` | `ModerationFlagResponse` | |
| `FlagDetails` | `FlagDetailsResponse` | |
| `FlagFeedback` | `FlagFeedbackResponse` | |
| `FlagMessageDetails` | `FlagMessageDetailsResponse` | |
| `FlagReport` | *(removed)* | Internal only |
| `FutureChannelBan` | `FutureChannelBanResponse` | |
| `MarkReviewedRequest` | `MarkReviewedRequestPayload` | |
| `Match` | `MatchResponse` | |
| `ModerationActionConfig` | `ModerationActionConfigResponse` | |
| `ModerationBulkSubmitActionRequest` | `BulkSubmitActionRequest` | `Moderation` prefix dropped |
| `ModerationConfig` | `ConfigResponse` | |
| `ModerationFlags` | *(removed)* | Use array of `ModerationFlagResponse` |
| `ModerationLog` | *(removed)* | Use `ActionLogResponse` |
| `ModerationLogResponse` | *(removed)* | Use `QueryModerationLogsResponse` |
| `ModerationUsageStats` | `ModerationUsageStatsResponse` | |
| `RestoreActionRequest` | `RestoreActionRequestPayload` | |
| `ReviewQueueItem` | `ReviewQueueItemResponse` | |
| `Rule` | `RuleResponse` | |
| `ShadowBlockActionRequest` | `ShadowBlockActionRequestPayload` | |
| `Task` | `TaskResponse` | |
| `Trigger` | `TriggerResponse` | |
| `UnbanActionRequest` | `UnbanActionRequestPayload` | |
| `UnblockActionRequest` | `UnblockActionRequestPayload` | |
| `VideoEndCallRequest` | `VideoEndCallRequestPayload` | |
| `VideoKickUserRequest` | `VideoKickUserRequestPayload` | |

### Feeds Types

| v2 | v3 | Notes |
| --- | --- | --- |
| `Activity` | `ActivityResponse` | |
| `ActivityFeedback` | `ActivityFeedbackRequest` | Request-only (no `Response` suffix) |
| `ActivityMark` | `MarkActivityRequest` | |
| `ActivityPin` | `ActivityPinResponse` | |
| `AggregatedActivity` | `AggregatedActivityResponse` | |
| `Bookmark` | `BookmarkResponse` | |
| `BookmarkFolder` | `BookmarkFolderResponse` | |
| `Collection` | `CollectionResponse` | |
| `Comment` | `CommentResponse` | |
| `CommentMedia` | *(removed)* | Embedded inline in `CommentResponse` |
| `CommentMention` | *(removed)* | Embedded inline in `CommentResponse` |
| `DenormalizedFeedsReaction` | *(removed)* | Internal only |
| `Feed` | `FeedResponse` | |
| `FeedGroup` | `FeedGroupResponse` | |
| `FeedMember` | `FeedMemberResponse` | |
| `FeedsReaction` | `FeedsReactionResponse` | |
| `FeedsReactionGroup` | `FeedsReactionGroupResponse` | |
| `FeedSuggestion` | `FeedSuggestionResponse` | |
| `FeedView` | `FeedViewResponse` | |
| `FeedVisibilityInfo` | `FeedVisibilityResponse` | |
| `Follow` | `FollowResponse` | |
| `MembershipLevel` | `MembershipLevelResponse` | |
| `ThreadedComment` | `ThreadedCommentResponse` | |

## Getting Help

- [Stream documentation](https://getstream.io/docs/)
- [GitHub Issues](https://github.com/GetStream/getstream-ruby/issues)
- [Stream support](https://getstream.io/contact/support/)
