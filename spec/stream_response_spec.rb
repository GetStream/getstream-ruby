# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GetStreamRuby::StreamResponse do

  describe 'dot notation access' do

    let(:response_data) do

      {
        'group_id' => 'user',
        'id' => 'test-user-123',
        'created_at' => 1_759_762_731_605_152_000,
        'updated_at' => 1_759_762_731_605_152_000,
        'activity' => {
          'id' => 'activity-123',
          'text' => 'Test activity',
          'user_id' => 'test-user-123',
        },
        'activities' => [
          {
            'id' => 'activity-1',
            'text' => 'Activity 1',
          },
          {
            'id' => 'activity-2',
            'text' => 'Activity 2',
          },
        ],
      }

    end

    let(:response) { described_class.new(response_data) }

    it 'allows dot notation access for top-level fields' do

      expect(response.group_id).to eq('user')
      expect(response.id).to eq('test-user-123')
      expect(response.created_at).to eq(1_759_762_731_605_152_000)

    end

    it 'allows dot notation access for nested objects' do

      expect(response.activity).to be_a(GetStreamRuby::StreamResponse)
      expect(response.activity.id).to eq('activity-123')
      expect(response.activity.text).to eq('Test activity')
      expect(response.activity.user_id).to eq('test-user-123')

    end

    it 'allows dot notation access for arrays with nested objects' do

      expect(response.activities).to be_an(Array)
      expect(response.activities.length).to eq(2)

      expect(response.activities[0]).to be_a(GetStreamRuby::StreamResponse)
      expect(response.activities[0].id).to eq('activity-1')
      expect(response.activities[0].text).to eq('Activity 1')

      expect(response.activities[1]).to be_a(GetStreamRuby::StreamResponse)
      expect(response.activities[1].id).to eq('activity-2')
      expect(response.activities[1].text).to eq('Activity 2')

    end

    it 'supports both string and symbol keys' do

      expect(response.group_id).to eq('user')
      expect(response.id).to eq('test-user-123')

    end

    it 'returns nil for non-existent keys' do

      expect(response.non_existent_field).to be_nil

    end

    it 'supports to_h method' do

      expect(response.to_h).to eq(response_data)

    end

    it 'supports to_json method' do

      expect(response.to_json).to eq(response_data.to_json)

    end

    it 'has proper inspect output' do

      expect(response.inspect).to include('GetStreamRuby::StreamResponse')
      expect(response.inspect).to include('@data=')

    end

  end

end
