# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GetStream::Generated::ChatClient do

  it 'answers to fork_message_ids and fork_message_i_ds with the same method' do

    names = %i[fork_message_ids fork_message_i_ds].map { |name| described_class.instance_method(name).original_name }
    expect(names.uniq.size).to eq(1)

  end

end
