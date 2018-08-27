import argparse

from connections import ConnectionType, RemoteType


def enum_action(enum):
    class EnumAction(argparse.Action):
        def __call__(self, parser, namespace, values, option_string=None):
            setattr(namespace, self.dest, enum[values])


def parse_arguments():
    parser = argparse.ArgumentParser(
        prog='gitsync',
        description='Manage your repositories across multiple locals and remotes'
    )

    parser.add_argument('username', help='GitHub username')
    parser.add_argument('action', help='pull | push')
    parser.add_argument('--token', help='GitHub token generated from https://github.com/settings/tokens')
    parser.add_argument('--connection', action=enum_action(ConnectionType), help='Connection to remote: https or ssh')
    parser.add_argument('--remote', action=enum_action(RemoteType), help='The type of remote: GitHub, GitLab, etc')
    parser.add_argument('--config', help='The path to the configuration file')
    parser.add_argument('-s', '--skip', action='store_true', help='Does a dry run without actually doing any operations')
    parser.add_argument('-d', '--debug', action='store_true', help='Debug mode')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose mode')

    args = parser.parse_args()

    config = {
        'remote': args.remote,
        'username': args.username,
        'token': args.token,
        'connection': args.connection,
        'debug': args.debug,
        'verbose': args.verbose,
    }

    return config
