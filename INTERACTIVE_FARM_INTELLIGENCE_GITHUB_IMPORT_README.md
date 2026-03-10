# GitHub Import Guide for Interactive Farm Intelligence Backlog

## Files
- INTERACTIVE_FARM_INTELLIGENCE_GITHUB_ISSUES.csv
- INTERACTIVE_FARM_INTELLIGENCE_ENGINE_SPEC.md
- INTERACTIVE_FARM_INTELLIGENCE_BACKLOG.md

## Recommended Import Path (GitHub Projects)

1. Open your target repository.
2. Go to Projects.
3. Create/open a project board.
4. Use Import CSV in project item creation flow.
5. Select INTERACTIVE_FARM_INTELLIGENCE_GITHUB_ISSUES.csv.

## Notes
- The CSV includes epics and stories as separate items.
- Parent linkage is encoded in each story body using Parent: EPIC-X.
- Labels, milestone names, and assignees can be adjusted post-import.

## Optional Issue Sync

If you want these as repository issues instead of only project items:
- Keep CSV as source of truth.
- Create issues in batches by epic using the rows and bodies.
- Use consistent labels (epic, story, priority:P0/P1/P2).

## Suggested First Batch
- [EPIC-A] Map Command Center
- [STORY-A1] Render inferred zone polygons
- [STORY-A6] Open zone command drawer on zone tap
- [EPIC-B] Action Execution Framework
- [STORY-B1] Create and assign task action

## QA Tip
After import, add custom project fields:
- Type (Epic/Story)
- Priority
- Status
- Sprint
- Risk
