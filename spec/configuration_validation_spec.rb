# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GetStreamRuby::Configuration do

  describe '#valid? and #validate!' do

    ['', '   ', nil].each do |blank|

      it "rejects blank api_secret (#{blank.inspect})" do

        config = described_class.new(api_key: 'key', api_secret: blank, use_env: false)
        expect(config.valid?).to be(false)
        expect { config.validate! }.to raise_error(GetStreamRuby::ConfigurationError, /API secret is required/)

      end

      it "rejects blank api_key (#{blank.inspect})" do

        config = described_class.new(api_key: blank, api_secret: 'secret', use_env: false)
        expect(config.valid?).to be(false)
        expect { config.validate! }.to raise_error(GetStreamRuby::ConfigurationError, /API key is required/)

      end

    end

  end

end
