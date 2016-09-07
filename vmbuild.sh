#!/bin/bash

set -e -o pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

hostname=`echo "${BUILD}" | jq -r .metadata.name`

[ -e /tmp/stderr ] || mkfifo /tmp/stderr

{
  cat /run/secrets/kubernetes.io/serviceaccount/ca.crt
  echo -n $'\v'
  cat /run/secrets/kubernetes.io/serviceaccount/namespace
  echo -n $'\v'
  cat /run/secrets/kubernetes.io/serviceaccount/token
  echo -n $'\v'
  exec 3</tmp/stderr
  read allocated port registry_port remote <&3
  read allocated port master_port remote <&3
  cat <&3 >/dev/null &
  echo -n $registry_port $master_port $'\v'
  cat <<-EOF
		hostnamectl set-hostname ${hostname}
		hwclock --hctosys
		rm -f /root/.dockercfg
		(cd / && tar xf -)
	EOF
  [ -e /root/.dockercfg ] && extra_files="/root/.dockercfg"
  (cd /; tar cf - tmp/build.sh run/secrets ${extra_files})
  cat <<-EOF
		trap 'rm -rf /run/secrets' EXIT INT TERM

		`export -p`

    cd /root
		/tmp/build.sh
	EOF
} | ${script_dir}/vmconnect.sh
