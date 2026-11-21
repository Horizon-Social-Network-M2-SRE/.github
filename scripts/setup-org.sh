#!/usr/bin/env bash
# S1-03: configure the Horizon GitHub organisation.
# Idempotent: safe to run again after adding a member or a repository.
#
# Usage: cp scripts/members.env.example scripts/members.env  # fill in logins
#        gh auth login && gh auth refresh -s admin:org
#        bash scripts/setup-org.sh            # apply
#        DRY_RUN=1 bash scripts/setup-org.sh  # print what would be done
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck source=/dev/null
source ./members.env

REPOS=(horizon-backend horizon-web horizon-infrastructure horizon-documentation .github)

run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then echo "DRY: $*"; else "$@"; fi
}

# --- Teams ---------------------------------------------------------------
declare -A TEAM_MEMBERS=(
  [backend]="$FIRAS $BOUGUI"
  [web]="$NESSRINE $KAIS"
  [platform]="$BOUCHIBA"
)

for team in "${!TEAM_MEMBERS[@]}"; do
  if ! gh api "orgs/$ORG/teams/$team" >/dev/null 2>&1; then
    run gh api -X POST "orgs/$ORG/teams" -f name="$team" -f privacy=closed >/dev/null
    echo "team created: $team"
  fi
  for login in ${TEAM_MEMBERS[$team]}; do
    # Adding a non-member to a team sends them an organisation invitation.
    run gh api -X PUT "orgs/$ORG/teams/$team/memberships/$login" -f role=member >/dev/null
    echo "  $login -> $team"
  done
done

# Every member writes to every repository; CODEOWNERS decides who must review.
for repo in "${REPOS[@]}"; do
  for team in backend web platform; do
    run gh api -X PUT "orgs/$ORG/teams/$team/repos/$ORG/$repo" -f permission=push >/dev/null
  done
done

# --- Repository settings: rebase and merge only ---------------------------
for repo in "${REPOS[@]}"; do
  run gh api -X PATCH "repos/$ORG/$repo" \
    -F allow_rebase_merge=true -F allow_squash_merge=false -F allow_merge_commit=false \
    -F delete_branch_on_merge=true -F allow_auto_merge=true >/dev/null
  echo "settings: $repo"
done

# --- Ruleset on the default branch (per repository: works on the free plan) --
RULESET=$(cat <<'JSON'
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["rebase"]
      } }
  ]
}
JSON
)

for repo in "${REPOS[@]}"; do
  existing=$(gh api "repos/$ORG/$repo/rulesets" --jq '.[] | select(.name=="protect-main") | .id' 2>/dev/null || true)
  if [[ -n "$existing" ]]; then
    echo "$RULESET" | run gh api -X PUT "repos/$ORG/$repo/rulesets/$existing" --input - >/dev/null
  else
    echo "$RULESET" | run gh api -X POST "repos/$ORG/$repo/rulesets" --input - >/dev/null
  fi
  echo "ruleset: $repo"
done
# Required status checks are added once S1-02 (reusable CI) has named its jobs.

# --- Labels (same set everywhere) -----------------------------------------
LABELS=(
  "epic|5319e7|Parent issue grouping stories"
  "story|1d76db|User or technical story"
  "task|c5def5|Finishable in under a day"
  "bug|d73a4a|Something does not work"
  "blocked|b60205|Waiting on something else"
  "ai-assisted|fbca04|An AI tool helped; author reviewed it"
  "sprint-1|0e8a16|" "sprint-2|0e8a16|" "sprint-3|0e8a16|" "sprint-4|0e8a16|" "sprint-5|0e8a16|"
)
for repo in "${REPOS[@]}"; do
  for entry in "${LABELS[@]}"; do
    IFS='|' read -r name color desc <<<"$entry"
    run gh label create "$name" --repo "$ORG/$repo" --color "$color" --description "$desc" --force >/dev/null
  done
  echo "labels: $repo"
done

# --- Professor: read access ---------------------------------------------
if [[ -n "${PROFESSOR:-}" ]]; then
  for repo in "${REPOS[@]}"; do
    run gh api -X PUT "repos/$ORG/$repo/collaborators/$PROFESSOR" -f permission=pull >/dev/null
  done
  echo "professor invited (read): $PROFESSOR"
fi

echo "done."
