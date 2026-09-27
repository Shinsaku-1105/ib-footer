<!-- ib-footer-jev:lanes BEGIN (managed by setup-mac.sh; --uninstall removes it) -->
## Subagent lanes
When delegating work with the Agent tool, use the cheapest lane that is enough:
- `lane-small` (Haiku, low): mechanical, fully specified edits and lookups.
- `lane-medium` (Sonnet, medium): ordinary implementation and investigation. Default when unsure.
- Design decisions and security-sensitive changes: do them in the main session.
Move up one lane only after the same lane failed twice. Confirm completion with tests, type checks, linters and `git diff`.
<!-- ib-footer-jev:lanes END -->
