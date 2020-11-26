require 'json'
require 'byebug'
require 'faker'
require 'awesome_print'
require 'aws-sdk-dynamodb'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative '../lib/database'

class DeleteContributors
  def execute
    contributors = Database.new.get_contributors(false)

    contributors.map do |contributor|
      database.delete_contributor(contributor['username'])
    end
  end

  def database
    @database ||= Database.new
  end
end

ap DeleteContributors.new.execute
