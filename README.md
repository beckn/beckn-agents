# NFH Beckn Agents

Model-agnostic AI skills for building with the [Beckn Protocol](https://becknprotocol.io) v2.0.0 LTS.

Skills are authored once in plain markdown and published as adapters for Claude Code, Cursor, and any model that accepts a system prompt.

---

## Available Skills

| Skill | What it does |
|---|---|
| [beckn-schema-builder](skills/beckn-schema-builder/skill.md) | Guides schema design decisions — when to create, how to abstract, inheritance vs composition, conformance checklist |
| [beckn-payload-builder](skills/beckn-payload-builder/skill.md) | Generates complete, valid Beckn 2.0.0 payloads for any use case across retail, energy, and data domains |

---

## Using the Skills

### Claude Code

Install the plugin directly from this repo:

```
/plugin install beckn/beckn-agents
```

The skills activate automatically when you work on Beckn-related tasks. You can also invoke them explicitly:

```
/beckn-schema-builder
/beckn-payload-builder
```

### Cursor

Copy the generated Cursor rules to your project:

```bash
cp -r adapters/cursor/.cursor /path/to/your-project/
```

Each skill becomes a rule in `.cursor/rules/`. Cursor picks them up automatically based on context, or you can reference them in chat with `@beckn-schema-builder`.

### Any model via API / system prompt

Every skill is a plain markdown file. Paste the contents of `skills/<name>/skill.md` as a system prompt, then send your user message. Works with Claude, GPT-4o, Gemini, Mistral, or any instruction-following model.

Example with the Anthropic API:

```python
import anthropic, pathlib

skill = pathlib.Path("skills/beckn-payload-builder/skill.md").read_text()

client = anthropic.Anthropic()
message = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=4096,
    system=skill,
    messages=[{
        "role": "user",
        "content": "Generate payloads for a buyer searching for an EV charging station near Koramangala, Bangalore."
    }]
)
print(message.content[0].text)
```

For skills that reference files in `references/`, append those files to the system prompt or provide them as context:

```python
import pathlib

skill_dir = pathlib.Path("skills/beckn-payload-builder")
skill = skill_dir.joinpath("skill.md").read_text()

# Append all reference files
for ref in sorted(skill_dir.joinpath("references").glob("*.md")):
    skill += f"\n\n---\n<!-- {ref.name} -->\n\n" + ref.read_text()
```

### OpenAI-compatible APIs

Same pattern — use the assembled skill text as the `system` message content.

```python
from openai import OpenAI
import pathlib

skill = pathlib.Path("skills/beckn-schema-builder/skill.md").read_text()

client = OpenAI()
response = client.chat.completions.create(
    model="gpt-4o",
    messages=[
        {"role": "system", "content": skill},
        {"role": "user", "content": "Should I create a new schema for a halal-certified grocery item in UAE?"}
    ]
)
```

---

## Authoring a New Skill

### 1. Create the skill directory

```
skills/
└── your-skill-name/
    ├── skill.md          ← required
    └── references/       ← optional supporting knowledge files
        └── guide.md
```

### 2. Write `skill.md`

Use this frontmatter:

```markdown
---
name: your-skill-name
version: 1.0.0
description: One sentence describing when and why to use this skill.
tags: [tag1, tag2, tag3]
license: MIT
---

## Purpose
What does this skill help with?

## When to use this skill
Describe activation conditions in plain English — both for human readers
and for models deciding whether to apply this skill.

## Step-by-step workflow
...
```

**Frontmatter fields:**

| Field | Required | Notes |
|---|---|---|
| `name` | yes | lowercase, hyphen-separated |
| `version` | yes | semver |
| `description` | yes | used as the trigger description in platform adapters |
| `tags` | no | YAML list, helps with discovery |
| `license` | no | defaults to repo license |

### 3. Writing effective skills

**Make the description trigger-precise.** The `description` field is what platform adapters use to decide when to activate the skill. Be specific about the user's intent, not just the topic:

```yaml
# Too vague — activates too broadly
description: Helps with Beckn protocol things.

# Good — activates on the right tasks
description: Use when the user is designing a new Beckn domain schema, deciding whether to extend an existing schema, or preparing a schema for submission to the Beckn registry.
```

**Reference files instead of bloating `skill.md`.** If the skill needs detailed lookup tables, example payloads, or spec excerpts, put them in `references/` and link to them:

```markdown
See [./references/payload-templates.md](./references/payload-templates.md) for canonical shapes.
```

Platform adapters handle references differently:
- Claude Code: copies `references/` alongside `SKILL.md` (relative links work)
- Cursor: inlines all reference files into a single `.mdc` (no broken links)
- Direct API use: append reference files manually (see examples above)

**Write for a model reading cold.** Assume the model has no prior context. Every step should be self-contained. Prefer numbered workflows over prose paragraphs.

**No platform-specific directives.** Do not use `<tool>`, `allowed-tools`, or any syntax tied to a specific platform. Those go in adapter headers generated by `build.sh`, not in the canonical skill.

### 4. Build the adapters

```bash
chmod +x build.sh
./build.sh
```

This generates:
- `adapters/claude-code/skills/your-skill-name/SKILL.md`
- `adapters/cursor/.cursor/rules/your-skill-name.mdc`

### 5. Commit both source and generated files

```bash
git add skills/your-skill-name/ adapters/
git commit -m "add your-skill-name skill"
```

Committing generated adapters means users can install without running the build script.

---

## Repository Structure

```
beckn-agents/
├── skills/                          ← canonical skill definitions (author here)
│   ├── beckn-schema-builder/
│   │   ├── skill.md
│   │   └── references/
│   └── beckn-payload-builder/
│       ├── skill.md
│       └── references/
│           ├── core-schema.md
│           ├── transaction-flows.md
│           ├── custom-schemas.md
│           ├── domain-schemas-energy-data.md
│           ├── payload-templates.md
│           └── usage-guide.md
├── adapters/                        ← generated by build.sh (do not edit directly)
│   ├── claude-code/
│   │   ├── plugin.json
│   │   └── skills/
│   └── cursor/
│       └── .cursor/
│           └── rules/
├── build.sh                         ← generates adapters from canonical skills
└── README.md
```

---

## Contributing

1. Fork the repo
2. Add or update a skill under `skills/`
3. Run `./build.sh` to regenerate adapters
4. Open a PR with both source and generated files

Please keep skills focused on a single domain. If a skill is growing large reference sections, split it rather than combining.

---

## License

MIT — see [LICENSE](LICENSE)
