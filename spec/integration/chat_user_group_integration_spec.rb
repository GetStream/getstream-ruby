# frozen_string_literal: true

require 'rspec'
require 'securerandom'
require 'json'
require_relative 'chat_test_helpers'

RSpec.describe 'Chat User Group Integration', type: :integration do

  include ChatTestHelpers

  before(:all) do

    init_chat_client
    @created_group_ids = []

  end

  after(:all) do

    @created_group_ids&.each do |gid|

      @client.common.delete_user_group(gid)
    rescue StandardError => e
      puts "Warning: Failed to delete user group #{gid}: #{e.message}"

    end

    cleanup_chat_resources

  end

  # ---------------------------------------------------------------------------
  # Helper: create a group and track it for cleanup
  # ---------------------------------------------------------------------------

  def create_group(id:, name:, description: nil, member_ids: nil)
    req = GetStream::Generated::Models::CreateUserGroupRequest.new(
      id: id,
      name: name,
      description: description,
      member_ids: member_ids,
    )
    resp = @client.common.create_user_group(req)
    @created_group_ids << id
    resp
  rescue GetStreamRuby::APIError => e
    skip 'User groups feature not available for this app' if e.message.include?('Not Found')
    raise
  end

  def delete_group(id)
    @client.common.delete_user_group(id)
    @created_group_ids.delete(id)
  rescue StandardError
    @created_group_ids.delete(id)
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe 'CreateAndGetUserGroup' do

    it 'creates a group with name and description, then retrieves it by ID' do

      group_id = "test-group-#{SecureRandom.uuid}"
      group_name = "Test Group #{group_id[0..14]}"
      description = 'A test user group'

      create_resp = create_group(id: group_id, name: group_name, description: description)
      expect(create_resp.user_group).not_to be_nil
      expect(create_resp.user_group.id).to eq(group_id)
      expect(create_resp.user_group.name).to eq(group_name)
      expect(create_resp.user_group.description).to eq(description)

      get_resp = @client.common.get_user_group(group_id)
      expect(get_resp.user_group).not_to be_nil
      expect(get_resp.user_group.id).to eq(group_id)
      expect(get_resp.user_group.name).to eq(group_name)

    end

  end

  describe 'CreateUserGroupWithInitialMembers' do

    it 'creates a group with initial member IDs and verifies members are present' do

      user_ids, _resp = create_test_users(2)
      group_id = "test-group-#{SecureRandom.uuid}"

      create_resp = create_group(id: group_id, name: "Group With Members #{group_id}", member_ids: user_ids)
      expect(create_resp.user_group).not_to be_nil
      expect(create_resp.user_group.id).to eq(group_id)

      get_resp = @client.common.get_user_group(group_id)
      expect(get_resp.user_group).not_to be_nil

      members = get_resp.user_group.members || []
      found_ids = members.map { |m| m.is_a?(Hash) ? m['user_id'] : m.user_id }
      user_ids.each do |uid|

        expect(found_ids).to include(uid)

      end

    end

  end

  describe 'UpdateUserGroup' do

    it 'updates the group name and description, then confirms via GET' do

      group_id = "test-group-#{SecureRandom.uuid}"
      create_group(id: group_id, name: "Original Name #{group_id}")

      new_name = "Updated Name #{group_id}"
      new_desc = 'Updated description'
      update_resp = @client.common.update_user_group(
        group_id,
        GetStream::Generated::Models::UpdateUserGroupRequest.new(
          name: new_name,
          description: new_desc,
        ),
      )
      expect(update_resp.user_group).not_to be_nil
      expect(update_resp.user_group.name).to eq(new_name)
      expect(update_resp.user_group.description).to eq(new_desc)

      get_resp = @client.common.get_user_group(group_id)
      expect(get_resp.user_group).not_to be_nil
      expect(get_resp.user_group.name).to eq(new_name)

    end

  end

  describe 'ListUserGroups' do

    it 'lists groups and at least one created group appears' do

      group_id_a = "test-group-#{SecureRandom.uuid}"
      group_id_b = "test-group-#{SecureRandom.uuid}"
      create_group(id: group_id_a, name: "List Test Group One #{group_id_a}")
      create_group(id: group_id_b, name: "List Test Group Two #{group_id_b}")

      list_resp = @client.common.list_user_groups
      expect(list_resp.user_groups).not_to be_nil
      expect(list_resp.user_groups).not_to be_empty

      found_ids = list_resp.user_groups.map { |g| g.is_a?(Hash) ? g['id'] : g.id }
      expect(found_ids).to include(group_id_a).or include(group_id_b)

    end

  end

  describe 'ListUserGroupsWithLimit' do

    it 'respects the limit parameter' do

      group_ids = Array.new(3) { "test-group-#{SecureRandom.uuid}" }
      group_ids.each_with_index do |gid, _i|

        create_group(id: gid, name: "Limit Test Group #{gid}")

      end

      limit = 2
      list_resp = @client.common.list_user_groups(limit)
      expect(list_resp.user_groups).not_to be_nil
      expect(list_resp.user_groups.length).to be <= limit

    end

  end

  describe 'SearchUserGroups' do

    it 'finds a group by name prefix search' do

      unique_prefix = "SearchTest-#{SecureRandom.hex(4)}"
      group_id = "test-group-#{SecureRandom.uuid}"
      create_group(id: group_id, name: "#{unique_prefix} Group")

      search_resp = @client.common.search_user_groups(unique_prefix)
      expect(search_resp.user_groups).not_to be_nil

      found = search_resp.user_groups.any? do |g|

        name = g.is_a?(Hash) ? g['name'] : g.name
        name.to_s.start_with?(unique_prefix)

      end
      expect(found).to be true

    end

  end

  describe 'AddUserGroupMembers' do

    it 'adds members to an existing group and verifies all are present' do

      user_ids, _resp = create_test_users(3)
      group_id = "test-group-#{SecureRandom.uuid}"

      # Create with first member only
      create_group(id: group_id, name: "Member Management Group #{group_id}", member_ids: user_ids[0, 1])

      # Add remaining members
      add_resp = @client.common.add_user_group_members(
        group_id,
        GetStream::Generated::Models::AddUserGroupMembersRequest.new(
          member_ids: user_ids[1..],
        ),
      )
      expect(add_resp.user_group).not_to be_nil

      # Verify all members are present
      get_resp = @client.common.get_user_group(group_id)
      expect(get_resp.user_group).not_to be_nil

      members = get_resp.user_group.members || []
      found_ids = members.map { |m| m.is_a?(Hash) ? m['user_id'] : m.user_id }
      user_ids.each do |uid|

        expect(found_ids).to include(uid)

      end

    end

  end

  describe 'RemoveUserGroupMembers' do

    # TODO(yun): unskip once backend is redeployed with POST /members/delete route
    it 'removes all members from a group and verifies it is empty' do

      skip 'Skipped: backend needs redeployment for new POST /members/delete endpoint'

      user_ids, _resp = create_test_users(2)
      group_id = "test-group-#{SecureRandom.uuid}"

      # Create group with members
      create_group(id: group_id, name: "Remove Members Group #{group_id}", member_ids: user_ids)

      # Verify members are present before removal
      get_resp = @client.common.get_user_group(group_id)
      expect(get_resp.user_group.members.length).to eq(user_ids.length)

      # Remove all members explicitly by ID (backend requires member_ids)
      @client.common.remove_user_group_members(
        group_id,
        GetStream::Generated::Models::RemoveUserGroupMembersRequest.new(
          member_ids: user_ids,
        ),
      )

      # Verify members are removed
      get_resp_after = @client.common.get_user_group(group_id)
      expect(get_resp_after.user_group).not_to be_nil
      members_after = get_resp_after.user_group.members
      expect(members_after).to satisfy('be nil or empty') { |m| m.nil? || m.empty? }

    end

  end

  describe 'DeleteUserGroup' do

    it 'deletes a group and verifies a subsequent GET returns an error' do

      group_id = "test-group-#{SecureRandom.uuid}"
      create_group(id: group_id, name: "Group To Delete #{group_id}")

      delete_group(group_id)

      expect { @client.common.get_user_group(group_id) }.to raise_error(StandardError)

    end

  end

end
