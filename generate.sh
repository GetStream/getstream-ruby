#!/usr/bin/env bash

DST_PATH=`pwd`
SOURCE_PATH=../chat

if [ ! -d $SOURCE_PATH ]
then
  echo "cannot find chat path on the parent folder (${SOURCE_PATH}), do you have a copy of the API source?";
  exit 1;
fi

# Check if bundle is available
if ! bundle --version &> /dev/null
then
  echo "cannot find bundle in path, did you setup this repo correctly?";
  exit 1;
fi

set -ex

# cd in API repo, generate new spec and then generate code from it
( cd $SOURCE_PATH ; make openapi ; go run ./cmd/chat-manager openapi generate-client --language ruby --spec ./releases/v2/serverside-api.yaml --output $DST_PATH )

# Fix any potential issues in generated code
echo "Applying Ruby-specific fixes..."

# Ensure generated directory exists
mkdir -p lib/getstream_ruby/generated/models

# Fix any potential issues in generated code
echo "Generated Ruby SDK for feeds in $DST_PATH"
echo ""
echo "Next steps:"
echo "1. Review generated files in lib/getstream_ruby/generated/"
echo "2. Update your client.rb to include the generated traits"
echo "3. Update your feed.rb to include the generated feed methods"
echo "4. Run tests: bundle exec rspec"
echo ""
echo "See CHAT_CONTEXT.md for detailed integration instructions."
