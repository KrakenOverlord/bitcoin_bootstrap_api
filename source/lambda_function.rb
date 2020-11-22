# This handler:
#   - prints out the incoming arguments
#   - executes a class with the same name as the lambda
#   - prints out the results
#
# The event parameter is a hash of the API Gateway request:
# event: {
#   "version"=>"2.0",
#   "routeKey"=>"POST /register",
#   "rawPath"=>"/register",
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
  def lambda_handler(event:)
    @event = event

    require_files

    body = get_body(event)

    command = body["command"]
    body.delete('command')

    command_class = "Commands::#{command}Command".constantize
    result = command_class.new.execute(body)
  end

  private

  def get_body(event)
    body = event["body"]
    body = Base64.decode64(body) if event["isBase64Encoded"]
    JSON.parse(body)
  end

  # Require all source files.
  def require_files
    project_root = File.dirname(File.absolute_path(__FILE__))
    Dir.glob(project_root + '/**/*.rb') {|file| require file }
  end
end
