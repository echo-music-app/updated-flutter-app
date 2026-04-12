import base64
import json
import uuid
from dataclasses import dataclass
from datetime import datetime


@dataclass(slots=True)
class PostCursor:
    created_at: datetime
    id: uuid.UUID


def encode_cursor(cursor: PostCursor) -> str:
    payload = {"created_at": cursor.created_at.isoformat(), "id": str(cursor.id)}
    raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii")


def decode_cursor(raw_cursor: str) -> PostCursor:
    decoded = base64.urlsafe_b64decode(raw_cursor.encode("ascii")).decode("utf-8")
    payload = json.loads(decoded)
    return PostCursor(created_at=datetime.fromisoformat(payload["created_at"]), id=uuid.UUID(payload["id"]))
