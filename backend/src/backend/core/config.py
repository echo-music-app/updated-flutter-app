import json
from functools import lru_cache
from typing import Annotated

from pydantic import SecretStr, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", case_sensitive=False)

    database_url: str
    secret_key: SecretStr
    debug: bool = False
    access_token_ttl_seconds: int = 900
    refresh_token_ttl_days: int = 30
    email_verification_code_ttl_seconds: int = 900
    api_v1_prefix: str = "/v1"
    app_name: str = "Echo"
    app_base_url: str = "http://localhost:8000"
    cors_allowed_origins: Annotated[list[str], NoDecode] = []
    apple_client_ids: Annotated[list[str], NoDecode] = []

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: SecretStr = SecretStr("")
    smtp_use_tls: bool = True
    smtp_use_ssl: bool = False
    email_from_address: str = ""

    spotify_client_id: str = ""
    spotify_client_secret: SecretStr = SecretStr("")
    spotify_redirect_uri: str = ""
    spotify_token_encryption_key: SecretStr = SecretStr("")

    # Music search provider credentials and limits
    music_search_spotify_enabled: bool = True
    music_search_soundcloud_enabled: bool = True
    spotify_token_url: str = "https://accounts.spotify.com/api/token"
    spotify_search_default_market: str = "US"
    soundcloud_client_id: str = ""
    soundcloud_client_secret: SecretStr = SecretStr("")
    soundcloud_token_url: str = "https://api.soundcloud.com/oauth2/token"
    music_search_request_timeout_seconds: float = 5.0
    music_search_provider_bulkhead_limit: int = 10

    attachment_url_provider_default: str = "nginx_secure_link"
    attachment_url_ttl_seconds: int = 300
    nginx_secure_link_base_url: str = "https://cdn.example.com"
    nginx_secure_link_secret: SecretStr = SecretStr("dev-nginx-secret")
    cloudfront_base_url: str = "https://d111111abcdef8.cloudfront.net"
    cloudfront_key_pair_id: str = "dev-key-pair"
    cloudfront_private_key: SecretStr = SecretStr("dev-cloudfront-secret")

    @field_validator("cors_allowed_origins", "apple_client_ids", mode="before")
    @classmethod
    def parse_string_list(cls, value: object) -> list[str]:
        if value is None or value == "":
            return []
        if isinstance(value, str):
            raw_value = value.strip()
            if not raw_value:
                return []
            if raw_value.startswith("["):
                parsed = json.loads(raw_value)
                if not isinstance(parsed, list):
                    raise ValueError("Value must be a JSON array or comma-separated string")
                return [str(item).strip().rstrip("/") for item in parsed if str(item).strip()]
            return [item.strip().rstrip("/") for item in raw_value.split(",") if item.strip()]
        if isinstance(value, list):
            return [str(item).strip().rstrip("/") for item in value if str(item).strip()]
        raise ValueError("Value must be a JSON array or comma-separated string")


@lru_cache
def get_settings() -> Settings:
    return Settings()
