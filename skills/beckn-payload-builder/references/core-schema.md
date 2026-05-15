# Beckn 2.0.0 LTS Core Schema Reference

**Source**: `protocol-specifications-v2` — **draft branch** — `api/v2.0.0/beckn.yaml`
**Canonical examples**: `examples/retail/food-and-beverages/IN/pizza-delivery-2.0/`

> Never use the main branch or older EOS-format examples. The draft branch is authoritative.

---

## @context / @type rule

**Only two things carry `@context` and `@type` in a Beckn payload:**

1. **The `Contract` object** (top-level linked-data anchor):
   ```json
   { "@context": "https://schema.beckn.io/Contract/v2.0", "@type": "beckn:Contract", ... }
   ```

2. **All `*Attributes` extension bags** (`resourceAttributes`, `offerAttributes`, `commitmentAttributes`, `performanceAttributes`, `considerationAttributes`, `contractAttributes`):
   ```json
   { "@context": "https://schema.beckn.io/FnBItem/v2.1/context.jsonld", "@type": "beckn:FnBItem", ... }
   ```

**Everything else does NOT get `@context`/`@type`:**
`Catalog`, `Resource`, `Offer`, `Commitment`, `Consideration`, `Performance`, `Participant`, `Descriptor`, `Location`, `Entitlement` — these are all defined by `beckn.yaml` and need no inline JSON-LD annotation.

---

## API Actions

### Discovery
| Action | Caller | Receiver | Message |
|---|---|---|---|
| `discover` | BAP | CDS/BPP | `intent` (textSearch, filters, spatial) |
| `on_discover` | BPP/CDS | BAP | `catalogs[]` |

### Transaction
| Action | Caller | Receiver | Message |
|---|---|---|---|
| `select` | BAP | BPP | `contract` (DRAFT, with commitments) |
| `on_select` | BPP | BAP | `contract` (with consideration and performance) |
| `init` | BAP | BPP | `contract` (adds full buyer participant, delivery location) |
| `on_init` | BPP | BAP | `contract` (confirms SLA, payment terms) |
| `confirm` | BAP | BPP | `contract` (echo of on_init, with entitlements/payment proof) |
| `on_confirm` | BPP | BAP | `contract` (status: ACTIVE, id assigned) |

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
| `catalog/publish` | BPP pushes catalog(s) to CDS |
| `catalog/on_publish` | CDS returns ACCEPTED/REJECTED per catalog |

---

## Context object (camelCase — no exceptions)

```yaml
Context:
  version: "2.0.0"          # always "2.0.0"
  action: string             # exact endpoint name (discover, on_select, confirm …)
  timestamp: date-time       # ISO 8601 UTC with Z suffix
  messageId: uuid            # new per request; on_* callback echoes same messageId
  transactionId: uuid        # same across entire discover→confirm flow
  bapId: string              # BAP subscriber ID
  bapUri: uri                # BAP callback URL
  bppId: string              # BPP subscriber ID — ABSENT only on discover
  bppUri: uri                # BPP request URL — ABSENT only on discover
  networkId: string          # "beckn:<namespace>:<region>" e.g. "beckn:retail-network:in"
  ttl: string                # ISO 8601 duration e.g. "PT30S"
```

**NEVER use**: `bap_id`, `bap_uri`, `bpp_id`, `bpp_uri`, `transaction_id`, `message_id`, `domain`

---

## Catalog (on_discover message body)

```yaml
Catalog:
  "@context": "https://schema.beckn.io/"
  "@type": "beckn:Catalog"
  id: string
  bppId: string              # echoed from context
  bppUri: string             # echoed from context
  providerId: string
  descriptor:
    "@context": "https://schema.beckn.io/"
    "@type": "beckn:Descriptor"
    name: string
    shortDesc: string
    thumbnailImage: uri
  items: Item[]              # NOT "resources"
  offers: Offer[]
```

### Item (inside catalog.items[])

```yaml
Item:
  "@context": "https://schema.beckn.io/"
  "@type": "beckn:Resource"
  id: string
  descriptor:
    "@context": "https://schema.beckn.io/"
    "@type": "beckn:Descriptor"
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
  resourceAttributes:            # domain extension — NOT "resourceAttributes"
    "@context": "https://schema.beckn.io/"
    "@type": "beckn:<DomainItemType>"
    # ... domain fields
```

### Offer (inside catalog.offers[])

```yaml
Offer:
  "@context": "https://schema.beckn.io/"
  "@type": "beckn:Offer" | "beckn:FnBOffer"
  id: string
  itemId: string
  price:
    currency: string
    value: number
  offerAttributes:           # domain extension
    "@context": "https://schema.beckn.io/"
    "@type": "beckn:<DomainOfferType>"
    customization:
      groups: CustomizationGroup[]
```

---

## Contract (select → on_confirm message body)

```yaml
Contract:
  "@context": "https://schema.beckn.io/Contract/v2.0"   # required top-level JSON-LD
  "@type": "beckn:Contract"
  id: string                    # uuid assigned by BPP (absent in early DRAFT)
  displayId: string             # human-readable e.g. "DOM-BLR-20260310-001"
  status:
    "@context": "https://schema.beckn.io/"
    "@type": "beckn:Descriptor"
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
    - "https://schema.beckn.io/Participant/v2.0"
    - "https://schema.beckn.io/Consumer/v2.0"     # role-specific context
  "@type":                      # array of types
    - "beckn:Participant"
    - "beckn:Consumer"          # role-specific type
  id: string                    # e.g. user@example.com or store-id
  displayName: string
  telephone: string             # direct prop, no wrapper
  email: string                 # direct prop, no wrapper
  descriptor: Descriptor        # optional — for BPP participants
  location: Location            # optional — for BPP participants
  rating:                       # optional
    ratingValue: number
    ratingCount: integer
```

**Common participant roles**:
- Consumer: `"https://schema.beckn.io/Consumer/v2.0"` / `"beckn:Consumer"`
- Restaurant: `"https://schema.beckn.io/Restaurant/v2.0"` / `"beckn:Restaurant"`
- EnergyCustomer: add EnergyCustomer context + type
- DSO/Utility: add relevant context + type

### Commitment

```yaml
Commitment:
  "@context": "https://schema.beckn.io/"
  "@type": "beckn:Commitment"
  ref: string                   # item/resource ID being committed
  commitmentAttributes:         # domain extension — contains line details
    "@context": "https://schema.beckn.io/"
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
    item:                       # inline Item object (echoed by BPP)
      "@context": "https://schema.beckn.io/"
      "@type": "beckn:Resource"
      id: string
      descriptor: Descriptor
      resourceAttributes: { "@context", "@type", ...domain fields }
      price: { currency, value }
      isActive: boolean
    offer:                      # inline Offer object (echoed by BPP)
      "@context": "https://schema.beckn.io/"
      "@type": "beckn:Offer" | "beckn:FnBOffer"
      id: string
      itemId: string
      offerAttributes: { "@context", "@type", customization: {...} }
      price: { currency, value }
```

### Consideration

```yaml
Consideration:
  "@context": "https://schema.beckn.io/"
  "@type": "beckn:Consideration"
  status:
    "@context": "https://schema.beckn.io/"
    "@type": "beckn:Descriptor"
    code: PENDING | SETTLED | VOIDED
  considerationAttributes:
    "@context": "https://schema.beckn.io/"
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
  "@context": "https://schema.beckn.io/"
  "@type": "beckn:Fulfillment"
  id: string
  status:
    "@context": "https://schema.beckn.io/"
    "@type": "beckn:Descriptor"
    name: string                # human-readable e.g. "Order Received"
    shortDesc: string
  performanceAttributes:        # NOT "performanceAttributes"
    "@context": "https://schema.beckn.io/"
    "@type": "beckn:<FulfillmentType>"   # e.g. beckn:HyperlocalDelivery
    # ... fulfillment-type fields
```

**HyperlocalDelivery** (food & retail delivery):
```yaml
HyperlocalDelivery:
  "@type": "beckn:HyperlocalDelivery"
  pickupLocation: Location
  deliveryLocation: Location
  itemsShipped:
    - "@context": [...multi-context array...]
      "@type": [...multi-type array...]
      itemId: string
      offerId: string
      quantity: QuantityMeasure
      lineId: string
```

### Entitlement

```yaml
Entitlement:
  descriptor:
    "@context": "https://schema.beckn.io/"
    "@type": "beckn:Descriptor"
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
  "@context": "https://schema.beckn.io/"
  "@type": "beckn:Descriptor"
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
  "@context": "https://schema.beckn.io/"
  "@type": "beckn:Location"
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
    "@context": "https://schema.beckn.io/"
    "@type": "beckn:Descriptor"
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
| Context fields | camelCase (`bapId`) | snake_case (`bap_id`) |
| Catalog items | `resources[]` | `items[]` |
| Resource attributes | `resourceAttributes` | `itemAttributes` |
| Contract execution | `performance[]` | `fulfillments[]` |
| Execution attributes | `performanceAttributes` | `fulfillmentAttributes` |
| on_confirm status | `code: "ACTIVE"` | `code: "CONFIRMED"` |
| Participant props | Direct on object | Inside `participantAttributes` wrapper |
| Consideration total | `value` + `components[]` | `totalAmount` + `breakup[]` |
| Contract JSON-LD | Top-level `@context` + `@type` on contract | Absent |
