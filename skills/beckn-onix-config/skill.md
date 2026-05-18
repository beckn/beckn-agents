---
name: beckn-onix-config
version: 1.0.0
description: "Helps developers configure Beckn-ONIX adapter YAML files — covering modules (BAP/BPP), handler steps, plugin wiring (registry, key manager, cache, schema validator, signer, router, publisher, middleware), routing rules, deployment scenarios, and observability setup."
tags: [beckn, onix, configuration, yaml, bap, bpp, plugins, routing, deployment]
license: MIT
---

## Authoritative reference

All configuration options, parameters, defaults, and examples live in the beckn-onix repo:
→ GitHub: https://github.com/beckn/beckn-onix/blob/main/CONFIG.md

**Always read that document first.** It is the single source of truth for every config key.

---

## What CONFIG.md covers

Use it to answer questions about any of these areas:

| Area | What it documents |
|---|---|
| `appName`, `http`, `log` | Top-level app identity, server port/timeouts, log level and destinations |
| `pluginManager` | Local (`root`) and remote (`remoteRoot`) plugin binary paths |
| `modules[]` | The four module types: `bapTxnReceiver`, `bapTxnCaller`, `bppTxnReceiver`, `bppTxnCaller` |
| `handler` | `type`, `role`, `subscriberId`, `httpClientConfig`, `steps[]` |
| Plugins | `registry`, `dediregistry`, `keyManager` (vault / secrets / simple), `cache` (Redis), `schemaValidator` (v1/v2), `signValidator`, `router`, `signer`, `publisher`, `middleware` (reqpreprocessor, reqmapper) |
| Routing rules | `routingRules[]` — `url`, `bpp`, `bap`, `msgq` target types; v1 domain-required vs v2 domain-agnostic behaviour; conflict detection |
| `plugins.otelsetup` | OpenTelemetry OTLP export, audit logs, metrics collected per module |
| Deployment scenarios | local-simple, local-vault, production combined, BAP-only, BPP-only |
| Config file layout | Directory structure for `config/onix/`, `config/onix-bap/`, `config/onix-bpp/` |

---

## How to help a developer

1. **Identify the deployment scenario** first (local dev, production BAP-only, BPP-only, or combined). The right starter file and plugin choices follow from that.
2. **Walk the module list** — confirm which of the four module types are needed and that `path` values are correct.
3. **Wire plugins bottom-up**: key manager → cache → registry → schema validator → sign validator → router → signer/publisher → middleware.
4. **Check routing rules** for protocol version: v1 rules require `domain`; v2 rules are domain-agnostic (one rule per endpoint per version).
5. **Validate** against the CONFIG.md parameter tables — required vs optional, correct types, string-encoded booleans where called for.
6. **Flag common mistakes**:
   - Using `simplekeymanager` in a production config
   - Setting `domain` on a v2 routing rule when there is already another rule for the same version+endpoint
   - Forgetting to set `subscriberId` on BPP handler if per-module node metrics are needed
   - Using `schemav2validator` without setting `type` (`url` or `file`)
