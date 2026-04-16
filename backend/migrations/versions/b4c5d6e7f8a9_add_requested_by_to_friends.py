"""add_requested_by_to_friends

Revision ID: b4c5d6e7f8a9
Revises: a9b8c7d6e5f4
Create Date: 2026-04-15 13:20:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "b4c5d6e7f8a9"
down_revision: str | None = "a9b8c7d6e5f4"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "friends",
        sa.Column("requested_by_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_friends_requested_by_id_users",
        "friends",
        "users",
        ["requested_by_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_friends_requested_by_id",
        "friends",
        ["requested_by_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_friends_requested_by_id", table_name="friends")
    op.drop_constraint("fk_friends_requested_by_id_users", "friends", type_="foreignkey")
    op.drop_column("friends", "requested_by_id")
