require 'aws-sdk-dynamodb'
require 'httparty'
require 'awesome_print'
require 'byebug'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

class SyncContributors
  def execute(environment, include_anonymous=true)
    start_time = Time.now.to_i
    @environment = environment

    File.open("last_sync.txt", "a") do |f|
      f.puts "******************************************************************"
      f.puts "Start Time: #{Time.now.to_s}"
    end

    contributors = get_contributors(include_anonymous)
    normal_contributors = contributors.select { |contributor| contributor['type'] != 'Anonymous' }
    anonymous_contributors = contributors.select { |contributor| contributor['type'] == 'Anonymous' }
    ap "Found #{contributors.count} total contributors."
    ap "Found #{normal_contributors.count} normal contributors."
    ap "Found #{anonymous_contributors.count} anonymous contributors."
    File.open("last_sync.txt", "a") do |f|
      f.puts "Total Contributors: #{contributors.count}"
      f.puts "Normal Contributors: #{normal_contributors.count}"
      f.puts "Anonymous Contributors: #{anonymous_contributors.count}"
    end

    verified_anonymous_contributors = verify_anonymous_contributors(anonymous_contributors)
    ap "Verified Anonymous Contributors: #{verified_anonymous_contributors.count}"

    filtered_verified_anonymous_contributors = []
    # Make sure they aern't aleady in normal contributors array.
    verified_anonymous_contributors.each do |anon|
      exist = normal_contributors.find { |nc| nc['login'] == anon['login']}
      filtered_verified_anonymous_contributors << anon unless exist
    end
    all_verified_contributors = normal_contributors + filtered_verified_anonymous_contributors

    formatted_contributors = format_contributors(all_verified_contributors)

    # Record contributors to database.
    File.open("last_sync.txt", "a") do |f|
      f.puts "Verified Anonymous Contributors: #{verified_anonymous_contributors.count}"
      f.puts "Verified (and filtered) Anonymous Contributors: #{filtered_verified_anonymous_contributors.count}"
      f.puts "Final Total Contributors: #{all_verified_contributors.count}"
      f.puts "Recording Contributors to Database: #{formatted_contributors.count} contributors"
    end
    record_contributors(formatted_contributors)

    ap "Run Time: #{"%.2f" % ((Time.now.to_i - start_time) / 60.0)} minutes"
    File.open("last_sync.txt", "a") do |f|
      f.puts "Run Time: #{"%.2f" % ((Time.now.to_i - start_time) / 60.0)} minutes"
    end

    formatted_contributors.count
  rescue Exception => e
    File.open("last_sync.txt", "a") do |f|
      f.puts "Exception: #{e.message}"
    end
  end

  private

  # Returns an array of contributor hashes in Githubs format.
  #
  # A contributor hash from github looks like this:
  # {
  #                 "login" => "example",
  #                    "id" => 15069,
  #               "node_id" => "MDQ6VXNlcjMDM5Njk=",
  #            "avatar_url" => "https://avatars3.githubusercontent.com/u/169?v=4",
  #           "gravatar_id" => "",
  #                   "url" => "https://api.github.com/users/example",
  #              "html_url" => "https://github.com/example",
  #         "followers_url" => "https://api.github.com/users/example/followers",
  #         "following_url" => "https://api.github.com/users/example/following{/other_user}",
  #             "gists_url" => "https://api.github.com/users/example/gists{/gist_id}",
  #           "starred_url" => "https://api.github.com/users/example/starred{/owner}{/repo}",
  #     "subscriptions_url" => "https://api.github.com/users/example/subscriptions",
  #     "organizations_url" => "https://api.github.com/users/example/orgs",
  #             "repos_url" => "https://api.github.com/users/example/repos",
  #            "events_url" => "https://api.github.com/users/example/events{/privacy}",
  #   "received_events_url" => "https://api.github.com/users/example/received_events",
  #                  "type" => "User",
  #            "site_admin" => false,
  #         "contributions" => 11
  # }
  #
  # or if anonymous
  #
  # {
  #   "email" => "example@example.com",
  #   "name" => "example",
  #   "type" => "Anonymous",
  #   "contributions" => 1
  # }
  def get_contributors(include_anonymous)
    index = 1
    contributors = {}

    # Add myself so I can test and debug the app.
    contributors['KrakenOverlord'] = {
        'login'         => 'KrakenOverlord',
        'type'          => 'User',
        'avatar_url'    => 'https://avatars0.githubusercontent.com/u/967768?v=4',
        'html_url'      => 'https://github.com/KrakenOverlord',
        'contributions' => 0,
        'donation_url'  => 'https://github.com/sponsors/KrakenOverlord'
    }

    loop do
      response = HTTParty.get("https://api.github.com/repos/bitcoin/bitcoin/contributors?per_page=100&page=#{index}&anon=#{include_anonymous}",
        headers: {
          'Accept' => 'application/vnd.github.v3+json'
        }
      )
      raise unless response.code.to_s.start_with?('2')
      users = response.parsed_response
      break if users.empty?

      # Build a list of contributors.
      # There can be multiple anonymous contributers with the same email but
      # different names.
      users.each do |user|
        identifier = (user['type'] == 'Anonymous' ? user['email'] : user['login'])
        contributors[identifier] = user if contributors[identifier].nil?
      end

      ap "Processed contributors page #{index}."
      index += 1
    end

    contributors.values
  end

  def verify_anonymous_contributors(anons)
    count = 0
    updated = 0
    verified_anons = []
    anons.each do |anon|
      ap "Searching for #{anon['email']}"
      res = find_user(anon['email'])
      if res
        response = res.parsed_response
        ap response

        if response['total_count'] && response['total_count'] == 1
          contributor = response['items'].first
          ap "New contributor info: #{contributor}"
          verified_anons << contributor
          updated = updated + 1
        elsif response['total_count'] && response['total_count'] > 1
          ap "Too many responses."
        end
      else
        ap 'Error'
      end

      count = count + 1

      limit = res ? res.headers['x-ratelimit-remaining'].to_i : 1

      ap "Processed #{count} of #{anons.count} anons. #{updated} anon updates. Limit: #{limit}"

      if limit < 3
        ap 'Throttling'
        sleep(4)
      else
        sleep(2)
      end
    end

    verified_anons
  end

  def find_user(email)
    HTTParty.get("https://api.github.com/search/users?q=#{email}+in:email",
      headers: {
        'Accept' => 'application/vnd.github.v3+json',
        'Authorization' => "Basic #{ENV['GH_BASIC_AUTH']}"
      }
    )
  rescue
    nil
  end

  # Returns an array of contributor hashes formatted for the database.
  def format_contributors(contributors)
    contributors.map do |contributor|
      {
        username: contributor['login'].to_s,
        contributor_type: contributor['type'].to_s,
        avatar_url: contributor['avatar_url'].to_s,
        html_url: contributor['html_url'].to_s,
        contributions: contributor['contributions'].to_i
      }
    end
  end

  def record_contributors(contributors)
    contributors.each do |contributor|
      sync_contributor(contributor)
    end
  end

  # This will create a contributor if one doesn't exist.
  def sync_contributor(contributor)
    values = [
      "contributor_type = :contributor_type",
      "avatar_url = :avatar_url",
      "html_url = :html_url",
      "contributions = :contributions",
      "access_token = if_not_exists(access_token, :access_token)",
      "voted_for = if_not_exists(voted_for, :voted_for)",
      "description = if_not_exists(description, :description)",
      "is_candidate = if_not_exists(is_candidate, :is_candidate)",
      "donation_url = if_not_exists(donation_url, :donation_url)"
    ].join(",")

    database.update_item(
      {
        table_name: contributors_table_name,
        key: { 'username' => contributor[:username] },
        update_expression: "set #{values}",
        expression_attribute_values: {
          ':contributor_type' => contributor[:contributor_type].to_s,
          ':avatar_url'       => contributor[:avatar_url].to_s,
          ':html_url'         => contributor[:html_url].to_s,
          ':contributions'    => contributor[:contributions].to_i,
          ':access_token'     => '',
          ':voted_for'        => '',
          ':description'      => '',
          ':is_candidate'     => false,
          ':donation_url'     => ''
        }
      }
    )
  end

  def contributors_table_name
    return 'contributors-production' if @environment == 'production'
    'contributors-stage'
  end

  def database
    @database ||= Aws::DynamoDB::Client.new
  end
end
