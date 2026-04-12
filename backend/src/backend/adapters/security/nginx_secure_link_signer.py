import hashlib
import hmac
import time
from urllib.parse import quote

from backend.application.ports.attachment_url_signer import AttachmentUrlSigner


class NginxSecureLinkSigner(AttachmentUrlSigner):
    provider_name = "nginx_secure_link"

    def __init__(self, *, base_url: str, secret: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._secret = secret.encode("utf-8")

    async def sign(self, *, storage_key: str, ttl_seconds: int) -> str:
        expires = int(time.time()) + ttl_seconds
        key_path = f"/{storage_key.lstrip('/')}"
        payload = f"{expires}{key_path}".encode()
        sig = hmac.new(self._secret, payload, hashlib.sha256).hexdigest()
        return f"{self._base_url}/{quote(storage_key.lstrip('/'))}?md5={sig}&expires={expires}"
