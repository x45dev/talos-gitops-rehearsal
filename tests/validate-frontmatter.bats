#!/usr/bin/env bats
#
# Tests for scripts/validate-frontmatter.sh. Run with `mise run test` (or
# `bats tests/validate-frontmatter.bats` directly).
#
# Each test builds a throwaway knowledge dir so the script is exercised end to
# end (find + yq + jq), not mocked. Negative cases mutate a known-good bundle
# one rule at a time so each test pins one specific ERROR string.
#
# PROVENANCE: adopted 2026-08-02 from the released `rka-template` v0.1.0
# (`template/tests/validate-frontmatter.bats`), per ADR-0012's consume-at-tagged-
# releases rule. Reindented from upstream's 4 spaces to this repo's 2 (the same
# treatment the validator itself got when it was ported), so a future
# reconciliation should normalise leading whitespace before diffing:
#   diff <(sed 's/^[[:space:]]*//' upstream.bats) <(sed 's/^[[:space:]]*//' this)
# Assertions match on error-string substrings, which is why they survive this
# repo's habit of appending RFC citations that upstream drops.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/knowledge/adr"
}

teardown() {
  rm -rf "$TMP"
}

# make_doc <path> <id> <type> [extra-frontmatter-line]
make_doc() {
  local path="$1" id="$2" type="$3" extra="${4:-}"
  {
    printf -- '---\n'
    printf 'id: %s\n' "$id"
    printf 'title: A Document\n'
    printf 'status: active\n'
    printf 'version: 0.1.0\n'
    printf 'date: 2026-01-01\n'
    printf 'type: %s\n' "$type"
    [ -n "$extra" ] && printf '%s\n' "$extra"
    printf -- '---\n\n# Body\n'
  } > "$path"
}

# A minimal bundle that passes every rule: the mandatory constitution plus one
# context document and one ADR.
valid_bundle() {
  make_doc "$TMP/knowledge/constitution.md" constitution constitution
  make_doc "$TMP/knowledge/context.md" context context
  make_doc "$TMP/knowledge/adr/ADR-0001.md" ADR-0001 adr "adr_status: accepted"
}

@test "passes on a valid bundle" {
  valid_bundle
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -eq 0 ]
}

@test "fails on a missing required field" {
  valid_bundle
  cat > "$TMP/knowledge/context.md" <<'EOF'
---
id: context
title: Missing status and more
version: 0.1.0
---
EOF
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required field"* ]]
}

@test "fails on a missing type field specifically" {
  valid_bundle
  cat > "$TMP/knowledge/context.md" <<'EOF'
---
id: context
title: No type
status: active
version: 0.1.0
date: 2026-01-01
---
EOF
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *'missing required field "type"'* ]]
}

@test "fails on an illegal status value" {
  valid_bundle
  make_doc "$TMP/knowledge/context.md" context context
  sed -i 's/^status: active$/status: published/' "$TMP/knowledge/context.md"
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid status"* ]]
}

@test "fails on duplicate ids across documents" {
  valid_bundle
  make_doc "$TMP/knowledge/progress.md" context context
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"duplicate id"* ]]
}

@test "fails when a non-ADR id does not match its filename stem" {
  valid_bundle
  make_doc "$TMP/knowledge/progress.md" wrong-id context
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not match filename stem"* ]]
}

@test "fails on an ADR without adr_status" {
  valid_bundle
  make_doc "$TMP/knowledge/adr/ADR-0002.md" ADR-0002 adr
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *'missing required field "adr_status"'* ]]
}

@test "fails on an ADR with an illegal adr_status" {
  valid_bundle
  make_doc "$TMP/knowledge/adr/ADR-0002.md" ADR-0002 adr "adr_status: rejected"
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid adr_status"* ]]
}

@test "fails on an ADR filename that violates the convention" {
  valid_bundle
  make_doc "$TMP/knowledge/adr/README.md" ADR-0002 adr "adr_status: accepted"
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ADR filename must be"* ]]
}

@test "fails when no constitution is present" {
  make_doc "$TMP/knowledge/context.md" context context
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no constitution found"* ]]
}

@test "index is optional: a valid bundle without index.md passes" {
  valid_bundle
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -eq 0 ]
}

@test "index present: fails when a governed document is not listed" {
  valid_bundle
  cat > "$TMP/knowledge/index.md" <<'EOF'
# Bundle index

* [Constitution](constitution.md)
* [ADR-0001](adr/ADR-0001.md)
EOF
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"is not listed in the bundle index"* ]]
}

@test "index present: fails when an entry does not resolve" {
  valid_bundle
  cat > "$TMP/knowledge/index.md" <<'EOF'
# Bundle index

* [Constitution](constitution.md)
* [Context](context.md)
* [ADR-0001](adr/ADR-0001.md)
* [Ghost](missing.md)
EOF
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not resolve to an existing file"* ]]
}

@test "reserved index.md is exempt from per-document rules" {
  valid_bundle
  cat > "$TMP/knowledge/index.md" <<'EOF'
# Bundle index (no RKA frontmatter, deliberately)

* [Constitution](constitution.md)
* [Context](context.md)
* [ADR-0001](adr/ADR-0001.md)
EOF
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -eq 0 ]
}

# --- Spec bundles (RKA ADR-0013, this repo's ADR-0009) ----------------------
#
# A feature spec is a governed bundle at knowledge/specs/<NNN>-<slug>/ holding
# spec.md (required) plus optional plan.md and tasks.md. Each document's id is
# <role>-<NNN>-<slug>, the bundle shares one status, an archived document carries
# an Extraction record, and a bundle whose tasks are all complete must be archived.

# make_spec_doc <path> <id> <type> <status> [extra-body]
make_spec_doc() {
  local path="$1" id="$2" type="$3" status="$4" body="${5:-}"
  {
    printf -- '---\n'
    printf 'id: %s\n' "$id"
    printf 'title: A Bundle Document\n'
    printf 'status: %s\n' "$status"
    printf 'version: 0.1.0\n'
    printf 'date: 2026-01-01\n'
    printf 'type: %s\n' "$type"
    printf -- '---\n\n# Body\n'
    if [ -n "$body" ]; then
      printf '\n%s\n' "$body"
    fi
  } > "$path"
}

# spec_bundle <NNN-slug> <status> [tasks-body] [spec-extra]
# Creates a three-document bundle. Default tasks body has one unchecked box, so
# rule 9b does not fire unless a caller asks for an all-complete list.
spec_bundle() {
  local slug="$1" status="$2" tasks_body="${3:-- [ ] T001 open}" spec_extra="${4:-}"
  mkdir -p "$TMP/knowledge/specs/$slug"
  make_spec_doc "$TMP/knowledge/specs/$slug/spec.md" "spec-$slug" spec "$status" "$spec_extra"
  make_spec_doc "$TMP/knowledge/specs/$slug/plan.md" "plan-$slug" plan "$status"
  make_spec_doc "$TMP/knowledge/specs/$slug/tasks.md" "tasks-$slug" tasks "$status" "$tasks_body"
}

@test "spec bundle: a well-formed active bundle passes" {
  valid_bundle
  spec_bundle 003-example active
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -eq 0 ]
}

@test "spec bundle: a completed, archived bundle with an extraction record passes" {
  valid_bundle
  spec_bundle 003-example archived '- [x] T001 done' '## Extraction record

Archived after shipping.'
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -eq 0 ]
}

@test "spec bundle: a bundle with no tasks.md passes" {
  valid_bundle
  mkdir -p "$TMP/knowledge/specs/003-example"
  make_spec_doc "$TMP/knowledge/specs/003-example/spec.md" spec-003-example spec active
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -eq 0 ]
}

@test "spec bundle: a tasks.md with no checkboxes does not trigger rule 9b" {
  valid_bundle
  spec_bundle 003-example active 'No checkboxes here, just prose.'
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -eq 0 ]
}

@test "spec bundle: fails on a filename that is not a known role" {
  valid_bundle
  spec_bundle 003-example active
  make_spec_doc "$TMP/knowledge/specs/003-example/notes.md" notes-003-example spec active
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"is not a known spec-bundle role"* ]]
}

@test "spec bundle: fails on a document nested below the bundle directory" {
  valid_bundle
  spec_bundle 003-example active
  mkdir -p "$TMP/knowledge/specs/003-example/evidence"
  make_spec_doc "$TMP/knowledge/specs/003-example/evidence/notes.md" notes evidence active
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must sit directly in the bundle directory"* ]]
}

@test "spec bundle: fails when the bundle has no spec.md" {
  # The fail-open case: without a required spec.md, an archived plan+tasks bundle
  # would carry no extraction record anywhere and every other rule would pass.
  valid_bundle
  mkdir -p "$TMP/knowledge/specs/003-example"
  make_spec_doc "$TMP/knowledge/specs/003-example/plan.md" plan-003-example plan archived
  make_spec_doc "$TMP/knowledge/specs/003-example/tasks.md" tasks-003-example tasks archived '- [x] T001 done'
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"has no spec.md"* ]]
}

@test "spec bundle: fails on a bundle id that is not role-NNN-slug" {
  valid_bundle
  spec_bundle 003-example active
  make_spec_doc "$TMP/knowledge/specs/003-example/spec.md" spec spec active
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"spec-bundle id must be"* ]]
}

@test "spec bundle: fails when an archived document has no extraction record" {
  valid_bundle
  spec_bundle 003-example archived '- [x] T001 done'
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Extraction record"* ]]
}

@test "spec bundle: fails on mixed statuses within one bundle" {
  valid_bundle
  spec_bundle 003-example active
  make_spec_doc "$TMP/knowledge/specs/003-example/plan.md" plan-003-example plan draft
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"mixed status values"* ]]
}

@test "spec bundle: fails when all tasks are complete but the bundle is not archived" {
  valid_bundle
  spec_bundle 003-example active '- [x] T001 done
- [x] T002 done'
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"all tasks complete but status is"* ]]
}

@test "spec bundle: a trailing slash on the knowledge dir still catches a violation" {
  # Fail-open guard: bundle detection strips $KNOWLEDGE_DIR from each path, so an
  # un-normalised trailing slash would make the regex miss and rules 9a/9b would
  # never run. The fixture must be rule-VIOLATING, or the case cannot go red.
  valid_bundle
  spec_bundle 003-example active '- [x] T001 done'
  run "$REPO_ROOT/scripts/validate-frontmatter.sh" "$TMP/knowledge/"
  [ "$status" -ne 0 ]
  [[ "$output" == *"all tasks complete but status is"* ]]
}
