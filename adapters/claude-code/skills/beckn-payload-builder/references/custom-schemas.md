# Beckn Custom Schema Catalogue

Custom schemas extend core Beckn entities via `*Attributes` extension fields.
Each uses JSON-LD (`@context` + `@type`) for semantic interoperability.

**Container field names** (v2.0.0 LTS draft):
- `resourceAttributes` on `Resource` in catalog
- `offerAttributes` on `Offer`
- `commitmentAttributes` on `Commitment`
- `performanceAttributes` on `Performance`
- `considerationAttributes` on `Consideration`
- `contractAttributes` on `Contract`
- Participant role props directly on `Participant` — no `participantAttributes` wrapper

**`@context`/`@type` rule**: Only `*Attributes` bags and the top-level `Contract` carry these. All other core objects (Descriptor, Location, Commitment envelope, Consideration envelope, Performance envelope, Resource envelope, Catalog, Participant, Entitlement) do NOT get `@context`/`@type`.

---

## Schema detection decision tree

```
Food/beverage (pizza, burger, meal, snack)?
  → FnBItem (resourceAttributes + commitmentAttributes)
  → FnBOffer if customizable (offerAttributes)
  → HyperlocalDelivery (performanceAttributes) for delivery
  → FnBPriceSpecification (considerationAttributes)

Grocery item (vegetables, packaged goods)?
  → GroceryItem (resourceAttributes)

Home/kitchen/furniture?
  → HomeAndKitchenItem (resourceAttributes)

EV charging?
  → EvChargingService (resourceAttributes)
  → EvChargingOffer (offerAttributes)
  → EvChargingSession (performanceAttributes)

P2P energy trade?
  → EnergyResource (resourceAttributes)
  → EnergyTradeOffer (offerAttributes)
  → EnergyCustomer direct props on Participant

Demand flex event?
  → DemandFlexNeed (resourceAttributes)
  → DemandFlexBuyOffer (offerAttributes)

Dataset/data exchange?
  → DatasetItem (resourceAttributes)
  → DatasetFulfillment (performanceAttributes)

None of the above?
  → Propose NEW custom schema (see "New Schema Pattern")
```

---

## Retail / F&B Schemas

### 1. FnBItem (Food & Beverage Item)

**Attaches to**: `Item.resourceAttributes` and `Commitment.commitmentAttributes`
**Context URI**: `https://schema.beckn.io/`
**Type**: `beckn:FnBItem`
**Use when**: Resource is a prepared food or beverage item

```json
"resourceAttributes": {
  "@context": "https://schema.beckn.io/",
  "@type": "beckn:FnBItem",
  "classification": "VEG",
  "cuisine": "Italian",
  "allergenInfo": {
    "contains": ["GLUTEN", "MILK", "EGGS"]
  },
  "preparation": {
    "instructions": "Best served hot",
    "storage": "Do not refrigerate. Consume immediately.",
    "shelfLife": "PT30M"
  }
}
```

**In commitmentAttributes** (also includes line-item fields):
```json
"commitmentAttributes": {
  "@context": "https://schema.beckn.io/",
  "@type": "beckn:FnBItem",
  "lineId": "line-001",
  "offerId": "offer-margherita-regular",
  "quantity": { "unitCode": "EA", "unitQuantity": 2 },
  "price": {
    "currency": "INR",
    "value": 790,
    "components": [
      { "type": "BASE_ITEM", "value": 395, "currency": "INR", "description": "Regular Margherita" }
    ]
  },
  "resourceId": "item-veg-margherita",
  "classification": "VEG",
  "cuisine": "Italian",
  "allergenInfo": { "contains": ["GLUTEN", "MILK", "EGGS"] }
}
```

**Key fields**:
```yaml
classification: VEG | NON_VEG | VEGAN | EGG | JAIN
cuisine: string                  # Italian, Indian, Chinese …
allergenInfo:
  contains: [GLUTEN, DAIRY, NUTS, SOY, EGGS, SHELLFISH, SESAME, SULFITES]
preparation:
  instructions: string
  storage: string
  shelfLife: string              # ISO 8601 duration e.g. "PT30M"
```

---

### 2. FnBOffer (Food & Beverage Offer)

**Attaches to**: `Offer.offerAttributes`
**Context URI**: `https://schema.beckn.io/`
**Type**: `beckn:FnBOffer`
**Use when**: Food offer has customization options (size, toppings, sauces, extras)

```json
"offerAttributes": {
  "@context": "https://schema.beckn.io/",
  "@type": "beckn:FnBOffer",
  "customization": {
    "groups": [
      {
        "code": "SIZE",
        "name": "Choose Size",
        "selection": "SINGLE_REQUIRED",
        "options": [
          { "code": "REGULAR", "name": "Regular (7-inch)", "priceDelta": { "type": "FIXED", "value": 0 } },
          { "code": "MEDIUM",  "name": "Medium (10-inch)", "priceDelta": { "type": "FIXED", "value": 100 } },
          { "code": "LARGE",   "name": "Large (12-inch)",  "priceDelta": { "type": "FIXED", "value": 200 } }
        ]
      },
      {
        "code": "TOPPINGS",
        "name": "Add Toppings",
        "selection": "MULTIPLE_OPTIONAL",
        "minSelections": 0,
        "maxSelections": 3,
        "options": [
          { "code": "ONION",    "name": "Onion",    "priceDelta": { "type": "FIXED", "value": 30 } },
          { "code": "CAPSICUM", "name": "Capsicum", "priceDelta": { "type": "FIXED", "value": 30 } },
          { "code": "MUSHROOM", "name": "Mushroom", "priceDelta": { "type": "FIXED", "value": 35 } },
          { "code": "PANEER",   "name": "Paneer",   "priceDelta": { "type": "FIXED", "value": 60 } }
        ]
      }
    ]
  }
}
```

**CustomizationGroup fields**:
```yaml
code: string                    # SIZE, TOPPINGS, SAUCE, CRUST, EXTRAS …
name: string
selection: SINGLE_REQUIRED | SINGLE_OPTIONAL | MULTIPLE_OPTIONAL
minSelections: integer
maxSelections: integer
options:
  - code: string
    name: string
    priceDelta:
      type: FIXED | PERCENTAGE
      value: number             # positive = surcharge, negative = discount
```

---

### 3. FnBPriceSpecification (Food & Beverage Consideration)

**Attaches to**: `Consideration.considerationAttributes`
**Context URI**: `https://schema.beckn.io/`
**Type**: `beckn:FnBPriceSpecification`
**Use when**: F&B monetary payment with price breakdown

```json
"considerationAttributes": {
  "@context": "https://schema.beckn.io/",
  "@type": "beckn:FnBPriceSpecification",
  "currency": "INR",
  "value": 929,
  "components": [
    { "type": "BASE_ITEM",   "value": 790, "currency": "INR", "description": "2x Regular Margherita" },
    { "type": "BASE_ITEM",   "value": 99,  "currency": "INR", "description": "1x Garlic Breadsticks" },
    { "type": "DELIVERY_FEE","value": 40,  "currency": "INR", "description": "Delivery fee" }
  ]
}
```

**Component types**: `BASE_ITEM`, `DELIVERY_FEE`, `TAX`, `PACKING_FEE`, `DISCOUNT`, `TIP`, `SURGE`, `CONVENIENCE_FEE`, `LOYALTY_DISCOUNT`

---

### 4. HyperlocalDelivery (Fulfillment)

**Attaches to**: `Fulfillment.performanceAttributes`
**Context URI**: `https://schema.beckn.io/`
**Type**: `beckn:HyperlocalDelivery`
**Use when**: Physical delivery of food/retail from store to buyer

```json
"performanceAttributes": {
  "@context": "https://schema.beckn.io/",
  "@type": "beckn:HyperlocalDelivery",
  "pickupLocation": {
    "@context": "https://schema.beckn.io/",
    "@type": "beckn:Location",
    "id": "store-id",
    "geo": { "type": "Point", "coordinates": [77.5946, 12.9716] },
    "address": {
      "streetAddress": "No. 15, Ground Floor, MG Road",
      "addressLocality": "Bangalore",
      "addressRegion": "Karnataka",
      "postalCode": "560001",
      "addressCountry": "IN"
    }
  },
  "deliveryLocation": {
    "@context": "https://schema.beckn.io/",
    "@type": "beckn:Location",
    "geo": { "type": "Point", "coordinates": [77.5946, 12.9716] },
    "address": {
      "streetAddress": "Apt 204, Sunrise Heights",
      "addressLocality": "Bangalore",
      "addressRegion": "Karnataka",
      "postalCode": "560001",
      "addressCountry": "IN"
    }
  },
  "itemsShipped": [
    {
      "@context": ["https://schema.beckn.io/Resource/v2.0", "https://schema.beckn.io/FoodAndBeverageItem/v2.0"],
      "@type": ["beckn:Resource", "beckn:FnBItem"],
      "itemId": "item-veg-margherita",
      "offerId": "offer-margherita-regular",
      "quantity": { "unitCode": "EA", "unitQuantity": 2 },
      "lineId": "line-001"
    }
  ]
}
```

---

### 5. GroceryItem

**Attaches to**: `Item.resourceAttributes`
**Context URI**: `https://schema.beckn.io/GroceryItem/v2.1/context.jsonld`
**Type**: `groc:GroceryItemAttributes`
**Use when**: Fresh produce or packaged grocery item

```yaml
type: FRESH | PACKAGED
brand: string
sku: string
weight: { unitQuantity: number, unitCode: KG | GRAM }
nutritionFacts:
  servingSize: string
  calories: number
  protein: number
  carbohydrates: number
  fat: number
expiryDate: date-time
organic: boolean
```

---

### 6. HomeAndKitchenItem

**Attaches to**: `Item.resourceAttributes`
**Context URI**: `https://schema.beckn.io/HomeAndKitchenItem/v2.1/context.jsonld`
**Type**: `hkr:HomeAndKitchenItemAttributes`
**Use when**: Furniture, appliance, kitchenware, home goods

```yaml
dimensions:
  length: { unitQuantity, unitCode }
  width: { unitQuantity, unitCode }
  height: { unitQuantity, unitCode }
  weight: { unitQuantity, unitCode }
material: string
color: string
assemblyRequired: boolean
warrantyPeriod: string         # ISO 8601 duration
installationAvailable: boolean
```

---

### 7. RetailOffer (base discount/availability)

**Attaches to**: `Offer.offerAttributes`
**Context URI**: `https://schema.beckn.io/RetailOffer/v2.1/context.jsonld`
**Type**: `rco:RetailOfferAttributes`
**Use when**: Standard retail offer with discounts or availability constraints

```yaml
discountType: FLAT | PERCENTAGE | BOGO | BUNDLE
discountValue: number
stockAvailability: number
minOrderQuantity: number
maxOrderQuantity: number
unitOfMeasure: string           # EA, KG, L …
```

---

## Schema selection summary

| Use case signal | Schema | Attaches to |
|---|---|---|
| Prepared food/meal | FnBItem | Item.resourceAttributes + Commitment.commitmentAttributes |
| Food with size/topping options | FnBOffer | Offer.offerAttributes |
| F&B price with delivery fee | FnBPriceSpecification | Consideration.considerationAttributes |
| Physical food/retail delivery | HyperlocalDelivery | Fulfillment.performanceAttributes |
| Grocery (fresh veg, packaged) | GroceryItem | Item.resourceAttributes |
| Furniture/appliances/home goods | HomeAndKitchenItem | Item.resourceAttributes |
| Retail discount/availability | RetailOffer | Offer.offerAttributes |

For DEG (EV charging, P2P trading, demand flex) and DDM (data exchange) schemas,
see [domain-schemas-energy-data.md](domain-schemas-energy-data.md).

---

## New schema pattern

**Before proposing a new schema, always:**

1. Check `https://schema.beckn.io` for existing schemas matching the domain
2. If the user has not specified a domain or schema set, ask:
   > "Which domain or schema catalogue should I check? (e.g. retail, energy/DEG, data/DDM, mobility, healthcare, or say 'none')"
3. Only propose a new schema after confirming no existing schema at schema.beckn.io covers the required fields

When a gap is confirmed, propose using this pattern:

```yaml
# Proposed: <DomainName><EntityType>Attributes

openapi: 3.1.1
info:
  title: <Domain> — <EntityType> Attributes (v1.0)

components:
  schemas:
    <DomainName><EntityType>Attributes:
      type: object
      additionalProperties: false
      x-beckn-container: <entityType>Attributes   # e.g. resourceAttributes, performanceAttributes
      x-jsonld:
        "@context": "https://schema.beckn.io/<DomainName><EntityType>/v1.0/context.jsonld"
        "@type": "<prefix>:<DomainName><EntityType>Attributes"
      properties:
        <property>:
          type: string | number | boolean | object | array
          description: <what this captures>
```

**Naming**: class names PascalCase, URI pattern `https://schema.beckn.io/<Name>/v<version>/context.jsonld`

**In the payload**, the new schema only appears inside its `*Attributes` bag:
```json
"resourceAttributes": {
  "@context": "https://schema.beckn.io/<DomainName><EntityType>/v1.0/context.jsonld",
  "@type": "<prefix>:<DomainName><EntityType>Attributes",
  "<property>": "<value>"
}
```
