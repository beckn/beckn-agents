# Beckn 2.0 Transaction Flows by Use Case Type

---

## Flow 1: Discovery only

**Scenario signals**: "find me", "search for", "browse", "discover", "show me available"

Steps: `discover` → `on_discover`

- `discover`: CN sends intent with textSearch and/or spatial filters
- `on_discover`: PN/DS returns matching catalogs with resources and offers

---

## Flow 2: Simple order (retail, food)

**Scenario signals**: full purchase journey — buyer finds item, places order, receives it

Steps:
1. `discover` — CN broadcasts intent (textSearch, geo filter)
2. `on_discover` — PN returns catalog with resources + offers
3. `select` — CN creates DRAFT contract with chosen resource+offer and quantity
4. `on_select` — PN returns contract with priceSpecification calculated
5. `init` — CN adds buyer details (participant), delivery address (performance), payment method (consideration)
6. `on_init` — PN confirms payment terms and delivery window
7. `confirm` — CN finalises contract
8. `on_confirm` — PN returns CONFIRMED contract with contract ID

---

## Flow 3: Order with tracking

Add after `on_confirm`:
9. `status` — CN polls current state
10. `on_status` — PN returns current contract status (ACTIVE, performance status)
11. `track` — CN requests real-time tracking handle
12. `on_track` — PN returns tracking URL or WebSocket endpoint

---

## Flow 4: Order with cancellation

After `on_confirm`, buyer wants to cancel:
- **Preview cancellation terms first** (recommended):
  - `cancel` with `context.try: true` — CN asks for policy
  - `on_cancel` with `context.try: true` — PN returns fees, refund timeline
- **Commit cancellation**:
  - `cancel` with `context.try: false` — CN confirms
  - `on_cancel` with `context.try: false` — PN returns CANCELLED contract

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
- `rate` — CN submits rating for provider, item, delivery agent
- `on_rate` — PN acknowledges
- `support` — CN requests support channels or opens ticket
- `on_support` — PN returns support details

---

## Flow 7: Customized food/beverage order

**Scenario signals**: pizza, restaurant, customizable meal, toppings, size selection

Steps 1–8 (same as Flow 2) PLUS:

- In `on_discover`: `offerAttributes` contains `customization.groups[]` (SIZE, TOPPINGS, SAUCE, etc.)
- In `select`: `commitmentAttributes` includes selected customization options via `specialInstructions`
- In `confirm`/`on_confirm`: full commitment details with quantity (EA), price delta captured

---

## Flow 8: Catalog publishing (PN side)

For PNs publishing to a Discovery Service (DS):

1. `catalog/publish` — PN pushes catalog(s) to DS
2. `catalog/on_publish` — DS returns per-catalog processing results (ACCEPTED/REJECTED/PARTIAL)

---

## Flow 9: EV Charging (reservation + session)

**Scenario signals**: EV charger, charging station, connector, kWh, session, EVSE

Steps:
1. `discover` — CN broadcasts intent with geo filter near user's location
2. `on_discover` — PN returns catalog with `EvChargingService` items + `EvChargingOffer` offers
3. `select` — CN picks connector + tariff; creates DRAFT contract
4. `on_select` — PN returns contract with price estimate (kWh rate + idle fee)
5. `init` — CN adds EV driver details (EnergyCustomer participant), desired session window
6. `on_init` — PN confirms reservation slot and payment method
7. `confirm` — CN finalises contract; reservation ID issued
8. `on_confirm` — PN returns ACTIVE contract with `EvChargingSession` in performanceAttributes

**During charging** (repeat as needed):
9. `status` — CN polls session state
10. `on_status` — PN returns updated `EvChargingSession` (meteredEnergyKwh, power, SoC)
11. `update` (try=true) — CN requests stop
12. `on_update` — PN returns final session summary
13. `update` — CN commits stop
14. `on_update` — PN finalises session with total cost

**Schema map**:
- `resourceAttributes`: EvChargingService
- `offerAttributes`: EvChargingOffer
- `performanceAttributes`: EvChargingSession
- Participant types: EnergyCustomer (buyer), ChargingOperator (seller)

---

## Flow 10: P2P Day-Ahead Energy Trade

**Scenario signals**: P2P energy, prosumer, peer trading, solar export, day-ahead market

Steps:
1. `discover` — CN (buyer DISCOM / aggregator) searches for energy sellers
2. `on_discover` — PN (seller/prosumer) returns catalog with `EnergyResource` items + `EnergyTradeOffer` offers (BecknTimeSeries with 24 hourly slots)
3. `select` — CN picks offer slots and submits `bidTimeseries` (REQUESTED_QTY per slot)
4. `on_select` — PN returns matched contract with consideration (value = sum of selected slots × price)
5. `init` — CN adds EnergyCustomer participant (buyer's meterId), settlement preference
6. `on_init` — PN confirms matched energy schedule and total INR value
7. `confirm` — CN finalises; DEGContract (Rego policy) governs execution
8. `on_confirm` — PN returns ACTIVE contract with matched energy schedule

**During delivery window** (repeat):
9. `status` — CN checks energy delivery state
10. `on_status` — PN returns telemetry (actual vs committed kWh per interval)

**Schema map**:
- `resourceAttributes`: EnergyResource (sourceType, meterId)
- `offerAttributes`: EnergyTradeOffer (validityWindow, offerTimeseries + bidTimeseries)
- Participant direct props: EnergyCustomer (meterId, utilityId, sanctionedLoad)
- Contract level: DEGContract terms with Rego policyUrl

---

## Flow 11: Demand Flex Event

**Scenario signals**: demand response, DR event, curtailment, load shifting, utility flex

Steps:
1. `discover` — Aggregator/CN searches for demand flex opportunities from utilities
2. `on_discover` — Utility/PN returns catalog with `DemandFlexNeed` items (direction, eventWindow, maxCapacityKw)
3. `select` — CN commits capacity (commitmentAttributes with capacityKw, participatingDERs)
4. `on_select` — PN returns contract with incentive amount (incentivePerKwh × committed kWh)
5. `init` — CN adds aggregator participant, participating DER IDs
6. `on_init` — PN confirms event commitment and payment terms
7. `confirm` — CN finalises participation contract
8. `on_confirm` — PN returns ACTIVE contract for the flex event

**During event**:
9. `status` — CN reports actual curtailment achieved
10. `on_status` — PN acknowledges and records compliance

**Schema map**:
- `resourceAttributes`: DemandFlexNeed (direction, eventWindow, maxCapacityKw, location)
- `offerAttributes`: DemandFlexBuyOffer (incentivePerKwh, baselineMethodology, DEGContract)
- `performanceAttributes`: custom DemandFlexPerformance (or use base Fulfillment with status)

---

## Flow 12: Data Exchange (DDM)

**Scenario signals**: dataset, data purchase, API access, historical data, analytics data

Steps:
1. `discover` — CN (data buyer) searches for datasets by keyword, topic, temporal coverage
2. `on_discover` — PN (data provider) returns catalog with `DatasetItem` items + pricing offers
3. `select` — CN picks dataset and license type; creates DRAFT contract
4. `on_select` — PN returns contract with price (flat, per-record, or subscription)
5. `init` — CN adds buyer details (organisation, billing, intended use)
6. `on_init` — PN confirms license terms, delivery format, access window
7. `confirm` — CN finalises; attaches payment proof in entitlements
8. `on_confirm` — PN returns ACTIVE contract with `DatasetFulfillment` (accessUrl, maxDownloads)

**Post-delivery** (optional):
9. `status` — CN checks download availability or API quota
10. `on_status` — PN returns usage (downloadsUsed, remaining quota)
11. `rate` — CN rates dataset quality
12. `on_rate` — PN acknowledges rating

**Schema map**:
- `resourceAttributes`: DatasetItem (schema:identifier, temporalCoverage, variableMeasured, qualityFlags)
- `offerAttributes`: RetailOffer or domain-specific pricing offer
- `performanceAttributes`: DatasetFulfillment (accessMethod, accessUrl, format, fileSizeBytes)
- Participant: data buyer org + data provider (direct props)

---

## Flow 13: Mobility (ride-hailing / transit / rental)

**Scenario signals**: cab, ride, taxi, bike/car rental, bus, metro, transit ticket, multimodal trip

Same lifecycle shape as Flow 2/3, no mobility-specific step sequence:

1. `discover` — CN broadcasts intent (origin/destination geo, mode, time window)
2. `on_discover` — PN returns catalog of vehicle/route/fare options
3. `select` — CN picks an option; creates DRAFT contract
4. `on_select` — PN returns contract with fare estimate
5. `init` — CN adds passenger details, pickup/drop specifics, payment method
6. `on_init` — PN confirms fare and any reservation terms
7. `confirm` — CN finalises contract
8. `on_confirm` — PN returns ACTIVE contract (driver/vehicle assignment where applicable)
9. `track` / `on_track` — live trip position during the ride
10. `status` / `on_status` — trip state polling
11. `cancel` / `on_cancel` — per Flow 4
12. `rate` / `on_rate` — post-trip rating

**Schema map**: not fixed here — see [domain-schemas-mobility.md](./domain-schemas-mobility.md) for the
concept-category → `*Attributes` mapping, and fetch the actual concept/field names live from the
`beckn/mobility` repo since that vocabulary evolves independently of this skill.

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

| Action | receiverId/bppUri required? | transactionId | messageId |
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
