#!/usr/bin/env bash
set -euo pipefail

if [[ "$EVENT" == workflow_dispatch ]]; then
  [[ "$ADVISORY" =~ ^(CVE-[0-9]{4}-[0-9]{4,}|GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4})$ ]] || {
    echo 'Invalid advisory identifier' >&2; exit 1;
  }
  [[ "$LANE" == general ]] || exit 0
fi

case "$LANE" in
  general)
    mapfile -t inputs < <(jq -r '.nodes[.root].inputs | keys[] | select(. != "pi" and . != "herdr")' flake.lock)
    ((${#inputs[@]} > 0))
    nix flake update "${inputs[@]}"
    ;;
  pi|herdr)
    python3 .github/update-releases.py "$LANE"
    nix flake update "$LANE"
    ;;
  *) echo "Invalid update lane: $LANE" >&2; exit 1 ;;
esac

git diff --exit-code -- . ':!flake.lock' ':!flake.nix'
if git diff --quiet -- flake.lock flake.nix; then
  echo "No $LANE updates." >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi
echo "Updates available for $LANE:" >> "$GITHUB_STEP_SUMMARY"
git diff --stat -- flake.nix flake.lock >> "$GITHUB_STEP_SUMMARY"
if [[ "$LANE" == general && "$EVENT" != workflow_dispatch && "$SCHEDULE" != '41 8 * * 1' ]]; then
  exit 0
fi

latest=$(gh api --method GET "repos/$GITHUB_REPOSITORY/git/ref/heads/master" --jq .object.sha)
[[ "$latest" == "$GITHUB_SHA" ]] || { echo 'master moved; refusing a stale proposal.' >&2; exit 1; }

# The API may require administrative read access, which the workflow token does not have.
if policy=$(gh api --method GET "repos/$GITHUB_REPOSITORY/actions/permissions/workflow" --jq .can_approve_pull_request_reviews 2>/dev/null); then
  [[ "$policy" == true ]] || { echo 'Repository policy blocks Actions from creating PRs; no branch was pushed.' >&2; exit 1; }
else
  echo 'Cannot read Actions PR policy with this token; publication may be blocked.' >&2
fi

title="chore: update $LANE flake inputs"
if [[ -n "$ADVISORY" ]]; then title="security: update flake inputs for $ADVISORY"; fi
candidate=$(git hash-object flake.lock)
candidate_flake=$(git hash-object flake.nix)
open=$(gh pr list --repo "$GITHUB_REPOSITORY" --base master --state open --limit 100 \
  --json headRefName,headRefOid,title,isCrossRepository \
  --jq ".[] | select(.isCrossRepository == false and (.headRefName | startswith(\"automation/flake-$LANE-\"))) | [.headRefOid,.title] | @tsv")
while IFS=$'\t' read -r previous previous_title; do
  [[ "$previous" =~ ^[a-f0-9]{40}$ && "$previous_title" == "$title" ]] || continue
  blob=$(gh api --method GET "repos/$GITHUB_REPOSITORY/contents/flake.lock?ref=$previous" --jq .sha)
  flake_blob=$(gh api --method GET "repos/$GITHUB_REPOSITORY/contents/flake.nix?ref=$previous" --jq .sha)
  if [[ "$candidate" == "$blob" && "$candidate_flake" == "$flake_blob" ]]; then
    echo 'An identical candidate already has an open PR.' >> "$GITHUB_STEP_SUMMARY"
    exit 0
  fi
done <<< "$open"

git add -- flake.nix flake.lock
tree=$(git write-tree)
branch="automation/flake-$LANE-${GITHUB_SHA:0:12}-${tree:0:12}"
remote_status=0
git ls-remote --exit-code --heads origin "refs/heads/$branch" > /dev/null || remote_status=$?
[[ "$remote_status" == 0 || "$remote_status" == 2 ]] || { echo 'Could not inspect remote branch.' >&2; exit 1; }
if [[ "$remote_status" == 0 ]]; then
  git fetch origin "refs/heads/$branch"
  sha=$(git rev-parse FETCH_HEAD)
  [[ "$(git rev-parse "$sha^{tree}")" == "$tree" && "$(git rev-parse "$sha^")" == "$GITHUB_SHA" ]] || {
    echo "Existing branch $branch has unexpected contents; refusing to overwrite." >&2; exit 1;
  }
else
  git -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    commit -m "$title"
  sha=$(git rev-parse HEAD)
  GIT_TERMINAL_PROMPT=0 git -c 'credential.helper=' \
    -c 'credential.helper=!gh auth git-credential' push origin "HEAD:refs/heads/$branch"
fi

checks="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/workflows/check.yml?query=branch%3A$branch"
gh workflow run check.yml --repo "$GITHUB_REPOSITORY" --ref "$branch" -f expected_sha="$sha" || {
  echo "CI dispatch failed for $branch; rerun to reuse the same branch." >&2; exit 1;
}
body="Review the reference and lockfile changes and [Checks for this exact branch]($checks). This proposal does not merge, deploy or reboot anything."
if [[ -n "$ADVISORY" ]]; then
  body="Priority review for $ADVISORY. Verify that the candidate actually includes the fix before accepting. $body"
fi
gh pr create --repo "$GITHUB_REPOSITORY" --base master --head "$branch" --title "$title" --body "$body" || {
  echo "PR creation failed for $branch. Check Actions PR policy and rerun; the same branch will be reused." >&2; exit 1;
}
