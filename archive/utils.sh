#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/vars.sh"


function dry() {
	printf "${COLOR_BLUE}[DRY_RUN] $@${COLOR_END}\n"
}

function debug() {
	printf "${COLOR_YELLOW}[DEBUG] $@${COLOR_END}\n"
}

function verbose() {
	printf "${COLOR_GREEN}[VERBOSE] $@${COLOR_END}\n"
}

function log() {
	printf "[LOG] $@\n"
}

function error() {
	printf "${COLOR_RED}[ERROR] $@${COLOR_END}\n"
}

function checkDependencies() {
	local DEPS=("$@")

	for DEP in "${DEPS[@]}"; do
		type $DEP &> /dev/null

		if [[ $? -ne 0 ]]; then
			error "MISSING DEPENDENCY: ${DEP}"
			printf "Please install ${DEP} and try again\n"
			exit 1
		fi
	done
}
