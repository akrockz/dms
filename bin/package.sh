#!/bin/bash

set -e

echo "coreservices-dms package script running."

# This script's directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Setup, cleanup.
STAGING="${DIR}/../_staging"
echo "STAGING=${STAGING}"
cd $DIR
mkdir -p $STAGING 
rm -rf $STAGING/*

# Copy deployspec and CFN templates into staging folder.
cp -pr $DIR/../*.yaml $STAGING/

echo "coreservices-dms package step complete, run.sh can be executed now."
