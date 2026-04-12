from fastapi import APIRouter
from fastapi.responses import JSONResponse

from backend.core.decorators import public_endpoint

router = APIRouter(tags=["well-known"])


@router.get("/.well-known/assetlinks.json")
@public_endpoint
async def asset_links():
    """Android App Links verification for Spotify OAuth redirect."""
    return JSONResponse(
        content=[
            {
                "relation": ["delegate_permission/common.handle_all_urls"],
                "target": {
                    "namespace": "android_app",
                    "package_name": "com.example.echo",
                    "sha256_cert_fingerprints": [],
                },
            }
        ],
        media_type="application/json",
    )


@router.get("/.well-known/apple-app-site-association")
@public_endpoint
async def apple_app_site_association():
    """iOS Universal Links verification for Spotify OAuth redirect."""
    return JSONResponse(
        content={
            "applinks": {
                "apps": [],
                "details": [
                    {
                        "appID": "TEAM_ID.com.example.echo",
                        "paths": ["/auth/callback"],
                    }
                ],
            }
        },
        media_type="application/json",
    )
