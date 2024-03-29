require_relative '../authenticator'

# Returns a JSON hash that looks like this:
#
#     {
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
# POST /api?command=Register&access_token=[access_token]&description=[description]
module Commands
  class RegisterCommand
    MAX_DESCRIPTION_SIZE = 750
    MAX_DONATION_URL_SIZE = 100

    def execute(args)
      access_token = args['access_token']
      description = args['description']
      donation_url = args['donation_url']

      # Verify user is authenticated.
      response = authenticator.signin_with_access_token(access_token)
      return response if response['error']
      contributor = response['contributor']

      # Verify business rules.
      return { 'error' => true, 'error_code' => 2 } unless business_rules_passed?(contributor, description, donation_url)

      # Record registration to $database.
      $database.register(contributor, description, donation_url)

      # Get the updated contributor.
      contributor = $database.get_contributor(contributor['username'])

      # Log the registration.
      $logs.log('Register', contributor)

      # Return the contributor and candidates.
      {
        'contributor' => contributor,
        'candidates'  => $database.get_candidates(true)
      }
    end

    private

    def business_rules_passed?(contributor, description, donation_url)
      return if contributor['is_candidate']
      return if description.to_s.size > MAX_DESCRIPTION_SIZE
      return if donation_url.to_s.size > MAX_DONATION_URL_SIZE

      true
    end

    def authenticator
      @authenticator ||= Authenticator.new
    end
  end
end
