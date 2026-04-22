"""add_soundcloud_subject_to_users

Revision ID: a2b3c4d5e6f7
Revises: d4e5f6a7b8c9
Create Date: 2026-04-20 23:58:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "a2b3c4d5e6f7"
down_revision: Union[str, None] = "d4e5f6a7b8c9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("soundcloud_subject", sa.String(length=255), nullable=True))
    op.create_index("ix_users_soundcloud_subject", "users", ["soundcloud_subject"], unique=False)
    op.create_unique_constraint("uq_users_soundcloud_subject", "users", ["soundcloud_subject"])


def downgrade() -> None:
    op.drop_constraint("uq_users_soundcloud_subject", "users", type_="unique")
    op.drop_index("ix_users_soundcloud_subject", table_name="users")
    op.drop_column("users", "soundcloud_subject")

