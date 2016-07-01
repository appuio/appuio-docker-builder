#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#		`cat secrets/kubernetes.io/serviceaccount/ca.crt | tr '\n' ';'`

{
  cat <<-EOF    
		`cat /run/secrets/kubernetes.io/serviceaccount/namespace`
		`cat /run/secrets/kubernetes.io/serviceaccount/token`
    rm -f /root/.dockercfg
		(cd / && tar xf -)
	EOF
  [ -e /root/.dockercfg ] && EXTRA_FILES="/root/.dockercfg"
  (cd /; tar cf - tmp/build.sh run/secrets ${EXTRA_FILES})
  cat <<-EOF
		trap 'rm -rf /run/secrets' EXIT

		`export -p`

    cd /root
		/tmp/build.sh
	EOF
} | ${SCRIPT_DIR}/vmconnect.sh
