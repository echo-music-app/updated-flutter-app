"""attachment_sti

Revision ID: b3c4d5e6f7a8
Revises: a1b2c3d4e5f6
Create Date: 2026-03-15 18:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b3c4d5e6f7a8"
down_revision: Union[str, None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    attachment_url_provider = sa.Enum("nginx_secure_link", "cloudfront", name="attachmenturlprovider")
    attachment_url_provider.create(op.get_bind(), checkfirst=True)

    op.add_column("attachments", sa.Column("content", sa.Text(), nullable=True))
    op.add_column("attachments", sa.Column("url", sa.String(length=512), nullable=True))
    op.add_column("attachments", sa.Column("track_id", sa.String(length=64), nullable=True))
    op.add_column("attachments", sa.Column("storage_key", sa.String(length=512), nullable=True))
    op.add_column("attachments", sa.Column("mime_type", sa.String(length=64), nullable=True))
    op.add_column("attachments", sa.Column("size_bytes", sa.BigInteger(), nullable=True))
    op.add_column("attachments", sa.Column("url_provider_override", attachment_url_provider, nullable=True))

    op.execute(
        """
        UPDATE attachments a
        SET content = t.content
        FROM attachments_text t
        WHERE a.id = t.id
        """
    )
    op.execute(
        """
        UPDATE attachments a
        SET content = ap.content
        FROM attachments_artist_post ap
        WHERE a.id = ap.id
        """
    )
    op.execute(
        """
        UPDATE attachments a
        SET url = s.url, track_id = s.track_id
        FROM attachments_spotify_link s
        WHERE a.id = s.id
        """
    )
    op.execute(
        """
        UPDATE attachments a
        SET url = s.url, track_id = s.track_id
        FROM attachments_soundcloud_link s
        WHERE a.id = s.id
        """
    )
    op.execute(
        """
        UPDATE attachments a
        SET storage_key = af.storage_key, mime_type = af.mime_type, size_bytes = af.size_bytes
        FROM attachments_audio_file af
        WHERE a.id = af.id
        """
    )
    op.execute(
        """
        UPDATE attachments a
        SET storage_key = vf.storage_key, mime_type = vf.mime_type, size_bytes = vf.size_bytes
        FROM attachments_video_file vf
        WHERE a.id = vf.id
        """
    )

    op.drop_table("attachments_video_file")
    op.drop_table("attachments_text")
    op.drop_table("attachments_spotify_link")
    op.drop_table("attachments_soundcloud_link")
    op.drop_table("attachments_audio_file")
    op.drop_table("attachments_artist_post")


def downgrade() -> None:
    op.create_table(
        "attachments_artist_post",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.ForeignKeyConstraint(["id"], ["attachments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "attachments_audio_file",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("storage_key", sa.String(length=512), nullable=False),
        sa.Column("mime_type", sa.String(length=64), nullable=False),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.ForeignKeyConstraint(["id"], ["attachments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "attachments_soundcloud_link",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("url", sa.String(length=512), nullable=False),
        sa.Column("track_id", sa.String(length=64), nullable=True),
        sa.ForeignKeyConstraint(["id"], ["attachments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "attachments_spotify_link",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("url", sa.String(length=512), nullable=False),
        sa.Column("track_id", sa.String(length=64), nullable=True),
        sa.ForeignKeyConstraint(["id"], ["attachments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "attachments_text",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.ForeignKeyConstraint(["id"], ["attachments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "attachments_video_file",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("storage_key", sa.String(length=512), nullable=False),
        sa.Column("mime_type", sa.String(length=64), nullable=False),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.ForeignKeyConstraint(["id"], ["attachments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.execute("INSERT INTO attachments_text (id, content) SELECT id, content FROM attachments WHERE attachment_type = 'text' AND content IS NOT NULL")
    op.execute(
        "INSERT INTO attachments_artist_post (id, content) SELECT id, content FROM attachments WHERE attachment_type = 'artist_post' AND content IS NOT NULL"
    )
    op.execute(
        "INSERT INTO attachments_spotify_link (id, url, track_id) SELECT id, url, track_id FROM attachments WHERE attachment_type = 'spotify_link' AND url IS NOT NULL"
    )
    op.execute(
        "INSERT INTO attachments_soundcloud_link (id, url, track_id) SELECT id, url, track_id FROM attachments WHERE attachment_type = 'soundcloud_link' AND url IS NOT NULL"
    )
    op.execute(
        "INSERT INTO attachments_audio_file (id, storage_key, mime_type, size_bytes) SELECT id, storage_key, mime_type, size_bytes FROM attachments WHERE attachment_type = 'audio_file' AND storage_key IS NOT NULL"
    )
    op.execute(
        "INSERT INTO attachments_video_file (id, storage_key, mime_type, size_bytes) SELECT id, storage_key, mime_type, size_bytes FROM attachments WHERE attachment_type = 'video_file' AND storage_key IS NOT NULL"
    )

    op.drop_column("attachments", "url_provider_override")
    op.drop_column("attachments", "size_bytes")
    op.drop_column("attachments", "mime_type")
    op.drop_column("attachments", "storage_key")
    op.drop_column("attachments", "track_id")
    op.drop_column("attachments", "url")
    op.drop_column("attachments", "content")

    sa.Enum("nginx_secure_link", "cloudfront", name="attachmenturlprovider").drop(op.get_bind(), checkfirst=True)
