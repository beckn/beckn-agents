# How to use the Beckn Payload Builder skill

---

## Input format

The skill accepts a **use case scenario** — a plain-English description of a value exchange.
Write it like a user story:

```
"A retail buyer is looking for a Margherita pizza. They want to customise it 
with a large size and extra cheese. The restaurant delivers within 45 minutes. 
The buyer pays with UPI. They want to track their order."
```

You can also provide structured hints:

```
Domain: food-and-beverage
Buyer: consumer app on ONDC network
Seller: Sarpino's Pizzeria, Bandra, Mumbai
Item: Margherita pizza (customisable)
Fulfillment: home delivery
Payment: UPI
Lifecycle: full order + tracking
```

---

## Output structure

The skill always outputs:

### 1. Beckn mapping summary (2–4 sentences)
Maps the scenario to Beckn concepts: who is the BAP, who is the BPP, what is the Resource,
what is the Offer, what is the Performance, what is the Consideration.

### 2. Transaction flow
A numbered list of API steps:
```
1. discover (BAP → CDS/BPP) — broadcast pizza search intent
2. on_discover (BPP → BAP) — return Sarpino's catalog with pizza resources + offers
3. select (BAP → BPP) — choose Margherita + SIZE=LARGE + EXTRA_CHEESE
4. on_select (BPP → BAP) — return contract with INR 450 + INR 50 delivery
5. init (BAP → BPP) — add buyer address + UPI payment preference
6. on_init (BPP → BAP) — confirm payment terms + 45-min SLA
7. confirm (BAP → BPP) — finalise order
8. on_confirm (BPP → BAP) — return CONFIRMED contract with contract ID
9. track (BAP → BPP) — request live tracking
10. on_track (BPP → BAP) — return WebSocket tracking URL
```

### 3. Custom schema table
| Schema | Attached to | Why |
|---|---|---|
| FoodAndBeverageResource | Resource.resourceAttributes | Captures VEG classification, allergens, cuisine |
| FoodAndBeverageOffer | Offer.offerAttributes | Captures SIZE + TOPPINGS customization groups |
| RetailCommitment | Commitment.commitmentAttributes | Captures selected size (LARGE) + special instructions |
| RetailPerformance | Performance.performanceAttributes | Captures DELIVERY mode, address, 45-min SLA |
| RetailContract | Contract.contractAttributes | Captures contactless delivery preference |
| RetailConsideration | Consideration.considerationAttributes | Captures UPI + price breakup (pizza + delivery + GST) |

### 4. Full payloads
One labelled JSON block per API action.

### 5. Schema gap analysis
If the scenario contains domain data not capturable by existing schemas:
- Description of the gap (e.g. "the scenario mentions a 'chef recommendation' flag not in FoodAndBeverageResource")
- Proposed new schema with key fields
- Which `*Attributes` container it would attach to

---

## Example use case: Pizza order (full flow)

**Input**:
> A retail buyer is looking for pizza. They find a Margherita pizza at Sarpino's Pizzeria.
> They want a large size with extra cheese and no onions. The restaurant delivers to their
> Mumbai address within 45 minutes for INR 449 + INR 49 delivery. The buyer pays via UPI.
> After placing the order, they want to track the delivery in real time.

**Beckn mapping**:
- BAP: consumer app (e.g. buyer.ondc.org)
- BPP: Sarpino's restaurant system (restaurant.sarpinos.ondc.org)
- Domain: food-and-beverage
- Resource: Margherita Pizza (FoodAndBeverageResource)
- Offer: customisable with SIZE + TOPPINGS groups (FoodAndBeverageOffer)
- Performance: DELIVERY mode, 45-min SLA (RetailPerformance)
- Consideration: UPI, INR 498 total (RetailConsideration)
- Flow: discover → on_discover → select → on_select → init → on_init → confirm → on_confirm → track → on_track

**Custom schemas needed**:
All captured by existing retail schemas. No new schema required.

---

## Example use case: Domain requiring a new schema

**Input**:
> A patient searches for a dental clinic near them. They want to book a teeth-cleaning
> appointment for next Tuesday at 10am. The appointment takes 45 minutes. They pay INR 800
> in advance via credit card. After the appointment, they want to rate the dentist.

**Beckn mapping**:
- Domain: healthcare (dental)
- Resource: "Teeth Cleaning" service (needs HealthcareResource schema — NOT in existing catalogue)
- Offer: appointment slot (needs HealthcareOffer with time-slot groups — NOT in existing catalogue)
- Performance: SERVICE mode (RetailPerformance covers this)
- Consideration: CREDIT payment (RetailConsideration covers this)

**Schema gap**:
- `HealthcareResource` needed: serviceType (DENTAL_CLEANING, CONSULTATION, ...), duration, providerId, licenseNumber, specialization
- `HealthcareOffer` needed: slot-based availability (date, startTime, endTime, capacity, bufferTime)

Proposed new schema `HealthcareResource`:
```yaml
HealthcareResourceAttributes:
  x-beckn-container: resourceAttributes
  x-jsonld:
    "@context": "https://schema.beckn.io/HealthcareResource/v1.0/context.jsonld"
    "@type": "hcr:HealthcareResourceAttributes"
  properties:
    serviceType: string            # DENTAL_CLEANING, GP_CONSULTATION, PHYSIOTHERAPY …
    serviceDurationMinutes: integer
    specialization: string
    licenseNumber: string
    licenseAuthority: string
    patientPreparation: string     # "No food 2 hours before" etc.
```

---

## Tips for writing a good use case input

| Include | Why |
|---|---|
| What the buyer is looking for | Drives discover intent + textSearch |
| Any customisation options | Drives FoodAndBeverageOffer/customization groups |
| How it will be delivered | Drives Performance schema (DELIVERY vs PICKUP vs SERVICE) |
| Payment method | Drives Consideration schema paymentMethods |
| Any special buyer instructions | Drives RetailContract.buyerInstructions |
| Post-order steps needed | Drives whether to generate tracking/cancel/rate payloads |
| Domain/industry | Critical for picking the right resource/offer schemas |

| Optional but useful | Why |
|---|---|
| Provider name + location | Makes payloads more realistic |
| Approximate price | Makes price breakup realistic |
| City/geo location | Enables spatial filter in discover |
| Buyer name + address | Populates init/on_init participant and delivery details |

---

## Variations

**"Just show me the discovery payloads"** → Only generate `discover` + `on_discover`

**"I only need the order placement flow"** → Generate `select` through `on_confirm` only

**"Show me what happens when the buyer cancels"** → Add `cancel (try=true)` → `on_cancel (try=true)` → `cancel (try=false)` → `on_cancel (try=false)`

**"The restaurant also offers dine-in"** → Add `DINE_IN` mapped to `SERVICE` in `supportedPerformanceModes`

**"Multi-item order"** → Add multiple commitments in `commitments[]`, each with its own `commitmentAttributes`
