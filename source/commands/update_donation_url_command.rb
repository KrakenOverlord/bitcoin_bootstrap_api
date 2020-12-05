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
# POST /api?command=UpdateDonationUrl&access_token=[access_token]&donation_url=[donation_url]
module Commands
  class UpdateDonationUrlCommand
    MAX_DONATION_URL_SIZE = 100

    def execute(args)
      access_token = args['access_token']
      donation_url = args['donation_url']

      # Verify user is authenticated.
      response = authenticator.signin_with_access_token(access_token)
      return response if response['error']
      contributor = response['contributor']

      # Verify business rules.
      return { 'error' => true, 'error_code' => 2 } unless business_rules_passed?(contributor, donation_url)

      # Record description to $database.
      $database.update_donation_url(contributor['username'], donation_url)

      # Get the updated contributor.
      contributor = $database.get_contributor(contributor['username'])

      # Log the update.
      $logs.log('UpdateDonationUrl', response['contributor'])

      # Return the updated contributor and candidates.
      {
        'contributor' => contributor,
        'candidates'  => $database.get_candidates(true)
      }
    end

    private

    def business_rules_passed?(contributor, donation_url)
      return unless contributor['is_candidate']
      return if donation_url.to_s.size == 0 || donation_url.to_s.size > MAX_DONATION_URL_SIZE

      true
    end

    def authenticator
      @authenticator ||= Authenticator.new
    end
  end
end
