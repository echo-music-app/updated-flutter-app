"""Unit tests for the SpotifyCredentials SQLAlchemy model (T008).

Verifies table name, column names, types, and constraints without hitting
the database (pure ORM metadata inspection).
"""

from sqlalchemy import LargeBinary, String, Text

from backend.infrastructure.persistence.models.spotify_credentials import SpotifyCredentials


class TestSpotifyCredentialsTableName:
    def test_tablename(self):
        """Model maps to the correct database table."""
        assert SpotifyCredentials.__tablename__ == "spotify_credentials"


class TestSpotifyCredentialsColumns:
    def _col(self, name: str):
        return SpotifyCredentials.__table__.c[name]

    def test_user_id_column_exists(self):
        assert "user_id" in SpotifyCredentials.__table__.c

    def test_access_token_column_exists_and_is_binary(self):
        col = self._col("access_token")
        assert isinstance(col.type, LargeBinary)
        assert not col.nullable

    def test_refresh_token_column_exists_and_is_binary(self):
        col = self._col("refresh_token")
        assert isinstance(col.type, LargeBinary)
        assert not col.nullable

    def test_token_expiry_column_exists(self):
        assert "token_expiry" in SpotifyCredentials.__table__.c

    def test_spotify_user_id_column_exists_and_is_string(self):
        col = self._col("spotify_user_id")
        assert isinstance(col.type, String)
        assert not col.nullable

    def test_scope_column_exists_and_is_text(self):
        col = self._col("scope")
        assert isinstance(col.type, Text)
        assert not col.nullable

    def test_created_at_and_updated_at_from_mixin(self):
        """TimestampMixin provides created_at and updated_at columns."""
        assert "created_at" in SpotifyCredentials.__table__.c
        assert "updated_at" in SpotifyCredentials.__table__.c


class TestSpotifyCredentialsConstraints:
    def test_user_id_unique(self):
        """user_id has a unique constraint (one row per Echo user)."""
        col = SpotifyCredentials.__table__.c["user_id"]
        assert col.unique

    def test_spotify_user_id_unique(self):
        """spotify_user_id has a unique constraint (upsert key)."""
        col = SpotifyCredentials.__table__.c["spotify_user_id"]
        assert col.unique

    def test_user_id_has_foreign_key(self):
        """user_id references users.id."""
        col = SpotifyCredentials.__table__.c["user_id"]
        fks = list(col.foreign_keys)
        assert len(fks) == 1
        assert "users.id" in str(fks[0].target_fullname)


class TestSpotifyCredentialsIndexes:
    def _index_names(self):
        return {idx.name for idx in SpotifyCredentials.__table__.indexes}

    def test_user_id_index_exists(self):
        assert "ix_spotify_credentials_user_id" in self._index_names()

    def test_spotify_user_id_index_exists(self):
        assert "ix_spotify_credentials_spotify_user_id" in self._index_names()
