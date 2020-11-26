require 'aws-sdk-sns'

# Returns a JSON hash that looks like this:
#
#     {
#       'error' => <true, false>,
#       'error_code' : <integer>
#     }
#
# Error Codes:
#   1 - Could not create the feature request.
#   100 - internal server error.
#
# POST /api?command=CreateFeatureRequest&username=[username]&description=[description]
module Commands
  class CreateFeatureRequestCommand
    MAX_DESCRIPTION_SIZE = 500

    def execute(args)
      username = args['username'] # Can be empty.
      description = args['description']

      # Verify business rules.
      error_code = business_rules(description)
      return { 'error' => true, 'error_code' => error_code } if error_code

      send_email(username, description)

      {
        'error' => false
      }
    end

    private

    def business_rules(description)
      return 1 if description.to_s.size == 0 || description.to_s.size > MAX_DESCRIPTION_SIZE
    end

    def send_email(username, description)
      sns.publish(
        topic_arn:  'arn:aws:sns:us-west-2:710246576414:bitcoin-bootstrap-contact',
        subject:    'Feature Request',
        message:    "From #{username} - #{description}"
      )
    end

    def sns
      @sns ||= Aws::SNS::Client.new
    end
  end
end
