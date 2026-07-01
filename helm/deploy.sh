#!/bin/bash
SERVER=$1
NAMESPACE=$2
# Usage: ./deploy.sh <env> <namespace>
# Example: ./deploy.sh uat default

helm upgrade --install supertokens ./ \
  -f ./values/base.yaml \
  -f ./values/$SERVER.yaml \
  -n $NAMESPACE
