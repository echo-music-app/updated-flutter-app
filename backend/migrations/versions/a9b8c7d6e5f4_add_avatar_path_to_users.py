"""add_avatar_path_to_users

Revision ID: a9b8c7d6e5f4
Revises: f1e2d3c4b5a6
Create Date: 2026-04-13 09:35:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "a9b8c7d6e5f4"
down_revision: Union[str, None] = "f1e2d3c4b5a6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("avatar_path", sa.String(length=512), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "avatar_path")
