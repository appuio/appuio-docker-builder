#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

{
  cat <<-EOF
		(cd / && tar xf -)
	EOF
  (cd /; tar cf - /tmp/build.sh /run/secrets)
  cat <<-EOF
		trap 'rm -rf /run/secrets' EXIT

		`export -p`

		/tmp/build.sh
	EOF
} | ${SCRIPT_DIR}/vmconnect.sh
