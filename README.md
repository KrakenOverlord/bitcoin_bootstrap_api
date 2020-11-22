# Lambda: Order Received

## Configure S3, SQS and Lambda Function

### Create Dead Letter Queues

When a lambda function returns an error, Lambda leaves it in the queue. After the visibility timeout occurs, Lambda receives the message again. If it still fails after the maximum number of retries, the message is discarded. To send messages to a second queue after a maximum number of receives, configure a dead-letter queue on the source queue.

  **Queue Name**

- `orderReceivedCA-[test, stage, production]-DLQ`

**Settings**

- Use standard queue (not FIFO)
- Set Message Retention Period to 7 days.
- Set Access Policy:

```
{
  "Version": "2008-10-17",
  "Id": "__default_policy_ID",
  "Statement": [
    {
      "Sid": "__owner_statement",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": [
        "SQS:*"
      ],
      "Resource": "arn:aws:sqs:us-west-1:087256792386:orderReceivedCA-[test, stage, production]-DLQ"
    }
  ]
}
```

#### Create an alarm for the DLQ

Create a CloudWatch alarm to notify the send an email to the alarms topic whenever there is a visible message in the queue.
- Queue metric: `ApproximateNumberOfMessagesVisible`
- Statistic: `Minimum`
- Threshold Value: `0`
- Send notifications to `alarms_fulfillment_[test, stage, production]`

### Create a Lambda Function

Using the AWS web interface:

- Specify the `Ruby 2.7 runtime`.
- Specify the `LambdaFullAccess` execution role.

### Configure the Lambda Function

Using the AWS web interface:

- Assign the protobuf layer.
- Add an S3 trigger:
  - Bucket: `smp-shared-[dev, stage, prod]`
  - Event Type: `All object create events`
  - Prefix: `ChannelAdvisorFeeds/Order/TO_SMP/` **Make sure there is a `/` suffix on the prefix or the trigger will enter an infinite loop!**
  - Suffix: `.json`
- Increase the timeout to 1 minute.
- Add a Dead-letter queue service:
  - Queue: `orderReceivedCA-[test, stage, production]-DLQ`
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
