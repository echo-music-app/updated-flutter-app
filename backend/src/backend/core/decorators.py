from collections.abc import Callable
from functools import wraps
from typing import TypeVar

F = TypeVar("F", bound=Callable)


def public_endpoint[F: Callable](func: F) -> F:
    """Mark an endpoint as public (no authentication required)."""
    func.__public__ = True  # type: ignore[attr-defined]

    @wraps(func)
    async def wrapper(*args, **kwargs):
        return await func(*args, **kwargs)

    wrapper.__public__ = True  # type: ignore[attr-defined]
    return wrapper  # type: ignore[return-value]
