require_relative '../database'
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
# POST /api?command=SigninWithCode&code=[code]
module Commands
  class SigninWithCodeCommand
    def execute(args)
      code = args['code']

      # Verify user is authenticated.
      response = authenticator.signin_with_code(code)
      return response if response['error']

      # Log the signin.
      log(response['contributor'])

      # Return the updated contributor and candidates.
      {
        'contributor' => response['contributor'],
        'candidates' => database.get_candidates(true)
      }
    end

    private

    def log(contributor)
      object = s3.bucket(bucket_name).object("logs/signin/#{contributor['username']}/#{Time.now.getutc.to_s}")
      object.put(body: contributor.to_json)
    rescue StandardError => e
      puts "Error uploading to S3: #{e.message}"
    end

    def bucket_name
      return 'bitcoin-bootstrap-production' if ENV['ENVIRONMENT'] == 'PRODUCTION'
      'bitcoin-bootstrap-stage'
    end

    def s3
      Aws::S3::Resource.new
    end

    def database
      @database ||= Database.new
    end

    def authenticator
      @authenticator ||= Authenticator.new
    end
  end
end
