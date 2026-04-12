from unittest.mock import AsyncMock, MagicMock, patch

import pytest


@pytest.mark.anyio
async def test_get_db_session_commits_on_success():
    """Cover database.py line 30: session.commit() on success."""
    mock_session = AsyncMock()
    mock_factory = MagicMock()
    mock_factory.return_value.__aenter__ = AsyncMock(return_value=mock_session)
    mock_factory.return_value.__aexit__ = AsyncMock(return_value=False)

    with patch("backend.core.database.get_session_factory", return_value=mock_factory):
        from backend.core.database import get_db_session

        gen = get_db_session()
        session = await gen.__anext__()
        assert session is mock_session
        try:
            await gen.__anext__()
        except StopAsyncIteration:
            pass
    mock_session.commit.assert_awaited_once()


@pytest.mark.anyio
async def test_get_db_session_rolls_back_on_error():
    """Cover database.py lines 31-33: rollback on exception."""
    mock_session = AsyncMock()
    mock_factory = MagicMock()
    mock_factory.return_value.__aenter__ = AsyncMock(return_value=mock_session)
    mock_factory.return_value.__aexit__ = AsyncMock(return_value=False)

    with patch("backend.core.database.get_session_factory", return_value=mock_factory):
        from backend.core.database import get_db_session

        gen = get_db_session()
        session = await gen.__anext__()
        assert session is mock_session
        with pytest.raises(ValueError, match="test error"):
            await gen.athrow(ValueError("test error"))
    mock_session.rollback.assert_awaited_once()
