# getstream-ruby

Official Ruby server SDK (`getstream-ruby` gem) for Stream Chat, Video, Feeds, and Moderation.

- Default branch: `master` (CI also accepts `main`)
- Gem: `getstream-ruby` (`getstream-ruby.gemspec`)
- Ruby require: `getstream_ruby`
- Version constant: `GetStreamRuby::VERSION` in `lib/getstream_ruby/version.rb` (CI tags may be ahead of this file on `master`; bump is computed from git tags)
- Required Ruby: `>= 2.6.0`; `.ruby-version` is `3.3.0`; CI uses `3.1.0`
- Clone sibling of the chat monorepo as `../chat` (required for OpenAPI regen)

## Layout

Generated: `lib/getstream_ruby/generated/` (`chat_client.rb`, `common_client.rb`, `feeds_client.rb`, `feed.rb`, `models/`, …). `generate.sh` deletes `lib/getstream_ruby/generated/models/apns.rb` (hyphenated JSON keys).

Handwritten: `lib/getstream_ruby.rb`, `lib/getstream_ruby/client.rb`, `configuration.rb`, `errors.rb`, `error_mapping.rb`, `version.rb`, `extensions/`.

- Unit tests: `spec/*_spec.rb` (exclude `spec/integration/`)
- Integration: `spec/integration/`
- Webhook fixtures: `test/fixtures/webhooks/`

Env template on the default branch is `env.example` (README/`make setup` also mention `.env.example`). Copy to `.env`.

## Local commands

```bash
cp env.example .env
make install           # bundle install
make test              # unit only
make test-unit
make test-integration
make test-integration-chat
make test-integration-feed
make test-integration-video
make test-integration-gcp-lb
make test-all
make lint
make format            # rubocop -A
make format-check
make security          # bundler-audit
make generate          # not a Makefile target; run ./generate.sh
bundle exec rspec spec/integration/feed_integration_spec.rb
```

`make test` is unit-only. Integration needs `STREAM_API_KEY`, `STREAM_API_SECRET`, `STREAM_BASE_URL`. Video CI uses `STREAM_VIDEO_*`. GCP keep-alive uses `STREAM_GCP_*` with fallback to the chat key/secret.

## OpenAPI regen

`./generate.sh`:

1. `make openapi` in `../chat`, then `./build/chat-manager openapi generate-client --language ruby --spec ./releases/v2/serverside-api.yaml --output <this repo>`.
2. Webhook fixtures into `test/fixtures/webhooks`.
3. Removes invalid `apns.rb`.

Uses chat’s local spec. Generator is internal. After regen, review generated traits/clients; do not hand-edit generated models.

Additive regen = **minor**. Title the PR `feat: …` so merge publishes a minor, not a major. Do not use `feat!:` unless the Ruby API actually breaks.

## CI

`.github/workflows/ci.yml` (`CI`): push/PR to `master`/`main`.

Jobs: `Unit Tests & Code Quality`; `Chat Integration Tests`; `Feed Integration Tests`; `Video Integration Tests`; `GCP load balancer keep-alive`. Integration jobs use environment `ci`.

`.github/workflows/release.yml` (`Release`): merged PR to `main`/`master`, or `workflow_dispatch`.

Vars: `STREAM_API_KEY`, `STREAM_BASE_URL`, `STREAM_VIDEO_API_KEY`, `STREAM_VIDEO_BASE_URL`, `STREAM_GCP_API_KEY`, `STREAM_GCP_BASE_URL`.
Secrets: `STREAM_API_SECRET`, `STREAM_VIDEO_API_SECRET`, `STREAM_GCP_API_SECRET`, `RUBYGEMS_API_KEY`.

Known flakes: live Chat API 503 if the CI app is on a bad shard.

README’s “create a tag to release” / pre-release-via-GitHub-draft notes are stale; the live path is `release.yml` below.

## Release

Tags: `vX.Y.Z`. Publishes to RubyGems (`gem push`), then GitHub Release.

- Merge a PR whose title starts with `feat:` (minor), `fix:`/`bug:` (patch), or `feat!:` / `<type>(scope)!:` (major). Other prefixes (`docs:`, `chore:`, `test:`) do **not** release.
- Fallback: Actions → **Release** → `version_bump` patch/minor/major. `use_current_version=true` publishes `lib/getstream_ruby/version.rb` as-is.
- Version is computed from the latest semver git tag (`scripts/release/bump_version.rb`). The bump commit is local for tagging only and is **not** pushed to protected `master`.
- Release job runs format-check, lint, security, unit, chat/feed/video integration, then `gem build` + `gem push` with `GEM_HOST_API_KEY` = `RUBYGEMS_API_KEY`.

## PR conventions

Conventional titles drive the bump. Example regen: `feat: regenerate from OpenAPI`.
