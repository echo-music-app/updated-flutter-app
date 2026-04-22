"""add_apple_subject_to_users

Revision ID: d4e5f6a7b8c9
Revises: c8d9e0f1a2b3
Create Date: 2026-04-20 18:05:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "d4e5f6a7b8c9"
down_revision: Union[str, None] = "c8d9e0f1a2b3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("apple_subject", sa.String(length=255), nullable=True))
    op.create_index("ix_users_apple_subject", "users", ["apple_subject"], unique=False)
    op.create_unique_constraint("uq_users_apple_subject", "users", ["apple_subject"])


def downgrade() -> None:
    op.drop_constraint("uq_users_apple_subject", "users", type_="unique")
    op.drop_index("ix_users_apple_subject", table_name="users")
    op.drop_column("users", "apple_subject")
