#!/usr/bin/env python3

import asyncio
import logging
import os
import subprocess

from connections import ConnectionType
from arguments import parse_arguments
import interfaces.github as github

import uvloop


logging.basicConfig(level=logging.WARNING, format='%(asctime)s [%(levelname)s]: %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
logger = logging.getLogger()


def setup_logger(config) -> None:
    global logger

    if config.verbose:
        logger.setLevel(logging.INFO)

    if config.debug:
        logger.setLevel(logging.DEBUG)

async def main():
    config = parse_arguments()

    setup_logger(config)

    username = config.username
    token = config.token
    user = await github.get_user(username, token)

    repos = await github.get_repositories(user, token)
    repos = [
        repo for inner in repos for repo in inner
    ]

    if config.connection == ConnectionType.SSH:
        urls = [
            repo['ssh_url'] for repo in repos
        ]
    else:
        urls = [
            repo['clone_url'] for repo in repos
        ]

    working_directory = os.getcwd()
    current_directories = os.listdir(path=working_directory)

    # directories = set([repo['name'] for repo in repos]) - current_directories


if __name__ == '__main__':
    asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
    event_loop = asyncio.get_event_loop()
    event_loop.run_until_complete(main())
