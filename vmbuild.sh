#!/bin/bash

set -e -o pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#secrets_dir=${secrets_dir:-/run/secrets}

#		`cat secrets/kubernetes.io/serviceaccount/ca.crt | tr '\n' ';'`

hostname=`echo "${BUILD}" | jq -r .metadata.name`

env

{
  cat /run/secrets/kubernetes.io/serviceaccount/ca.crt
  echo $'\v'
  cat /run/secrets/kubernetes.io/serviceaccount/namespace
  echo $'\v'
	cat /run/secrets/kubernetes.io/serviceaccount/token
  echo $'\v'
  cat <<-EOF
		hostnamectl set-hostname ${hostname}
		hwclock --hctosys
		rm -f /root/.dockercfg
		(cd / && tar xf -)
	EOF
  [ -e /root/.dockercfg ] && extra_files="/root/.dockercfg"
  (cd /; tar cf - tmp/build.sh run/secrets ${extra_files})
  cat <<-EOF
		trap 'rm -rf /run/secrets' EXIT

		`export -p`

    cd /root
		/tmp/build.sh
	EOF
} | ${script_dir}/vmconnect.sh
