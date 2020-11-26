require 'json'
require 'byebug'
require 'faker'
require 'awesome_print'
require 'aws-sdk-dynamodb'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative '../lib/database'

class UnregisterCandidates
  def execute
    candidates = Database.new.get_candidates(false)

    candidates.map do |candidate|
      database.unregister(candidate['username'])
    end
  end

  def database
    @database ||= Database.new
  end
end

ap UnregisterCandidates.new.execute
