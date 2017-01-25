#!/bin/sh
set -e

USAGE="Deploy a new docker image to an existing WordPress instance in ECS/CloudFormation.

Usage:
  $0 <cf-stack> <cluster> <image>

Parameters:
  <cf-stack>   Name of the CloudFormation stack.
  <cluster>    Name of the ECS cluster.
  <image>      Name and tag of the docker image to deploy.

Example usage:
  $0 mystack-dev wp-dev image/to-deploy:1.0.0
"

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]
then
	echo "$USAGE"
	exit 1
fi

CF_STACK=$1
CLUSTER=$2
IMAGE=$3

export AWS_DEFAULT_OUTPUT="text"

##
# Get service and task names from CloudFormation stack
##
echo "Looking up CloudFormation stack"

CF_STACK_DESCRIPTION=$(aws cloudformation describe-stack-resources --stack-name "$CF_STACK")

TASK_ARN=$(echo "$CF_STACK_DESCRIPTION" | grep "WebTaskDefinition" | awk '{print $3;}')
TASK_FAMILY=$(aws ecs describe-task-definition --task-definition "$TASK_ARN" | awk 'NR==1 {print $2;}')

SERVICE_ARN=$(echo "$CF_STACK_DESCRIPTION" | grep "WebService" | awk '{print $3;}')
SERVICE_NAME=$(aws ecs describe-services --cluster "$CLUSTER" --service "$SERVICE_ARN" | awk 'NR==1 {print $9;}')

##
# Update the container definition to use new docker image
##
CURRENT_TASK=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --output json)
NEW_TASK=$(echo "$CURRENT_TASK" | python -c 'import json,sys;obj=json.load(sys.stdin);obj["taskDefinition"]["containerDefinitions"][0]["image"]="'$IMAGE'";print json.dumps(obj["taskDefinition"]["containerDefinitions"], separators=(",", ":"))')

##
# Register new task definition
##
echo "Registering new task definition for family $TASK_FAMILY"
NEW_TASK_REVISION=$(aws ecs register-task-definition --family "$TASK_FAMILY" --container-definitions "$NEW_TASK" | awk 'NR==1 {print $3;}')

##
# Update service to use new task definition
##
echo "Updating service $SERVICE_NAME in cluster $CLUSTER"
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE_NAME" --task-definition "$TASK_FAMILY:$NEW_TASK_REVISION" > /dev/null

if [ $? -eq 0 ]
then
    echo "Deployed $IMAGE to $CF_STACK"
    exit 0
else
    exit 1
fi
