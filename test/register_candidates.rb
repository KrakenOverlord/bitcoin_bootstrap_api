require 'byebug'
require 'awesome_print'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative '../source/database'

class RegisterCandidates
  def execute(num_candidates = nil)
    contributors = database.get_contributors(false)

    description = "But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system," \
    " and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because " \
    "it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or."

    index = 0
    contributors.map do |contributor|
      database.register(contributor, description)
      index = index + 1
      break if num_candidates && index >= num_candidates
    end

    index
  end

  def database
    @database ||= Database.new
  end
end
