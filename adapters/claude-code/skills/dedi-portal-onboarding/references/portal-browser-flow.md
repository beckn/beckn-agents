# Portal flow with a browser tool (Claude in Chrome)

The hosted DeDi onboarding is a portal (UI) action. This is the click-by-click flow for driving
`dedi.global` with a browser tool. The exact labels may change — read the page, don't assume — so
treat the field **names** below (which come from the role schemas) as the source of truth, not the
button text.

## 0. Session setup (do this first, every time)

- If the browser tools are deferred, load them in **one** `ToolSearch` call:
  `tabs_context_mcp, navigate, computer, read_page, tabs_create_mcp, tabs_close_mcp`,
  plus `find`, `form_input` for forms.
- Call `tabs_context_mcp` once before anything else.
- Open a **new** tab (`tabs_create_mcp`) to `https://dedi.global`. Do not reuse an unrelated tab.
- **The operator logs in themselves.** Never type the account password, an API key, or a one-time
  code. If the portal is not already authenticated, stop and ask the operator to sign in, then continue.
- Never click an element that triggers a native `alert`/`confirm`/`prompt` dialog; it freezes the
  extension. Prefer reading state back through the public query API over scraping the DOM.

## 1. Create the namespace

1. Go to the namespaces / "Create namespace" area.
2. Enter the entity's **domain** as the namespace (e.g. `nfo-x.com`).
3. Submit, then **confirm the namespace exists** by reading it back:
   `GET https://api.dedi.global/dedi/query/<namespace>` (or the namespace page).
4. The portal will issue a **DNS TXT** challenge to prove domain ownership — capture the exact
   record **name** and **value** it shows. Complete it with `references/dns-providers.md` (mode C),
   then return and finish verification. Do **not** guess the token.

## 2. Create the registry

1. Inside the namespace, "Create registry".
2. **Name** by convention: `<nfoname>_<networkname>_<env>_registry` (NP) or
   `<nfoname>_<networkname>_<env>_ref_registry` (NFO).
3. **Role schema**:
   - NP → *Beckn Subscriber* (endpoints + keys).
   - NFO → *Beckn Subscriber Reference* (references to NPs).
4. Set `state` to `live` when prompted. Confirm with
   `GET https://api.dedi.global/dedi/query/<namespace>/<registry>`.

## 3. Add records

Confirm the exact values with the operator **before** each submit (writes are live and shared).

- **NP subscriber record** (one per role — BAP/"VAP", BPP/"VPP", CS, DS, CDS):
  `subscriber_id`, `url` (ONIX callback base), `type`, `countries`, `signing_public_key`,
  `encr_public_key`. Public keys only.
- **NFO reference record**: `subscriber_id`, `url` (the NP's lookup URL, e.g.
  `https://api.dedi.global/dedi/lookup/<np>/<registry>`), `type` = `Registry` or `Record`.
  Validate the NP first (its callback, role, key, environment).

After each add, read it back: `GET /dedi/lookup/<namespace>/<registry>/<record>` and check `state: live`.

## 4. Finish

- Complete portal domain verification once DNS resolves (mode C).
- Re-query the registry; confirm all records present and `live`.
- Record a short summary for the operator: namespace, registry, record names, and the lookup URLs
  to share (an NFO shares nothing extra; an NP shares its registry lookup URL with its NFO).

## If a step fails 2–3 times

Stop and report what you tried, the page state, and ask the operator how to proceed — do not loop on
a failing click or explore unrelated pages.
