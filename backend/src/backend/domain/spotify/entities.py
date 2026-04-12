from dataclasses import dataclass


@dataclass
class TrackResponse:
    id: str
    uri: str
    name: str
    artist_name: str
    album_art_url: str
    duration_ms: int
