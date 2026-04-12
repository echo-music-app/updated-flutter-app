---
description: Create a new Architecture Decision Record (ADR) based on the template
---

# Create ADR Workflow

This workflow creates a new Architecture Decision Record using the template at `docs/adr/0000-template.md`.

## Usage

Run this workflow with: `/adr-create`

## Steps

1. **Get next ADR number**
   - Find the highest existing ADR number in `docs/adr/`
   - Calculate next sequential number

2. **Prompt for ADR details**
   - Ask for ADR title
   - Ask for context/problem description
   - Ask for the decision made
   - Ask for consequences (pros/cons)
   - Optionally ask for implementation details
   - Optionally ask for alternatives considered

3. **Generate ADR file**
   - Copy template to new file: `docs/adr/NNNN-title.md`
   - Replace placeholders with provided information
   - Set initial status to "Proposed"
   - Format title to be URL-friendly (lowercase, hyphens)

4. **Create the ADR file**
   - Write the complete ADR content
   - Confirm creation with file path

## Generated ADR Structure

The workflow will create an ADR with these sections:
- Title and ADR number
- Status: Proposed
- Context: [User-provided]
- Decision: [User-provided]
- Consequences: [User-provided]
- Implementation: [Optional, user-provided]
- Alternatives Considered: [Optional, user-provided]
- References: [Auto-populated with template info]

## Example Output

```
✅ Created ADR: docs/adr/0001-add-user-authentication.md
📝 Status: Proposed (ready for review)
🔗 Template used: docs/adr/0000-template.md
```
