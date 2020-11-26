require 'json'
require 'byebug'
require 'awesome_print'
require 'aws-sdk-dynamodb'
require 'httparty'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative '../lib/database'

class Test
  def execute
    database = Database.new

    index = 0

    starting = Time.now
    100.times do
      contributors = database.get_contributors(false)
      ap "#{index}: #{contributors.count}"
      index += 1
    end
    ending = Time.now

    elapsed = ending - starting

    ap "Elapsed: #{elapsed}"
  end
end

ap Test.new.execute
