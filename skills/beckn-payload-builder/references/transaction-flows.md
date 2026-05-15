# Beckn 2.0 Transaction Flows by Use Case Type

---

## Flow 1: Discovery only

**Scenario signals**: "find me", "search for", "browse", "discover", "show me available"

Steps: `discover` → `on_discover`

- `discover`: BAP sends intent with textSearch and/or spatial filters
- `on_discover`: BPP/CDS returns matching catalogs with resources and offers

---

## Flow 2: Simple order (retail, food)

**Scenario signals**: full purchase journey — buyer finds item, places order, receives it

Steps:
1. `discover` — BAP broadcasts intent (textSearch, geo filter)
2. `on_discover` — BPP returns catalog with resources + offers
3. `select` — BAP creates DRAFT contract with chosen resource+offer and quantity
4. `on_select` — BPP returns contract with priceSpecification calculated
5. `init` — BAP adds buyer details (participant), delivery address (performance), payment method (consideration)
6. `on_init` — BPP confirms payment terms and delivery window
7. `confirm` — BAP finalises contract
8. `on_confirm` — BPP returns CONFIRMED contract with contract ID

---

## Flow 3: Order with tracking

Add after `on_confirm`:
9. `status` — BAP polls current state
10. `on_status` — BPP returns current contract status (ACTIVE, performance status)
11. `track` — BAP requests real-time tracking handle
12. `on_track` — BPP returns tracking URL or WebSocket endpoint

---

## Flow 4: Order with cancellation

After `on_confirm`, buyer wants to cancel:
- **Preview cancellation terms first** (recommended):
  - `cancel` with `context.try: true` — BAP asks for policy
  - `on_cancel` with `context.try: true` — BPP returns fees, refund timeline
- **Commit cancellation**:
  - `cancel` with `context.try: false` — BAP confirms
  - `on_cancel` with `context.try: false` — BPP returns CANCELLED contract

---

## Flow 5: Order modification (update)

Buyer wants to change item quantity, address, or timing:
- **Preview updated terms**:
  - `update` with `context.try: true`
  - `on_update` returns revised quote (state NOT changed)
- **Commit update**:
  - `update` with `context.try: false`
  - `on_update` returns updated contract

---

## Flow 6: Post-fulfillment

After contract is COMPLETE:
- `rate` — BAP submits rating for provider, item, delivery agent
- `on_rate` — BPP acknowledges
- `support` — BAP requests support channels or opens ticket
- `on_support` — BPP returns support details

---

## Flow 7: Customized food/beverage order

**Scenario signals**: pizza, restaurant, customizable meal, toppings, size selection

Steps 1–8 (same as Flow 2) PLUS:

- In `on_discover`: `offerAttributes` contains `customization.groups[]` (SIZE, TOPPINGS, SAUCE, etc.)
- In `select`: `commitmentAttributes` includes selected customization options via `specialInstructions`
- In `confirm`/`on_confirm`: full commitment details with quantity (EA), price delta captured

---

## Flow 8: Catalog publishing (BPP side)

For BPPs publishing to a Catalog Discovery Service (CDS):

1. `catalog/publish` — BPP pushes catalog(s) to CDS
2. `catalog/on_publish` — CDS returns per-catalog processing results (ACCEPTED/REJECTED/PARTIAL)

---

## Flow 9: EV Charging (reservation + session)

**Scenario signals**: EV charger, charging station, connector, kWh, session, EVSE

Steps:
1. `discover` — BAP broadcasts intent with geo filter near user's location
2. `on_discover` — BPP returns catalog with `EvChargingService` items + `EvChargingOffer` offers
3. `select` — BAP picks connector + tariff; creates DRAFT contract
4. `on_select` — BPP returns contract with price estimate (kWh rate + idle fee)
5. `init` — BAP adds EV driver details (EnergyCustomer participant), desired session window
6. `on_init` — BPP confirms reservation slot and payment method
7. `confirm` — BAP finalises contract; reservation ID issued
8. `on_confirm` — BPP returns ACTIVE contract with `EvChargingSession` in performanceAttributes

**During charging** (repeat as needed):
9. `status` — BAP polls session state
10. `on_status` — BPP returns updated `EvChargingSession` (meteredEnergyKwh, power, SoC)
11. `update` (try=true) — BAP requests stop
12. `on_update` — BPP returns final session summary
13. `update` — BAP commits stop
14. `on_update` — BPP finalises session with total cost

**Schema map**:
- `resourceAttributes`: EvChargingService
- `offerAttributes`: EvChargingOffer
- `performanceAttributes`: EvChargingSession
- Participant types: EnergyCustomer (buyer), ChargingOperator (seller)

---

## Flow 10: P2P Day-Ahead Energy Trade

**Scenario signals**: P2P energy, prosumer, peer trading, solar export, day-ahead market

Steps:
1. `discover` — BAP (buyer DISCOM / aggregator) searches for energy sellers
2. `on_discover` — BPP (seller/prosumer) returns catalog with `EnergyResource` items + `EnergyTradeOffer` offers (BecknTimeSeries with 24 hourly slots)
3. `select` — BAP picks offer slots and submits `bidTimeseries` (REQUESTED_QTY per slot)
4. `on_select` — BPP returns matched contract with consideration (value = sum of selected slots × price)
5. `init` — BAP adds EnergyCustomer participant (buyer's meterId), settlement preference
6. `on_init` — BPP confirms matched energy schedule and total INR value
7. `confirm` — BAP finalises; DEGContract (Rego policy) governs execution
8. `on_confirm` — BPP returns ACTIVE contract with matched energy schedule

**During delivery window** (repeat):
9. `status` — BAP checks energy delivery state
10. `on_status` — BPP returns telemetry (actual vs committed kWh per interval)

**Schema map**:
- `resourceAttributes`: EnergyResource (sourceType, meterId)
- `offerAttributes`: EnergyTradeOffer (validityWindow, offerTimeseries + bidTimeseries)
- Participant direct props: EnergyCustomer (meterId, utilityId, sanctionedLoad)
- Contract level: DEGContract terms with Rego policyUrl

---

## Flow 11: Demand Flex Event

**Scenario signals**: demand response, DR event, curtailment, load shifting, utility flex

Steps:
1. `discover` — Aggregator/BAP searches for demand flex opportunities from utilities
2. `on_discover` — Utility/BPP returns catalog with `DemandFlexNeed` items (direction, eventWindow, maxCapacityKw)
3. `select` — BAP commits capacity (commitmentAttributes with capacityKw, participatingDERs)
4. `on_select` — BPP returns contract with incentive amount (incentivePerKwh × committed kWh)
5. `init` — BAP adds aggregator participant, participating DER IDs
6. `on_init` — BPP confirms event commitment and payment terms
7. `confirm` — BAP finalises participation contract
8. `on_confirm` — BPP returns ACTIVE contract for the flex event

**During event**:
9. `status` — BAP reports actual curtailment achieved
10. `on_status` — BPP acknowledges and records compliance

**Schema map**:
- `resourceAttributes`: DemandFlexNeed (direction, eventWindow, maxCapacityKw, location)
- `offerAttributes`: DemandFlexBuyOffer (incentivePerKwh, baselineMethodology, DEGContract)
- `performanceAttributes`: custom DemandFlexPerformance (or use base Fulfillment with status)

---

## Flow 12: Data Exchange (DDM)

**Scenario signals**: dataset, data purchase, API access, historical data, analytics data

Steps:
1. `discover` — BAP (data buyer) searches for datasets by keyword, topic, temporal coverage
2. `on_discover` — BPP (data provider) returns catalog with `DatasetItem` items + pricing offers
3. `select` — BAP picks dataset and license type; creates DRAFT contract
4. `on_select` — BPP returns contract with price (flat, per-record, or subscription)
5. `init` — BAP adds buyer details (organisation, billing, intended use)
6. `on_init` — BPP confirms license terms, delivery format, access window
7. `confirm` — BAP finalises; attaches payment proof in entitlements
8. `on_confirm` — BPP returns ACTIVE contract with `DatasetFulfillment` (accessUrl, maxDownloads)

**Post-delivery** (optional):
9. `status` — BAP checks download availability or API quota
10. `on_status` — BPP returns usage (downloadsUsed, remaining quota)
11. `rate` — BAP rates dataset quality
12. `on_rate` — BPP acknowledges rating

**Schema map**:
- `resourceAttributes`: DatasetItem (schema:identifier, temporalCoverage, variableMeasured, qualityFlags)
- `offerAttributes`: RetailOffer or domain-specific pricing offer
- `performanceAttributes`: DatasetFulfillment (accessMethod, accessUrl, format, fileSizeBytes)
- Participant: data buyer org + data provider (direct props)

---

## State machine — Contract.status.descriptor.code

```
DRAFT → (select, on_select, init, on_init, confirm)
       ↓
ACTIVE → (on_confirm, status during fulfillment)
       ↓
COMPLETE → (after delivery/performance confirmed)
       ↓ (or at any point)
CANCELLED
```

## State machine — Commitment.status.descriptor.code

```
DRAFT → ACTIVE → CLOSED
```

## State machine — Performance.status.descriptor.code

```
PENDING → ACTIVE → COMPLETED | FAILED
```

---

## Context rules by action

| Action | bppId/bppUri required? | transactionId | messageId |
|---|---|---|---|
| `discover` | No (broadcast) | New UUID | New UUID |
| `on_discover` | Yes | Same as discover | New UUID |
| `select` | Yes (from on_discover) | Same | New UUID |
| `on_select` | Yes | Same | Same as select (mirrors request) |
| `init` | Yes | Same | New UUID |
| `on_init` | Yes | Same | Same as init |
| `confirm` | Yes | Same | New UUID |
| `on_confirm` | Yes | Same | Same as confirm |
| `status` | Yes | Same | New UUID |
| `on_status` | Yes | Same | Same as status (or new if unsolicited) |

---

## Timing conventions

- `ttl`: `"PT30S"` for synchronous ACK window; `"PT30M"` for long-running async
- `timestamp`: ISO 8601 UTC with Z suffix
- `transactionId`: established at discover, reused through confirm

---

## Domain → networkId conventions (examples)

| Domain | networkId example |
|---|---|
| Food & Beverage | `beckn.network/food-and-beverage` |
| Retail | `beckn.network/retail` |
| Grocery | `beckn.network/grocery` |
| Mobility | `beckn.network/mobility` |
| Healthcare | `beckn.network/healthcare` |
| Logistics | `beckn.network/logistics` |
| Energy | `beckn.network/energy` |

Always use the actual network's registered ID. These are illustrative examples.
