require 'byebug'
require 'awesome_print'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative '../source/database'

class CopyContributorsFromProductionToStage
  def execute
    $environment = 'production'

    contributors = Database.new.get_contributors(false)

    $environment = 'development'

    count = 0
    contributors.map do |contributor|
      database.create_contributor(contributor)
      count = count + 1
    end

    count
  end

  def database
    @database ||= Database.new
  end
end
