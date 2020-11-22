class Database
  # Returns the contributor record hash or nil if not found.
  def get_contributor(username)
    contributor = dynamodb.get_item(
      table_name: contributors_table_name,
      key: { "username" => username },
      consistent_read: true
    )[:item]

    contributor
  end

  # Returns the candidate record hash or nil if not found.
  def get_candidate(username)
    candidate = dynamodb.get_item(
      table_name: candidates_table_name,
      key: { "username" => username },
      consistent_read: true
    )[:item]

    candidate['votes'] = candidate['votes'].to_i if candidate
    candidate
  end

  def delete_contributor(username)
    dynamodb.delete_item(
      {
        table_name: contributors_table_name,
        key: {
          'username' => username
        }
      }
    )
  end

  def delete_candidate(username)
    dynamodb.delete_item(
      {
        table_name: candidates_table_name,
        key: {
          'username' => username
        }
      }
    )
  end

  # Returns an array of contributor hashes.
  def get_contributors(consistent_read)
    contributors = []
    params = {
      table_name: contributors_table_name,
      consistent_read: consistent_read
    }

    loop do
      result = dynamodb.scan(params)

      # Add the contributor to the contributors array.
      result.items.each do |contributor|
        contributors << contributor
      end

      break if result.last_evaluated_key.nil?

      params[:exclusive_start_key] = result.last_evaluated_key
    end

    contributors
  end

  # Returns an array of candidate hashes.
  def get_candidates(consistent_read)
    candidates = []
    params = {
      table_name: candidates_table_name,
      consistent_read: consistent_read
    }

    loop do
      result = dynamodb.scan(params)

      # Convert votes to an integer and add the candidate to the candidates array.
      result.items.each do |candidate|
        candidate['votes'] = candidate['votes'].to_i
        candidates << candidate
      end

      break if result.last_evaluated_key.nil?

      params[:exclusive_start_key] = result.last_evaluated_key
    end

    candidates
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

    dynamodb.update_item(
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
        },
        return_values: "ALL_NEW"
      }
    )
  end

  # Creates a new candidate.
  def register(contributor, description)
    dynamodb.transact_write_items(
      {
        transact_items: [
          {
            put: {
              table_name: candidates_table_name,
              item: {
                'username' => contributor['username'],
                'avatar_url' => contributor['avatar_url'],
                'contributions' => contributor['contributions'],
                'contributor_type' => contributor['contributor_type'],
                'html_url' => contributor['html_url'],
                'votes' => votes(contributor['username']),
                'description' => description
              }
            }
          },
          {
            update: {
              table_name: contributors_table_name,
              key: { 'username' => contributor['username'] },
              update_expression: 'SET is_candidate = :is_candidate, description = :description',
              expression_attribute_values: {
                ':is_candidate' => true,
                ':description' => description
              }
            }
          }
        ]
      }
    )
  end

  # Deletes a candidate.
  def unregister(username)
    dynamodb.transact_write_items(
      {
        transact_items: [
          {
            delete: {
              table_name: candidates_table_name,
              key: {
                'username' => username
              }
            }
          },
          {
            update: {
              table_name: contributors_table_name,
              key: { 'username' => username },
              update_expression: 'SET is_candidate = :is_candidate',
              expression_attribute_values: {
                ':is_candidate' => false
              }
            }
          }
        ]
      }
    )
  end

  # Updates a candidates description.
  def update_description(username, description)
    dynamodb.transact_write_items(
      {
        transact_items: [
          {
            update: {
              table_name: candidates_table_name,
              key: { 'username' => username },
              update_expression: 'SET description = :description',
              expression_attribute_values: {
                ':description' => description
              }
            }
          },
          {
            update: {
              table_name: contributors_table_name,
              key: { 'username' => username },
              update_expression: 'SET description = :description',
              expression_attribute_values: {
                ':description' => description
              }
            }
          }
        ]
      }
    )
  end

  def increment_metric(command)
    dynamodb.update_item(
      table_name: metrics_table_name,
      key: { 'command' => command },
      update_expression: 'ADD numCalls :numCalls',
      expression_attribute_values: { ':numCalls' => 1 }
    )
  end

  def vote(voter_username, old_candidate_username, new_candidate_username)
    if old_candidate_username.empty?
      dynamodb.transact_write_items(
        {
          transact_items: [
            { # Add a vote for the new candidate
              update: {
                table_name: candidates_table_name,
                key: { 'username' => new_candidate_username },
                update_expression: 'SET votes = votes + :votes',
                expression_attribute_values: { ':votes' => 1 }
              }
            },
            { # Update who the contributor voted for
              update: {
                table_name: contributors_table_name,
                key: { 'username' => voter_username },
                update_expression: 'SET voted_for = :voted_for',
                condition_expression: "voted_for <> :voted_for",
                expression_attribute_values: { ':voted_for' => new_candidate_username }
              }
            }
          ]
        }
      )
    else
      dynamodb.transact_write_items(
        {
          transact_items: [
            { # Decrement vote for the old candidate
              update: {
                table_name: candidates_table_name,
                key: { 'username' => old_candidate_username },
                update_expression: 'SET votes = votes - :votes',
                expression_attribute_values: { ':votes' => 1 }
              }
            },
            { # Add a vote for the new candidate
              update: {
                table_name: candidates_table_name,
                key: { 'username' => new_candidate_username },
                update_expression: 'SET votes = votes + :votes',
                expression_attribute_values: { ':votes' => 1 }
              }
            },
            { # Update who the contributor voted for
              update: {
                table_name: contributors_table_name,
                key: { 'username' => voter_username },
                update_expression: 'SET voted_for = :voted_for',
                condition_expression: "voted_for <> :voted_for",
                expression_attribute_values: { ':voted_for' => new_candidate_username }
              }
            }
          ]
        }
      )
    end
  end

  # Returns the contributor with username
  def update_access_token(username, access_token)
    contributor = dynamodb.update_item(
      {
        table_name: contributors_table_name,
        key: { 'username' => username },
        update_expression: 'set access_token = :access_token',
        expression_attribute_values: { ':access_token' => access_token },
        return_values: "ALL_NEW"
      }
    )['attributes']

    contributor['votes'] = contributor['votes'].to_i
    contributor
  end

  def contributors_table_name
    return 'contributors-production' if ENV['ENVIRONMENT'] == 'PRODUCTION'
    'contributors-stage'
  end

  def candidates_table_name
    return 'candidates-production' if ENV['ENVIRONMENT'] == 'PRODUCTION'
    'candidates-stage'
  end

  def metrics_table_name
    return 'metrics-production' if ENV['ENVIRONMENT'] == 'PRODUCTION'
    'metrics-stage'
  end

  def votes(username)
    votes = 0
    contributors = get_contributors(false)

    contributors.each do |contributor|
      votes = votes + 1 if contributor['voted_for'] == username
    end

    votes
  end

  def dynamodb
    @dynamodb ||= Aws::DynamoDB::Client.new
  end
end
