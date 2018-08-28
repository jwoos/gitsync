import argparse

from connections import ConnectionType, RemoteType


def parse_arguments() -> None:
    parser = argparse.ArgumentParser(
        prog='gitsync',
        description='Manage your repositories across multiple locals and remotes'
    )

    parser.add_argument('username', help='GitHub username')
    parser.add_argument('action', help='info, pull, push')
    parser.add_argument(
        '--token',
        help='GitHub token generated from https://github.com/settings/tokens',
    )
    parser.add_argument(
        '--connection',
        type=lambda connection: ConnectionType[connection],
        choices=list(ConnectionType),
        help='Connection to remote: https or ssh',
    )
    parser.add_argument(
        '--remote',
        type=lambda remote: RemoteType[remote],
        choices=list(RemoteType),
        help='The type of remote: GitHub'
    )
    parser.add_argument('--config', help='The path to the configuration file')
    parser.add_argument(
        '-s',
        '--skip',
        action='store_true',
        help='Does a dry run without actually doing any operations',
    )
    parser.add_argument('-d', '--debug', action='store_true', help='Debug mode')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose mode')

    args = parser.parse_args()

    return args
