#!/usr/bin/env bash

function usage() {
	echo "Usage: $0 [-s <45|90>] [-p <string>]" 1>&2
	exit 1
}

while getopts "s:p:" O; do
    case "${O}" in
        s)
            s=${OPTARG}
            ;;
        p)
            p=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND - 1))

if [ -z "${s}" ] || [ -z "${p}" ]; then
    usage
fi

echo "s = ${s}"
echo "p = ${p}"
