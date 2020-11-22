# In order for the Ruby code to be able to use bundled gems, we must include these lines.
require 'rubygems'
require 'bundler/setup'

# Loads environment variables.
require 'dotenv'
Dotenv.overload

require 'aws-sdk-s3'
require 'faker'
require 'byebug'
require 'awesome_print'

load 'source/lambda_function.rb'

require_relative '../source/protobufs/events_pb'

s3_message = {
  "Records" => [
    {
      "s3" => {
        "bucket" => {
          "name" => 'smp-shared-dev'
        },
        "object" => {
          "key" => "ChannelAdvisorFeeds/Order/TO_SMP/test_file.json"
        }
      }
    }
  ]
}

# Put a file on S3 to be used for this test
s3 = Aws::S3::Resource.new
s3.bucket('smp-shared-dev').object('ChannelAdvisorFeeds/Order/TO_SMP/test_file.json').upload_file('test/ebay_order.json')

ap lambda_handler(event: s3_message, context: nil)
