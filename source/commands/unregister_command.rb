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
# POST /api?command=Unregister&access_token=[access_token]
module Commands
  class UnregisterCommand
    def execute(args)
      access_token = args['access_token']

      # Verify user is authenticated.
      response = authenticator.signin_with_access_token(access_token)
      return response if response['error']
      contributor = response['contributor']

      # Verify business rules.
      return { 'error' => true, 'error_code' => 2 } unless business_rules_passed?(contributor)

      # Record registration to $database.
      $database.unregister(contributor['username'])

      # Get the updated contributor.
      contributor = $database.get_contributor(contributor['username'])

      # Log the registration.
      $logs.log('Unregister', contributor)

      # Return the updated contributor and candidates.
      {
        'contributor' => contributor,
        'candidates'  => $database.get_candidates(true)
      }
    end

    private

    def business_rules_passed?(contributor)
      return unless contributor['is_candidate']

      true
    end

    def authenticator
      @authenticator ||= Authenticator.new
    end
  end
end
