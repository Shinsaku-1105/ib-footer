<!-- ib-footer-jev:lanes BEGIN (managed by setup-mac.sh; --uninstall removes it) -->
## Subagent lanes
Delegate with the Agent tool to the cheapest lane that is enough:
- `web-operator` (Sonnet): anything that needs a browser or computer use. Never drive a browser or take screenshots in the main session; screenshots stay in the subagent's context.
- `lane-small` (Haiku, low): mechanical, fully specified edits and lookups.
- `lane-medium` (Sonnet, medium): ordinary implementation and investigation. Default when unsure.
- Design decisions and security-sensitive changes: do them in the main session.
Move up one lane only after the same lane failed twice. Confirm completion with tests, type checks, linters and `git diff`.
<!-- ib-footer-jev:lanes END -->
