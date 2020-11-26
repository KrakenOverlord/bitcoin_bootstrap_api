require 'json'
require 'byebug'
require 'faker'
require 'awesome_print'
require 'aws-sdk-dynamodb'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative 'delete_contributors'
require_relative 'delete_candidates'
require_relative '../lib/commands/sync_contributors_command'
require_relative 'register_candidates'

DeleteContributors.new.execute
ap 'Deleted all contributors.'
DeleteCandidates.new.execute
ap 'Deleted all candidates.'
Commands::SyncContributorsCommand.new.execute(ENV['SYNC_CONTRIBUTORS_COMMAND_CODE'], true)
ap "Sync'ed contributors."
RegisterCandidates.new.execute
ap "Registered candidates."
ap "Done."
