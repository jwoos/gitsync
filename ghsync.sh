#!/usr/bin/env bash

END="\033[0m"
BLACK="\033[0;30m"
WHITE="\033[0;37m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"

TRUE=1
FALSE=0

function usage() {
	TEXT="
		Usage: ${0} -u USERNAME -t TOKEN [-d | -h] [-c CONNECTION] \n
		\t-u USERNAME ===> your Github username \n
		\t-t TOKEN ======> your token - if you don't have one generate one from https://github.com/settings/tokens \n
		\t-h ============> display this menu \n
		\t-d ============> debug mode \n
		\t-x ============> does a dry run without actually doing any git operations \n
		\t-c CONNECTION => connection to GitHub either 'ssh' or 'git', defaults to 'ssh'
	"
	if [[ $1 == $TRUE ]]; then
		echo -e $TEXT 1>&2
	else
		echo -e $TEXT
	fi
}

function dry() {
	echo -e "${BLUE}[DRY_RUN] $1${END}"
}

function debug() {
	echo -e "${YELLOW}[DEBUG] $1${END}"
}

DEBUG=$FALSE

while getopts "hdxu:t:c:" O; do
	case "${O}" in
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
			CONNECTION="${OPTARG}"
			;;
		x)
			DRY_RUN=$TRUE
			;;
		*)
			usage
			exit 0
			;;
	esac
done
shift $((OPTIND - 1))

if [[ -z $USERNAME ]] || [[ -z $TOKEN ]]; then
	usage $TRUE
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

GITHUB_BASE='https://api.github.com'
GITHUB_PER_PAGE=30

USER_FILE=$(mktemp)
if [[ $DEBUG -eq $TRUE ]]; then
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
if [[ $DEBUG -eq $TRUE ]]; then
	debug $REPO_COUNT
fi

REPO_FILE=$(mktemp)
if [[ $DEBUG -eq $TRUE ]]; then
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
	if [[ $DEBUG -eq $TRUE ]]; then
		debug $CHUNKED_URLS
	fi


	while read -r GH_URL; do
		URLS+=("${GH_URL}")
		if [[ $DEBUG -eq $TRUE ]]; then
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
	if [[ $DEBUG -eq $TRUE ]]; then
		debug "DIRECTORY: ${DIRECTORY}"
	fi

	GH_URL="$(echo $GH_URL | sed $STRIP_QUOTATIONS_PATTERN)"

	if [[ -d ${DIRECTORY} ]]; then
		pushd ${DIRECTORY}

		BRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)

		if [[ $DRY_RUN -eq $TRUE ]]; then
			dry "checking out master"
		else
			git checkout master
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

		popd
	else
		if [[ $DRY_RUN -eq $TRUE ]]; then
			dry "cloning ${GH_SSH_URL}"
		else
			git clone $GH_SSH_URL
			git remote set-url origin $GH_SSH_URL
		fi
	fi
done
