#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

{
  cat <<-EOF
		(cd / && tar xvf -)
	EOF
  (cd /; tar cf - tmp/build.sh run/secrets)
  cat <<-EOF
		# trap 'rm -rf /run/secrets' EXIT

		`export -p`

    cd /root

    env

		/tmp/build.sh
	EOF
} | ${SCRIPT_DIR}/vmconnect.sh
