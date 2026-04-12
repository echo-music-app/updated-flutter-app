import hashlib
import hmac
import time
from urllib.parse import quote

from backend.application.ports.attachment_url_signer import AttachmentUrlSigner


class CloudFrontSignedUrlSigner(AttachmentUrlSigner):
    provider_name = "cloudfront"

    def __init__(self, *, base_url: str, key_pair_id: str, private_key: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._key_pair_id = key_pair_id
        self._private_key = private_key.encode("utf-8")

    async def sign(self, *, storage_key: str, ttl_seconds: int) -> str:
        expires = int(time.time()) + ttl_seconds
        resource = f"{self._base_url}/{quote(storage_key.lstrip('/'))}"
        policy = f"{resource}:{expires}".encode()
        signature = hmac.new(self._private_key, policy, hashlib.sha256).hexdigest()
        return f"{resource}?Expires={expires}&Signature={signature}&Key-Pair-Id={self._key_pair_id}"
