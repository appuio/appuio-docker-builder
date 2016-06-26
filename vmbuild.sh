#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

{
  cat <<-EOF
    rm -f /root/.dockercfg
		(cd / && tar xvf -)
	EOF
  (cd /; tar cf - tmp/build.sh run/secrets root/.dockercfg)
  cat <<-EOF
		# trap 'rm -rf /run/secrets' EXIT

		`export -p`

    cd /root

    env

		/tmp/build.sh
	EOF
} | ${SCRIPT_DIR}/vmconnect.sh
