# Echo Project Glossary

This document defines key terms, domain entities, and concepts used throughout the Echo project.

## System Components

### Backend
Refers to the server-side application that handles business logic, data persistence, and API endpoints. 
- **Technology Stack**: Python, FastAPI, PostgreSQL
- **Responsibilities**: User management, data processing, API serving, authentication
- **Location**: `backend/` directory in the monorepo
- **Access**: Typically accessed via REST API endpoints

### Mobile
Refers to the mobile application that end-users interact with on their devices.
- **Platform**: iOS and/or Android mobile applications
- **Responsibilities**: User interface, client-side logic, offline capabilities
- **Location**: `mobile/` directory in the monorepo
- **Access**: Native mobile application installed on user devices

### Admin
Refers to the administrative interface for managing the Echo system.
- **Purpose**: System administration, user management, content moderation
- **Implementation**: Could be web-based, desktop, or mobile admin interface
- **Location**: Currently TBD, likely in `admin/` or part of `backend/`
- **Access**: Restricted to authorized administrators and system operators

## Domain Entities

### Admin User
A person who has access to the admin interface and can manage the system.
- **Attributes**: email
- **Operations**: Activate users, deactivate users, manage content

### User
A person who uses the Echo system.
- **Attributes**: username, bio, preferred_genres, is_artist
- **Operations**: Create profile, update profile, view profiles
- **Endpoints**: `/v1/me`, `/v1/users/{user_id}`

### Profile
The collection of user-specific information and preferences.
- **Components**: Basic info, preferences, artist status
- **Mutability**: username, bio, preferred_genres are updatable; is_artist is not
- **Storage**: PostgreSQL database via backend

### Artist
A special type of user who creates content or performs in the system.
- **Status**: Boolean flag (`is_artist`)
- **Permissions**: May have additional capabilities for content creation
- **Management**: Set by administrators, not self-modifiable

### Genre
A category or classification for content preferences.
- **Purpose**: Content recommendation and filtering
- **Format**: String-based identifiers
- **Usage**: Stored in user's `preferred_genres` list

## Technical Terms

### Monorepo
A single Git repository containing all project components (backend, mobile, shared, docs).
- **Benefits**: Unified codebase, simplified dependency management
- **Structure**: Organized by component type in subdirectories

### API (Application Programming Interface)
The contract between backend and client applications.
- **Format**: RESTful endpoints using JSON
- **Version**: Currently v1 (`/v1/` prefix)
- **Documentation**: Auto-generated via FastAPI

### Docker
Containerization platform used for local development environment.
- **Purpose**: Consistent development setup across machines
- **Configuration**: `docker-compose.yml` and related files
- **Services**: Database, backend application, and supporting services

## Common Patterns

### CRUD Operations
Create, Read, Update, Delete operations for data entities.
- **Implementation**: FastAPI route handlers
- **Database**: SQLAlchemy ORM with PostgreSQL

### Authentication
The process of verifying user identity.
- **Method**: TBD (likely token-based)
- **Scope**: Applied to protected endpoints

### Validation
The process of ensuring data meets required constraints.
- **Backend**: Pydantic models for request/response validation
- **Database**: Constraints and data types in PostgreSQL

## Project Structure Terms

### Shared
Code and resources used across multiple components.
- **Location**: `shared/` directory
- **Contents**: Common models, utilities, configurations
- **Purpose**: Code reuse and consistency

### Specs
Specification documents for features and requirements.
- **Location**: `specs/` directory
- **Format**: Markdown with structured sections
- **Usage**: Feature planning and development guidance

### ADR (Architecture Decision Record)
Documents that capture important architectural decisions.
- **Location**: `docs/adr/` directory
- **Format**: Standardized template
- **Purpose**: Historical context and decision rationale
