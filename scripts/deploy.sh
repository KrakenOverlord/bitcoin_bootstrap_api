aws lambda update-function-code --profile andrew --region us-west-1 --function-name orderReceivedCA --zip-file fileb://lambda_function.zip
rm lambda_function.zip
