from enum import Enum


class RemoteType(Enum):
    GITHUB = 1
    GITLAB = 2
    OTHER = 3


class ConnectionType(Enum):
    SSH = 1
    HTTPS = 2
