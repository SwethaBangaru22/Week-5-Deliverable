---
name: document-creation
description: >-
  Create structured project documents from templates: READMEs, API specs,
  architecture docs, design docs, changelogs, tutorials, and educational
  content. Use when the user asks to create, write, draft, or generate any
  project documentation, or when a new feature or module needs accompanying docs.
---

# Document Creation

## Instructions

When creating a document, follow this workflow:

1. **Identify the document type** from the user's request
2. **Select the matching template** from the templates below
3. **Gather context** by reading relevant source files, existing docs, and project structure
4. **Generate the document** using the template structure, filled with real project context
5. **Place the document** in the correct location (see File Placement below)
6. **Add a sync marker** at the top so the document-sync skill can track it

## Sync Marker

Every generated document MUST include a sync marker as the first line after the title:

```markdown
<!-- sync: auto-generated | source: path/to/source | last-sync: YYYY-MM-DD -->
```

- `auto-generated` or `manual` — indicates origin
- `source` — the primary source file/directory this doc describes
- `last-sync` — date the doc was last verified against source

## File Placement

| Document Type       | Location                          |
|---------------------|-----------------------------------|
| Project README      | `./README.md`                     |
| Module README       | `./<module>/README.md`            |
| API spec            | `docs/api/<name>.md`              |
| Architecture        | `docs/architecture/<name>.md`     |
| Design doc          | `docs/design/<name>.md`           |
| Changelog           | `./CHANGELOG.md`                  |
| Tutorial / lesson   | `docs/tutorials/<name>.md`        |
| Educational content | `docs/content/<name>.md`          |

## Templates

### README (Project or Module)

```markdown
# <Project/Module Name>

<!-- sync: auto-generated | source: ./ | last-sync: YYYY-MM-DD -->

## Overview
[One-paragraph description of purpose and scope]

## Quick Start
[Minimal steps to get running]

## Project Structure
[Key directories and their purpose]

## Development
[Setup, build, test commands]

## Contributing
[How to contribute, branch strategy]
```

### API Specification

```markdown
# <API Name>

<!-- sync: auto-generated | source: backend/app/<path> | last-sync: YYYY-MM-DD -->

## Base URL
`<base-url>`

## Authentication
[Auth method and required headers]

## Endpoints

### `METHOD /path`
**Description:** [What it does]

**Request:**
| Parameter | Type   | Required | Description |
|-----------|--------|----------|-------------|
| param     | string | yes      | ...         |

**Response:**
\`\`\`json
{ "example": "response" }
\`\`\`

**Error Codes:**
| Code | Meaning        |
|------|----------------|
| 400  | Bad request    |
| 404  | Not found      |
```

### Architecture Document

```markdown
# <System/Component> Architecture

<!-- sync: auto-generated | source: <root-path> | last-sync: YYYY-MM-DD -->

## Context
[Why this system exists, what problem it solves]

## High-Level Design
[System diagram description, major components and their relationships]

## Components

### <Component Name>
- **Responsibility:** [What it does]
- **Location:** `path/to/code`
- **Dependencies:** [What it depends on]

## Data Flow
[How data moves through the system]

## Key Decisions
| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| ...      | ...       | ...                    |

## Trade-offs
[Known limitations and why they were accepted]
```

### Design Document

```markdown
# <Feature> Design Doc

<!-- sync: manual | source: N/A | last-sync: YYYY-MM-DD -->

## Status
[Draft | In Review | Approved | Implemented | Deprecated]

## Problem Statement
[What problem are we solving and for whom]

## Goals / Non-Goals
**Goals:**
- [Goal 1]

**Non-Goals:**
- [Explicit non-goal 1]

## Proposed Solution
[Detailed description of the approach]

## Alternatives Considered
| Approach | Pros | Cons |
|----------|------|------|
| ...      | ...  | ...  |

## Implementation Plan
- [ ] Step 1
- [ ] Step 2

## Open Questions
- [Question 1]
```

### Changelog

```markdown
# Changelog

<!-- sync: auto-generated | source: ./ | last-sync: YYYY-MM-DD -->

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- [New feature description]

### Changed
- [Change description]

### Fixed
- [Bug fix description]
```

### Tutorial / Educational Content

```markdown
# <Topic Title>

<!-- sync: manual | source: N/A | last-sync: YYYY-MM-DD -->

## Learning Objectives
By the end of this tutorial, you will:
- [Objective 1]
- [Objective 2]

## Prerequisites
- [Prerequisite 1]

## Steps

### Step 1: <Title>
[Explanation]

\`\`\`language
// code example
\`\`\`

### Step 2: <Title>
[Explanation]

## Summary
[Key takeaways]

## Next Steps
[Where to go from here]
```

## Guidelines

- Use real values from the codebase, never placeholder text in final output
- Keep language clear and scannable: short paragraphs, bullet lists, tables
- Include code examples pulled from actual source when documenting APIs or architecture
- Always run a final check: does every section have real content, not template placeholders?
