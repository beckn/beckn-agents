# Worked example — hosted onboarding (fictional)

Every identifier here is invented. Use it as a shape, not as real values. Fetch live schemas and
confirm the exact portal fields and DNS token before acting.

## Scenario

- NFO: **`nfo-x.com`**, running the `mobility` network, `prod` environment.
- NP: **`np1.com`**, a buyer-side app (BAP) and a seller-side app (BPP).
- Hosted on dedi.global.

## NP (np1.com) onboards itself

1. **Namespace** `np1.com`. Portal issues TXT challenge `name=_dedi.np1.com`,
   `value=dedi-verify=4f2a…`. (Exact name/value come from the portal.)
2. **DNS** (Namecheap, operator-run): add TXT `_dedi` → `dedi-verify=4f2a…`, TTL 300. Add A
   `@` → `203.0.113.10` for the ONIX host. `dig +short TXT _dedi.np1.com` returns the token.
3. **Registry** `np1_mobility_prod_registry`, role schema *Beckn Subscriber*, `state: live`.
4. **Records** (public keys only):
   - `bap` — `{subscriber_id:"np1.com", url:"https://np1.com/beckn", type:"BAP",
     countries:["IND"], signing_public_key:"<ed25519-b64>", encr_public_key:"<x25519-b64>"}`
   - `bpp` — same with `type:"BPP"` (and its own endpoint if different).
5. **Verify**: `GET https://api.dedi.global/dedi/query/np1.com/np1_mobility_prod_registry` shows both
   records `live`. Share the registry lookup URL with the NFO.

## NFO (nfo-x.com) adds the NP

1. **Namespace** `nfo-x.com`, DNS TXT verified (as above).
2. **Registry** `nfo-x_mobility_prod_ref_registry`, role schema *Beckn Subscriber Reference*.
3. **Validate np1** first: read `GET /dedi/lookup/np1.com/np1_mobility_prod_registry/bap` and check
   callback, role, key, environment.
4. **Reference record** `np1` —
   `{subscriber_id:"np1.com", url:"https://api.dedi.global/dedi/lookup/np1.com/np1_mobility_prod_registry", type:"Registry"}`.
5. **Verify**: query the ref registry; the `np1` reference resolves. np1 is now a member of the
   `nfo-x mobility prod` network.

## Testnet note

The real NFH EV-charging testnet reference registry is `nfh.global/testnet-evcharging` (role: Beckn
Subscriber Reference). An NFO adds an NP there as a reference record with `{subscriber_id, url, type}`
after validating the NP — exactly the step above. Do testnet before any production network.
