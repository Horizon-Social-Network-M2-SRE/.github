# .github

Organisation-wide defaults for **Horizon Social Network**.

| Path | Purpose |
| --- | --- |
| `profile/README.md` | Organisation profile page |
| `ISSUE_TEMPLATE/` | Story, bug and epic forms inherited by every repository |
| `pull_request_template.md` | Pull request checklist inherited by every repository |
| `scripts/setup-org.sh` | Creates teams, repository settings, the `protect-main` ruleset and labels (S1-03) |

Repositories that define their own templates override these. This repository must stay public for
the defaults to apply.

## Organisation setup

```bash
cp scripts/members.env.example scripts/members.env   # fill in GitHub logins
gh auth login && gh auth refresh -s admin:org
DRY_RUN=1 bash scripts/setup-org.sh                  # preview
bash scripts/setup-org.sh                            # apply
```
