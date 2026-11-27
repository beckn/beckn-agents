# Worked example — hosted onboarding (fictional)

Every identifier, key, token and IP here is invented. Use it as a shape, not as real values. Routes
are the code-verified ones from `references/api-endpoints.md`; confirm field details against the
target instance's live `openapi.yaml` before acting.

Two columns throughout: **Portal** (browser tool, `references/portal-browser-flow.md`) and **API**
(authenticated with the operator's `X-API-Key` — the operator runs these; the skill never holds the
key). Base `https://api.dedi.global`.

## Scenario

- NFO: **`nfo-x.com`**, network `mobility`, env `prod`.
- NP: **`np1.com`**, a buyer-side app (BAP) and a seller-side app (BPP).
- DNS at **Namecheap**. Hosted on dedi.global.

## NP (np1.com) onboards itself

**1. Create the namespace**
```
POST /dedi/create-namespace
X-API-Key: <np1-operator-key>
{ "name": "np1.com", "description": "Akasha-style EV buyer app" }
```
Note the `namespace_id` it returns (a `76EU…`-style id) — the DNS step needs it.

**2. Prove the domain (DNS TXT)**
```
GET /dedi/generate-dns-txt/<namespace_id>/np1.com      # returns the exact TXT name + value
```
Publish that TXT at Namecheap (operator-run; `<KEY>` is theirs, never logged). `setHosts` replaces
the whole host list, so include existing records plus the new ones:
```
https://api.namecheap.com/xml.response?ApiUser=np1&ApiKey=<KEY>&UserName=np1&ClientIp=<ip>
  &Command=namecheap.domains.dns.setHosts&SLD=np1&TLD=com
  &HostName1=_dedi&RecordType1=TXT&Address1=<txt-value-from-dedi>&TTL1=300
  &HostName2=@&RecordType2=A&Address2=203.0.113.10&TTL2=300
```
Then:
```
dig +short TXT _dedi.np1.com        # expect the DeDi token
POST /dedi/verify-domain            # trigger verification
GET  /dedi/check-verification/<namespace_id>   # poll until verified
```
(If a DNS MCP is connected, use its create-record tool for the TXT/A instead of the Namecheap URL —
see `references/dns-providers.md`.)

**3. Create the registry** (role schema: Beckn Subscriber)
```
POST /dedi/np1.com/create-registry
{ "registry_name": "np1_mobility_prod_registry",
  "description": "np1 subscriber endpoints + keys",
  "schema": "<beckn_subscriber role schema>" }
```

**4. Add records** (public keys only; one per role)
```
POST /dedi/np1.com/np1_mobility_prod_registry/save-record-as-draft?publish=true
{ "record_name": "bap", "description": "np1 BAP",
  "details": { "subscriber_id": "np1.com", "url": "https://np1.com/beckn", "type": "BAP",
               "countries": ["IND"], "signing_public_key": "<ed25519-b64>",
               "encr_public_key": "<x25519-b64>" } }
```
Repeat with `record_name:"bpp"`, `type:"BPP"`.

**5. Verify** (public reads — no auth)
```
GET /dedi/query/np1.com/np1_mobility_prod_registry     # both records, state: live
```
Share the registry lookup URL with the NFO.

## NFO (nfo-x.com) adds the NP

1. **Namespace + DNS** for `nfo-x.com` (steps 1–2 above, with the NFO's key).
2. **Registry** (role: Beckn Subscriber Reference):
   ```
   POST /dedi/nfo-x.com/create-registry
   { "registry_name": "nfo-x_mobility_prod_ref_registry", "description": "mobility prod members",
     "schema": "<beckn_subscriber_reference role schema>" }
   ```
3. **Validate np1 first**: `GET /dedi/lookup/np1.com/np1_mobility_prod_registry/bap` — check callback,
   role, key, environment.
4. **Reference record**:
   ```
   POST /dedi/nfo-x.com/nfo-x_mobility_prod_ref_registry/save-record-as-draft?publish=true
   { "record_name": "np1", "description": "np1 membership",
     "details": { "subscriber_id": "np1.com",
                  "url": "https://api.dedi.global/dedi/lookup/np1.com/np1_mobility_prod_registry",
                  "type": "Registry" } }
   ```
5. **Verify**: `GET /dedi/query/nfo-x.com/nfo-x_mobility_prod_ref_registry` — the `np1` reference
   resolves. np1 is now a member of the `nfo-x mobility prod` network.

## Grant access without sharing a key

API keys are account-wide. To let a teammate's account write to this namespace/registry, use
`POST /dedi/nfo-x.com/add-namespace-delegate` (or `.../add-delegate` on a registry) rather than
sharing the key.

## Testnet note

The real NFH EV-charging testnet reference registry is `nfh.global/testnet-evcharging` (role: Beckn
Subscriber Reference). An NFO adds an NP there as a reference record with `{subscriber_id, url, type}`
after validating the NP — exactly step 4 above. Do testnet before any production network.
