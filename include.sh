#!/bin/bash

logstamp() {
  #LC_NUMERIC="en_US.UTF-8" printf "[%12.2f]" `awk '{printf $1}' /proc/uptime`
  printf "[%14d]" "$SECONDS"
}

log () {
	echo -e "\e[1m$(logstamp) \e[21m\e[7m$* \e[0m"
}

die () {
  log "${@:2}"
  exit "$1"
}
