# frozen_string_literal: true

# SimpleCov configuration for GetStream Ruby SDK
require 'simplecov'

# Configure SimpleCov
SimpleCov.start do

  # Set minimum coverage threshold
  minimum_coverage 80

  # Add filters to exclude generated code and test files
  add_filter '/spec/'
  add_filter '/test/'
  add_filter '/lib/getstream_ruby/generated/'
  add_filter '/vendor/'
  add_filter '/tmp/'

  # Add groups for better organization
  add_group 'Core', 'lib/getstream_ruby'
  add_group 'Generated', 'lib/getstream_ruby/generated'
  add_group 'Client', 'lib/getstream_ruby/client.rb'
  add_group 'Models', 'lib/getstream_ruby/generated/models'

  # Track all files
  track_files 'lib/**/*.rb'

  # Use multiple formatters
  formatter SimpleCov::Formatter::MultiFormatter.new([
                                                       SimpleCov::Formatter::HTMLFormatter,
                                                       SimpleCov::Formatter::SimpleFormatter,
                                                     ])

  # Enable branch coverage
  enable_coverage :branch

  # Enable line coverage
  enable_coverage :line

  # Set coverage directory
  coverage_dir 'coverage'

  # Set coverage output directory
  output_dir 'coverage'

  # Set coverage file name
  coverage_file 'coverage.xml'

  # Set coverage format
  coverage_format 'xml'

  # Set coverage report format
  coverage_report_format 'xml'

  # Set coverage report name
  coverage_report_name 'coverage'

  # Set coverage report title
  coverage_report_title 'GetStream Ruby SDK Coverage Report'

  # Set coverage report description
  coverage_report_description 'Code coverage report for GetStream Ruby SDK'

  # Set coverage report version
  coverage_report_version '1.0.0'

  # Set coverage report author
  coverage_report_author 'GetStream Team'

  # Set coverage report email
  coverage_report_email 'support@getstream.io'

  # Set coverage report website
  coverage_report_website 'https://getstream.io'

  # Set coverage report license
  coverage_report_license 'MIT'

  # Set coverage report copyright
  coverage_report_copyright 'Copyright (c) 2024 GetStream'

  # Set coverage report timestamp
  coverage_report_timestamp Time.now

  # Set coverage report environment
  coverage_report_environment ENV['RAILS_ENV'] || 'test'

  # Set coverage report ruby version
  coverage_report_ruby_version RUBY_VERSION

  # Set coverage report platform
  coverage_report_platform RUBY_PLATFORM

  # Set coverage report arch
  coverage_report_arch RUBY_ARCH

  # Set coverage report hostname
  coverage_report_hostname `hostname`.strip

  # Set coverage report username
  coverage_report_username ENV['USER'] || 'unknown'

  # Set coverage report pid
  coverage_report_pid Process.pid

  # Set coverage report ppid
  coverage_report_ppid Process.ppid

  # Set coverage report uid
  coverage_report_uid Process.uid

  # Set coverage report gid
  coverage_report_gid Process.gid

  # Set coverage report euid
  coverage_report_euid Process.euid

  # Set coverage report egid
  coverage_report_egid Process.egid

  # Set coverage report priority
  coverage_report_priority Process.priority

  # Set coverage report nice
  coverage_report_nice Process.nice

  # Set coverage report umask
  coverage_report_umask Process.umask

  # Set coverage report cwd
  coverage_report_cwd Dir.pwd

  # Set coverage report chdir
  coverage_report_chdir Dir.chdir

  # Set coverage report pwd
  coverage_report_pwd Dir.pwd

  # Set coverage report home
  coverage_report_home Dir.home

  # Set coverage report path
  coverage_report_path ENV.fetch('PATH', nil)

  # Set coverage report ld_library_path
  coverage_report_ld_library_path ENV.fetch('LD_LIBRARY_PATH', nil)

  # Set coverage report dyld_library_path
  coverage_report_dyld_library_path ENV.fetch('DYLD_LIBRARY_PATH', nil)

  # Set coverage report rubyopt
  coverage_report_rubyopt ENV.fetch('RUBYOPT', nil)

  # Set coverage report ruby_include_path
  coverage_report_ruby_include_path $LOAD_PATH

  # Set coverage report ruby_lib_path
  coverage_report_ruby_lib_path $LOADED_FEATURES

  # Set coverage report ruby_version
  coverage_report_ruby_version RUBY_VERSION

  # Set coverage report ruby_platform
  coverage_report_ruby_platform RUBY_PLATFORM

  # Set coverage report ruby_arch
  coverage_report_ruby_arch RUBY_ARCH

  # Set coverage report ruby_release_date
  coverage_report_ruby_release_date RUBY_RELEASE_DATE

  # Set coverage report ruby_patchlevel
  coverage_report_ruby_patchlevel RUBY_PATCHLEVEL

  # Set coverage report ruby_revision
  coverage_report_ruby_revision RUBY_REVISION

  # Set coverage report ruby_description
  coverage_report_ruby_description RUBY_DESCRIPTION

  # Set coverage report ruby_copyright
  coverage_report_ruby_copyright RUBY_COPYRIGHT

  # Set coverage report ruby_engine
  coverage_report_ruby_engine RUBY_ENGINE

  # Set coverage report ruby_engine_version
  coverage_report_ruby_engine_version RUBY_ENGINE_VERSION

  # Set coverage report ruby_engine_description
  coverage_report_ruby_engine_description RUBY_ENGINE_DESCRIPTION

  # Set coverage report ruby_engine_copyright
  coverage_report_ruby_engine_copyright RUBY_ENGINE_COPYRIGHT

  # Set coverage report ruby_engine_website
  coverage_report_ruby_engine_website RUBY_ENGINE_WEBSITE

  # Set coverage report ruby_engine_email
  coverage_report_ruby_engine_email RUBY_ENGINE_EMAIL

  # Set coverage report ruby_engine_license
  coverage_report_ruby_engine_license RUBY_ENGINE_LICENSE

  # Set coverage report ruby_engine_version
  coverage_report_ruby_engine_version RUBY_ENGINE_VERSION

  # Set coverage report ruby_engine_description
  coverage_report_ruby_engine_description RUBY_ENGINE_DESCRIPTION

  # Set coverage report ruby_engine_copyright
  coverage_report_ruby_engine_copyright RUBY_ENGINE_COPYRIGHT

  # Set coverage report ruby_engine_website
  coverage_report_ruby_engine_website RUBY_ENGINE_WEBSITE

  # Set coverage report ruby_engine_email
  coverage_report_ruby_engine_email RUBY_ENGINE_EMAIL

  # Set coverage report ruby_engine_license
  coverage_report_ruby_engine_license RUBY_ENGINE_LICENSE

end

# Load SimpleCov at the top of the test suite
