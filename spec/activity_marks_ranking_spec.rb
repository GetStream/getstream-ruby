# frozen_string_literal: true

require 'json'
require 'spec_helper'

RSpec.describe 'activity_marks ranking is_seen' do

  it 'serializes CreateFeedGroupRequest with activity_marks and an is_seen ranking score' do
    request = GetStream::Generated::Models::CreateFeedGroupRequest.new(
      id: 'timeline',
      activity_marks: GetStream::Generated::Models::ActivityMarksConfig.new(
        track_seen: true,
        track_read: true,
      ),
      ranking: GetStream::Generated::Models::RankingConfig.new(
        type: 'expression',
        score: 'is_seen ? 0 : 100',
      ),
    )

    payload = JSON.parse(request.to_json)

    expect(payload['activity_marks']).to include('track_seen' => true, 'track_read' => true)
    expect(payload['ranking']).to include('type' => 'expression', 'score' => 'is_seen ? 0 : 100')
  end
end
