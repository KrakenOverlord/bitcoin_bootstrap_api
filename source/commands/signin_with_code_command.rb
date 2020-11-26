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
#   2 - invalid request.
#   100 - internal server error.
#
# POST /api?command=SigninWithCode&code=[code]
module Commands
  class SigninWithCodeCommand
    def execute(args)
      code = args['code']

      # Verify user is authenticated.
      response = authenticator.signin_with_code(code)
      return response if response['error']

      # Log the signin.
      $logs.log('SigninWithCode', response['contributor'])

      # Return the updated contributor and candidates.
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
