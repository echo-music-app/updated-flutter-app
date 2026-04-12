# Backend Architecture — Clean Architecture Layers

Source root: `backend/src/backend/`

## Layer Map
```
domain/           Pure domain: entities, exceptions, repository interfaces
  auth/           User / token entities
  posts/          Post domain + value objects (PostCursor)
  spotify/        Spotify entities

application/      Use cases (orchestration only, no framework deps)
  auth/           Auth use cases
  posts/          Post use cases
  spotify/        Spotify use cases
  ports/          Abstract port interfaces (e.g. AttachmentUrlSigner)

infrastructure/   Concrete implementations
  persistence/
    models/       SQLAlchemy ORM models
    repositories/ Repository implementations
  spotify/        Spotify HTTP client

adapters/         Adapter implementations of application ports
  api/v1/         (adapter-level API helpers if any)
  security/       URL signers (CloudFront, nginx)

presentation/     FastAPI routers / request-response schemas
  api/v1/         auth, health, posts, spotify_auth, tracks, well_known

core/             Config, DB session, deps, security helpers, decorators
main.py           FastAPI app entry point
```

## Key Conventions
- Repository interfaces live in `domain/<context>/repositories.py`
- Concrete repos live in `infrastructure/persistence/repositories/`
- Use cases receive repos/ports via constructor injection
- FastAPI deps (`core/deps.py`) wire everything together
