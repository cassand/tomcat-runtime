#!/bin/bash

# Copyright 2016 Google Inc. All rights reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# Runs integration tests on a given runtime image

readonly dir=$(dirname $0)
readonly projectRoot=${dir}/..
readonly testAppDir=${projectRoot}/tests/test-war-integration
readonly deployDir=${testAppDir}/target/docker-src
readonly service="tomcat-runtime-integration"

readonly imageUnderTest=$1
if [ -z "${imageUnderTest}" ]; then
  echo "Usage: ${0} <image_under_test>"
  exit 1
fi

# build the test app
pushd ${testAppDir}
  mvn -B -P-local-docker-build -P-local.test clean install
popd

# deploy to app engine
pushd $deployDir
  export STAGING_IMAGE=$imageUnderTest
  envsubst '$STAGING_IMAGE' < Dockerfile.in > Dockerfile
  echo "Deploying to App Engine..."
  gcloud app deploy -q
popd

readonly DEPLOYED_APP_URL="https://${service}-dot-$(gcloud app describe | grep defaultHostname | awk '{print $2}')"
echo "Running integration tests on application that is deployed at $DEPLOYED_APP_URL"

# run in cloud container builder
gcloud container builds submit \
  --config $testAppDir/target/cloudbuild/integration.yaml \
  --substitutions "_DEPLOYED_APP_URL=$DEPLOYED_APP_URL" \
  --timeout=25m \
  ${dir}