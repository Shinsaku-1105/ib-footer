<!-- ib-footer-jev:lanes BEGIN (managed by setup-mac.sh; --uninstall removes it) -->
## Subagent lanes
Delegate with the Agent tool to the cheapest lane that is enough:
- `web-operator` (Sonnet): anything that needs a browser (Claude in Chrome, jev-browser) or computer use. Screen tools are blocked in the main session by a hook; give web-operator the goal, the values to type and what to report back.
- `lane-small` (Haiku, low): mechanical, fully specified edits and lookups.
- `lane-medium` (Sonnet, medium): ordinary implementation and investigation. Default when unsure.
- Design decisions and security-sensitive changes: do them in the main session.
Move up one lane only after the same lane failed twice. Confirm completion with tests, type checks, linters and `git diff`.
<!-- ib-footer-jev:lanes END -->
