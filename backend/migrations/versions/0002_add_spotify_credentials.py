"""add_spotify_credentials

Revision ID: a1b2c3d4e5f6
Revises: 5b0ba984d40c
Create Date: 2026-03-01 10:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "5b0ba984d40c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "spotify_credentials",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("access_token", sa.LargeBinary(), nullable=False),
        sa.Column("refresh_token", sa.LargeBinary(), nullable=False),
        sa.Column("token_expiry", sa.DateTime(timezone=True), nullable=False),
        sa.Column("spotify_user_id", sa.String(length=255), nullable=False),
        sa.Column("scope", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("spotify_user_id"),
        sa.UniqueConstraint("user_id"),
    )
    op.create_index("ix_spotify_credentials_user_id", "spotify_credentials", ["user_id"])
    op.create_index("ix_spotify_credentials_spotify_user_id", "spotify_credentials", ["spotify_user_id"])


def downgrade() -> None:
    op.drop_index("ix_spotify_credentials_spotify_user_id", table_name="spotify_credentials")
    op.drop_index("ix_spotify_credentials_user_id", table_name="spotify_credentials")
    op.drop_table("spotify_credentials")