require 'json'
require 'byebug'
require 'faker'
require 'awesome_print'
require 'aws-sdk-dynamodb'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative '../lib/database'

class RegisterCandidates
  def execute
    contributors = Database.new.get_contributors(false)

    description = "But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system," \
    " and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because " \
    "it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or."

    index = 0
    contributors.map do |contributor|
      database.register(contributor, description)
      index = index + 1
      break if index >= 3
    end
  end

  def database
    @database ||= Database.new
  end
end

ap RegisterCandidates.new.execute
