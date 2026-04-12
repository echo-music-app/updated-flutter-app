from typing import Protocol


class AttachmentUrlSigner(Protocol):
    provider_name: str

    async def sign(self, *, storage_key: str, ttl_seconds: int) -> str: ...
