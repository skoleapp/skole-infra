#!/bin/sh

# Get the the latest tag in the given ECR repo.

aws ecr describe-images --repository-name="$1" --query='sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output=text
