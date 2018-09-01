import re
import subprocess


class SSHAgent:
    def __init__(self):
        self.pid = None
        self.auth_sock = None

    def start(self):
        comp = subprocess.run(
            ["ssh-agent", "-s"],
            text=True,
            capture_output=True,
            check=True,
        )

        results = dict(re.findall(r'((?:\w|_)+)=([^;]+);', comp.stdout))
        self.pid = results['SSH_AGENT_PID']
        self.auth_sock = results['SSH_AUTH_SOCK']

    def stop(self):
        subprocess.run(
            ["kill", self.pid],
            text=True,
            capture_output=True,
            check=True,
        )
        self.pid = None
        self.auth_sock = None

    def add_key(self, key_path):
        subprocess.run(
            ["ssh-add", key_path],
            text=True,
            check=True,
            env={
                'SSH_AGENT_PID': self.pid,
                'SSH_AUTH_SOCK': self.auth_sock,
            }
        )
