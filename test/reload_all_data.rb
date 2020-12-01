require 'byebug'
require 'awesome_print'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative 'delete_contributors'
require_relative 'delete_candidates'
require_relative 'register_candidates'
require_relative 'copy_contributors_from_production_to_stage'

DeleteContributors.new.execute
ap 'Deleted all contributors.'
DeleteCandidates.new.execute
ap 'Deleted all candidates.'
CopyContributorsFromProductionToStage.new.execute
ap "Copied contributors."
RegisterCandidates.new.execute(5)
ap "Registered candidates."
ap "Done."