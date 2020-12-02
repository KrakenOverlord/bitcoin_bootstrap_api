require 'aws-sdk-dynamodb'
require 'httparty'
require 'awesome_print'
require 'byebug'

require_relative 'sync_contributors'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

SyncContributors.new.execute('production')
