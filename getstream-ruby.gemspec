# frozen_string_literal: true

require_relative 'lib/getstream_ruby/version'

Gem::Specification.new do |spec|

  spec.name          = 'getstream-ruby'
  spec.version       = GetStreamRuby::VERSION
  spec.authors       = ['GetStream']
  spec.email         = ['support@getstream.io']

  spec.summary       = 'Ruby SDK for GetStream'
  spec.description   = "Official Ruby SDK for GetStream's activity feeds and chat APIs"
  spec.homepage      = 'https://getstream.io'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*.rb', 'README.md', 'LICENSE']
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.6.0'

  spec.add_dependency 'dotenv', '>= 2.0'
  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'faraday-multipart', '~> 1.0'
  spec.add_dependency 'faraday-retry', '~> 2.0'
  spec.add_dependency 'json', '~> 2.0'
  spec.add_dependency 'jwt', '~> 2.0'

  # spec.metadata['rubygems_mfa_required'] = 'true'

end
