#!/bin/sh
set -e

# Kamal Install
if ! command -v kamal >/dev/null 2>&1; then
  echo "Installing Kamal..."
  gem install kamal
fi

kamal version
ruby --version

if [ -z "${DEPLOY_VERSION}" ]; then
  # No version specified - use current commit (will build new image)
  DEPLOY_VERSION=$(git rev-parse HEAD)
  echo "No DEPLOY_VERSION specified, using current commit: $DEPLOY_VERSION"
else
  # Version specified - check if image exists
  echo "DEPLOY_VERSION specified: ${DEPLOY_VERSION}"
fi
 
echo "KAMAL_STAGE: $KAMAL_STAGE"
echo "DEPLOY_VERSION: $DEPLOY_VERSION"

kamal server bootstrap -d ${KAMAL_STAGE}
kamal build push -d ${KAMAL_STAGE}
kamal deploy --skip-push -d ${KAMAL_STAGE} --version ${DEPLOY_VERSION}

