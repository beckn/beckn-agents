# Adapters

This directory contains **generated** platform-specific adapter files. Do not edit files here directly — they are produced by `build.sh` from the canonical skill definitions in `skills/`.

To regenerate:
```bash
./build.sh
```

## claude-code/

A Claude Code plugin. Install it from any terminal with Claude Code:

```
/plugin install beckn/beckn-agents
```

Or for a project-local install, copy `claude-code/skills/` into your project's `.claude/skills/` directory.

## cursor/

Cursor rules in `.mdc` format. Copy the `.cursor/` directory to your project root:

```bash
cp -r adapters/cursor/.cursor /path/to/your-project/
```

Or copy individual rule files to your existing `.cursor/rules/` directory.
