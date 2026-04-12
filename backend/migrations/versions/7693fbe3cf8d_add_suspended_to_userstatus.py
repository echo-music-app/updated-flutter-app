"""add_suspended_to_userstatus

Revision ID: 7693fbe3cf8d
Revises: c4d5e6f7a8b9
Create Date: 2026-03-18 19:06:18.385680

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7693fbe3cf8d'
down_revision: Union[str, None] = 'c4d5e6f7a8b9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TYPE userstatus ADD VALUE IF NOT EXISTS 'suspended'")


def downgrade() -> None:
    # PostgreSQL does not support removing enum values; downgrade is a no-op
    pass