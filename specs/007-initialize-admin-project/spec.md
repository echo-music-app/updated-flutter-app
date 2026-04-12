# Feature Specification: Admin Project Initialization

**Feature Branch**: `007-initialize-admin-project`  
**Created**: 2026-03-17  
**Status**: Draft  
**Input**: User description: "Initialize the Admin project. The Admin system has a distinct user base with wide permissions to manage users, their contents, friend relationships, but have no access to messages."

## Clarifications

### Session 2026-03-17

- Q: Should the admin project reuse the same backend API surface with an `/admin` prefix and enforce independent authorization on all admin endpoints? → A: Yes. Admin capabilities reuse the application API style under `/admin/v1/...` endpoints, and every admin endpoint enforces independent admin authorization.
- Q: What admin authorization granularity should govern `/admin` endpoints? → A: Use a single broad admin permission model where any active admin can access all in-scope `/admin/v1` endpoints, while non-admin credentials are denied.
- Q: Which route versioning format should admin endpoints use? → A: Use `/admin/v1/...` for all admin endpoints.
- Q: Which deletion policy should apply to admin moderation actions? → A: Permanent deletion is allowed for managed content and friend relationships, while user accounts remain reversible-only (no permanent user deletion).
- Q: What audit data must be captured for admin operations? → A: Every admin operation must create an audit log entry with operation time, acting admin user, impacted entity, operation name, and a +/- diff of changes (empty diff for non-mutating operations).
- Q: Which concrete frontend runtime and library versions should initialize the admin UI project? → A: Use Node.js 24, React 19, React Hook Form 8, and Zod 4.
- Q: Which JavaScript/TypeScript linting and formatting tool should the admin UI use? → A: Use Biome.
- Q: How should admin action changes be persisted? → A: Use a single `AdminAction` audit log entry with `entityType`, `entityId`, and a serialized JSON change payload; do not create separate change tables or separate action tables.
- Q: Should the admin feature expose managed admin-facing entities, and how should sensitive data be returned to the UI? → A: Yes. Use managed admin-facing entities derived from the operational records, and anonymize sensitive fields such as email addresses on the backend by default before returning them to the UI.
- Q: How should admin authentication satisfy the opaque-token requirement? → A: Admin authentication uses backend-issued opaque tokens that are validated server-side on every authenticated request, with issuance, rotation, and revocation remaining fully backend-controlled.
- Q: How should conflicting admin moderation updates resolve? → A: Use optimistic concurrency so stale conflicting writes are rejected with a deterministic conflict response and require refresh before retry.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Access Dedicated Admin Workspace (Priority: P1)

As an internal administrator, I can access a dedicated admin workspace using admin-only credentials so administrative capabilities are isolated from the standard user experience.

**Why this priority**: Access control and user-base separation are foundational prerequisites for all other admin capabilities.

**Independent Test**: Verify that active admin accounts can enter the admin workspace and non-admin accounts are consistently denied.

**Acceptance Scenarios**:

1. **Given** an active admin account exists, **When** the admin signs in to the admin workspace, **Then** access is granted.
2. **Given** a regular user account exists, **When** that user attempts to sign in to the admin workspace, **Then** access is denied.
3. **Given** an admin account has been deactivated, **When** it attempts to sign in, **Then** access is denied.
4. **Given** an active admin is authenticated, **When** they call any in-scope `/admin/v1` endpoint, **Then** access is granted without domain-specific permission assignment.

---

### User Story 2 - Manage Users and User-Owned Content (Priority: P1)

As an administrator, I can review and manage user accounts and user-owned content so policy violations and account issues can be resolved quickly.

**Why this priority**: User and content management drive the primary operational value of the admin project.

**Independent Test**: Verify an admin can complete a full moderation workflow (find user, change user status, moderate content) with visible outcomes.

**Acceptance Scenarios**:

1. **Given** an administrator is authenticated, **When** they search for a user account, **Then** matching user records are returned with relevant moderation context.
2. **Given** an administrator identifies a problematic account, **When** they update the account status, **Then** the new status is saved and visible in subsequent views.
3. **Given** content violates policy, **When** an administrator moderates that content, **Then** the moderation outcome is applied and visible.
4. **Given** an administrator completes any user or content action, **When** the action is finalized, **Then** a traceable audit entry is recorded with operation time, acting admin user, impacted entity, operation name, and a +/- diff of changes.
5. **Given** an administrator attempts to permanently delete a user account, **When** they submit the action, **Then** the request is denied and a reversible moderation action is required instead.

---

### User Story 3 - Enforce Message Privacy Boundary (Priority: P1)

As an administrator, I have broad moderation permissions but cannot access private messages, preserving message privacy boundaries by design.

**Why this priority**: Explicitly excluding message access is a critical privacy and trust requirement.

**Independent Test**: Verify all message access attempts from the admin workspace are denied while other admin actions remain functional.

**Acceptance Scenarios**:

1. **Given** an authenticated administrator, **When** they attempt to view private messages, **Then** access is denied.
2. **Given** an authenticated administrator, **When** they attempt to search or export message data, **Then** access is denied.
3. **Given** a message-access attempt is denied, **When** the denial occurs, **Then** the attempt is recorded for audit and compliance review with operation time, acting admin user, impacted entity, operation name, and an explicit empty diff.

---

### User Story 4 - Manage Friend Relationships (Priority: P2)

As an administrator, I can inspect and manage friend relationships so abuse cases and relationship disputes can be resolved.

**Why this priority**: Friend relationship moderation is important but depends on core admin access and user-management workflows.

**Independent Test**: Verify an admin can find a relationship between two users and apply a corrective action that is reflected in relationship status.

**Acceptance Scenarios**:

1. **Given** two users have a friend relationship, **When** an administrator reviews their relationship record, **Then** the current relationship status is visible.
2. **Given** a relationship requires intervention, **When** an administrator removes the relationship, **Then** the relationship status updates accordingly.
3. **Given** a relationship action is completed, **When** the admin revisits the related users, **Then** the updated relationship state is reflected in user context.
4. **Given** a relationship requires irreversible removal, **When** an administrator permanently deletes the relationship record, **Then** the relationship is no longer recoverable and the action is auditable with operation time, acting admin user, impacted entity, operation name, and a +/- diff of changes.

---

### Edge Cases

- An administrator account is disabled while an active admin session is in progress.
- Two administrators attempt conflicting updates to the same user account at the same time, and one request must be deterministically rejected according to the optimistic-concurrency conflict rule.
- A moderation action targets a user or content record that was already removed by another admin.
- An administrator attempts message access indirectly through user detail views or exports.
- A friend relationship action references users that no longer have an active relationship.
- A regular user token is presented to an `/admin/v1` endpoint that requires admin authorization.
- A request targets `/v1/admin/...` or unversioned `/admin/...` instead of the canonical `/admin/v1/...` route pattern.
- An administrator attempts hard deletion of a user account, which is outside allowed moderation actions.
- An administrator performs a read-only operation; an audit entry is still required and must record an explicit empty diff.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST maintain a dedicated admin user base that is distinct from regular end-user accounts.
- **FR-002**: The system MUST allow only active admin accounts to access the admin workspace.
- **FR-003**: The system MUST deny admin-workspace access to non-admin accounts.
- **FR-004**: Administrators MUST be able to locate and view user accounts for moderation purposes.
- **FR-005**: Administrators MUST be able to change user account moderation state (the permitted values are defined in `data-model.md` under the user status enum; examples include restrict, suspend, and reactivate) with a recorded reason.
- **FR-006**: Administrators MUST be able to view and moderate user-owned content.
- **FR-007**: The system MUST record an immutable audit log entry for every `/admin/v1` operation (including successful, denied, and failed operations), including operation timestamp, acting admin user, impacted entity, operation name, and operation outcome. Audit entries for mutating operations MUST include a +/- diff describing the change set; audit entries for non-mutating or denied operations MUST include an explicit empty diff.
- **FR-008**: Administrators MUST be able to inspect friend relationships between users.
- **FR-009**: Administrators MUST be able to apply friend-relationship corrective actions and persist the resulting relationship state.
- **FR-010**: The admin workspace MUST NOT expose private message content or allow any message action (including search, export, deletion, or restoration) under any circumstance. Any denied message-access attempt from an admin context MUST generate a traceable audit record with an explicit empty diff.
- **FR-013**: The system MUST provide clear confirmation of each successful admin action so administrators can verify outcomes immediately.
- **FR-014**: Concurrent admin updates to the same moderation target MUST resolve deterministically using optimistic concurrency, so stale conflicting writes are rejected with predictable conflict outcomes and final state remains unambiguous.
- **FR-015**: The feature scope covers user management, content moderation, and friend-relationship management. All message-management capabilities are explicitly out of scope and enforced by FR-010.
- **FR-016**: Admin endpoints MUST follow the same API conventions and resource patterns as the main backend application endpoints, and every admin route MUST use the canonical `/admin/v1/...` pattern.
- **FR-017**: Every `/admin/v1` endpoint MUST enforce authorization rules that are independent from regular end-user authorization, MUST deny non-admin credentials, and MUST rely on backend-issued opaque tokens validated server-side on every authenticated request.
- **FR-018**: The initial admin authorization model MUST use one broad admin permission scope, so any active admin account can access all in-scope `/admin/v1` endpoints for user, content, and friend-relationship management.
- **FR-019**: Administrators MUST be able to permanently delete managed content records and friend relationship records when policy requires irreversible removal.
- **FR-020**: Administrators MUST NOT be able to permanently delete user accounts; user-account moderation MUST remain reversible through status changes.
- **FR-021**: *(consolidated into FR-007)*
- **FR-022**: The admin workspace frontend MUST be initialized as a browser-based React 19 application using TypeScript and Vite, running on Node.js 24.
- **FR-023**: The admin workspace frontend MUST use React Router for routing, TanStack Query for REST API state, React Hook Form 8 for form state management, Zod 4 for schema validation, and `shadcn/ui` with Tailwind CSS for UI composition and styling.
- **FR-024**: The admin workspace frontend MUST use Biome as the JavaScript/TypeScript linting and formatting tool.
- **FR-025**: The backend MUST persist each admin audit record as a single `AdminAction` entry that stores the impacted `entityType`, the impacted `entityId`, and the serialized JSON change payload; separate persistence tables for action records or per-entity change details MUST NOT be introduced for this feature.
- **FR-026**: The admin feature MUST use managed admin-facing entities such as `ManagedUser` and `ManagedContent`, derived from the operational `User` and `Content` records while keeping the operational database as the source of truth.
- **FR-027**: The backend MUST anonymize sensitive fields (such as email addresses) by default before returning admin-facing entities to the UI. No exceptions are permitted within this feature's scope.

### Key Entities *(include if feature involves data)*

- **AdminAccount**: Internal account identity allowed to access administrative capabilities, with lifecycle state and assigned permissions.
- **AdminPermissionSet**: Initial broad admin permission scope that grants in-scope `/admin/v1` capabilities to active admin accounts.
- **ManagedUser**: Admin-facing projection of an operational user record used for moderation workflows, with sensitive fields anonymized by default.
- **ManagedContent**: Admin-facing projection of an operational content record used for moderation workflows, with only the fields needed for safe moderation views exposed.
- **FriendRelationship**: Relationship record connecting two users, including current status and moderation history.
- **AdminAction**: Immutable record of each admin operation with operation time, acting admin user, impacted `entityType` and `entityId`, operation name, outcome, and a serialized JSON +/- diff payload (or explicit empty JSON object for non-mutating operations).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of attempted admin-workspace sign-ins by non-admin accounts are denied during acceptance testing.
- **SC-002**: At least 95% of tested admin sign-ins with valid active admin accounts succeed on first attempt.
- **SC-003**: In pilot operations, administrators complete the core user-management workflow (find user, apply status change, verify outcome) in 2 minutes or less for at least 90% of sampled cases.
- **SC-004**: In pilot operations, administrators complete the core content-moderation workflow in 3 minutes or less for at least 90% of sampled cases.
- **SC-005**: 100% of tested message-access attempts from the admin workspace are blocked.
- **SC-006**: 100% of tested `/admin/v1` operations (including successful, denied, and failed operations) produce an auditable event record with operation time, acting admin user, impacted entity, and operation name.
- **SC-007**: During UAT, administrators resolve at least 90% of flagged friend-relationship issues without engineering intervention.
- **SC-008**: 100% of tested `/admin/v1` endpoints reject non-admin credentials and permit active admin credentials.
- **SC-009**: 100% of in-scope admin capabilities are exposed through `/admin/v1/...` routes during acceptance testing.
- **SC-010**: 100% of sampled active admin accounts can execute all in-scope admin actions without additional domain-specific permission assignment.
- **SC-011**: 100% of tested attempts to permanently delete user accounts are denied and produce auditable outcomes.
- **SC-012**: 100% of tested permanent deletions of managed content and friend relationships are applied and recorded in the admin audit trail.
- **SC-013**: 100% of tested mutating admin operations include a +/- diff in the audit record that matches the applied state change, and 100% of tested non-mutating operations include an explicit empty diff.

## Assumptions

- Existing user, content, friend-relationship, and message domains are already present and are the source of truth.
- Internal operations or security owners define who is granted admin accounts and permissions.
- Administrative policy definitions (for suspension, moderation, and relationship intervention) are available before rollout.
- Message privacy requirements prohibit admin visibility into direct or private messages by default.
- The initial admin rollout does not require domain-scoped sub-roles inside the admin user base.
- The admin UI build and tooling environment can standardize on Node.js 24 across local development and CI.
- Admin authentication tokens remain opaque to the client and are never interpreted by the admin UI.
