# frozen_string_literal: true

source 'https://rubygems.org'

gemspec name: 'getstream-ruby'

# Pin transitive dep: connection_pool 3.x requires Ruby >= 3.2.
# net-http-persistent accepts 2.x (>= 2.2.4, < 4), and CI runs Ruby 3.1.
gem 'connection_pool', '< 3.0'

group :development, :test do

  gem 'bundler-audit', '~> 0.9'
  gem 'pry'
  gem 'rake', '~> 13.0'
  gem 'rspec'
  gem 'rubocop', '~> 1.50'
  gem 'rubocop-performance', '~> 1.17'
  gem 'rubocop-rake', '~> 0.6'
  gem 'rubocop-rspec', '~> 2.20'
  gem 'simplecov', '~> 0.22'
  gem 'webmock'
  gem 'yard', '~> 0.9'

end
