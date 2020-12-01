require 'json'
require 'byebug'
require 'awesome_print'
require 'httparty'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require_relative '../source/lambda_function' # Sets global variables.

class Test
  def execute
    contributors = database.get_contributors(false)

    contributors = contributors.select { |contributor| contributor['contributor_type'] == 'Anonymous' }

    contributors.each do |contributor|
      # ap contributor
      response = HTTParty.get("https://api.github.com/search/users?q=#{contributor['username']}+in:email",
        headers: {
          'Accept' => 'application/vnd.github.v3+json'
        }
      )
      ap response.parsed_response
      sleep(10)
    end
  end

  def database
    @database ||= Database.new
  end
end

response = HTTParty.get("https://api.github.com/search/users?q=andrew@ajr.systems+in:email",
  headers: {
    'Accept' => 'application/vnd.github.v3+json'
  }
)

byebug

ap response.parsed_response


# ap Test.new.execute

# class Test
#   def execute
#     database = Database.new
#
#     index = 0
#
#     starting = Time.now
#     100.times do
#       contributors = database.get_contributors(false)
#       ap "#{index}: #{contributors.count}"
#       index += 1
#     end
#     ending = Time.now
#
#     elapsed = ending - starting
#
#     ap "Elapsed: #{elapsed}"
#   end
# end
#
# ap Test.new.execute
