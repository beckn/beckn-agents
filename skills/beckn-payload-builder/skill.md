---
name: beckn-payload-builder
version: 1.0.0
description: Understands Beckn 2.0.0 LTS core schema and generates complete, valid sample payloads for all API actions given a use case description. Detects when domain-specific custom schemas are needed and maps them correctly. Covers retail, food & beverage, grocery, EV charging, energy (P2P trading, demand flex), and data marketplace (DDM) domains.
tags: [beckn, protocol, payload, api, schema, retail, food, energy, ev-charging, p2p-trading, demand-flex, data-marketplace, ddm, deg]
license: MIT
---

## Authoritative spec source

The **canonical schema** is the `draft` branch of `protocol-specifications-v2`:
https://github.com/beckn/protocol-specifications-v2/tree/draft — file `api/v2.0.0/beckn.yaml`

Reference examples:
- `examples/retail/food-and-beverages/IN/pizza-delivery-2.0/`
- `examples/retail/food-and-beverages/IN/pizza-delivery/`

> **CRITICAL**: DEG repo examples use an older EOS schema format with snake_case context fields
> (`bap_id`, `transaction_id`) and `message.order`. Those formats are INVALID in v2.0.0 LTS.
> Always use the draft spec structure with camelCase context fields.

## Step 1 — Parse the use case

Read the user's scenario and extract:

1. **Domain** — What vertical? (`food-and-beverage`, `retail`, `energy/ev-charging`, `energy/p2p-trading`, `energy/demand-flex`, `data/ddm`, etc.)
2. **Actors** — Who is the buyer (BAP side) and seller/provider (BPP side)?
3. **Resource** — What good, service, or data is being exchanged?
4. **Fulfillment type** — Physical delivery? Service? Energy transfer? Data download? API access?
5. **Customization** — Does the buyer configure the resource (size, toppings, connector type, etc.)?
6. **Consideration** — Payment method, currency, price structure (per-unit, per-kWh, flat, time-series)?
7. **Special terms** — Reservations, cancellation, tracking, rating, gift, loyalty, policy-as-code?
8. **Transaction scope** — Discovery only? Full order lifecycle? Post-fulfillment?

## Step 2 — Map to the transaction lifecycle

See [./references/transaction-flows.md](./references/transaction-flows.md) for full lifecycle reference by domain type.

Standard lifecycle:
```
discover → on_discover
select → on_select
init → on_init
confirm → on_confirm
[status / on_status]*
[update / on_update]*
[cancel / on_cancel]?
[track / on_track]*
rate / on_rate
support / on_support
```

## Step 3 — Identify custom schemas

**Before proposing any new schema**, check `https://schema.beckn.io` for existing schemas.

If the user has not specified a domain or schema set, **ask**:
> "Which domain or schema set should I check for existing schemas? (e.g. retail, energy/DEG, data/DDM, mobility, healthcare — or say 'none' to skip)"

Only after confirming no suitable schema exists at schema.beckn.io should you propose a new one.

See [./references/custom-schemas.md](./references/custom-schemas.md) for the known catalogue.

Custom schemas attach to core entities via `*Attributes` extension fields:

| Extension field | Attaches to | Key types |
|---|---|---|
| `resourceAttributes` | Catalog `resources[]` entry | domain resource properties |
| `offerAttributes` | Catalog `offers[]` entry | customization, pricing rules |
| `commitmentAttributes` | `Contract.commitments[]` | line-item details, domain type |
| `contractAttributes` | `Contract` | buyer prefs, contract-level terms |
| `performanceAttributes` | `Contract.performance[]` | delivery, service, energy execution |
| `considerationAttributes` | `Contract.consideration[]` | payment, price breakdown |
| Participant direct props | `Contract.participants[]` | role-specific identity — no `participantAttributes` wrapper |

For energy and data domains, see [./references/domain-schemas-energy-data.md](./references/domain-schemas-energy-data.md).

## Step 4 — Generate payloads

See [./references/payload-templates.md](./references/payload-templates.md) for canonical shapes.

### Context block — EVERY payload (camelCase, no domain field)

```json
{
  "context": {
    "version": "2.0.0",
    "action": "<action-name>",
    "bapId": "<bap.example.com>",
    "bapUri": "https://<bap.example.com>/beckn",
    "bppId": "<bpp.example.com>",
    "bppUri": "https://<bpp.example.com>/beckn",
    "networkId": "beckn:<network-id>",
    "transactionId": "<uuid-same-across-flow>",
    "messageId": "<uuid-new-per-pair>",
    "timestamp": "<ISO8601-UTC>",
    "ttl": "PT30S"
  }
}
```

Rules:
- All context fields are **camelCase** — never `bap_id`, `transaction_id` etc.
- `bppId`/`bppUri` absent only on `discover`
- `transactionId` same across entire discover→confirm flow
- `messageId` new per request; callback echoes same `messageId`
- No `domain` field — domain identity goes in `networkId` or catalog `@context`

### @context / @type rule — CRITICAL

> **`@context` and `@type` belong ONLY on `*Attributes` extension objects and the top-level `Contract`.**
> Core Beckn schema objects (`Descriptor`, `Location`, `Catalog`, `Resource`, `Offer`, `Commitment`,
> `Consideration`, `Performance`, `Participant`, `Entitlement`) are already defined by `beckn.yaml`
> and do **NOT** need `@context`/`@type` inline in the payload.

| Object | @context/@type? |
|---|---|
| `Contract` (top-level only) | ✅ Yes — `"@context": "https://schema.beckn.io/Contract/v2.0"` |
| `*Attributes` (all extension bags) | ✅ Yes — specifies which domain schema |
| Everything else (Descriptor, Location, Participant, Commitment, Consideration, Performance, Resource, Offer, Catalog, Entitlement) | ❌ No |

### Catalog structure (on_discover)

```
message.catalogs[]
  ├── id, descriptor { name, shortDesc }, bppId, bppUri, providerId
  └── resources[]
      ├── id, descriptor { name, shortDesc }, isActive, price { currency, value }
      ├── provider { id, descriptor, locations[] }
      └── resourceAttributes { @context, @type, ...domain fields }
```

Offers array under catalog: `offers[]` — each offer has `id`, `resourceIds[]`, `price`, `offerAttributes { @context, @type, ... }`

### Contract structure (select → confirm)

```
message.contract
  ├── @context: "https://schema.beckn.io/Contract/v2.0"
  ├── @type: "beckn:Contract"
  ├── id (UUID, assigned by BPP)
  ├── displayId (human-readable, e.g. "ORD-20260310-001")
  ├── status { code: DRAFT|ACTIVE|CANCELLED|COMPLETE }
  ├── participants[] { id, displayName, telephone, email, ...role props }
  ├── commitments[]
  │   ├── id, status { descriptor { code } }, resources[], offer { id, resourceIds[] }
  │   └── commitmentAttributes { @context, @type, lineId, offerId, quantity, price, resourceId, ... }
  ├── consideration[]
  │   ├── id, status { descriptor { code: PENDING|SETTLED|VOIDED } }
  │   └── considerationAttributes { @context, @type, currency, value, components[] }
  └── performance[]
      ├── id, status { descriptor { code, name } }
      └── performanceAttributes { @context, @type, ...domain delivery/service fields }
```

## Step 5 — Version discipline checklist

Before writing any payload, confirm:
- [ ] Context fields camelCase (`bapId` not `bap_id`, `messageId` not `message_id`)
- [ ] No `domain` key in context
- [ ] `version: "2.0.0"` present
- [ ] Contract has top-level `@context: "https://schema.beckn.io/Contract/v2.0"` and `@type: "beckn:Contract"`
- [ ] `@context`/`@type` ONLY on `*Attributes` objects and the top-level Contract — NOT on Descriptor, Location, Consideration, Commitment, Performance, Participant, Resource, Offer, Catalog, Entitlement
- [ ] Catalog uses `resources[]` not `items[]`
- [ ] Contract uses `performance[]` not `fulfillments[]`
- [ ] Participants use direct props (id, displayName, telephone, email) — no `participantAttributes` wrapper
- [ ] Consideration `components[]` has type/value/currency/description (not old `breakup[]`)
- [ ] Status code on `on_confirm` is `ACTIVE` (not `CONFIRMED`)

## Step 6 — Custom schema detection

Ask yourself:
- **Food/beverage prepared item?** → `beckn:FnBItem` in `resourceAttributes` + `commitmentAttributes`; `beckn:FnBPriceSpecification` in `considerationAttributes`
- **F&B customizable offer?** → `beckn:FnBOffer` with `customization.groups[]` in `offerAttributes`
- **F&B/retail delivery?** → `beckn:HyperlocalDelivery` in `performanceAttributes`
- **Grocery item?** → `GroceryItem` schema in `resourceAttributes`
- **EV charging station?** → `EvChargingService` in `resourceAttributes`; `EvChargingOffer` in `offerAttributes`; `EvChargingSession` in `performanceAttributes`
- **P2P energy trade?** → `EnergyResource` in `resourceAttributes`; `EnergyTradeOffer` (with BecknTimeSeries) in `offerAttributes`; `EnergyCustomer` direct props on Participant
- **Demand flex event?** → `DemandFlexNeed` in `resourceAttributes`; `DemandFlexBuyOffer` in `offerAttributes`
- **Dataset/data exchange?** → `DatasetItem` in `resourceAttributes`; `DatasetFulfillment` in `performanceAttributes`
- **New domain?** → First check `https://schema.beckn.io` for existing schemas. Ask the user which domain/schema set to search. Only propose a new schema after confirming no existing one fits.

## Step 7 — Output format

1. **Beckn mapping** — 2–4 sentences: BAP, BPP, resource, offer, performance, consideration
2. **Transaction flow** — numbered list with one-line descriptions
3. **Schema table** — which `*Attributes` schemas used and why
4. **Payloads** — one labelled fenced JSON block per action
5. **Schema gap analysis** — any domain data not covered by existing schemas

## Reference files

- [references/core-schema.md](references/core-schema.md) — Full v2.0.0 draft data model
- [references/transaction-flows.md](references/transaction-flows.md) — Lifecycle by domain type
- [references/custom-schemas.md](references/custom-schemas.md) — Retail + F&B schema catalogue
- [references/domain-schemas-energy-data.md](references/domain-schemas-energy-data.md) — DEG (EV, P2P, flex) + DDM schemas
- [references/payload-templates.md](references/payload-templates.md) — Canonical JSON shapes
- [references/usage-guide.md](references/usage-guide.md) — Input format and examples
