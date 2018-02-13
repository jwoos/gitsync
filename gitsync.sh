#!/usr/bin/env bash

set -u

source "${BASH_SOURCE%/*}/vars.sh"

trap 'cleanUp' SIGINT SIGTERM SIGKILL

function cleanUp() {
	debug 'CLEANING UP'
}

function usage() {
	local TEXT=$(
	cat << EOM
Usage: ${0} -u USERNAME -t TOKEN [-d | -h] [-c CONNECTION]
	-u USERNAME      your Github username
	-t TOKEN         your token - if you don't have one generate one from https://github.com/settings/tokens
	-h               display this menu
	-d               debug mode
	-x               does a dry run without actually doing any git operations
	-c CONNECTION    connection to GitHub either 'ssh' or 'https', defaults to 'ssh'
	-v               verbose logging
EOM
	)

	if [[ $1 -eq $TRUE ]]; then
		printf "${TEXT}\n" 1>&2
	else
		printf "${TEXT}\n"
	fi
}

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

DEBUG=$FALSE
VERBOSE=$FALSE
DRY_RUN=$FALSE
TOKEN=''
USERNAME=''

while getopts "hdxvu:t:c:" OPT; do
	case "${OPT}" in
		h)
			usage
			exit 0
			;;
		d)
			DEBUG=$TRUE
			;;
		u)
			USERNAME="${OPTARG}"
			;;
		t)
			TOKEN="${OPTARG}"
			;;
		c)
			CONNECTION="${OPTARG:-ssh}"
			;;
		x)
			DRY_RUN=$TRUE
			;;
		v)
			VERBOSE=$TRUE
			;;
		*)
			usage
			exit 0
			;;
	esac
done
shift $((OPTIND - 1))

CONNECTION=${CONNECTION:-ssh}

if [[ -z $USERNAME ]] || [[ -z $TOKEN ]]; then
	usage $TRUE
	exit 1
fi

DEPS=('jq' 'cat' 'less' 'curl' 'git' 'bc')

for DEP in "${DEPS[@]}"; do
	type $DEP &> /dev/null

	if [[ $? -ne 0 ]]; then
		error "MISSING DEPENDENCY: ${DEP}"
		printf "Please install ${DEP} and try again\n"
		exit 1
	fi
done

GITHUB_BASE='https://api.github.com'
GITHUB_PER_PAGE=30

USER_FILE=$(mktemp)
if [[ $DEBUG -eq $TRUE ]]; then
	debug "USER_FILE: ${USER_FILE}"
fi

curl -s -u $USERNAME:$TOKEN $GITHUB_BASE/user > $USER_FILE

# User has lots of keys, it should be bigger than 8 if successful
if [[ $(less $USER_FILE | jq 'length' 2>/dev/null) -lt 8 ]]; then
	error "Error fetching user"
	printf 'Response: \n'
	cat $USER_FILE
	exit 1
fi

# Query user information and get total repository count (private + public) that are owned by $USERNAME
REPO_COUNT=$(less $USER_FILE | jq '.owned_private_repos , .public_repos' | paste -sd+ | bc)
if [[ $DEBUG -eq $TRUE ]]; then
	debug "REPO_COUNT: ${REPO_COUNT}"
fi

REPO_FILE=$(mktemp)
if [[ $DEBUG -eq $TRUE ]]; then
	debug "REPO_FILE: ${REPO_FILE}"
fi

PAGE=0
HTTPS_URLS=()
SSH_URLS=()
DIRECTORIES=()

while [[ $(($PAGE * $GITHUB_PER_PAGE)) -lt $REPO_COUNT ]]; do
	curl -s -H "Authorization: token ${TOKEN}" "${GITHUB_BASE}/user/repos?type=owner&page=$((PAGE+1))" > $REPO_FILE

	# Check if in an array and has message
	if [[ -z $(less $REPO_FILE | jq '.[] | .message' 2>/dev/null) ]]; then
		error "Error fetching repositories"
		printf 'Response: \n'
		cat $REPO_FILE
		exit 1
	fi

	HTTPS_URLS+=( $(less $REPO_FILE | jq -r '.[] | .clone_url') )
	SSH_URLS+=( $(less $REPO_FILE | jq -r '.[] | .ssh_url') )
	DIRECTORIES+=( $(less $REPO_FILE | jq -r '.[] | .name') )

	if [[ $DEBUG -eq $TRUE ]]; then
		debug "NEW PAGE"
	fi

	((PAGE+=1))
done

if [[ $CONNECTION == 'ssh' ]]; then
	# SSH_AGENT_PID is provided by the following command
	eval $(ssh-agent -s)
	ssh-add ~/.ssh/id_rsa

	if [[ $DEBUG -eq $TRUE ]]; then
		debug "SSH agent PID: ${SSH_AGENT_PID}"
	fi
elif [[ $CONNECTION == 'https' ]]; then
	error "HTTPS not implemented yet"
	exit 1
else
	error "Invalid connection"
	exit 1
fi

for INDEX in "${!HTTPS_URLS[@]}"; do
	DIRECTORY="${DIRECTORIES[$INDEX]}"
	GH_SSH_URL="${SSH_URLS[$INDEX]}"
	GH_HTTPS_URL="${HTTPS_URLS[$INDEX]}"

	if [[ $DEBUG -eq $TRUE ]]; then
		debug "DIRECTORY: ${DIRECTORY}"
		debug "SSH_URL: ${GH_SSH_URL}"
		debug "HTTPS_URL: ${GH_HTTPS_URL}"
	fi

	if [[ -d ${DIRECTORY} ]]; then
		pushd ${DIRECTORY} &> /dev/null

		BRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)

		if [[ $DRY_RUN -eq $TRUE ]]; then
			dry "checking out master"
		else
			# git stash
			# STASH_CODE=$?
			git checkout master
			# git stash pop
		fi

		# if checkout errors while switching to master just fetch
		if [[ $? -ne 0 ]]; then
			if [[ $DRY_RUN -eq $TRUE ]]; then
				dry "checkout failed, fetching"
			else
				git fetch
			fi
		else
			if [[ $DRY_RUN -eq $TRUE ]]; then
				dry "pull origin and switching back to original branch: ${BRANCH}"
			else
				git pull origin master
				git checkout $BRANCH
			fi
		fi

		popd &> /dev/null
	else
		if [[ $DRY_RUN -eq $TRUE ]]; then
			dry "cloning ${GH_SSH_URL}"
		else
			git clone $GH_SSH_URL
		fi
	fi
done

if [[ $CONNECTION == 'ssh' ]]; then
	kill $SSH_AGENT_PID
fi
