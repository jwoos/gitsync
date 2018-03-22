#!/usr/bin/env python3

import logging

from connections import ConnectionType
from arguments import parse_arguments


logging.basicConfig(level=logging.WARNING, format='%(asctime)s [%(levelname)s]: %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
logger = logging.getLogger()

def setup_logger(config):
    global logger

    if config['verbose']:
        logger.setLevel(logging.INFO)

    if config['debug']:
        logger.setLevel(logging.DEBUG)

def main():
    config = parse_arguments()

    setup_logger(config)

    logger.debug(config)


main()
