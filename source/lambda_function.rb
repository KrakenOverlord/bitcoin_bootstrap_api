require_relative './commands/create_bug_report_command'
require_relative './commands/create_feature_request_command'
require_relative './commands/get_candidates_command'
require_relative './commands/register_command'
require_relative './commands/signin_with_access_token_command'
require_relative './commands/signin_with_code_command'
require_relative './commands/sync_contributors_command'
require_relative './commands/unregister_command'
require_relative './commands/update_description_command'
require_relative './commands/vote_command'

require_relative 'database'
require_relative 'authenticator'


# This handler:
#   - prints out the incoming arguments
#   - executes a class with the same name as the lambda
#   - prints out the results
#
# The event parameter is a hash of the API Gateway request:
# event: {
#   "version"=>"2.0",
#   "routeKey"=>"POST /api",
#   "rawPath"=>"/api",
#   "rawQueryString"=>"",
#   "headers"=>{
#     "accept"=>"*/*",
#     "accept-encoding"=>"gzip, deflate",
#     "cache-control"=>"no-cache",
#     "content-length"=>"17",
#     "content-type"=>"application/x-www-form-urlencoded",
#     "host"=>"0kikswga8d.execute-api.us-west-2.amazonaws.com",
#     "postman-token"=>"c78da990-d133-46d7-972c-6d6935bc4462",
#     "user-agent"=>"PostmanRuntime/7.6.0",
#     "x-amzn-trace-id"=>"Root=1-5fb9c9f1-27b533b462ed338c7b4f1f92",
#     "x-forwarded-for"=>"198.27.221.195",
#     "x-forwarded-port"=>"443",
#     "x-forwarded-proto"=>"https"
#   },
#   "requestContext"=>{
#     "accountId"=>"710246576414",
#     "apiId"=>"0kikswga8d",
#     "domainName"=>"0kikswga8d.execute-api.us-west-2.amazonaws.com",
#     "domainPrefix"=>"0kikswga8d",
#     "http"=>{
#       "method"=>"POST",
#       "path"=>"/register",
#       "protocol"=>"HTTP/1.1",
#       "sourceIp"=>"198.27.221.195",
#       "userAgent"=>"PostmanRuntime/7.6.0"},
#       "requestId"=>"WYx9ugCtPHcEP2g=",
#       "routeKey"=>"POST /register",
#       "stage"=>"$default",
#       "time"=>"22/Nov/2020:02:16:17 +0000",
#       "timeEpoch"=>1606011377316
#     },
#   }
#   "body"=>"YWNjZXNzX2NvZGU9MTIzNDU=",
#   "isBase64Encoded"=>true
# }

def lambda_handler(event:, context:)
  # The puts show up in the logs. A separate line for each puts.
  puts "event: #{event}"

  result = LambdaFunction.new.lambda_handler(event: event)

  puts "result: #{result}"

  # Synchronouse invocations can use return values.
  result.to_json
end

class LambdaFunction
  INTERNAL_SERVER_ERROR = 100

  def lambda_handler(event:)
    return { status: 200 } if event["requestContext"]["http"]["method"] == "OPTIONS"

    @event = event

    params_hash = get_params_hash(event)

    command = params_hash["command"]
    params_hash.delete('command')

    qualified_command = "Commands::#{command}Command"

    command_class = Object.const_get(qualified_command)

    command_class.new.execute(params_hash)
  rescue Exception => e
    puts e.message
    return { 'error' => true, error_code: INTERNAL_SERVER_ERROR }
  ensure
    Database.new.increment_metric(command) unless command.to_s.empty?
  end

  private

  def get_params_hash(event)
    body = event["body"]
    body = Base64.decode64(body) if event["isBase64Encoded"]


    # params_array = URI.decode_www_form(body)
    #
    # params_hash = {}
    # params_array.each do |param_array|
    #   params_hash[param_array.first] = param_array.last
    # end

    # params_hash

    JSON.parse(body)
  end

  # Require all source files.
  # def require_files
  #   project_root = File.dirname(File.absolute_path(__FILE__))
  #   Dir.glob(project_root + '/**/*.rb') {|file| require file }
  # end
end
