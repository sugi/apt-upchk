#!/bin/bash

workroot=/var/lib/apt-upchk/workroot


apt_get="apt-get -o Dir=${workroot} -o Dir::State::status=${workroot}/var/lib/dpkg/status"

if ! tmp="$(mktemp -p /tmp apt-upchk.XXXXXX)"; then
  echo "Can't create tempfile. Abort." >&2
  exit 100
fi

cleanup() {
  rm -f $tmp > /dev/null 2>&1
}
trap cleanup 0 SIGHUP SIGINT SIGABRT SIGQUIT SIGTERM

$apt_get -qq update 2> $tmp

if [ "$?" != "0" ]; then
  echo "Werning: errors when 'apt-get update'."
  cat "$tmp"
  echo
fi

$apt_get -u -s upgrade > $tmp

if ! egrep -q "^Inst " $tmp; then
  # no package upgraded.
  exit 0
fi

if grep -qi security: $tmp; then
  echo "== SECURITY UPDATE =="
  egrep "^Inst " $tmp | grep -i security: | sed -e 's/^Inst \(.*)\).*$/\1/'
  echo
fi

if (grep -i "^Inst " $tmp | grep -qiv security: ); then
  echo "== Update Package =="
  egrep "^Inst " $tmp | grep -iv security: | sed -e 's/^Inst \(.*)\).*$/\1/'
  echo
fi

if grep -q "have been kept back:" $tmp; then
  # XXX FIXME.
  echo "Werning: holded package exits."
  echo "[fixme] currentry no information."
fi

cleanup
