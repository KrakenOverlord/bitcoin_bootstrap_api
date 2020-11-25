require 'httparty'

# POST /sync_contributors
# curl -X POST "http://localhost:3000/api?code=[code]&include_anonymous=true"
module Commands
  class SyncContributorsCommand
    def execute(args)
      code = args['code']
      include_anonymous = args['include_anonymous']

      return unless code == ENV['SYNC_CONTRIBUTORS_COMMAND_CODE']

      contributors = get_contributors(include_anonymous)
      formatted_contributors = format_contributors(contributors)
      record_contributors(formatted_contributors)

      {
        num_contributors: formatted_contributors.count
      }
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

        index += 1
      end

      contributors.values
    end

    # Returns an array of contributor hashes formatted for the $database
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
        $database.sync_contributor(contributor)
      end
    end
  end
end
