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
require_relative 'register_candidates'
require_relative '../scripts/sync_contributors'

DeleteContributors.new.execute
ap 'Deleted all contributors.'
DeleteCandidates.new.execute
ap 'Deleted all candidates.'
SyncContributors.new.execute('development', true)
ap "Sync'ed contributors."
RegisterCandidates.new.execute
ap "Registered candidates."
ap "Done."
