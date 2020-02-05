#!/bin/bash
# -*- mode: sh; tabstop: 4; shiftwidth: 4; softtabstop: 4; -*-

# Note: this script may be useless if you know how to correctly configure and use 'caff' from package 'signing-party'.
# Tip: for caff and in vim: use following command to easily fill (or not) boxes from a printed version:
# :%s,\[ \] Fingerprint OK        \[ \] ID OK,[x] Fingerprint OK        [x] ID OK,gc


#set -x

default_key="$(gpg --list-secret-keys --with-colons | grep -m1 "^sec" | cut -d: -f 5)"
#default_keyserver="ksp.fosdem.org" #alas this key server seems not running anymore: can't send or recv key at this time: Mon, 03 Feb 2020 02:45:51
#default_keyserver="hkps://keyserver.ubuntu.com" #WTF... since precedent attacks on sks network there seems to be no key servers running properly ... :-/
default_keyserver="keys.gnupg.net"

rks="$default_keyserver"

helpmsg="Usage: $0 [OPTIONS...] KSP_FILE

General options:
    -r, --recv-from URL    key server to retrieve OpenPGP certificate to sign (default: $rks)
    -s, --send-to   URL    key server to send signed OpenPGP certificate (default: $default_keyserver)
    -k, --key       KEYID  key ID to use for signing uids in OpenPGP certificates (default: $default_key)
    -h, --help             this help
    -V, --version          show version and exit

Notes:
    option '--send-to' may be used multiple time to send key to multiple servers
    option '--key' may be used multiple time to certificates uids with multiple keys
    if --key \"\" is used, $(basename "$0") will try to use caff for signing, which is a good idea as caff may also send mail.
"

for ((;$#;)) ; do
	case "$1" in
		-r|--r*) shift ; rks="$1" ;;
		-s|--s*) shift ; sendks+=("$1") ;;
		-k|--k*) shift ; keyid+=("$1") ;;
		-h|--h*) echo "$helpmsg" ; exit ;;
		-V|--vers*) echo "$0 0.2" ; exit ;;
		*) [ -f "$1" -a -r "$1" ] && ksp_file="$1" || { echo "Error: $1 is not a readable file" >&2 ; exit 2 ; } ;;
	esac
	shift
done

[[ "$ksp_file" ]] || { echo "$helpmsg" >&2 ; exit 2 ; }

((${#sendks[@]})) || sendks=("$default_keyserver")
((${#keyid[@]})) || keyid=("$default_key")
if [[ -z "${keyid[0]}" ]] ; then
	echo "Info: No key given using option -k, assume using configured caff from package 'signing-party'"
	caff --version && gpgoption4caff="--no-default-keyring --keyring $HOME/.caff/gnupghome/pubring.kbx" || exit 3
fi

exec 10<&0

while read d type etc ; do
	if [[ $d == pub ]] ; then
		read
		fpr=${REPLY// /}
		echo -e "$d  $etc\n$fpr"
		while read d uid && [[ $d == uid ]] ; do
			echo "$d $uid"
		done
		for ((;;)) ; do
			read -p " Did this individual validate its fingerprint and did you verify its ID (y/N) [No] ? " rep <&10
			case "$rep" in
			  [yY]*)
				if [[ "$rks" == keys.gnupg.net ]] ; then
					curl -v "http://$rks/pks/lookup?op=get&search=0x$fpr" | gpg --import $gpgoption4caff
				else
					gpg --verbose --keyserver "$rks" --recv-key $gpgoption4caff "$fpr"
				fi
				if [[ "$gpgoption4caff" ]] ; then
					caff "$fpr" <&10
				else
					for k in "${keyid[@]}" ; do
						gpg --sign-key -u "$k"\! "$fpr"
					done
				fi
				for ks in "${sendks[@]}" ; do
					gpg --keyserver $ks --send-key $gpgoption4caff "$fpr"
				done
				break
				;;
			  ""|[nN]*) break ;;
			  *) echo "  please answer \"yes\" or \"no\"" ;;
			esac
		done
	fi
done <"$ksp_file"

exec 10<&-

