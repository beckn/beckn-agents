---
name: dedi-portal-onboarding
version: 0.1.0
description: "Onboards a Network Facilitator Organisation (NFO) or Network Participant (NP) onto the NFH fabric using the HOSTED DeDi registry at dedi.global — creating the namespace, the registry, and the subscriber / reference records through the DeDi portal (driven with a browser tool such as Claude in Chrome) or the hosted API — and proving domain control with a DNS TXT record plus optional A records, across DNS providers (Namecheap and others), using a DNS MCP when one is available. The hosted counterpart to dedi-onboarding-builder (file-based). Never handles private keys or account passwords."
tags: [dedi, dedi-global, onboarding, nfh-fabric, beckn, namespace, registry, subscriber, dns, txt-verification, namecheap, browser, mcp]
license: MIT
---

## What this skill does

Onboards an entity onto the **NFH fabric** using the **hosted** DeDi registry at `dedi.global`
(API `https://api.dedi.global`), by creating — in order — a **namespace**, a **registry**, and the
**records** inside it, then proving domain control over the namespace with **DNS**.

Two onboarding paths exist. Pick one:

| Path | Where the registry lives | Skill |
|---|---|---|
| **Hosted** | `dedi.global` (portal + `api.dedi.global`) | **this skill** |
| **File-based** | the entity's own domain (`/.well-known/dedi.index.json` + a signed registry file) | [`dedi-onboarding-builder`](../dedi-onboarding-builder/skill.md) |

Use the file-based skill when the entity self-hosts signed files; use **this** skill when it registers
on the hosted dedi.global directory.

### Entities and roles

- **Namespace** — the entity's identity in DeDi, tied to its domain (e.g. `nfo-x.com`). Proven by DNS.
- **Registry** — a typed collection inside a namespace. Its **role schema** decides what it holds:
  - **NFO** → a *Beckn Subscriber Reference* registry — references to its NPs' registries/records.
  - **NP** → a *Beckn Subscriber* registry — its own endpoint + public keys.
- **Record** — one entry. For an NP, one record **per subscriber role**. In Beckn the subscriber
  roles are **BAP** (consumer / buyer-side node, "VAP") and **BPP** (provider / seller-side node,
  "VPP"), plus `CS`, `DS`, `CDS`. "Add a VAP / VPP" = add a record whose `type` is `BAP` / `BPP`.

## Authoritative references — fetch live, never invent

Per this repo's ground rules, **never invent an endpoint, schema field, URL or DNS token.** When the
exact write route, field or verification token is not already confirmed below, fetch it:

1. **DeDi docs MCP** (`dedi-docs`) or `https://dedi-global.gitbook.io/docs` — hosted portal + API.
2. **NFH fabric onboarding guide** — `https://docs.nfh.global/build/onboarding` (append `.md` for
   Markdown, or `GET https://docs.nfh.global/index.md?ask=<question>&goal=<goal>`). The NFO step is
   *"If you are an NFO: add NPs to your network."*
3. **DeDi protocol schemas** (role schemas) —
   `https://github.com/LF-Decentralized-Trust-labs/decentralized-directory-protocol`.
4. The live **portal** itself, read through the browser tool.

**Confirmed public read endpoints** (safe to use directly; verify writes against the docs):

- Namespace/registry query: `GET https://api.dedi.global/dedi/query/<namespace>/<registry>`
- Record lookup: `GET https://api.dedi.global/dedi/lookup/<namespace>/<registry>/<record>`

## Hard rules

1. **Never ask for, accept, store, or log a private signing key**, and **never type the operator's
   DeDi account password or an API key into a login form or request.** Authentication is the
   operator's to perform. Work with **public** keys only. If a private key is pasted, tell the user
   to rotate it.
2. **Writes go to a shared, live registry.** Before every create (namespace, registry, record),
   show the exact values and get explicit confirmation. Prefer **sandbox / testnet** first.
3. **Validate the NP before adding a reference** (NFO path): confirm its callback URL, role, public
   key and environment match what was supplied (read its record with the lookup endpoint).
4. **Verify by reading back.** After any write, re-read with the query/lookup endpoint and confirm
   `state: live` and the expected fields — do not report success from the write response alone.
5. **No secrets in URLs or query strings.** API keys and tokens stay with the operator's tooling.

## Operating mode A — browser tool (primary; the portal is UI-driven)

The hosted onboarding guide describes portal actions, so driving the portal with a browser tool
(e.g. **Claude in Chrome**) is the robust path. See `references/portal-browser-flow.md` for the
click-by-click flow. In outline:

1. **Load the browser tool** and `tabs_context` first; open a new tab to `dedi.global`.
2. **The operator logs in** (OAuth / magic link / API key). The skill never enters the password.
3. **Create the namespace** for the entity's domain.
4. **Create the registry** — choose the role schema (Subscriber for an NP, Subscriber Reference for
   an NFO); name it by the convention `<nfoname>_<networkname>_<env>_registry` (NP) or
   `..._ref_registry` (NFO).
5. **Add records** (see "The records" below), confirming each before submit.
6. **Prove the domain with DNS** (mode C), then complete verification in the portal.
7. **Verify** every write with the public query/lookup endpoints.

Never trigger a native browser dialog; read results back with the query API rather than scraping.

## Operating mode B — hosted API

Reads use the confirmed endpoints above. **Writes require the namespace account's API key**, which
the skill must **not** embed or request in chat — the operator runs the authenticated write with
their own tooling, or uses mode A. For the exact write routes and bodies, consult `dedi-docs`; do
not hardcode an unverified route.

## The records

Build the record `details` to the role schema (fetch the live schema; fields confirmed from the
NFH testnet registry):

- **NP — Beckn Subscriber** (`type: BAP|BPP|CS|DS|CDS`): `subscriber_id` (the domain),
  `url` (ONIX callback base), `type`, `countries`, `signing_public_key`, `encr_public_key`.
- **NFO — Beckn Subscriber Reference** (`type: Registry|Record`): `subscriber_id`, `url`
  (the NP's DeDi lookup URL, e.g. `https://api.dedi.global/dedi/lookup/<np>/<registry>`), `type`.
  Record names must be unique within the registry.

## Operating mode C — DNS (domain proof + hosting)

DeDi proves namespace ownership with a **DNS TXT** record; hosting a callback/host often also needs
an **A** record. Get the **exact TXT name and value from the portal's verification step** (do not
invent the token). Then set the records with whatever the operator uses — in order of preference:

1. **A DNS MCP if one is connected** (e.g. a Cloudflare/Namecheap MCP) — list tools first and use it.
2. **The provider's API** (operator supplies/runs the credential). Namecheap:
   `namecheap.domains.dns.setHosts` (worked example in `references/dns-providers.md`).
3. **The provider portal via the browser tool** (Namecheap → *Advanced DNS*, etc.).

Then confirm propagation: `dig +short TXT <name>` and `dig +short A <host>` before finishing portal
verification. `references/dns-providers.md` covers Namecheap, Cloudflare, Route 53, Google Cloud DNS
and the generic pattern.

## Verify end to end

- `GET /dedi/query/<namespace>/<registry>` returns the registry with your records, `state: live`.
- Each NP record resolves via `/dedi/lookup/...`; NFO reference `url`s resolve.
- DNS TXT (and A) resolve publicly; the portal shows the namespace **verified**.
- Record names unique; `next_update` (if shown) in the future.

## References

- `references/portal-browser-flow.md` — Claude-in-Chrome steps for the dedi.global portal.
- `references/dns-providers.md` — TXT/A via Namecheap, Cloudflare, Route 53, Google Cloud DNS, MCP, generic.
- `references/worked-example.md` — a complete hosted NFO + NP onboarding (fictional identifiers).
