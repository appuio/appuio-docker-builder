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
  TAG="${OUTPUT_REGISTRY}/${OUTPUT_IMAGE}"
else
  TAG=`echo "${BUILD}" | jq -r .spec.output.to.name`
fi

INLINE_DOCKERFILE=`echo "${BUILD}" | jq -r '.spec.source.dockerfile // empty'`
DOCKERFILE_PATH=`echo "${BUILD}" | jq -r '.spec.strategy.dockerStrategy.dockerFilePath // "Dockerfile"'`
SECRET_NAMES=`echo "${BUILD}" | jq -r '.spec.source.secrets[].secret.name'`

if [[ "${SOURCE_REPOSITORY}" != "git://"* ]] && [[ "${SOURCE_REPOSITORY}" != "git@"* ]]; then
  URL="${SOURCE_REPOSITORY}"
  if [[ "${URL}" != "http://"* ]] && [[ "${URL}" != "https://"* ]]; then
    URL="https://${URL}"
  fi
  curl --head --silent --fail --location --max-time 16 $URL > /dev/null
  if [ $? != 0 ]; then
    echo "Could not access source url: ${SOURCE_REPOSITORY}"
    exit 1
  fi
fi

if [ -n "${SOURCE_REF}" ]; then
  SOURCE_REF=master
fi

BUILD_DIR=$(mktemp --directory)
trap 'rm -rf ${BUILD_DIR}' EXIT
if [ -n "${SOURCE_REPOSITORY}" ]; then
  git clone --recursive "${SOURCE_REPOSITORY}" "${BUILD_DIR}"
  if [ $? != 0 ]; then
    echo "Error trying to fetch git source: ${SOURCE_REPOSITORY}"
    exit 1
  fi
  pushd "${BUILD_DIR}"
  git checkout "${SOURCE_REF}"
  if [ $? != 0 ]; then
    echo "Error trying to checkout branch: ${SOURCE_REF}"
    exit 1
  fi
  popd
fi

if [ -n "${INLINE_DOCKERFILE}" ]; then
  echo -e "${INLINE_DOCKERFILE}" >"${BUILD_DIR}/Dockerfile"
fi

for SECRET in ${SECRET_NAMES}; do
  DESTINATION_DIR=`echo "$BUILD" | jq '(.spec.source.secrets[].secret | select(.name == "${SECRET}").destinationDir) // "./"'`
  cp -a /var/run/secrets/openshift.io/build/${SECRET}/* "${BUILD_DIR}/${DESTINATION_DIR}"
done

docker build --rm -t "${TAG}" -f "${BUILD_DIR}/${DOCKERFILE_PATH}" "${BUILD_DIR}"

if [[ -d /var/run/secrets/openshift.io/push ]] && [[ ! -e /root/.dockercfg ]]; then
  cp /var/run/secrets/openshift.io/push/.dockercfg /root/.dockercfg
fi

if [ -n "${OUTPUT_IMAGE}" ] || [ -s "/root/.dockercfg" ]; then
  docker push "${TAG}"
fi
