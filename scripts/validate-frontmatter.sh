#!/usr/bin/env bash
set -euo pipefail

# Validate RKA frontmatter for all knowledge/**/*.md files.
# Rules (RFC-003 sections 3, 4, 5 and 8; RFC-002 section 3):
#   1. All six required fields present and non-empty: id, title, status, version,
#      date, type (type is OKF's one required field).
#   2. status is one of: draft, active, canonical, archived
#   3. id is non-empty and unique across all governed documents
#   4. id / filename convention:
#      - ADRs (knowledge/adr/): id is ADR-NNNN (4 digits, no slug); filename is
#        ADR-NNNN.md or ADR-NNNN-<kebab-slug>.md; the leading ADR-NNNN token of
#        the filename stem must equal the id.
#      - Spec bundles (knowledge/specs/<NNN>-<slug>/): the filename is the
#        document's role (spec.md, plan.md, tasks.md) and the id is
#        <role>-<NNN>-<slug>, because a bundle's documents cannot all share one
#        stem.
#      - Every other governed document: id must equal the filename stem.
#   5. adr_status: every document under knowledge/adr/ must carry adr_status,
#      one of proposed, accepted, superseded.
#   6. constitution presence: the tree must contain exactly one document with
#      id "constitution", the one mandatory artifact.
#   7. bundle-index integrity: knowledge/index.md is optional, but WHEN PRESENT
#      it must list every governed document and every entry must resolve.
#   8. extraction record on archival (RFC-002 section 3): a document at status
#      "archived" must carry a heading titled "Extraction record". Archival
#      without extraction is knowledge loss. Inside a spec bundle only spec.md
#      carries the record for the whole bundle.
#   9. spec bundle lifecycle (RFC-003 sections 4, 5):
#      9a. every governed document in one spec bundle carries the same status; a
#          bundle has a single lifecycle.
#      9b. a bundle whose tasks.md holds at least one checkbox and no unchecked
#          checkbox must be archived. This catches a shipped feature whose spec
#          was never retired and whose knowledge was never extracted.
# Rules 8 and 9 are the ADR-0013 spec-lifecycle gate, adopted early from the RKA
# reference repo by recorded maintainer decision (this repo's ADR-0009); when a
# tagged rka-template release ships them, reconcile this script against the
# released one and note any divergence in knowledge/progress.md.
# The reserved OKF bundle-structure files (index.md, log.md) are not governed
# documents: they are excluded from rules 1-6 and 8-9 and validated only by
# rule 7.
# Reports every error before exiting non-zero, so one run surfaces all problems
# rather than failing on the first.
# NOTE (template maintainers): this file is rendered by Copier with default
# Jinja delimiters, so it must not contain a "{" immediately followed by "#"
# (Jinja comment open); counts are tracked with explicit counter variables
# instead of parameter-expansion length operators.

KNOWLEDGE_DIR="${1:-knowledge}"
REQUIRED_FIELDS=("id" "title" "status" "version" "date" "type")
LEGAL_STATUSES=("draft" "active" "canonical" "archived")
LEGAL_ADR_STATUSES=("proposed" "accepted" "superseded")
SPEC_ROLES=("spec" "plan" "tasks")

errors=0
declare -A id_to_file
declare -A bundle_statuses
declare -A bundle_tasks_file
file_count=0
governed_rel=()
governed_count=0
has_constitution=false

is_reserved() {
  local base="$1"
  [[ "$base" == "index.md" || "$base" == "log.md" ]]
}

# Slice the leading YAML frontmatter block (between the first `---` and the next
# `---`). Portable: depends only on awk, so it is independent of the yq flavor.
extract_frontmatter() {
  awk 'NR == 1 && $0 != "---" { exit }   # no frontmatter delimiter -> emit nothing
     NR == 1 { next }                  # skip the opening ---
     $0 == "---" { exit }              # stop at the closing ---
     { print }' "$1"
}

# Transcode YAML on stdin to JSON. Frontmatter is sliced with awk above, so
# extraction is flavor-independent; yq is used only to turn that YAML block into
# JSON, which both common implementations can do:
#   * mikefarah/yq (Go, the tool mise pins): needs `-o=json`.
#   * kislyuk/yq   (Python jq wrapper):      emits JSON by default.
# Probe the capability rather than the `--version` string, so the validator
# works whichever yq is on PATH. If NEITHER form transcodes, no usable yq is
# installed (usually the toolchain was not provisioned) - fail loudly with the
# fix instead of misreporting every document as missing all six fields.
if printf 'probe: 1\n' | yq -o=json '.' > /dev/null 2>&1; then
  yaml_to_json() { yq -o=json '.'; }
elif printf 'probe: 1\n' | yq '.' > /dev/null 2>&1; then
  yaml_to_json() { yq '.'; }
else
  printf 'ERROR: validate-frontmatter.sh needs a working yq (mikefarah Go yq, or the python yq).\n' >&2
  printf '       found: %s\n' "$(yq --version 2>&1 || echo 'no yq on PATH')" >&2
  printf '       fix:   provision the pinned toolchain by running: mise install\n' >&2
  exit 2
fi

while IFS= read -r -d '' file; do
  # Reserved OKF bundle-structure files are not governed documents.
  if is_reserved "$(basename "$file")"; then
    continue
  fi
  file_count=$((file_count + 1))
  rel="$file"
  rel="${rel/#"$KNOWLEDGE_DIR"\//}"
  governed_rel+=("$rel")
  governed_count=$((governed_count + 1))

  # A spec bundle is knowledge/specs/<NNN>-<slug>/<role>.md (RFC-003 sections
  # 4, 5).
  spec_bundle=""
  spec_role=""
  if [[ "$rel" =~ ^specs/([^/]+)/([^/]+)\.md$ ]]; then
    spec_bundle="${BASH_REMATCH[1]}"
    spec_role="${BASH_REMATCH[2]}"
    valid_role=false
    for r in "${SPEC_ROLES[@]}"; do
      [[ "$spec_role" == "$r" ]] && valid_role=true && break
    done
    if [[ "$valid_role" == false ]]; then
      printf 'ERROR: %s: "%s.md" is not a known spec-bundle role (must be one of: spec, plan, tasks) per RFC-003 section 5\n' \
        "$file" "$spec_role" >&2
      errors=$((errors + 1))
    fi
    [[ "$spec_role" == "tasks" ]] && bundle_tasks_file["$spec_bundle"]="$file"
  fi

  block=$(extract_frontmatter "$file")
  if [[ -z "$block" ]]; then
    # No frontmatter at all: fall through so every required field is reported
    # missing (a governed document must carry frontmatter).
    fm="{}"
  else
    fm=$(printf '%s\n' "$block" | yaml_to_json 2> /dev/null) || fm=""
    if [[ -z "$fm" || "$fm" == "null" ]]; then
      # Frontmatter is present but did not parse: a toolchain or YAML-syntax
      # problem, not a missing field. Report it as such instead of masking it.
      printf 'ERROR: %s: frontmatter block present but could not be parsed as YAML (check syntax, or that yq is installed)\n' "$file" >&2
      errors=$((errors + 1))
      continue
    fi
  fi

  for field in "${REQUIRED_FIELDS[@]}"; do
    val=$(printf '%s' "$fm" | jq -r --arg f "$field" '.[$f] // ""')
    if [[ -z "$val" || "$val" == "null" ]]; then
      printf 'ERROR: %s: missing required field "%s"\n' "$file" "$field" >&2
      errors=$((errors + 1))
    fi
  done

  status=$(printf '%s' "$fm" | jq -r '.status // ""')
  if [[ -n "$status" && "$status" != "null" ]]; then
    valid_status=false
    for legal in "${LEGAL_STATUSES[@]}"; do
      [[ "$status" == "$legal" ]] && valid_status=true && break
    done
    if [[ "$valid_status" == false ]]; then
      printf 'ERROR: %s: invalid status "%s" (must be one of: draft, active, canonical, archived)\n' \
        "$file" "$status" >&2
      errors=$((errors + 1))
    fi
  fi

  if [[ -n "$spec_bundle" && -n "$status" && "$status" != "null" ]]; then
    bundle_statuses["$spec_bundle"]="${bundle_statuses[$spec_bundle]:-} $status"
  fi

  # Rule 8: an archived document must carry its extraction record (RFC-002
  # section 3). Within a spec bundle the record lives once, in spec.md, and
  # covers the bundle.
  if [[ "$status" == "archived" ]]; then
    if [[ -n "$spec_bundle" && "$spec_role" != "spec" ]]; then
      :
    elif ! grep -qiE '^#{1,6}[[:space:]]+extraction record[[:space:]]*$' "$file"; then
      printf 'ERROR: %s: archived document has no "Extraction record" section (RFC-002 section 3, PRD FR5.2)\n' \
        "$file" >&2
      errors=$((errors + 1))
    fi
  fi

  # Rule 5: ADRs must carry a legal adr_status.
  if [[ "$(basename "$(dirname "$file")")" == "adr" ]]; then
    adr_status=$(printf '%s' "$fm" | jq -r '.adr_status // ""')
    if [[ -z "$adr_status" || "$adr_status" == "null" ]]; then
      printf 'ERROR: %s: missing required field "adr_status" for an ADR\n' "$file" >&2
      errors=$((errors + 1))
    else
      valid_adr_status=false
      for legal in "${LEGAL_ADR_STATUSES[@]}"; do
        [[ "$adr_status" == "$legal" ]] && valid_adr_status=true && break
      done
      if [[ "$valid_adr_status" == false ]]; then
        printf 'ERROR: %s: invalid adr_status "%s" (must be one of: proposed, accepted, superseded)\n' \
          "$file" "$adr_status" >&2
        errors=$((errors + 1))
      fi
    fi
  fi

  id=$(printf '%s' "$fm" | jq -r '.id // ""')
  if [[ -n "$id" && "$id" != "null" ]]; then
    [[ "$id" == "constitution" ]] && has_constitution=true
    if [[ -v id_to_file["$id"] ]]; then
      printf 'ERROR: %s: duplicate id "%s" (first seen in %s)\n' \
        "$file" "$id" "${id_to_file[$id]}" >&2
      errors=$((errors + 1))
    else
      id_to_file["$id"]="$file"
    fi

    # Rule 4: type-keyed id / filename convention.
    stem=$(basename "$file" .md)
    parent=$(basename "$(dirname "$file")")
    if [[ "$parent" == "adr" ]]; then
      if [[ ! "$id" =~ ^ADR-[0-9]{4}$ ]]; then
        printf 'ERROR: %s: ADR id "%s" must be ADR-NNNN (4 digits, no slug)\n' \
          "$file" "$id" >&2
        errors=$((errors + 1))
      fi
      if [[ ! "$stem" =~ ^ADR-[0-9]{4}(-[a-z0-9]+)*$ ]]; then
        printf 'ERROR: %s: ADR filename must be ADR-NNNN.md or ADR-NNNN-<kebab-slug>.md\n' \
          "$file" >&2
        errors=$((errors + 1))
      elif [[ "$id" =~ ^ADR-[0-9]{4}$ && "$stem" =~ ^(ADR-[0-9]{4}) ]]; then
        lead="${BASH_REMATCH[1]}"
        if [[ "$lead" != "$id" ]]; then
          printf 'ERROR: %s: ADR filename prefix "%s" does not match id "%s"\n' \
            "$file" "$lead" "$id" >&2
          errors=$((errors + 1))
        fi
      fi
    elif [[ -n "$spec_bundle" ]]; then
      # A bundle's documents share a directory, so the filename carries the
      # role and the id carries role plus bundle (RFC-003 section 5).
      expected_id="$spec_role-$spec_bundle"
      if [[ "$id" != "$expected_id" ]]; then
        printf 'ERROR: %s: spec-bundle id must be "%s" (got "%s") per RFC-003 section 5\n' \
          "$file" "$expected_id" "$id" >&2
        errors=$((errors + 1))
      fi
    else
      if [[ "$stem" != "$id" ]]; then
        printf 'ERROR: %s: id "%s" does not match filename stem "%s"\n' \
          "$file" "$id" "$stem" >&2
        errors=$((errors + 1))
      fi
    fi
  fi
done < <(find "$KNOWLEDGE_DIR" -name "*.md" -print0 | sort -z)

# Rule 9a: a spec bundle has one lifecycle, so its documents share a status
# (RFC-003 sections 4, 5).
for bundle in "${!bundle_statuses[@]}"; do
  read -ra bundle_status_list <<< "${bundle_statuses[$bundle]}"
  distinct=$(printf '%s\n' "${bundle_status_list[@]}" | sort -u)
  if (($(printf '%s\n' "$distinct" | wc -l) > 1)); then
    printf 'ERROR: %s/specs/%s: spec bundle has mixed status values (%s); a bundle shares one lifecycle (RFC-003 section 4)\n' \
      "$KNOWLEDGE_DIR" "$bundle" "$(printf '%s' "$distinct" | tr '\n' ' ' | sed 's/ $//')" >&2
    errors=$((errors + 1))
  fi
done

# Rule 9b: a spec bundle whose tasks are all complete must be archived
# (RFC-002 section 3). A bundle with no tasks.md, or a tasks.md carrying no
# checkboxes, is out of scope: tasks.md is optional.
for bundle in "${!bundle_tasks_file[@]}"; do
  tasks_file="${bundle_tasks_file[$bundle]}"
  total=$(grep -cE '^[[:space:]]*[-*][[:space:]]+\[[ xX]\]' "$tasks_file" || true)
  ((total == 0)) && continue
  open=$(grep -cE '^[[:space:]]*[-*][[:space:]]+\[[[:space:]]\]' "$tasks_file" || true)
  ((open > 0)) && continue
  read -ra bundle_status_list <<< "${bundle_statuses[$bundle]:-}"
  for s in "${bundle_status_list[@]}"; do
    if [[ "$s" != "archived" ]]; then
      printf 'ERROR: %s/specs/%s: all tasks complete but status is "%s"; a shipped spec is archived after extraction (RFC-002 section 3)\n' \
        "$KNOWLEDGE_DIR" "$bundle" "$s" >&2
      errors=$((errors + 1))
      break
    fi
  done
done

# Rule 6: the mandatory constitution must be present.
if [[ "$has_constitution" == false ]]; then
  printf 'ERROR: %s: no constitution found (a document with id "constitution" is the one mandatory artifact)\n' \
    "$KNOWLEDGE_DIR" >&2
  errors=$((errors + 1))
fi

# Rule 7: bundle-index integrity. The index is optional; validated only when
# present.
index_file="$KNOWLEDGE_DIR/index.md"
if [[ -f "$index_file" ]]; then
  declare -A index_targets
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    [[ "$target" == *"://"* ]] && continue
    target="${target%%\#*}"
    [[ -z "$target" ]] && continue
    index_targets["$target"]=1
  done < <(grep -oE '\]\([^)]+\)' "$index_file" | sed -e 's/^](//' -e 's/)$//')

  # Every governed document must be listed in the index.
  if ((governed_count > 0)); then
    for rel in "${governed_rel[@]}"; do
      if [[ -z "${index_targets[$rel]:-}" ]]; then
        printf 'ERROR: %s: governed document "%s" is not listed in the bundle index\n' \
          "$index_file" "$rel" >&2
        errors=$((errors + 1))
      fi
    done
  fi

  # Every index entry must resolve to an existing file under the bundle root.
  for target in "${!index_targets[@]}"; do
    if [[ ! -f "$KNOWLEDGE_DIR/$target" ]]; then
      printf 'ERROR: %s: index entry "%s" does not resolve to an existing file\n' \
        "$index_file" "$target" >&2
      errors=$((errors + 1))
    fi
  done
fi

if ((errors > 0)); then
  printf 'Frontmatter validation failed: %d error(s) across %d file(s).\n' "$errors" "$file_count" >&2
  exit 1
fi

printf 'Frontmatter OK: %d file(s) validated.\n' "$file_count"
