
source ~/.cred/aws.sh

tofu apply \
  -var="deployment_name=flash-test" \
  -var="aws_access_key=$KEY"        \
  -var="aws_secret_key=$SEC"        \
  -auto-approve