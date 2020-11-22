$LOAD_PATH.unshift File.dirname(__FILE__) + '/..'

# Require all source files.
Dir['source/**/*.rb'].each{ |f| require f }

require 'dotenv/load'
require 'faker'
require 'awesome_print'
require 'rspec/its'
require 'byebug'
require 'webmock/rspec'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  # config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end
end
