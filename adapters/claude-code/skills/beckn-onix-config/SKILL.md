---
name: beckn-onix-config
description: '"Helps developers configure Beckn-ONIX adapter YAML files — covering modules (BAP/BPP), handler steps, plugin wiring (registry, key manager, cache, schema validator, schema version mediator, VC validator, payload store, OPA policy checker, signer, router, publisher, middleware), routing rules, deployment scenarios, and observability setup."'
metadata:
  tags: beckn,onix,configuration,yaml,bap,bpp,plugins,routing,deployment,schema-version-mediation,verifiable-credentials,opa,policy
---


## Authoritative reference

All configuration options, parameters, defaults, and examples live in the beckn-onix repo:
→ GitHub: https://github.com/beckn/beckn-onix/blob/main/CONFIG.md

**Always read that document first — fetch it live, don't rely on a cached copy.** It is the
single source of truth for every config key, and this skill deliberately does not duplicate its
parameter tables so it can't go stale as the repo evolves.

A handful of plugins ship in the repo but aren't folded into CONFIG.md's "Available Plugins" list
yet — for those, the plugin's own README (linked below) is the source of truth instead.

---

## What CONFIG.md covers

Use it to answer questions about any of these areas:

| Area | What it documents |
|---|---|
| `appName`, `http`, `log` | Top-level app identity, server port/timeouts, log level and destinations |
| `pluginManager` | Local (`root`) and remote (`remoteRoot`) plugin binary paths |
| `pluginManager.becknConstants` | Signed baseline constants (e.g. `dediregistry.url`, `schemav2validator.type`/`location`) auto-injected at plugin creation time — some are locked (startup fails on contradiction), others are overridable (warning logged) |
| `modules[]` | The four module types: `bapTxnReceiver`, `bapTxnCaller`, `bppTxnReceiver`, `bppTxnCaller` |
| `handler` | `type`, `role`, `subscriberId`, `httpClientConfig`, `steps[]` |
| Plugins documented in CONFIG.md | `registry`, `dediregistry` (+ `allowedNetworkIDs`), `keyManager` (vault / secrets / simple), `cache` (Redis, `use_tls`), `schemaValidator` (v1 JSON schema / v2 OpenAPI + auxiliary specs + extended `@context` validation), `signValidator` (+ `clockSkewToleranceSeconds`), `router`, `signer`, `publisher`, `middleware` (`reqpreprocessor`), `reqmapper` (its own `plugins.<name>` entry — NOT part of `middleware:` — step `transformPayload`), `schemaVersionMediator` (`schemaversionmediator`, step `mediateSchema`), `payloadStore` (`payloadstore`, step `storePayload`), VC validation (`vcvalidator`, step `validateVC`) |
| Plugins documented only via their own README (not yet in CONFIG.md) | `manifestloader` (required companion whenever `schemaversionmediator` or an `opapolicychecker` policy uses `type: manifest`) — [README](https://github.com/beckn/beckn-onix/blob/main/pkg/plugin/implementation/manifestloader/README.md); `opapolicychecker` (Rego/OPA network policy enforcement, step `checkPolicy`) — [README](https://github.com/beckn/beckn-onix/blob/main/pkg/plugin/implementation/opapolicychecker/README.md) |
| Routing rules | `routingRules[]` — `url`, `bpp`, `bap`, `msgq` target types; v1 domain-required vs v2 domain-agnostic behaviour; conflict detection |
| `plugins.otelsetup` | OpenTelemetry OTLP export, audit logs, metrics collected per module |
| Deployment scenarios | local-simple, local-vault, production combined, BAP-only, BPP-only |
| Config file layout | Directory structure for `config/onix/`, `config/onix-bap/`, `config/onix-bpp/` |

Plugin directory in the repo (`pkg/plugin/implementation/`) also has `encrypter` and `decrypter`
entries with no CONFIG.md section and no README as of this writing — treat as in-progress/internal,
don't assume a stable config contract for them without checking the repo directly.

---

## How to help a developer

1. **Identify the deployment scenario** first (local dev, production BAP-only, BPP-only, or combined). The right starter file and plugin choices follow from that.
2. **Walk the module list** — confirm which of the four module types are needed and that `path` values are correct.
3. **Wire plugins bottom-up**: key manager → cache → registry (→ `manifestLoader` if using schema mediation or manifest-backed policies) → schema validator → sign validator → schema version mediator / VC validator / OPA policy checker (as needed) → router → signer/publisher → middleware.
4. **Check step ordering for the newer gated steps** — these have a required relative order, unlike most plugin wiring which is order-independent:
   - `validateSchema` must come before `mediateSchema` (validates the source payload before translation; reversing this breaks `@context` consistency)
   - `validateSign` must come before `validateVC`
   - `checkPolicy` typically runs after schema validation
   - `storePayload` placement controls what gets recorded — put it after `validateSign` to only store signed requests
5. **Check routing rules** for protocol version: v1 rules require `domain`; v2 rules are domain-agnostic (one rule per endpoint per version).
6. **Validate** against the CONFIG.md parameter tables — required vs optional, correct types, string-encoded booleans where called for.
7. **Flag common mistakes**:
   - Using `simplekeymanager` in a production config
   - Setting `domain` on a v2 routing rule when there is already another rule for the same version+endpoint
   - Forgetting to set `subscriberId` on BPP handler if per-module node metrics are needed
   - Using `schemav2validator` without setting `type` (`url` or `file`) — note `type`/`location` are now auto-injected from beckn constants when omitted, so only set them explicitly to override
   - Manually setting `dediregistry.url` to a value that contradicts the signed beckn-constants baseline — this is a locked constant and fails startup, not just a warning
   - Wiring `schemaversionmediator` without a `manifestLoader` plugin in the same handler — it's a hard requirement, not optional
   - Wiring `vcvalidator` (`validateVC` step) without setting `actions` — there is no code default, so gated actions must always be explicit in config
   - Confusing `reqmapper` with `reqpreprocessor` — `reqpreprocessor` lives under the `middleware:` list; `reqmapper` is its own `plugins.<name>` entry (commonly named `payloadTransformer`) with a `transformPayload` step
