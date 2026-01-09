
source ~/.cred/aws.sh

tofu destroy \
  -var="deployment_name=flash-test" \
  -var="aws_access_key=$KEY"        \
  -var="aws_secret_key=$SEC"        \
  -auto-approve