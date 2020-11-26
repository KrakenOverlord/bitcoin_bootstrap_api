require_relative '../authenticator'

# Returns a JSON hash that looks like this:
#
#     {
#       'contributor' : <contributor hash>,
#       'candidates' : [<contributor hash>]
#     }
#
#  OR
#
#     {
#       'error' => <true, false>,
#       'error_code' : <integer>
#     }
#
# Error Codes:
#   0 - cannot authenticate user with Github.
#   1 - the user is not a contributor.
#   2 - invalid request.
#   100 - internal server error.
#
# POST /api?command=Vote&access_token=[access_token]&vote=[username]
module Commands
  class VoteCommand
    def execute(args)
      access_token = args['access_token']
      new_candidate_username = args['vote']

      # Verify user is authenticated.
      response = authenticator.signin_with_access_token(access_token)
      return response if response['error']
      contributor = response['contributor']

      voter_username = contributor['username']

      old_candidate_username = get_old_candidate_username(contributor['voted_for'])

      # Verify business rules.
      return { 'error' => true, 'error_code' => 2 } unless business_rules_passed?(voter_username, old_candidate_username, new_candidate_username)

      # Record votes to $database.
      $database.vote(voter_username.to_s, old_candidate_username.to_s, new_candidate_username.to_s)

      # Get the updated contributor.
      contributor = $database.get_contributor(contributor['username'])

      # Log the voting.
      $logs.log('Vote', contributor)

      # Return the updated contributor and candidates.
      {
        'contributor' => contributor,
        'candidates'  => $database.get_candidates(true)
      }
    end

    private

    def get_old_candidate_username(old_candidate_username)
      return if old_candidate_username.empty?

      # See if old candidate is still registered.
      old_candidate = $database.get_candidate(old_candidate_username)
      return old_candidate_username if old_candidate
    end

    def business_rules_passed?(voter_username, old_candidate_username, new_candidate_username)
      return if new_candidate_username.to_s.empty?

      # Verify candidate exists.
      new_candidate = $database.get_contributor(new_candidate_username)
      return unless new_candidate

      # Verify that the new candidate is registered.
      return unless new_candidate['is_candidate']

      true
    end

    def authenticator
      @authenticator ||= Authenticator.new
    end
  end
end
