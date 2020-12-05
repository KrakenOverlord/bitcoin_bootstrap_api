require 'aws-sdk-dynamodb'

class Database
  def initialize
    @database = Aws::DynamoDB::Client.new
  end

  # Returns the contributor record hash or nil if not found.
  def get_contributor(username)
    contributor = @database.get_item(
      table_name: contributors_table_name,
      key: { "username" => username },
      consistent_read: true
    )[:item]

    contributor
  end

  # Returns the candidate record hash or nil if not found.
  def get_candidate(username)
    candidate = @database.get_item(
      table_name: candidates_table_name,
      key: { "username" => username },
      consistent_read: true
    )[:item]

    candidate['votes'] = candidate['votes'].to_i if candidate
    candidate
  end

  def create_contributor(contributor)
    @database.put_item(
      table_name: contributors_table_name,
      item: contributor
    )
  end

  def create_candidate(candidate)
    @database.put_item(
      table_name: candidates_table_name,
      item: candidate
    )
  end

  def delete_contributor(username)
    @database.delete_item(
      {
        table_name: contributors_table_name,
        key: {
          'username' => username
        }
      }
    )
  end

  def delete_candidate(username)
    @database.delete_item(
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
      result = @database.scan(params)

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
      result = @database.scan(params)

      # Convert votes to an integer and add the candidate to the candidates array.
      result.items.each do |candidate|
        candidate['votes'] = candidate['votes'].to_i
        candidate['contributions'] = candidate['contributions'].to_i
        candidates << candidate
      end

      break if result.last_evaluated_key.nil?

      params[:exclusive_start_key] = result.last_evaluated_key
    end

    candidates
  end

  # Creates a new candidate.
  def register(contributor, description, donation_url)
    @database.transact_write_items(
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
                'description' => description,
                'donation_url' => donation_url
              }
            }
          },
          {
            update: {
              table_name: contributors_table_name,
              key: { 'username' => contributor['username'] },
              update_expression: 'SET is_candidate = :is_candidate, description = :description, donation_url = :donation_url',
              expression_attribute_values: {
                ':is_candidate' => true,
                ':description' => description,
                ':donation_url' => donation_url
              }
            }
          }
        ]
      }
    )
  end

  # Deletes a candidate.
  def unregister(username)
    @database.transact_write_items(
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
    @database.transact_write_items(
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

  # Updates a candidates donation_url.
  def update_donation_url(username, donation_url)
    @database.transact_write_items(
      {
        transact_items: [
          {
            update: {
              table_name: candidates_table_name,
              key: { 'username' => username },
              update_expression: 'SET donation_url = :donation_url',
              expression_attribute_values: {
                ':donation_url' => donation_url
              }
            }
          },
          {
            update: {
              table_name: contributors_table_name,
              key: { 'username' => username },
              update_expression: 'SET donation_url = :donation_url',
              expression_attribute_values: {
                ':donation_url' => donation_url
              }
            }
          }
        ]
      }
    )
  end

  def vote(voter_username, old_candidate_username, new_candidate_username)
    if old_candidate_username.empty?
      @database.transact_write_items(
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
      @database.transact_write_items(
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

  def increment_metric(command)
    @database.update_item(
      table_name: metrics_table_name,
      key: { 'command' => command },
      update_expression: 'ADD numCalls :numCalls',
      expression_attribute_values: { ':numCalls' => 1 }
    )
  end

  # Returns the contributor with username
  def update_access_token(username, access_token)
    contributor = @database.update_item(
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
    return 'contributors-production' if $environment == 'production'
    'contributors-stage'
  end

  def candidates_table_name
    return 'candidates-production' if $environment == 'production'
    'candidates-stage'
  end

  def metrics_table_name
    return 'metrics-production' if $environment == 'production'
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
end
