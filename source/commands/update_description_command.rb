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
# POST /api?command=UpdateDescription&access_token=[access_token]&description=[description]
module Commands
  class UpdateDescriptionCommand
    MAX_DESCRIPTION_SIZE = 500

    def execute(args)
      access_token = args['access_token']
      description = args['description']

      # Verify user is authenticated.
      response = authenticator.signin_with_access_token(access_token)
      return response if response['error']
      contributor = response['contributor']

      # Verify business rules.
      return { 'error' => true, 'error_code' => 2 } unless business_rules_passed?(contributor, description)

      # Record description to $database.
      $database.update_description(contributor['username'], description)

      # Get the updated contributor.
      contributor = $database.get_contributor(contributor['username'])

      # Log the update.
      $logs.log('UpdateDescription', response['contributor'])

      # Return the updated contributor and candidates.
      {
        'contributor' => contributor,
        'candidates'  => $database.get_candidates(true)
      }
    end

    private

    def business_rules_passed?(contributor, description)
      return unless contributor['is_candidate']
      return if description.to_s.size == 0 || description.to_s.size > MAX_DESCRIPTION_SIZE

      true
    end

    def authenticator
      @authenticator ||= Authenticator.new
    end
  end
end
