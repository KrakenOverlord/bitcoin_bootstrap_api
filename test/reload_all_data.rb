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

num_copied = CopyContributorsFromProductionToStage.new.execute
ap "Copied: #{num_copied}."

num_registered = RegisterCandidates.new.execute(5)
ap "Registered: #{num_registered}"

ap "Done."
