# Beckn 2.0.0 LTS Core Schema Reference

**Source**: `protocol-specifications-v2` — **`core-v2.0.0-lts` release tag** — `api/v2.0.0/beckn.yaml`
**Canonical examples**: `examples/retail/food-and-beverages/IN/pizza-delivery-2.0/`

> Never use older EOS-format examples. The `core-v2.0.0-lts` release tag is authoritative.

---

## @context / @type rule

**Only the `*Attributes` extension bags carry `@context` and `@type` in a Beckn payload**
(`resourceAttributes`, `offerAttributes`, `commitmentAttributes`, `performanceAttributes`, `considerationAttributes`, `contractAttributes`):
```json
{ "@context": "https://schema.nfh.global/FnBItem/v2.1/context.jsonld", "@type": "beckn:FnBItem", ... }
```

**Everything else does NOT get `@context`/`@type`:**
`Contract`, `Catalog`, `Resource`, `Offer`, `Commitment`, `Consideration`, `Performance`, `Participant`, `Descriptor`, `Location`, `Entitlement` — these are all defined by `beckn.yaml` with `additionalProperties: false` and need no inline JSON-LD annotation. `Contract` in particular does NOT define `@context`/`@type` as properties — sending them gets rejected (`property @context is unsupported`); only its `contractAttributes` bag carries JSON-LD.

---

## API Actions

### Discovery
| Action | Caller | Receiver | Message |
|---|---|---|---|
| `discover` | CN | DS/PN | `intent` (textSearch, filters, spatial) |
| `on_discover` | PN/DS | CN | `catalogs[]` |

### Transaction
| Action | Caller | Receiver | Message |
|---|---|---|---|
| `select` | CN | PN | `contract` (DRAFT, with commitments) |
| `on_select` | PN | CN | `contract` (with consideration and performance) |
| `init` | CN | PN | `contract` (adds full buyer participant, delivery location) |
| `on_init` | PN | CN | `contract` (confirms SLA, payment terms) |
| `confirm` | CN | PN | `contract` (echo of on_init, with entitlements/payment proof) |
| `on_confirm` | PN | CN | `contract` (status: ACTIVE, id assigned) |

### Fulfillment
| Action | Notes |
|---|---|
| `status` / `on_status` | Poll or push current contract/fulfillment state |
| `track` / `on_track` | Returns tracking URL or WebSocket endpoint |
| `update` / `on_update` | Modify active contract. `context.try: true` for preview |
| `cancel` / `on_cancel` | Cancel contract. `context.try: true` for cancellation terms |

### Post-fulfillment
| Action | Notes |
|---|---|
| `rate` / `on_rate` | Submit ratings (contract, provider, item, agent) |
| `support` / `on_support` | Request support channels or open ticket |

### Catalog management
| Action | Notes |
|---|---|
| `catalog/publish` | PN pushes catalog(s) to DS |
| `catalog/on_publish` | DS returns ACCEPTED/REJECTED per catalog |

---

## Context object (camelCase — no exceptions)

```yaml
Context:
  version: "2.0.0"          # always "2.0.0"
  action: string             # exact endpoint name (discover, on_select, confirm …)
  timestamp: date-time       # ISO 8601 UTC with Z suffix
  messageId: uuid            # new per request; on_* callback echoes same messageId
  transactionId: uuid        # same across entire discover→confirm flow
  senderId: string              # CN subscriber ID
  bapUri: uri                # CN callback URL
  receiverId: string              # PN subscriber ID — ABSENT only on discover
  bppUri: uri                # PN request URL — ABSENT only on discover
  networkId: string          # "<namespace_id>/<registry_id>" e.g. "beckn.one/testnet-retail"
  ttl: string                # ISO 8601 duration e.g. "PT30S"
```

**NEVER use**: `bap_id`, `bap_uri`, `bpp_id`, `bpp_uri`, `transaction_id`, `message_id`, `domain`

---

## Catalog (on_discover message body)

```yaml
Catalog:
  id: string
  receiverId: string              # echoed from context
  bppUri: string             # echoed from context
  providerId: string
  descriptor:
    name: string
    shortDesc: string
    thumbnailImage: uri
  items: Item[]              # NOT "resources"
  offers: Offer[]
```

### Item (inside catalog.items[])

```yaml
Item:
  id: string
  descriptor:
    name: string
    shortDesc: string
    thumbnailImage: uri
  provider:
    id: string
    descriptor: Descriptor
    locations: Location[]
  category: Descriptor       # codeValue field for category code
  price:
    currency: string         # ISO 4217
    value: number
  isActive: boolean
  resourceAttributes:            # domain extension — carries @context/@type (Attributes schema)
    "@context": "https://schema.nfh.global/<DomainItemType>/v<version>/context.jsonld"
    "@type": "beckn:<DomainItemType>"
    # ... domain fields
```

### Offer (inside catalog.offers[])

```yaml
Offer:
  id: string
  itemId: string
  price:
    currency: string
    value: number
  offerAttributes:           # domain extension — carries @context/@type (Attributes schema)
    "@context": "https://schema.nfh.global/<DomainOfferType>/v<version>/context.jsonld"
    "@type": "beckn:<DomainOfferType>"
    customization:
      groups: CustomizationGroup[]
```

---

## Contract (select → on_confirm message body)

```yaml
Contract:
  # no top-level @context/@type — Contract has additionalProperties: false and defines neither
  id: string                    # uuid assigned by PN (absent in early DRAFT)
  displayId: string             # human-readable e.g. "DOM-BLR-20260310-001"
  status:
    # Descriptor — no @context/@type here either
    code: DRAFT | ACTIVE | COMPLETE | CANCELLED
  participants: Participant[]
  commitments: Commitment[]
  consideration: Consideration[]
  performance: Performance[]    # NOT "fulfillments"
  entitlements: Entitlement[]   # optional — payment proofs, vouchers
```

**Status transitions**:
- `DRAFT` — during select, on_select, init, on_init, confirm
- `ACTIVE` — on on_confirm (NOT "CONFIRMED" — use ACTIVE)
- `COMPLETE` — after fulfillment done
- `CANCELLED` — after cancellation

### Participant

Participants use multi-value `@context` and `@type` arrays. Properties are placed **directly** on the participant object — no `participantAttributes` wrapper.

```yaml
Participant:
  "@context":                   # array of JSON-LD contexts
    - "https://schema.nfh.global/Participant/v2.0"
    - "https://schema.nfh.global/Consumer/v2.0"     # role-specific context
  "@type":                      # array of types
    - "beckn:Participant"
    - "beckn:Consumer"          # role-specific type
  id: string                    # e.g. user@example.com or store-id
  displayName: string
  telephone: string             # direct prop, no wrapper
  email: string                 # direct prop, no wrapper
  descriptor: Descriptor        # optional — for PN participants
  location: Location            # optional — for PN participants
  rating:                       # optional
    ratingValue: number
    ratingCount: integer
```

**Common participant roles**:
- Consumer: `"https://schema.nfh.global/Consumer/v2.0"` / `"beckn:Consumer"`
- Restaurant: `"https://schema.nfh.global/Restaurant/v2.0"` / `"beckn:Restaurant"`
- EnergyCustomer: add EnergyCustomer context + type
- DSO/Utility: add relevant context + type

### Commitment

```yaml
Commitment:
  ref: string                   # item/resource ID being committed
  commitmentAttributes:         # domain extension — carries @context/@type (Attributes schema)
    "@context": "https://schema.nfh.global/<DomainCommitmentType>/v<version>/context.jsonld"
    "@type": "beckn:<DomainCommitmentType>"
    lineId: string              # e.g. "line-001"
    offerId: string
    quantity:
      unitCode: EA | KG | KWH | UNIT
      unitQuantity: number
    price:
      currency: string
      value: number
      components: PriceComponent[]
    resourceId: string          # mirrors ref
    # ... domain fields (classification, cuisine, allergenInfo, etc.)
    item:                       # inline Item object (echoed by PN) — no @context/@type on Item itself
      id: string
      descriptor: Descriptor
      resourceAttributes: { "@context", "@type", ...domain fields }
      price: { currency, value }
      isActive: boolean
    offer:                      # inline Offer object (echoed by PN) — no @context/@type on Offer itself
      id: string
      itemId: string
      offerAttributes: { "@context", "@type", customization: {...} }
      price: { currency, value }
```

### Consideration

```yaml
Consideration:
  status:
    code: PENDING | SETTLED | VOIDED
  considerationAttributes:      # carries @context/@type (Attributes schema)
    "@context": "https://schema.nfh.global/<DomainPriceType>/v<version>/context.jsonld"
    "@type": "beckn:<DomainPriceType>"    # e.g. beckn:FnBPriceSpecification
    currency: string
    value: number                         # total amount
    components:                           # NOT "breakup"
      - type: BASE_ITEM | DELIVERY_FEE | TAX | DISCOUNT | PACKING_FEE | ...
        value: number
        currency: string
        description: string
```

### Fulfillment

```yaml
Fulfillment:
  id: string
  status:
    name: string                # human-readable e.g. "Order Received"
    shortDesc: string
  performanceAttributes:        # carries @context/@type (Attributes schema)
    "@context": "https://schema.nfh.global/<FulfillmentType>/v<version>/context.jsonld"
    "@type": "beckn:<FulfillmentType>"   # e.g. beckn:HyperlocalDelivery
    # ... fulfillment-type fields
```

**HyperlocalDelivery** (food & retail delivery):
```yaml
HyperlocalDelivery:
  pickupLocation: Location
  deliveryLocation: Location
  itemsShipped:
    - itemId: string
      offerId: string
      quantity: QuantityMeasure
      lineId: string
```

### Entitlement

```yaml
Entitlement:
  descriptor:
    name: string
    shortDesc: string
  type: PAYMENT_PROOF | VOUCHER | COUPON
  id: string                   # e.g. UTR reference number
```

---

## Common sub-schemas

### Descriptor
```yaml
Descriptor:
  name: string
  shortDesc: string
  longDesc: string
  code: string           # machine-readable status enum
  thumbnailImage: uri
```

### QuantityMeasure
```yaml
QuantityMeasure:
  unitCode: EA | KG | L | M | BOX | GRAM | ML | KWH | UNIT
  unitQuantity: number
```

### Location
```yaml
Location:
  id: string
  geo:
    type: "Point"
    coordinates: [longitude, latitude]
  address:
    streetAddress: string
    addressLocality: string    # city
    addressRegion: string      # state
    postalCode: string
    addressCountry: string     # ISO-3166-1 alpha-2
```

### Intent (discover)
```yaml
Intent:
  textSearch: string           # free-text query
  filters:                     # JSONPath RFC 9535
    type: "jsonpath"
    expression: string         # e.g. "$[?(@.resourceAttributes.food.classification == 'VEG')]"
                                # RFC 9535 comparisons only: ==, !=, <, <=, >, >=, &&, ||, !
                                # no non-standard operators (~, contains, =~) or JSONPath-Plus-only syntax
  spatial:
    - op: S_DWITHIN
      targets: string          # JSONPath to geo field
      geometry:
        type: "Point"
        coordinates: [lng, lat]
      distanceMeters: number
```

### Tracking (on_track)
```yaml
Tracking:
  id: string
  url: uri
  websocketUrl: uri
  status:
    code: ACTIVE | INACTIVE
```

---

## ACK / NACK

All Beckn actions return a synchronous ACK before the async callback:

```json
{ "message": { "ack": { "status": "ACK" } } }
```

Error NACK:
```json
{ "message": { "ack": { "status": "NACK" } }, "error": { "code": "...", "message": "..." } }
```

---

## Version discipline — quick checklist

| Check | Correct | Wrong |
|---|---|---|
| Context fields | camelCase (`senderId`) | snake_case (`bap_id`) |
| Catalog items | `resources[]` | `items[]` |
| Resource attributes | `resourceAttributes` | `itemAttributes` |
| Contract execution | `performance[]` | `fulfillments[]` |
| Execution attributes | `performanceAttributes` | `fulfillmentAttributes` |
| on_confirm status | `code: "ACTIVE"` | `code: "CONFIRMED"` |
| Participant props | Direct on object | Inside `participantAttributes` wrapper |
| Consideration total | `value` + `components[]` | `totalAmount` + `breakup[]` |
| Contract JSON-LD | Absent (Contract has no `@context`/`@type` properties) | Top-level `@context` + `@type` on contract |
