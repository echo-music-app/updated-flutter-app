# ADR-0003: Build a Custom Platform Instead of Adopting Mastodon

## Status
Proposed

## Context
We need to decide whether Echo should be built as a custom system or based on an existing social platform such as Mastodon.

Our current product direction requires tight control over:
- A domain model that combines social interactions with music-specific entities and workflows
- API contracts and mobile UX tailored to Echo-specific use cases
- Cross-application development across backend, admin, and mobile in a single monorepo
- Incremental feature delivery with minimal architecture overhead and fast iteration

Mastodon is a mature, production-proven platform with built-in federation and social features, but adopting it would introduce significant constraints:
- Its domain model and product assumptions are optimized for federated microblogging
- Deep customization would require substantial divergence from upstream behavior
- Ongoing maintenance would include tracking upstream changes while preserving custom patches
- The core stack and extension model would increase cognitive load versus our current team/tooling direction

## Decision
We will continue building Echo as a custom-developed platform using our current architecture and technology choices, rather than adopting and customizing Mastodon as the system foundation.

Federation support is not a near-term requirement and will be treated as a future capability, not a design constraint for the initial platform architecture.

## Consequences

**Positive consequences:**
- Full control over data model, APIs, and user experience aligned to Echo product goals
- Faster iteration for product-specific features without upstream platform constraints
- Lower conceptual overhead for the team by staying within the chosen stack and repository structure
- Clear ownership of architecture and release cadence across backend, admin, and mobile

**Negative consequences:**
- We must build and maintain social-platform capabilities ourselves (moderation, safety tooling, operational hardening)
- Slower time-to-feature for capabilities that ready-made platforms already provide
- Higher long-term engineering responsibility for reliability and security
- Potential duplication of functionality available in established ecosystems

## Implementation
- Continue implementing core domain capabilities directly in the existing backend and mobile applications
- Prioritize only features required for Echo's product scope; avoid over-generalizing for federation in the initial phases
- Keep integration boundaries explicit so external protocol support (e.g., ActivityPub) can be evaluated later
- Reassess this decision if product strategy shifts toward federation-first requirements

## Alternatives Considered
- **Adopt Mastodon with minimal customization:** Rejected because product/domain mismatch would still require significant compromises in UX and APIs
- **Fork Mastodon and customize heavily:** Rejected due to high long-term maintenance burden and upstream divergence risk
- **Use another ready-made federated platform (e.g., Pleroma/Misskey):** Rejected for similar mismatch and maintenance trade-offs

## References
- Template: `docs/adr/0000-template.md`
- Monorepo structure decision: `docs/adr/0001-monorepo-structure.md`
- Backend tech stack decision: `docs/adr/0002-backend-tech-stack.md`
- Mastodon project documentation: https://docs.joinmastodon.org/
