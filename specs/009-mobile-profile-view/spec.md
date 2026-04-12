# Feature Specification: Mobile Profile Viewing

**Feature Branch**: `009-mobile-profile-view`  
**Created**: 2026-03-20  
**Status**: Draft  
**Input**: User description: "New features in the mobile application: showing profiles. Showing profile of the own user (/v1/me) or any other user (/v1/users/{userId}). This shold contain a placeholder for the profile image (which is not yet implemented on the backend), bio, music genres, posts."

## Clarifications

### Session 2026-03-20

- Q: What post visibility rules apply when viewing another user's profile? → A: Show only posts that are publicly visible on another user's profile.
- Q: How should posts be loaded in profile views? → A: Load posts in pages with an initial batch and incremental load-more behavior.
- Q: What should happen when a `/v1/users/{userId}` navigation targets the signed-in user's own ID? → A: Resolve to own-profile mode using the same behavior as `/v1/me`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Own Profile (Priority: P1)

As a signed-in user, I can open my profile screen and view my current profile details so I can confirm how my account appears in the app.

**Why this priority**: Own-profile viewing is a core account experience and the baseline for profile-related navigation.

**Independent Test**: Sign in, open the profile screen, and verify the page shows profile image placeholder, bio, music genres, and posts with correct loading, empty, and error states.

**Acceptance Scenarios**:

1. **Given** I am authenticated and profile data exists, **When** I open my profile, **Then** I see a profile image placeholder, bio, music genres, and my posts.
2. **Given** I have no bio, no genres, or no posts, **When** I open my profile, **Then** each missing section shows an explicit empty-state message.
3. **Given** my session is no longer valid, **When** I open my profile, **Then** I am prompted to re-authenticate instead of seeing stale profile data.

---

### User Story 2 - View Another User Profile (Priority: P1)

As a signed-in user, I can open another user's profile so I can view their public profile context before interacting with their content.

**Why this priority**: Viewing other users' profiles is essential for social discovery and context across the app.

**Independent Test**: Navigate to another user's profile from any in-app entry point and verify the screen shows the target user's profile image placeholder, bio, genres, and posts.

**Acceptance Scenarios**:

1. **Given** I am authenticated and the target user exists, **When** I open that user's profile, **Then** I see the target user's profile image placeholder, bio, music genres, and publicly visible posts.
2. **Given** the target user does not exist, **When** I open that profile, **Then** I see a dedicated not-found state.
3. **Given** profile retrieval fails temporarily, **When** I open another user's profile, **Then** I see an error state with a retry action.
4. **Given** my session is no longer valid, **When** I open another user's profile, **Then** I am prompted to re-authenticate instead of seeing stale profile data.
5. **Given** I navigate to a user-profile route with my own user ID, **When** the profile screen resolves, **Then** it uses own-profile mode and behavior.
6. **Given** I open my own profile and another user's profile, **When** both screens render, **Then** each shows the correct explicit profile-mode indicator/title.

---

### User Story 3 - Browse Profile Posts (Priority: P2)

As a signed-in user, I can browse posts directly within a profile so I can quickly understand that user's recent activity.

**Why this priority**: Profile post visibility increases engagement, but profile identity details must land first.

**Independent Test**: Open profiles with and without posts and verify that posts render in expected order and that empty/error post states are handled without breaking the profile header content.

**Acceptance Scenarios**:

1. **Given** a profile has posts, **When** I open that profile, **Then** I see the posts section populated with recent entries first in an initial page.
2. **Given** a profile has zero posts, **When** I open that profile, **Then** I see a clear empty-state message for posts.
3. **Given** post retrieval fails while profile header data succeeds, **When** I open that profile, **Then** profile identity sections still render and only the posts section shows an error state.
4. **Given** a profile has more posts than the initial page, **When** I request more posts, **Then** the app appends the next page of posts without losing already shown content.

### Edge Cases

- Profile image is unavailable for all users because backend image support is not yet implemented.
- The user profile exists but one or more optional fields (`bio`, genres, posts) are empty.
- The target profile ID is malformed or refers to a deleted/non-existent user.
- A user rapidly switches between different profiles before prior requests complete.
- Profile header data succeeds but posts retrieval fails.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Mobile app MUST provide a profile view for the authenticated user's own account.
- **FR-002**: Mobile app MUST provide a profile view for any other user by user identifier.
- **FR-003**: The app MUST use the existing backend self-profile source for own-profile retrieval and the existing backend user-profile source for other-user retrieval.
- **FR-004**: Every profile view MUST include a non-broken profile image area rendered as a placeholder until profile images are supported.
- **FR-005**: Every profile view MUST display a bio section.
- **FR-006**: Every profile view MUST display a music genres section.
- **FR-007**: Every profile view MUST display a posts section.
- **FR-008**: When `bio`, genres, or posts are absent, the app MUST display explicit per-section empty states.
- **FR-009**: The app MUST display a dedicated not-found state when the requested user profile cannot be found.
- **FR-010**: The app MUST display loading feedback while profile data is being retrieved.
- **FR-011**: The app MUST display an actionable error state with retry when profile retrieval fails.
- **FR-012**: The app MUST show an explicit profile-mode indicator: own profile uses localized title key `myProfileTitle`; other profile uses `userProfileTitle` and includes the target username.
- **FR-013**: When viewing another user's profile, the app MUST display only posts that are publicly visible for that user.
- **FR-014**: The app MUST load profile posts in pages, showing an initial set first and supporting incremental load-more behavior.
- **FR-015**: If user-profile navigation targets the signed-in user's own ID, the app MUST resolve to own-profile mode behavior instead of treating it as another-user mode.
- **FR-016**: If own-profile or other-profile retrieval returns an authentication/session-expired failure, the app MUST clear stale profile content for that target and prompt re-authentication.

### Key Entities *(include if feature involves data)*

- **Profile View Model**: User-facing profile representation containing identity context, placeholder image state, bio, music genres, and profile posts.
- **Profile Post Item**: A post unit shown inside the profile posts section with user-visible post summary information and ordering metadata.
- **Profile View State**: The view state for each profile screen and section (`loading`, `data`, `empty`, `error`, `not_found`, `auth_required`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In QA validation, 100% of own-profile and other-profile views show a profile image area without broken-image presentation.
- **SC-002**: In 100 profile navigations under the SC-002 Baseline Test Profile defined in `specs/009-mobile-profile-view/quickstart.md`, at least 95% render core profile header content in <=2.0 seconds.
- **SC-003**: In validation scenarios, at least 95% of profile navigations show the correct target user data with no cross-user mix-up.
- **SC-004**: 100% of defined empty/error/not-found scenarios for bio, genres, posts, and missing users render expected user-facing states.
- **SC-005**: In product acceptance testing, at least 90% of users can correctly identify whether they are viewing their own profile or another user's profile on first attempt.

## Assumptions

- Existing authentication/session behavior for protected profile access is already in place in the mobile app.
- Existing backend profile endpoints for self and other users are available for the mobile client.
- Profile image upload/storage remains out of scope for this feature; only placeholder rendering is included.
- Profile editing, privacy controls, and post creation flows are out of scope for this feature.
