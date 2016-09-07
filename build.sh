#!/bin/bash
set -e -o pipefail
IFS=$'\n\t'

DOCKER_SOCKET=/var/run/docker.sock

if [ ! -e "${DOCKER_SOCKET}" ]; then
  echo "Docker socket missing at ${DOCKER_SOCKET}"
  exit 1
fi

echo "APPUiO Docker Builder"

if [ -n "${OUTPUT_IMAGE}" ]; then
  DOCKER_TAG="${OUTPUT_REGISTRY}/${OUTPUT_IMAGE}"
else
  DOCKER_TAG=`echo "${BUILD}" | jq -r '.spec.output.to.name // empty'`
fi

# Disabled to work around rhbz#1346167
# BASE_IMAGE=`echo "${BUILD}" | jq -r '.spec.strategy.dockerStrategy.from.name // empty'`

CONTEXT_DIR=`echo "${BUILD}" | jq -r '.spec.source.contextDir // "."'`
INLINE_DOCKERFILE=`echo "${BUILD}" | jq -r '.spec.source.dockerfile // empty'`
DOCKERFILE_PATH=`echo "${BUILD}" | jq -r ".spec.strategy.dockerStrategy.dockerfilePath // \"${DOCKERFILE_PATH:-Dockerfile}\""`
SECRET_NAMES=`echo "${BUILD}" | jq -r '.spec.source.secrets[]?.secret.name'`
FORCE_PULL=`echo "${BUILD}" | jq -r '.spec.strategy.dockerStrategy.forcePull // .spec.strategy.customStrategy.forcePull // "false"'`
NO_CACHE=`echo "${BUILD}" | jq -r ".spec.strategy.dockerStrategy.noCache // \"${NO_CACHE:-false}\""`

if [ -n "${SOURCE_REF}" ]; then
  SOURCE_REF=master
fi

BUILD_DIR=$(mktemp --directory)
trap 'cd /tmp; rm -rf ${BUILD_DIR}' EXIT INT TERM

if [ -n "${SOURCE_REPOSITORY}" ]; then
  git clone --recursive "${SOURCE_REPOSITORY}" "${BUILD_DIR}"
  if [ $? != 0 ]; then
    echo "Error trying to fetch git source: ${SOURCE_REPOSITORY}"
    exit 1
  fi
  cd "${BUILD_DIR}"
  git checkout "${SOURCE_REF}"
  if [ $? != 0 ]; then
    echo "Error trying to checkout branch: ${SOURCE_REF}"
    exit 1
  fi
fi

cd "${BUILD_DIR}/${CONTEXT_DIR}"

if [ -n "${INLINE_DOCKERFILE}" ]; then
  echo -e "${INLINE_DOCKERFILE}" >Dockerfile
fi

if [ -n "${BASE_IMAGE}" ]; then
  sed -i "s|^FROM.*|FROM ${BASE_IMAGE}|" "${DOCKERFILE_PATH}"
fi

for SECRET in ${SECRET_NAMES}; do
  DESTINATION_DIR=`echo "$BUILD" | jq -r '(.spec.source.secrets[].secret | select(.name == "${SECRET}").destinationDir) // "."'`
  cp -a /var/run/secrets/openshift.io/build/${SECRET}/* "${DESTINATION_DIR}"
done

DOCKER_ARGS=("build")

if [ "${FORCE_PULL}" == "true" ]; then
  DOCKER_ARGS+=("--pull")
fi

if [ "${NO_CACHE}" == "true" ]; then
  DOCKER_ARGS+=("--no-cache")
fi

DOCKER_ARGS+=("--rm" "-t" "${DOCKER_TAG}" "-f" "${DOCKERFILE_PATH}" .)

export DOCKERFILE_PATH DOCKER_TAG DOCKER_ARGS FORCE_PULL NO_CACHE
if [ -x .d2i/pre_build ]; then
  .d2i/pre_build "${DOCKERFILE_PATH}" "$DOCKER_TAG"
fi

echo docker "${DOCKER_ARGS[@]}"
docker "${DOCKER_ARGS[@]}"

if [[ -d /var/run/secrets/openshift.io/push ]] && [[ ! -e /root/.dockercfg ]]; then
  cp /var/run/secrets/openshift.io/push/.dockercfg /root/.dockercfg
fi

if [ -n "${DOCKER_TAG}" ] || [ -s "/root/.dockercfg" ]; then
  docker push "${DOCKER_TAG}"
fi

if [ -x .d2i/post_build ]; then
  .d2i/post_build
fi
