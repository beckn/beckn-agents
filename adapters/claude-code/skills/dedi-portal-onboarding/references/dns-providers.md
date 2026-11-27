# DNS records for DeDi onboarding

DeDi proves namespace (domain) ownership with a **DNS TXT** record. Hosting a callback/host may also
need an **A** record (or CNAME). Two rules hold for every provider:

- **Get the exact TXT name and value from the DeDi portal's verification step.** Never invent the
  token.
- **The credential stays with the operator.** Never put an API key in a URL or ask for it in chat;
  if there is no DNS MCP, the operator runs the API call or edits DNS in their provider portal.

Order of preference: **(1) a DNS MCP if connected → (2) the provider API, operator-run → (3) the
provider portal via the browser tool.**

## 1. DNS MCP (preferred when available)

List the available tools first (an MCP may be deferred). If a DNS provider MCP is connected
(Cloudflare, Namecheap, Route 53, etc.), use its create-record tool: set `type` (`TXT`/`A`), `name`,
`content`/`value`, and `ttl`. These run as the authenticated user, so no key passes through chat.
If none is connected, say so and fall back to mode 2 or 3.

## 2. Provider API (operator-run)

### Namecheap

`namecheap.domains.dns.setHosts` **replaces the full host list**, so include existing records plus
the new one. Params use `HostName1/RecordType1/Address1/TTL1`, `...2`, etc. Example (operator runs
it; `<API_KEY>` is theirs, never logged):

```
https://api.namecheap.com/xml.response?ApiUser=<user>&ApiKey=<API_KEY>&UserName=<user>
  &ClientIp=<ip>&Command=namecheap.domains.dns.setHosts
  &SLD=example&TLD=com
  &HostName1=@&RecordType1=TXT&Address1=<dedi-txt-value>&TTL1=300
  &HostName2=@&RecordType2=A&Address2=<host-ip>&TTL2=300
```

Enable API access in the Namecheap dashboard and allowlist the client IP first. TXT `HostName` is the
subdomain the portal names (often `@` or `_dedi`-style); copy it exactly.

### Cloudflare

`POST https://api.cloudflare.com/client/v4/zones/<zone_id>/dns_records`
`Authorization: Bearer <token>` · body `{"type":"TXT","name":"<name>","content":"<value>","ttl":300}`
(`A` the same with `content:"<ip>"`). Operator supplies the token.

### AWS Route 53

`aws route53 change-resource-record-sets --hosted-zone-id <id> --change-batch <json>` with an
`UPSERT` of a `TXT` (value **double-quoted**) or `A` record.

### Google Cloud DNS

`gcloud dns record-sets create <name> --zone=<zone> --type=TXT --ttl=300 --rrdatas="<value>"`
(or `--type=A --rrdatas=<ip>`).

## 3. Provider portal via the browser tool

If there is no API/MCP, drive the provider's dashboard with the browser tool (see
`portal-browser-flow.md` session rules). Namecheap: Domain List → **Manage** → **Advanced DNS** →
**Add New Record** → TXT (Host, Value, TTL) and/or A record. The operator stays logged in; the skill
never enters credentials.

## Verify propagation

```
dig +short TXT <name>      # expect the exact DeDi token
dig +short A <host>        # expect the host IP
```

Only return to the DeDi portal to finish verification once these resolve. Propagation can take a few
minutes to a couple of hours depending on the record's previous TTL.
