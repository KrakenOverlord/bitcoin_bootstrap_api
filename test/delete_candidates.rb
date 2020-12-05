require 'byebug'
require 'awesome_print'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative '../source/database'

class DeleteCandidates
  def execute
    candidates = database.get_candidates(false)

    candidates.map do |candidate|
      database.delete_candidate(candidate['username'])
    end
  end

  def database
    @database ||= Database.new
  end
end
