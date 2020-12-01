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

    contributors.map do |contributor|
      database.create_contributor(contributor)
    end
  end

  def database
    @database ||= Database.new
  end
end
