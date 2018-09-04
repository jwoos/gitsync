import asyncio
import math

from utils import fetch

import aiohttp


API_BASE = 'https://api.github.com'
PER_PAGE_COUNT = 30


# get the authenticated user
async def get_user(username: str, token: str) -> dict:
    async with aiohttp.ClientSession() as session:
        return await fetch(
            session,
            f'{API_BASE}/user',
            headers={
                'Authorization': f'token {token}'
            },
        )

# get the authenticated user's repos
async def get_repositories(user: dict, token: str) -> list:
    private_repos = int(user['owned_private_repos'])
    public_repos = int(user['public_repos'])
    total_repo_count = private_repos + public_repos

    async with aiohttp.ClientSession() as session:
        requests = [
            asyncio.ensure_future(
                fetch(
                    session,
                    f'{API_BASE}/user/repos?type=owner&sort=full_name&page={page}',
                    headers={
                        'Authorization': f'token {token}',
                    },
                )
            )
            for page in range(math.ceil(total_repo_count / PER_PAGE_COUNT))
        ]

        return await asyncio.gather(*requests)
