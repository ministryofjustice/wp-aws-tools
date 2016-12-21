#!/bin/sh

#REGISTRY="ecr-registry-url"
#IMAGE="image-name"
#TAG="image-tag"

##
# Login to docker registry
##
LOGIN=$(aws ecr get-login --region eu-west-1)
if [ $? -ne 0 ] || ! eval $LOGIN
then
	echo "ERROR: Could not login to AWS ECR"
	exit 1
fi

##
# Build and push docker image
##
docker build -t "$REGISTRY/$IMAGE:$TAG" .
docker push "$REGISTRY/$IMAGE:$TAG"

exit $?
