# Hosted DeDi API — endpoints

Routes verified against the DeDi backend source (`nfh-trust-labs/dedi-backend`, `openapi.yaml` +
`src/modules/*/*.routes.ts` + `src/validators/*.validation.ts`). Base: `https://api.dedi.global`.
All paths are under `/dedi`. Confirm field details against the running `openapi.yaml` of the instance
you target before a write — schemas evolve.

## Auth

- Writes require an authenticated principal. Two accepted mechanisms (CORS allows both headers in
  `src/app/createApp.ts`): a logged-in session, or an **API key** sent as **`X-API-Key: <key>`**
  (also accepted on `Authorization`).
- Create a key: `POST /dedi/api-keys`. List: `GET /dedi/api-keys`. Delete: `DELETE /dedi/api-keys/{key_id}`.
- **The operator creates and holds the key. Never enter it in chat, a URL, or a login form, and
  never log it.** API keys here are account-wide (no per-key scope), so treat them as high-value.
- Account/session: `POST /dedi/register` (register/login), `GET /dedi/verify-email`, `GET /dedi/auth/me`.

## Reads (public — safe to call directly)

| Method | Path | Purpose |
|---|---|---|
| GET | `/dedi/lookup/{namespace}` | Namespace lookup |
| GET | `/dedi/lookup/{namespace}/{registry_name}` | Registry lookup |
| GET | `/dedi/lookup/{namespace}/{registry_name}/{record_name}` | Record lookup |
| GET | `/dedi/query/{namespace}` | List a namespace's registries |
| GET | `/dedi/query/{namespace}/{registry_name}` | List a registry's records |
| GET | `/dedi/versions/{namespace}/...` | Version history |
| GET | `/dedi/search/{namespace}` | Search records |

## Writes (authenticated)

### Create namespace
`POST /dedi/create-namespace`
Body: `{ "name": "<domain>", "description": "<text>", "meta"?: {...} }`

### Create registry
`POST /dedi/{namespace}/create-registry`
Body: `{ "registry_name": "<name>", "description": "<text>", "schema"?: <role-schema>, "tag"?: "<tag>", "meta"?: {...} }`
- `schema` is the role schema the records must conform to (Beckn Subscriber for an NP, Beckn
  Subscriber Reference for an NFO).

### Add a record (optionally publish in one call)
`POST /dedi/{namespace}/{registry_name}/save-record-as-draft?publish=true`
Body: `{ "record_name": "<unique>", "description": "<text>", "details": { ... }, "valid_till"?: <...>, "meta"?: {...} }`
- `details` is the record payload conforming to the registry's role schema:
  - NP subscriber: `{ subscriber_id, url, type: "BAP"|"BPP"|"CS"|"DS"|"CDS", countries, signing_public_key, encr_public_key }`
  - NFO reference: `{ subscriber_id, url, type: "Registry"|"Record" }`
- Omit `?publish=true` to keep it a draft, then publish with:
  `POST /dedi/{namespace}/{registry_name}/publish-records` Body: `{ "records": ["<record_name>", ...] }`

### Update
- `POST /dedi/{namespace}/update-namespace`
- `POST /dedi/{namespace}/{registry_name}/update-registry`
- `POST /dedi/{namespace}/{registry_name}/{record_name}/update-record`
- Lifecycle: `inactivate-registry` / `reactivate-registry`; `DELETE .../delete-registry`,
  `DELETE .../delete-records`, `DELETE /dedi/{namespace}/delete-namespace` (soft-delete; see
  `/dedi/deleted/*` and `/dedi/restore/*`).

### Delegation / ownership
`add-namespace-delegate`, `add-delegate` (registry), `transfer-ownership` — use these to grant
another account write access rather than sharing an API key.

## Domain verification (DNS)

| Method | Path | Purpose |
|---|---|---|
| GET | `/dedi/generate-dns-txt/{namespace_id}/{domain}` | Get the TXT record to publish |
| GET | `/dedi/get-dns-txt/{namespace_id}` | Re-fetch the TXT verification record |
| POST | `/dedi/verify-domain` | Trigger verification once the TXT is live |
| GET | `/dedi/check-verification/{namespace_id}` | Check verification status |

Flow: create namespace → `generate-dns-txt` → publish the returned TXT at your DNS provider
(`references/dns-providers.md`) → `verify-domain` → poll `check-verification`. Use the exact TXT
value the API returns; never invent it.

> Bulk: `POST /dedi/bulk-upload` + `GET /dedi/{namespace}/{registry_name}/download-sample-csv` for
> many records at once.
