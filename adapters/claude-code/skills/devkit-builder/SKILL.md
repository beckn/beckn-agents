---
name: devkit-builder
description: 'Builds a runnable Beckn devkit (docker-compose stack + onix-adapter config + routing rules + catalog publishing + sandbox mock fixtures + its own README) for a domain, given payloads produced by beckn-payload-builder. Follows the two-file compose convention, v2.0.0 LTS routing config, real registry-checked test identities, starter-kit''s decentralized catalog-publishing model, and sandbox-2.0''s undocumented response-resolution rules — all learned by booting real adapters, not by reading docs.'
metadata:
  tags: beckn,onix,devkit,docker-compose,adapter,routing,sandbox,testnet,deployment
---


## What this skill produces

A self-contained devkit directory (`<domain>-devkit/`) that a developer can `docker compose up` and
immediately exchange real, schema-validated Beckn payloads against, modeled on the existing devkits
in `starter-kit/generic-devkit`, `mobility-devkit`, `local-retail`, `DEG/devkits`, and
`financial-services`. It takes as input the payload set produced by the `beckn-payload-builder`
skill (search/on_search through the full lifecycle for the domain) and wraps them in a working
onix-adapter + sandbox-mock stack.

Layout to produce:

```
<domain>-devkit/
  install/
    docker-compose-<domain>.yml          # published-image variant
    docker-compose-<domain>-local.yml    # local-build variant
    Caddyfile
  config/
    <domain>-bap.yaml
    <domain>-bpp.yaml
    <domain>-routing-BAPCaller.yaml
    <domain>-routing-BAPReceiver.yaml
    <domain>-routing-BPPCaller.yaml
    <domain>-routing-BPPReceiver.yaml
  payloads/                              # from beckn-payload-builder
    bap/{search,select,init,confirm,status,update,cancel,track,rate,support}.json
    bpp/{on_search,on_select,on_init,on_confirm,on_status,...}.json
  sandbox-payloads/<networkId>/response/ # sandbox-2.0 fixtures, path MUST equal networkId
  data/beckn/                            # catalogPublisher outputRoot, bind-mounted (Step 8)
  postman/ or api-collection/            # optional, mirror an existing devkit if present
  README.md                              # own README, templated from sibling devkits (Step 9)
```

Adapt directory names to whichever sibling devkit's layout is closest to the target domain
(`local-retail`'s `testnet/<domain>-devkit/` nesting for commerce domains, `mobility-devkit`'s flat
layout, `financial-services`' testnet nesting for regulated/contract-heavy domains) — don't invent a
new layout when a close analog already exists.

## Step 1 — Gather inputs before writing anything

1. **Payload set.** If not already provided, run the `beckn-payload-builder` skill for the domain's
   full transaction lifecycle first. Every payload the devkit ships must already be schema-valid
   per that skill's own live-validation loop (Step 7 below re-validates against a real adapter —
   don't skip straight there without payload-builder's static pass first).
2. **Adapter config shape.** Use the `beckn-onix-config` skill (and CONFIG.md, fetched live) to
   produce `<domain>-bap.yaml` / `<domain>-bpp.yaml` and the four routing-rule files. Don't hand-copy
   another domain's config verbatim — wire plugins per that skill's guidance, then only reuse
   literal values (ports, image tags, Redis address pattern) from a sibling devkit.
3. **Closest sibling devkit.** Pick the structurally nearest existing devkit as your layout
   template — `local-retail` is the cleanest v2.0.0-native reference; prefer it when nothing else
   fits better.
4. **Registered test identities.** Do not invent `senderId`/`receiverId`/`subscriberId` values.
   Either reuse `starter-kit/generic-devkit`'s already-registered `bap.example.com`/`bpp.example.com`
   identities and their checked-in keys as a bootstrap, or confirm the domain already has its own
   registered subscribers. Verify liveness before using an identity — see Step 4.

## Step 2 — Two-file docker-compose convention

Every devkit ships **two** compose files, same services and config, differing only in the adapter
image source:

| File | Adapter image | Notes |
|---|---|---|
| `docker-compose-<domain>.yml` | `fidedocker/onix-adapter:latest` | Published image, no build step, works immediately — this is the default path most developers should use. |
| `docker-compose-<domain>-local.yml` | `beckn-onix:latest` | Requires the operator to `docker build` that image from a local `beckn-onix` checkout first — state this prerequisite prominently in the devkit README. |

Required services in both files:

- **`redis`** (or `redis-bap`/`redis-bpp` split, matching your chosen template) — must have a
  `healthcheck` (`redis-cli ping`), and every adapter service that depends on it must use
  `depends_on: <redis>: condition: service_healthy`, not a bare `depends_on` list. An adapter that
  starts before Redis is ready fails silently on first request.
- **`caddy`** — a single reverse-proxy entry point (service name `beckn-router` or similar),
  exposing exactly one host port, routing `/bap/*` → `onix-bap` and `/bpp/*` → `onix-bpp`. Write the
  matching `Caddyfile` alongside it.
- **`onix-bap`**, **`onix-bpp`** — the adapters themselves, config mounted from `../config`.
- **`sandbox-bap`**, **`sandbox-bpp`** (optional but recommended for a devkit meant to run
  standalone without a real counterparty) — `fidedocker/sandbox-2.0:latest` mocks; see Step 5 for
  their volume-mount contract.

Keep both compose files' service definitions identical except the adapter `image:` (and, for the
local variant, dropping `platform:` pins if the locally built image doesn't need them) — a drift
between the two files is a maintenance trap, diff them before finishing.

## Step 3 — Routing config: `version`, not `domain`

Routing rule YAML for v2.0.0 LTS **must** use:

```yaml
version: "2.0.0"
```

**Never** `domain: "..."` — that key is a v1-era leftover. It still parses (no hard error), but a
real adapter logs a live boot warning: `"Domain field ... is not needed for version 2.0.0 and will
be ignored"`. Some copied-from-v1 templates (including `starter-kit/generic-devkit`'s
`generic-routing-*.yaml`, if used as a source) still carry `domain:` — strip it when adapting.
Use `local-retail`'s routing YAML as the clean v2.0.0-native reference with no `domain` field
anywhere.

Don't just grep for `domain:` and delete it — confirm the fix by actually booting the adapter and
reading its own startup logs (Step 7), since this is the kind of thing that "looks fine" statically
but only proves out live.

## Step 4 — Context field identity: `bapUri`/`bppUri` are real addresses, real registry checks

`context.bapUri` / `context.bppUri` in every payload must be the **actual reachable endpoint** the
adapter should route to, not a placeholder domain:

- For a devkit meant to run fully locally: Docker-network hostnames of your own containers, e.g.
  `http://onix-bap:8081/bap/receiver`, `http://onix-bpp:8082/bpp/receiver` — never fictional
  external-looking domains like `bap.lending.example.com`. `targetType: "bpp"`/`"bap"` routing rules
  resolve straight to `context.bppUri`/`bapUri` — a fake hostname is a live DNS failure
  (`"no such host"`), not a validation warning.
- `senderId`/`receiverId`/`subscriberId` values must be **real, registered** identities if the
  devkit will hit DeDi (`fabric.nfh.global`) for signature verification — a fictional identity
  404s and verification can't complete. `starter-kit`'s shared `bap.example.com`/`bpp.example.com`
  identities (with keys already checked into `generic-devkit/config`) are a reusable bootstrap
  before a domain has its own dedicated registered entities.
- Every registered subscriber has a `network_memberships` array. Check it live before picking a
  `networkId` for your payloads — don't invent one:
  ```bash
  curl https://fabric.nfh.global/registry/dedi/lookup/<subscriberId>/subscribers.beckn.one/<keyId>
  ```
  A `networkId` not in that subscriber's actual memberships produces
  `"context.network_id ... is not in network_memberships of subscriber"`.

## Step 5 — sandbox-2.0 mock: response resolution is by `networkId`, undocumented

`fidedocker/sandbox-2.0` resolves its canned responses by `context.networkId`, not by any
documented convention. This was found by reading its shipped source directly:

```bash
docker run --rm --entrypoint sh fidedocker/sandbox-2.0:latest -c "cat <path to controller.js/utils>"
```

On receiving an action it builds `jsons/<context.networkId>/response/<action>.json` under its
`RESPONSES_BASE_PATH` and reads from that exact path — falling back **silently** to `{}` (a
`console.warn`, no error surfaced to the caller) if the path doesn't exist.

Consequences for the devkit you build:

- The `sandbox-bap`/`sandbox-bpp` volume mount target
  (`/app/dist/webhook/jsons/<path>/response`) must equal your payloads' `networkId` **exactly**, or
  callbacks silently carry no `message` and debugging looks like a routing problem when it isn't.
- Keep the response-fixture directory path and the `networkId` value identical always — this is
  the pattern `local-retail` uses (`networkId: beckn.one/testnet-retail` ↔ mount path
  `sandbox-payloads/beckn.one/testnet-retail/response`), and it's why that devkit never hits this
  footgun.
- If Step 4's registry-membership constraint forces you to decouple them temporarily (registered
  `networkId` ≠ desired fixture path), the mount target and the payload `networkId` become a
  coupled pair that nothing else enforces — call this out explicitly in the devkit's README and in
  a comment next to the compose volume line, because a silent `{}` fallback gives no signal that
  the coupling broke.

## Step 6 — onix-adapter's local-schema dev mode (for devkits testing unmerged/custom schemas)

Only relevant when the domain's schema isn't merged into the public schema registry yet. Found by
extracting strings from the shipped plugin binary — not documented anywhere:

```bash
docker run --rm --entrypoint sh fidedocker/onix-adapter:latest -c \
  "strings /app/plugins/schemav2validator.so | grep -i localSchema"
```

- Config key: `extendedSchema_localSchemaPath`, a `schemaValidator` plugin field alongside
  `extendedSchema_enabled` / `extendedSchema_allowedDomains`.
- Mount the repo's schema directory into the container, e.g. `../../../schema:/app/schema-local`,
  and set `extendedSchema_localSchemaPath: "/app/schema-local"`.
- The adapter resolves a schema by `@type` name locally first (log line
  `Loading from memory: <Type>/attributes.yaml`) before ever attempting the remote `@context` URL
  fetch — this unblocks testing a custom schema still on an unmerged branch, no dependency on
  `raw.githubusercontent.com` already having the content.
- **Gotcha — caching**: successes and failures are both cached in memory. Editing a schema file
  while the stack is running requires `docker compose restart onix-bap onix-bpp` to pick it up; it
  does not watch the filesystem. Include this restart step in the devkit README's iteration loop.
- **Gotcha — nested `$ref`s still go over the network**: a schema's own `$ref` to another schema
  (e.g. composing a core type like `FormSubmission`) resolves over the network regardless of local
  mode. Check every nested `$ref` target is a real, reachable URL — a dead redirect target (e.g. an
  old `schema.beckn.io` link) breaks validation with no obvious connection to the ref that caused it.

Wire this into whichever compose file(s) actually need it — typically only the `-local` variant, or
both if the published image also ships the plugin (check for the string above in
`fidedocker/onix-adapter:latest` too before assuming it's build-variant-only).

## Step 7 — Live-validate against a real adapter before calling the devkit done

Static schema review misses things a running adapter catches. Boot the stack
(`docker compose -f install/docker-compose-<domain>.yml up`) and POST every payload in the lifecycle
through it. Known classes of live-only failures to specifically check for (informed by, but not
limited to, prior sessions):

- Action payloads that need `message.contract` (`select`, `status`, `on_select`, ...) must use that
  exact key — not ad-hoc wrapper shapes.
- `Contract.commitments` (minItems 1) is required on every `Contract` instance, even on
  `status`/`on_status` polls where only `contract.id` is functionally needed.
- `Commitment.resources[]` items must be full `Resource` objects (`id` + `quantity`), never bare ID
  strings.
- `Commitment.status` / `Contract.status` nest under `{descriptor: {code}}`; `Consideration.status`
  does **not** — it's a bare `{code}` (`$ref: Descriptor` directly). Easy to get backwards.
- `Contract` has no top-level `@context`/`@type` (`additionalProperties: false`) — only
  `*Attributes` bags carry those.
- `Offer` has no `price` property — use `considerations[]`.

**General principle:** whenever a payload-authoring skill's static rules and a live schema
validator disagree, trust the live validator, fix the skill/payloads, and don't assume the static
rules were ground truth. Bring up a real adapter as a core step of building any devkit — never as
an afterthought or something left to "the user can test it later."

## Step 8 — Catalog publishing: every new devkit follows starter-kit's decentralized model

Wire `catalogPublisher` into every new devkit's BPP config — this is not optional or
domain-specific, and it is currently missing or incomplete in several existing devkits (check the
target domain's config for `catalogPublisher`/`catalog/publish`/`catalogBaseURL` before assuming
it's already there; `financial-services` has it wired correctly, `local-retail` and
`mobility-devkit` do not yet — don't copy their BPP config as a catalog-publishing reference, only
`starter-kit/generic-devkit` and `financial-services` qualify for that).

The model is **publish-plain-files-and-let-a-crawler-find-them**, not a central Cataloging Service
call — read `starter-kit/README.md`'s "Catalog Publishing (`catalog/publish`)" section in full
before wiring this, it is the authoritative walkthrough. Key points to carry into the new devkit:

1. **`onix-bpp` exposes `/catalog/publish`** — a DS-internal, same-operator, unsigned trigger (no
   ACK/NACK envelope). Request shape: `context` (only `action` is meaningful),
   `message.catalogs[]` (full `Catalog` objects, each carrying its own `id`, used verbatim as
   `catalogId`), `message.publishDirectives[]` (matched to a catalog by `catalogId`; `catalogType`
   `MASTER`/`REGULAR` required, `visibleTo` is a **relevance filter only, never an access gate** —
   catalogs are public unconditionally). It diffs against what was last published, producing a
   fresh baseline, an incremental change file, or a no-op; resubmitting unchanged content is a
   no-op, not an error.
2. **Config wiring in `<domain>-bpp.yaml`**: `catalogPublisher` plugin with `outputRoot` (e.g.
   `/beckn` in-container), bind-mounted to a host directory (e.g. `data/beckn/`) via the compose
   file — so published files are inspectable directly on disk, no need to exec into the container.
   Set `catalogBaseURL` to the public URL the compose file's reverse proxy (`caddy`/`beckn-router`)
   actually serves that mount at (e.g. `.../beckn` route) — this is a **separate, manually-kept-in-sync**
   setting, not derived from any other URL in the stack; if the tunnel/public domain changes, both
   must be updated together, or published index URLs 404.
3. **Discoverability is opt-in and separate from writing the files.** Files land under
   `outputRoot`/`data/beckn/` (`index/becknCatalogs.index.json`, `catalogs/<localName>.v<n>.json.gz`,
   `catalogs/<localName>.latest.json.gz`, `catalogs/changes/...`) regardless. For those files to
   actually show up in `discover` results elsewhere on the network, the devkit's registered
   Subscriber record needs `meta.catalog_index_urls` pointing at the public index URL — this is a
   DeDi-registration step, not a compose/config step; document it in the devkit README as an
   optional "make it network-discoverable" section, distinct from the mandatory "run
   `catalog/publish` locally and see files land on disk" happy path.
4. **Don't build the old, retired model** — no ACK/NACK response body, no `catalog/subscription`
   CRUD, no central Cataloging Service call, no `authMethods`/download gates. If a domain's existing
   examples or docs describe that older shape, treat them as stale and follow the plain-files +
   `catalog_index_urls` model instead — same principle as Step 7's "trust the live validator over a
   stale static doc," applied to catalog publishing docs specifically.
5. **Verify it, don't just wire it.** Boot the stack, POST a sample `catalog/publish` call (build
   one from the domain's own `Catalog`/`Resource`/`Offer` schema, matching the shape used elsewhere
   in the devkit's payload set), confirm `status: COMPLETED` / per-catalog `ACCEPTED`, and confirm
   the files actually land under the mounted `data/beckn/` directory. Only chase the DeDi
   registration + public-reachability check (point 3) when the devkit is meant to be reachable on
   the wider testnet, not for a purely local smoke-test devkit.

## Step 9 — README and handoff

**Don't maintain a README template in this skill.** Instead, read the `README.md` from 2–3 of the
closest sibling devkits (`starter-kit/README.md` for the catalog-publishing section specifically,
plus whichever of `local-retail/testnet/*/README.md`, `financial-services/testnet/*/README.md`, or
`mobility-devkit/README.md` is structurally closest to the target domain) and use their structure,
tone, and level of detail as the template — don't reinvent the shape each time, and don't let this
skill's own copy of that structure drift out of sync with what the actual devkits do. Every devkit
in the repo family gets its own `README.md` — this is not optional, and it lives at the devkit's own
root, not only referenced from a top-level index.

At minimum, the generated README should cover: prerequisites (Docker, and for the `-local` variant,
building `beckn-onix:latest` first), which compose file to use and why, how to bring the stack up
and confirm health, where the payload set lives and how to fire the full lifecycle against it (curl
examples or a Postman/API collection if the sibling devkits you drew from ship one), the
`networkId` ↔ sandbox-fixture-path coupling from Step 5 if it applies, the schema-restart caveat
from Step 6 if local-schema mode is wired in, and a catalog-publishing section per Step 8 (local
happy path as the default walkthrough, network-discoverability as a clearly separated optional
section). Link back to the payloads' source (`beckn-payload-builder` output) rather than duplicating
payload content in the README.
