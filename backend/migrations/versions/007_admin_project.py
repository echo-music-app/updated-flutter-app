"""admin_project

Revision ID: c4d5e6f7a8b9
Revises: b3c4d5e6f7a8
Create Date: 2026-03-17 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "c4d5e6f7a8b9"
down_revision: Union[str, None] = "b3c4d5e6f7a8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "admin_accounts",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column(
            "permission_scope",
            postgresql.ENUM("full_admin", name="adminpermissionscope", create_type=True),
            nullable=False,
            server_default="full_admin",
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
    )
    op.create_index("ix_admin_accounts_email", "admin_accounts", ["email"])
    op.create_index("ix_admin_accounts_is_active", "admin_accounts", ["is_active"])

    op.create_table(
        "admin_actions",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("actor_admin_id", sa.UUID(), nullable=False),
        sa.Column(
            "entity_type",
            postgresql.ENUM(
                "user",
                "content",
                "friend_relationship",
                "auth",
                "message_access_denial",
                name="adminentitytype",
                create_type=True,
            ),
            nullable=False,
        ),
        sa.Column("entity_id", sa.UUID(), nullable=True),
        sa.Column("operation_name", sa.String(length=100), nullable=False),
        sa.Column(
            "outcome",
            postgresql.ENUM("success", "denied", "failed", name="adminactionoutcome", create_type=True),
            nullable=False,
        ),
        sa.Column("change_payload", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'{}'")),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_admin_actions_actor_admin_id", "admin_actions", ["actor_admin_id"])
    op.create_index("ix_admin_actions_entity", "admin_actions", ["entity_type", "entity_id"])
    op.create_index("ix_admin_actions_occurred_at", "admin_actions", ["occurred_at"])

    op.create_table(
        "admin_access_tokens",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("token_hash", sa.LargeBinary(length=32), unique=True, nullable=False),
        sa.Column("admin_id", sa.UUID(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["admin_id"], ["admin_accounts.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_admin_access_tokens_admin_id", "admin_access_tokens", ["admin_id"])


def downgrade() -> None:
    op.drop_index("ix_admin_access_tokens_admin_id", table_name="admin_access_tokens")
    op.drop_table("admin_access_tokens")

    op.drop_index("ix_admin_actions_occurred_at", table_name="admin_actions")
    op.drop_index("ix_admin_actions_entity", table_name="admin_actions")
    op.drop_index("ix_admin_actions_actor_admin_id", table_name="admin_actions")
    op.drop_table("admin_actions")

    op.drop_index("ix_admin_accounts_is_active", table_name="admin_accounts")
    op.drop_index("ix_admin_accounts_email", table_name="admin_accounts")
    op.drop_table("admin_accounts")

    op.execute("DROP TYPE IF EXISTS adminactionoutcome")
    op.execute("DROP TYPE IF EXISTS adminentitytype")
    op.execute("DROP TYPE IF EXISTS adminpermissionscope")
