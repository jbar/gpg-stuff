#!/bin/bash
# -*- mode: sh; tabstop: 4; shiftwidth: 4; softtabstop: 4; -*-

# Note: this script use to get keys with signatures. As, since sks-pool security design issue have been exploited they use to send key with no signature.
# It may also sometime get some keys that some other tools don't find.


#set -x

helpmsg="Usage: $0 [OPTIONS...] FILE_CONTAINING_FINGERPRINTS

General options:
    -h, --help             this help
    -V, --version          show version and exit
"

for ((;$#;)) ; do
	case "$1" in
		-h|--h*) echo "$helpmsg" ; exit ;;
		-V|--vers*) echo "$0 0.1" ; exit ;;
		*) [ -f "$1" -a -r "$1" ] && file="$1" || { echo "Error: $1 is not a readable file" >&2 ; exit 2 ; } ;;
	esac
	shift
done

cat "$file" | tr -d ' ' | grep -o "[a-fA-F0-9]\{40\}" | while read fpr ; do
	curl -v "http://keys.gnupg.net/pks/lookup?op=get&search=0x$fpr" | gpg --import
done

