require_relative './commands/create_bug_report_command'
require_relative './commands/create_feature_request_command'
require_relative './commands/get_candidates_command'
require_relative './commands/register_command'
require_relative './commands/signin_with_access_token_command'
require_relative './commands/signin_with_code_command'
require_relative './commands/unregister_command'
require_relative './commands/update_description_command'
require_relative './commands/vote_command'

require_relative 'database'
require_relative 'authenticator'
require_relative 'logs'

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

$environment = nil
$database ||= Database.new
$logs ||= Logs.new

def lambda_handler(event:, context:)
  puts "event: #{event}"
  result = LambdaFunction.new.lambda_handler(event: event)
  puts "result: #{result}"

  result.to_json
end

class LambdaFunction
  INTERNAL_SERVER_ERROR = 100

  def lambda_handler(event:)
    return { status: 200 } if options_call?(event)
    return { status: 400 } unless post_call?(event)

    $environment = event["requestContext"]["stage"] # ["development", "stage", "production"]

    command_class(event).new.execute(params_hash(event))
  rescue Exception => e
    raise e
    puts "Exception: #{e}: #{e.message}"
    return { 'error' => true, error_code: e.message } #INTERNAL_SERVER_ERROR }
  ensure
    $database.increment_metric(command(event)) unless command(event).to_s.empty?
  end

  private

  def options_call?(event)
    event["requestContext"]["http"]["method"] == "OPTIONS"
  end

  def post_call?(event)
    event["requestContext"]["http"]["method"] == "POST"
  end

  def command_class(event)
    Object.const_get("Commands::#{command(event)}Command")
  end

  def command(event)
    params_hash(event)["command"]
  end

  def params_hash(event)
    body = event["body"]
    return {} if body.nil?
    body = Base64.decode64(body) if event["isBase64Encoded"]
    JSON.parse(body)
  end
end
