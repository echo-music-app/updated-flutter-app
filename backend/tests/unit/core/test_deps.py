from unittest.mock import AsyncMock, MagicMock

import pytest

from backend.core.deps import get_current_user


@pytest.mark.anyio
async def test_public_endpoint_returns_none():
    """Cover deps.py line 19: public endpoint returns None."""

    def fake_endpoint():
        pass

    fake_endpoint.__public__ = True

    request = MagicMock()
    request.scope = {"endpoint": fake_endpoint}

    result = await get_current_user(request, db=AsyncMock())
    assert result is None
