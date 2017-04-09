#!/usr/bin/env bash

END="\033[0m"
BLACK="\033[0;30m"
WHITE="\033[0;37m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"

function printUsage() {
	echo 'USAGE:'
	echo -e "\t./gh_sync.sh <USERNAME> <TOKEN>"
	echo -e "\tUSERNAME: your GitHub username"
	echo -e "\tTOKEN: your token - if you don't have one generate one from https://github.com/settings/tokens"
}

function debug() {
	echo -e "${YELLOW}[DEBUG] $1${END}"
}

if [[ $# -ne 2 ]]; then
	echo -e "${RED}Illegal number of parameters\n${END}"
	printUsage
	exit 1
fi

DEPS=('jq' 'cat' 'less' 'curl' 'git' 'sed' 'bc')

for DEP in "${DEPS[@]}"; do
	type $DEP > /dev/null 2>&1

	if [[ $? -ne 0 ]]; then
		echo -e "${RED}MISSING DEPENDENCY: ${DEP}${END}"
		echo -e "Please install ${DEP} and try again"
		exit 1
	fi
done

USERNAME=$1
TOKEN=$2

GITHUB_BASE='https://api.github.com'
GITHUB_PER_PAGE=30

USER_FILE=$(mktemp)
if [[ "$DEBUG" == true ]]; then
	debug "${YELLOW}${USER_FILE}${END}"
fi

curl -s -u $USERNAME:$TOKEN $GITHUB_BASE/user > $USER_FILE

# User has lots of keys, it should be bigger than 8 if successful
if [[ $(less $USER_FILE | jq 'length' 2>/dev/null) -lt 8 ]]; then
	echo -e "${RED}Error fetching user${END}"
	echo 'Response: '
	cat $USER_FILE
	exit 1
fi

# Query user information and get total repository count (private + public) that are owned by $USERNAME
REPO_COUNT=$(less $USER_FILE | jq '.owned_private_repos , .public_repos' | paste -sd+ | bc)
if [[ "$DEBUG" == true ]]; then
	debug $REPO_COUNT
fi

REPO_FILE=$(mktemp)
if [[ "$DEBUG" == true ]]; then
	debug $REPO_FILE
fi

EXTRACTION_PATTERN="s/https:\/\/github.com\/${USERNAME}\/\([a-zA-Z0-9_-]\+\)\.git/\1/"
STRIP_QUOTATIONS_PATTERN="s/\"//g"
PID_EXTRACTION_PATTERN="s/Agent pid \([0-9]\+\)$/\1/"

PAGE=0
URLS=()

while [ $(($PAGE * $GITHUB_PER_PAGE)) -lt $REPO_COUNT ]; do
	curl -s -H "Authorization: token ${TOKEN}" "${GITHUB_BASE}/user/repos?type=owner&page=$((PAGE+1))" > $REPO_FILE

	# Check if in an array and has message
	if [[ -z $(less $REPO_FILE | jq '.[] | .message' 2>/dev/null) ]]; then
		echo -e "${RED}Error fetching repositories${END}"
		echo 'Response: '
		cat $REPO_FILE
		exit 1
	fi

	CHUNKED_URLS=$(less $REPO_FILE | jq '.[] | .clone_url')
	if [[ "$DEBUG" == true ]]; then
		debug $CHUNKED_URLS
	fi


	while read -r GH_URL; do
		URLS+=("${GH_URL}")
		if [[ "$DEBUG" == true ]]; then
			debug "Working on: ${GH_URL}"
		fi
	done <<< "$CHUNKED_URLS"

	((PAGE+=1))
done

SSH_AGENT_PID=$(eval $(ssh-agent -s)) | sed $PID_EXTRACTION_PATTERN
ssh-agent add ~/.ssh/id_rsa

for GH_URL in "${URLS[@]}"; do
	DIRECTORY=$(echo $GH_URL | sed $EXTRACTION_PATTERN | sed $STRIP_QUOTATIONS_PATTERN)
	GH_SSH_URL="git@github.com:${USERNAME}/${DIRECTORY}.git"
	if [[ "$DEBUG" == true ]]; then
		debug "DIRECTORY: ${DIRECTORY}"
	fi

	GH_URL="$(echo $GH_URL | sed $STRIP_QUOTATIONS_PATTERN)"

	if [[ -d ${DIRECTORY} ]]; then
		pushd ${DIRECTORY}

		BRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)

		git checkout master

		# if checkout errors while switching to master just fetch
		if [[ $? -ne 0 ]]; then
			git fetch
		else
			git pull origin master
			git checkout $BRANCH
		fi

		popd
	else
		git clone $GH_SSH_URL
		git remote set-url origin $GH_SSH_URL
	fi
done
