./scripts/build_remote.sh

aws lambda update-function-code --profile personal --region us-west-2 --function-name bitcoin_bootstrap_api --zip-file fileb://lambda_function.zip
# rm lambda_function.zip
