**TODO**
- follow links in getting contributors from GitHub or use https://developer.github.com/v3/libraries/
- finish specs
- use hash in signin command
- strip out the '#non-github-bitcoin' contributor

**Sync Contributors**

`curl -X POST "http://localhost:3000/sync_contributors?code=[code]&include_anonymous=true"`

# Lambda: bitcoin_bootstrap_api

## Configure Lambda Function

### Create a Lambda Function

Using the AWS web interface:

- Specify the `Ruby 2.7 runtime`.
- Specify the `LambdaFullAccess` execution role.

### Configure the Lambda Function

Using the AWS web interface:

- Increase the timeout to 1 minute.
- Create environment variables:
```
GEM_PATH=/var/task/vendor/bundle/ruby/2.5.0:/opt/ruby/gems/2.5.0:/opt/ruby/2.5.0
SNS_TOPIC_ARN_TEST=arn:aws:sns:us-west-1:087256792386:fulfillment-test
SNS_TOPIC_ARN_STAGE=arn:aws:sns:us-west-1:087256792386:fulfillment-stage
SNS_TOPIC_ARN_PRODUCTION=arn:aws:sns:us-west-1:087256792386:fulfillment-production
```
- Create aliases for stage and production.

## Build and Deploy the code

- `$ ./scripts/build_remote.sh`
- `$ ./scripts/deploy.sh`

## Run the Lambda Function

### Invoke Locally

- `$ cp .env.sample .env`
- `$ ./scripts/build_local.sh`
- `$ ruby test/lambda_handler.rb`

### Invoke Remotely using AWS CLI

AWS Lambda console uses the RequestResponse invocation type, so when you invoke
the function, the console will display the returned value.

```
$ aws lambda invoke \
  --profile [profile name] \
  --region us-west-1 \
  --function-name [lambda function name] \
  --payload fileb://event.json \
  /dev/stdout
```

## View Logs

```
$ aws logs filter-log-events \
  --log-group-name /aws/lambda/[lambda function name] \
  --log-stream-name-prefix "YYYY/MM/DD/[lambda version]" \
  --filter-pattern [some text] \
  --output text
```

Example:

```
$ aws logs filter-log-events \
  --log-group-name /aws/lambda/email \
  --log-stream-name-prefix "2020/06/25/[12]" \
  --filter-pattern "itemsCancelled" \
  --output text
```

## Test

- `$ ./scripts/build_local.sh`
- `$ bundle exec rspec`
