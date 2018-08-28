async def fetch(session, url, headers={}):
    async with session.get(url, headers=headers) as resp:
        return await resp.json()
