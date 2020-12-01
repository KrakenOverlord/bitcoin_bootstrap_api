require 'aws-sdk-dynamodb'
require 'httparty'
require 'awesome_print'
require 'byebug'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

class SyncContributors
  def execute(environment, include_anonymous=true)
    @environment = environment

    contributors = get_contributors(include_anonymous)

    normal_contributors = contributors.select { |contributor| contributor['type'] != 'Anonymous' }
    anonymous_contributors = contributors.select { |contributor| contributor['type'] == 'Anonymous' }

    # contributors = JSON.parse(File.read('test/contributors.json'))
    ap "Found #{contributors.count} contributors."
    ap "Found #{normal_contributors.count} normal contributors."
    ap "Found #{anonymous_contributors.count} anonymous contributors."

    verified_anonymous_contributors = verify_anonymous_contributors(anonymous_contributors)
    all_verified_contributors = normal_contributors + verified_anonymous_contributors
    formatted_contributors = format_contributors(all_verified_contributors)
    record_contributors(formatted_contributors)

    time = Time.now.to_s
    File.open("last_sync-#{time}.txt", "w") { |f| f.write "Total: #{all_verified_contributors.count}, Verified anons: #{verified_anonymous_contributors.count}" }

    formatted_contributors.count
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
        'contributions' => 0
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
      # There can be duplicate anonymous contributers with the same email but
      # different names.
      users.each do |user|
        user['login'] = user['email'] if user['type'] == 'Anonymous'

        contributors[user['login']] = user if contributors[user['login']].nil?
      end

      ap "Processed contributors page #{index}."
      index += 1
      break
    end

    contributors.values
  end

  def verify_anonymous_contributors(anons)
    count = 0
    updated = 0
    verified_anons = []
    anons.each do |anon|
      ap "Searching for #{anon['login']}"
      response = find_user(anon['login'])
      ap response

      if response['total_count'] && response['total_count'] == 1
        contributor = response['items'].first
        ap "New contributor info: #{contributor}"
        verified_anons << contributor
        updated = updated + 1
      elsif response['total_count'] && response['total_count'] > 1
        ap "Too many responses."
      end

      count = count + 1

      ap "Processed #{count} of #{anons.count} anons. #{updated} anon updates."

      sleep(10)
    end

    verified_anons
  end

  def find_user(email)
    HTTParty.get("https://api.github.com/search/users?q=#{email}+in:email",
      headers: {
        'Accept' => 'application/vnd.github.v3+json'
      }
    ).parsed_response
  rescue
    return {}
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
      "is_candidate = if_not_exists(is_candidate, :is_candidate)"
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
          ':is_candidate'     => false
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
