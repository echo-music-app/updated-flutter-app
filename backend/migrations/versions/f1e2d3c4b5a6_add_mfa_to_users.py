"""add_mfa_to_users

Revision ID: f1e2d3c4b5a6
Revises: e7f6a5b4c3d2
Create Date: 2026-04-12 22:15:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "f1e2d3c4b5a6"
down_revision: Union[str, None] = "e7f6a5b4c3d2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("mfa_enabled", sa.Boolean(), nullable=False, server_default=sa.text("false")))
    op.add_column("users", sa.Column("mfa_totp_secret", sa.String(length=128), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "mfa_totp_secret")
    op.drop_column("users", "mfa_enabled")
