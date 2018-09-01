import subprocess


def update_repo():
    status = subprocess.run(
        [
            'git',
            'status',
            '--short',
        ],
        text=True,
        capture_output=True,
        check=True,
    ).stdout
    if status:
        stashed = True
        subprocess.run(
            [
                'git',
                'stash',
            ]
        )

    branch = subprocess.run(
        [
            'git',
            'rev-parse',
            '--symbolic-full-name',
            '--abbrev-ref',
            'HEAD',
        ],
        text=True,
        capture_output=True,
        check=True,
    ).stdout
    if branch != 'master':
        subprocess.run(
            ['git', 'checkout', 'master'],
            text=True,
            capture_output=True,
            check=True,
        )

    subprocess.run(
        [
            'git',
            'pull',
            'origin',
            'master',
        ],
        text=True,
        capture_output=True,
        check=True,
    )


def clone_repo(url):
    subprocess.run(
        [
            'git',
            'clone',
            'url',
        ],
        text=True,
        capture_output=True,
        check=True,
    )
