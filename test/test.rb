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

response = HTTParty.get("https://github.com/sponsors/jonasschnelli")


byebug

ap response.parsed_response
