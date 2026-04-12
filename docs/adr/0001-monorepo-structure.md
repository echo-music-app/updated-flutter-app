# ADR-0002: Monorepo Structure

## Status
Proposed

## Context
We need to decide on the repository structure for the Echo project. The requirements are:
- Simplicity is the primary concern
- All developers should easily see and touch different parts of the system
- Avoid switching between applications/projects
- Support backend (Python/FastAPI), mobile, and shared components
- Enable rapid development and cross-team collaboration
- Minimize cognitive overhead for developers

## Decision
We will use a monorepo structure where all code (admin, backend, mobile, shared components, documentation) lives in a single Git repository. This approach prioritizes developer convenience and simplicity over repository isolation.

## Consequences

**Positive consequences:**
- Developers can easily access and modify any part of the system
- No need to switch between multiple repositories or projects
- Simplifies dependency management between components
- Enables atomic commits across multiple components
- Easier code sharing and reuse between backend and mobile
- Single source of truth for the entire project
- Simplified CI/CD pipeline configuration
- Better visibility into the entire codebase for all team members

**Negative consequences:**
- Larger repository size and longer clone times
- Potential for unrelated changes to be coupled
- More complex access control if needed
- Build times may increase as the project grows
- Harder to enforce strict component boundaries
- Potential for merge conflicts across different teams
- Tooling may need to handle multiple languages/frameworks

## Implementation
- Organize code by component type (admin/, backend/, mobile/, shared/, docs/)
- Use Makefile for common commands across components
- Configure tooling to handle multiple languages (Python, mobile languages)
- Set up CI/CD to build and test only changed components
- Use clear directory structure and naming conventions
- Implement shared libraries in the shared/ directory
- Use Docker Compose for local development across components

## Alternatives Considered
- **Multiple repositories**: Better isolation but requires switching between projects
- **Polyrepo with package management**: Cleaner but adds complexity to dependency management
- **Git submodules**: Allows separation but adds Git complexity
- **Micro-repos with tooling**: Automated but over-engineered for our needs

## References
- Template: docs/adr/0000-template.md
- ADR-0001: Backend Tech Stack (docs/adr/0001-backend-tech-stack.md)
