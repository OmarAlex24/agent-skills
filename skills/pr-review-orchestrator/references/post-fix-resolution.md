# Post-fix: Resolve addressed PR review threads

After you have pushed fixes to the PR branch, any review threads (inline comments or requested changes) that are now fully addressed should be marked **resolved** so the PR state stays accurate and reviewers see what remains open.

## Preconditions

- `gh` CLI is installed and authenticated (`gh auth status`).
- You have write access to the PR (required to resolve threads).
- Fixes are already committed and pushed to the PR head branch.

## How to resolve threads

GitHub does not expose thread resolution through the REST API; use the GraphQL API via `gh api graphql`.

### 1) Identify the PR coordinates

Extract owner, repo, and PR number explicitly before running mutations:

```bash
gh pr view <n> --json number,url --jq '
  {
    number: .number,
    owner: (.url | split("/")[3]),
    repo: (.url | split("/")[4])
  }'
```

### 2) Fetch unresolved review threads

Use a paginated GraphQL query so you do not miss threads on large PRs:

```bash
gh api graphql \
  -F owner="{owner}" \
  -F name="{repo}" \
  -F prNumber={number} \
  -F after="{afterCursor}" \
  -f query='
    query($owner: String!, $name: String!, $prNumber: Int!, $after: String) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $prNumber) {
          reviewThreads(first: 100, after: $after) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              isResolved
              isOutdated
              path
              line
              startLine
              comments(last: 5) {
                nodes {
                  body
                  author { login }
                }
              }
            }
          }
        }
      }
    }'
```

Paginate until `hasNextPage` is `false`. Collect all `nodes` into one list.

### 3) Match threads to the fixes you pushed

For each unresolved thread, decide whether it is fully addressed:

- **Resolve** — the fix directly addresses the comment (same file/line region, same concern). No unanswered follow-up questions remain.
- **Leave open** — the feedback is partially addressed, unclear, contested, or requires further discussion.
- **Reply first (optional)** — the fix is in but not obvious from the diff; post a short explanation before resolving so the reviewer understands.

Use these signals when matching:
- `path` and `line` / `startLine` point to a region you changed in the fix commit(s).
- Thread text matches the code change, refactor, or test update.
- Commit message references the concern.

### 4) Resolve the eligible threads

Run the `resolveReviewThread` mutation per eligible thread:

```bash
gh api graphql \
  -F threadId="{threadNodeId}" \
  -f query='
    mutation($threadId: ID!) {
      resolveReviewThread(input: { threadId: $threadId }) {
        thread { id isResolved }
      }
    }'
```

- The `threadId` is the `id` field of each `reviewThread` node (format `PRRT_kwDO...`), **not** an individual comment ID.
- Resolve one thread at a time so you can log the result.

### 5) Verify

Re-run the fetch query (step 2) and confirm:
- Every thread you intended to resolve now shows `isResolved: true`.
- No unexpected thread was resolved.
- Any remaining unresolved threads match your plan.

### 6) Report

Summarize what you did:
- Count of threads resolved.
- List of resolved thread IDs and one-line reasons.
- Any threads left open and why.
- Any permission or tooling issues encountered.

## Safety rules

- Never resolve a thread in bulk without a per-thread check.
- Never resolve if the feedback is only partially addressed or still requires discussion.
- If GraphQL returns a permissions error, stop and report it instead of silently failing.
- If you are unsure whether a thread is addressed, leave it open and leave a brief PR comment linking the relevant commit.

## Fallback

If GraphQL is unavailable, use the REST API only to **read** review comments for context (`gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate`), but you will not be able to resolve threads via REST.
