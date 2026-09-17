# Handoff: az-pim-activate PowerShell fallback

## Context

Azure DevOps ticket **103323** ("Adapt az-pim-activate script", project *Monitoring and Control*) — group-based
PIM activation isn't possible via `az rest`, because the Azure CLI's access token lacks the MS Graph scopes for
`identityGovernance/privilegedAccess/group/*`, and Microsoft hasn't granted first-party consent for the CLI to
request them (see https://github.com/Azure/azure-cli/issues/26471, linked from the ticket). The app-registration
workaround was marked "won't fix, too much effort" in the ticket comments. The last comment on the ticket
suggested trying PowerShell + the `Microsoft.Graph` module instead, since it's a first-party client with the
required consent already granted. Full comment history: see ticket 103323 comments (already read this session,
not duplicated here).

A colleague already had a working script for this; it landed on branch `feature/az-pim-activate-support-groups`
as `bin/az-pim-activate.ps1` (currently staged as a new file — see `git diff --cached bin/az-pim-activate.ps1`
for the original).

## What's been done this session

- Read ticket 103323 and its 3 comments to confirm the PowerShell approach is the agreed direction.
- Reviewed `bin/az-pim-activate.ps1` (uses `Connect-MgGraph` + `Invoke-MgGraphRequest` against
  `identityGovernance/privilegedAccess/group/*` endpoints to look up a group, check eligible assignments, and
  submit a `selfActivate` request).
- Edited the script (unstaged changes — see `git diff bin/az-pim-activate.ps1`):
  - Added a comment-based help block (`.SYNOPSIS` / `.DESCRIPTION` / `.NOTES`) documenting *why* this approach
    exists and its dependencies (PowerShell 7+, `Microsoft.Graph.Authentication` module, delegated Graph
    permission `PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup`).
  - Replaced the placeholder `<REPLACE_WITH_PIM_GROUP_NAME>` with the target group:
    `RBAC-Team-Mc-Apps-Dev-Contributor`.
- Confirmed locally that `pwsh` is installed but `Microsoft.Graph.Authentication` is **not** yet installed.
- User declined to have the module installed / script run by the assistant; asked for manual instructions
  instead (provided: `Install-Module Microsoft.Graph.Authentication -Scope CurrentUser`, then
  `pwsh bin/az-pim-activate.ps1`). **Not yet run — no confirmation of a successful activation yet.**
- Discussed whether the interactive browser login can be avoided:
  - `Connect-MgGraph -UseDeviceCode` avoids a local browser popup (device-code flow) but is still interactive.
  - The MS Graph SDK caches tokens locally (MSAL cache), so re-runs may silently reuse the session until it
    expires.
  - A fully non-interactive (app-only/client-secret) flow is not viable: PIM `selfActivate` requests are
    delegated-user actions, not something an app-only identity can do on the user's behalf. This is the same
    "won't fix" workaround already rejected in the ticket.
  - Open question at handoff: whether to default the script to `-UseDeviceCode` — not yet decided or applied.

## Repo state

- Branch: `feature/az-pim-activate-support-groups`
- `bin/az-pim-activate.ps1`: staged (new file, colleague's original) + unstaged edits (help block + group name,
  see diffs above). **Not committed.**

## Next steps

1. Decide on `-UseDeviceCode` default (or leave as-is) in `Connect-ToMicrosoftGraph`.
2. User runs the script manually (module install + `pwsh bin/az-pim-activate.ps1`) and reports back output/errors.
3. Once confirmed working, stage + commit per this repo's Azure DevOps commit convention:
   `#103323 <lowercase description>` (branch has no ticket number in its name, so the number must be taken from
   the ticket directly, not inferred from the branch).
4. Consider whether the tenant ID constant and hardcoded `$reason = "Migration work"` / `$duration = "PT1H"`
   should become script parameters instead of hardcoded values — not raised by the user yet, just an observation.

## Suggested skills for next session

- **code-review** — run before committing, to review the diff on `bin/az-pim-activate.ps1` (correctness +
  simplification pass) given it's largely third-party-authored code being adapted.
- **find-skills** — if PowerShell/Azure-specific tooling gaps come up (e.g. linting `.ps1` files), search for a
  skill rather than hand-rolling.

## Redactions

None needed — no secrets, credentials, or personal data surfaced in this session beyond the tenant ID already
present in the committed script (not treated as a secret by the user/repo).
