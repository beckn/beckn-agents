---
name: dedi-onboarding-builder
description: '"Generates the DeDi file-based onboarding set for the NFH fabric — the dedi.index.json manifest and the registry file — for an NFO (Beckn Subscriber Reference registry) or an NP (Beckn Subscriber registry). Validates against the DeDi schemas, sequences signing and digest computation in the correct order, and hands signing off to the Beckn-ONIX signer plugin. Never handles private keys."'
metadata:
  tags: dedi,nfh-fabric,onboarding,beckn,onix,registry,manifest,index,signing,jws,jcs
---


## What this skill does

Walks a Network Facilitator Organisation (NFO) or Network Participant (NP) through producing the two
files that constitute file-based onboarding onto the NFH fabric:

| File | Hosted at | Conforms to |
|---|---|---|
| DeDi index file (manifest) | `https://<domain>/.well-known/dedi.index.json` | [dedi-manifest.schema.json](https://raw.githubusercontent.com/LF-Decentralized-Trust-labs/decentralized-directory-protocol/refs/heads/main/schemas/dedi-manifest.schema.json) |
| Registry file | URL declared in the index file, conventionally `https://<domain>/dedi/<registry-name>.json` | [dedi-file.schema.json](https://raw.githubusercontent.com/LF-Decentralized-Trust-labs/decentralized-directory-protocol/refs/heads/main/schemas/dedi-file.schema.json) |

The registry's records follow the role schema:

- **NFO** → reference registry of its NPs — [beckn_subscriber_reference.json](https://raw.githubusercontent.com/LF-Decentralized-Trust-labs/decentralized-directory-protocol/refs/heads/main/schemas/beckn_subscriber_reference.json)
- **NP** → network key registry (endpoints + keys) — [beckn_subscriber.json](https://raw.githubusercontent.com/LF-Decentralized-Trust-labs/decentralized-directory-protocol/refs/heads/main/schemas/beckn_subscriber.json)

## Authoritative references — fetch live, do not rely on cached copies

1. **DeDi publishing spec** — file format (§5), manifest (§6), signing and verification (§7),
   freshness (§9): https://github.com/LF-Decentralized-Trust-labs/decentralized-directory-protocol/blob/main/docs/publishing-dedi-files.md
2. **The four schemas** linked in the tables above.
3. **NFH fabric onboarding guide** (steps, naming conventions, portal, URL forms):
   https://docs.nfh.global/build/onboarding — file-based path and worked example.
4. **Beckn-ONIX configuration** (signer plugin, key manager):
   https://github.com/beckn/beckn-onix/blob/main/CONFIG.md

## Hard rules

1. **Never ask for, accept, generate, store, or log private key material.** Work with public keys
   only. If the user pastes a private key, tell them to treat it as compromised and rotate it.
   Signing happens in the user's own Beckn-ONIX signer plugin (backed by its key manager) or
   equivalent tooling they control.
2. **DeDi files sign with Ed25519 over JCS (RFC 8785) canonicalized content, as a detached JWS**
   (`alg: EdDSA`, `b64: false`), per spec §7. Do NOT use the ES256/OpenSSL recipe documented for
   network manifests and Rego policy artifacts — that is a different artifact family.
3. **Digest ordering.** The manifest's `files[].digest` commits to the **hosted bytes** of the
   registry file. The registry file must therefore be finalized and signed FIRST; only then is the
   digest computed, and only then is the manifest assembled and signed. A digest taken over a draft
   or unsigned registry is permanently stale.
4. The only hard protocol requirements are: record names unique within a registry, and published
   URLs (in the manifest and in reference records) correct and resolvable. Registry naming below is
   a suggested convention, not a requirement.

## Workflow

### Step 1 — Interview

Collect, asking only for what is missing:

| Input | Notes |
|---|---|
| Role | NFO or NP |
| Domain | The entity's own domain; becomes `domain`, `namespace`, and the hosting origin |
| Network name + environment | Drives the suggested registry name: `<nfoname>_<networkname>_<env>_registry` for an NP, `<nfoname>_<networkname>_<env>_ref_registry` for an NFO (e.g. `nfo-x_mobility_prod_registry`) |
| Signing public key | Ed25519 public key as a JWK (`kty: OKP`, `crv: Ed25519`, `x`), with a `kid`. Public key only — see hard rule 1 |
| NP only: subscriber details | `subscriber_id` (typically the domain), callback URL (ONIX receiver endpoint), role/type, countries, base64 signing public key; one record per role |
| NFO only: NP references | Per NP: `subscriber_id`, registry URL (file-based `https://<np-domain>/dedi/<registry-name>` or hosted `https://api.dedi.global/dedi/lookup/<np-domain>/<registry-name>`), and `type` (`Registry` or `Record`) |

### Step 2 — Generate the registry file

Build the `dedi-file` envelope: `dedi_version`, `type: dedi-file`, `source_url` (must equal the URL
it will be hosted at), `next_update`, `publisher` (domain + public-key JWK), `namespace` (the
domain), `registry` (name, role schema URL, `state: live`, `updated_at`), `records`, and a `proof`
scaffold with `verification_method`, `canonicalization: JCS`, and `jws` left as a placeholder.
Validate the envelope against `dedi-file.schema.json` and every `records[].details` against the
role schema before handing it over for signing.

### Step 3 — First signing handoff (registry file)

The user signs the registry file with their ONIX signer plugin (or equivalent): JCS-canonicalize,
sign Ed25519, place the detached JWS in `proof.jws`. The signed file is then hosted at its
`source_url`. The bytes are now frozen.

### Step 4 — Compute the digest

Over the hosted (signed) registry file bytes: `sha-256:<hex>`. Offer the command:
`echo "sha-256:$(curl -s <registry-url> | shasum -a 256 | cut -d' ' -f1)"` — fetching the hosted
copy, not a local draft, so the digest provably matches what verifiers will see.

### Step 5 — Generate the manifest

Build `dedi.index.json`: `dedi_version`, `type: dedi-manifest`, `domain`, `name`, `keys` (must
include the JWK whose `kid` the proofs reference), `updated_at`, `next_update`, `files[]` (registry
name, URL, the digest from Step 4, role schema URL), and the `proof` scaffold. Freshness discipline
per spec §9: `updated_at` advances only when content changes; `next_update` advances on every
re-issue and must be in the future.

### Step 6 — Second signing handoff (manifest)

Same signing procedure. The manifest is self-signed: its `proof.verification_method` must name a
`kid` present in its own `keys`. Host at `https://<domain>/.well-known/dedi.index.json`.

### Step 7 — Verify end to end

Run the checks a verifier will run (spec §7.3), plus cross-file consistency:

- both files validate against their schemas; record `details` validate against the role schema
- `source_url` equals the actual hosting URL; the well-known path serves the manifest
- `publisher.key` in the registry file appears in the manifest's `keys` (same `kid` and `x`)
- manifest digest matches the hosted registry bytes
- `next_update` is in the future in both files; `registry.state` is `live`
- record names are unique within the registry
- NFO reference records: every referenced URL resolves

### Step 8 — Publish checklist

1. Both signed files hosted at their final URLs (HTTPS, publicly fetchable).
2. Enter the domain on the NFH fabric onboarding portal — always for an NFO; for an NP only when
   onboarding untied to any NFO (otherwise the NFO's reference registry brings the NP into the
   network — the NP shares its registry URL with the NFO).
3. Re-issue before `next_update` passes, even when nothing changed.
4. On every registry change: re-sign registry → re-digest → rebuild + re-sign manifest (hard rule 3).

## Signing with the Beckn-ONIX signer plugin

The ONIX `signer` plugin (with `keyManager` for key storage — vault, secrets, or simple) performs
the signature; configuration lives in
[CONFIG.md](https://github.com/beckn/beckn-onix/blob/main/CONFIG.md). The suggested registry naming
above also keeps the record name reusable as the key ID in the publisher's ONIX configuration.
Whatever the tool, the contract with this skill is the same: the skill produces the unsigned file
and the exact bytes-to-sign procedure (JCS + detached JWS), the user's tooling holds the keys.

## References

- `references/worked-example.md` — a complete mobility network: file-based NFO (`nfo-x.com`),
  file-based NP (`np1.com`), hosted NP (`np2.com`) referenced via dedi.global lookup. Use these as
  output templates; every identifier in them is fictional.
