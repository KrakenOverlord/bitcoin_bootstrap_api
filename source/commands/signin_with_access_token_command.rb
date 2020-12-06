require_relative '../authenticator'

# Returns a JSON hash that looks like this:
#
#     {
#       'contributor' : <contributor hash>
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
#   100 - internal server error.
#
# POST /api?command=SigninWithAccessToken&access_token=[access_token]
module Commands
  class SigninWithAccessTokenCommand
    def execute(args)
      access_token = args['access_token']

      # Verify user is authenticated.
      response = authenticator.signin_with_access_token(access_token)
      return response if response['error']

      # Log the signin.
      $logs.log('SigninWithAccessToken', response['contributor'])

      # Return the updated contributor.
      {
        'contributor' => response['contributor']
      }
    end

    private

    def authenticator
      @authenticator ||= Authenticator.new
    end
  end
end
