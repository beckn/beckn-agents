#!/usr/bin/env bash
# Generates platform-specific adapters from canonical skill definitions in skills/*/skill.md
set -euo pipefail

SKILLS_DIR="skills"
ADAPTERS_DIR="adapters"

extract_frontmatter_field() {
  local file="$1" field="$2"
  grep "^${field}:" "$file" | head -1 | sed "s/^${field}: *//"
}

strip_frontmatter() {
  # Drops everything between the first and second --- delimiters (inclusive)
  awk 'BEGIN{f=0} /^---/{f++; if(f==2){skip=1; next}} skip{print; skip=0; next} f>=2{print}' "$1"
}

echo "Building adapters..."

# ── Claude Code ───────────────────────────────────────────────────────────────
echo "  [claude-code]"
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/skill.md"
  [ -f "$skill_file" ] || continue

  out_dir="$ADAPTERS_DIR/claude-code/skills/$skill_name"
  mkdir -p "$out_dir"

  name=$(extract_frontmatter_field "$skill_file" "name")
  description=$(extract_frontmatter_field "$skill_file" "description")
  tags=$(extract_frontmatter_field "$skill_file" "tags" | tr -d '[]' | sed 's/, */,/g')

  {
    echo "---"
    echo "name: $name"
    echo "description: $description"
    if [ -n "$tags" ]; then
      echo "metadata:"
      echo "  tags: $tags"
    fi
    echo "---"
    echo ""
    strip_frontmatter "$skill_file"
  } > "$out_dir/SKILL.md"

  # Copy references verbatim — Claude Code follows relative paths
  if [ -d "$skill_dir/references" ]; then
    rm -rf "$out_dir/references"
    cp -r "$skill_dir/references" "$out_dir/references"
  fi

  echo "    wrote $out_dir/SKILL.md"
done

# ── Cursor ────────────────────────────────────────────────────────────────────
echo "  [cursor]"
cursor_rules_dir="$ADAPTERS_DIR/cursor/.cursor/rules"
mkdir -p "$cursor_rules_dir"

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/skill.md"
  [ -f "$skill_file" ] || continue

  description=$(extract_frontmatter_field "$skill_file" "description")
  out_file="$cursor_rules_dir/$skill_name.mdc"

  {
    echo "---"
    echo "description: $description"
    echo "alwaysApply: false"
    echo "---"
    echo ""
    strip_frontmatter "$skill_file"

    # Inline all reference files so Cursor has a single self-contained rule
    if [ -d "$skill_dir/references" ]; then
      for ref_file in "$skill_dir/references"/*.md; do
        [ -f "$ref_file" ] || continue
        ref_name=$(basename "$ref_file")
        echo ""
        echo "---"
        echo "<!-- inlined reference: $ref_name -->"
        echo ""
        cat "$ref_file"
      done
    fi
  } > "$out_file"

  echo "    wrote $out_file"
done

echo ""
echo "Done."
echo "  Claude Code → $ADAPTERS_DIR/claude-code/   (install: /plugin install beckn/beckn-agents)"
echo "  Cursor      → $ADAPTERS_DIR/cursor/        (copy .cursor/ to your project root)"
