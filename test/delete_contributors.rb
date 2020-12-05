require 'byebug'
require 'awesome_print'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative '../source/database'

class DeleteContributors
  def execute
    contributors = database.get_contributors(false)

    contributors.map do |contributor|
      database.delete_contributor(contributor['username'])
    end
  end

  def database
    @database ||= Database.new
  end
end
