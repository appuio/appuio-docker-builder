{
  cat <<-EOF
		(cd / && tar xf -)
	EOF
  (cd root; tar cf - tmp/build.sh run/secrets)
  cat <<-EOF
		trap 'rm -rf /run/secrets' EXIT

		`export -p`

		/tmp/build.sh
	EOF
} | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -R 5000:172.30.1.1:5000 builder@buildvm1.beta.puzzle.cust.vshn.net ssh -R 5000:localhost:5000 default sudo bash
