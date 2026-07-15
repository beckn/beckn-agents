# Mobility Domain Reference

Unlike the retail/F&B and DEG/DDM domains, this file does **not** embed mobility schema
fields or example payloads. The mobility domain vocabulary is large, actively evolving,
and owned by a separate repo — copying field names here would go stale. Instead, this
file tells you **where to look** and **how to map** whatever you find onto the v2.0.0
LTS core structure.

## Authoritative source — fetch live, don't rely on a cached copy

**Repo**: https://github.com/beckn/mobility

| What you need | Where |
|---|---|
| Concept vocabulary / ontology (Vehicle, Fare, Booking, Stop, Route, Leg, Journey, Operator, Passenger, etc.) | `docs/4_Beckn_Mobility_Concepts.md`, `docs/Mobility_Ontology.md` |
| Domain background & scope | `docs/1_Overview.md`, `docs/2_Mobility_Concepts.md`, `docs/3_Mobility_Standards.md`, `docs/4_Beckn_Mobility_Concepts.md` |
| Action-by-action flow narratives | `docs/API-Flows.md` |
| Worked use cases with example request/response JSON | `docs/example_implementations/<use-case>/README.md` and `.../example-jsons/` |

Known use-case folders under `docs/example_implementations/` (check the repo for the current list — this list itself can grow):
`ride_hailing`, `cab_rental`, `advance_cab_reservation`, `intercity_bus`, `metro_ticket_booking`, `public_transit_bus`.
The `ride_hailing` example further breaks out by mode: `bike_rental`, `cab_hailing`, `car_rental`, `driver_rental`, `metro_fare`, `multimodal_itinerary`.

Fetch the relevant doc or example (`gh api repos/beckn/mobility/contents/<path>` or WebFetch on the raw file) at the time you need it, rather than assuming a schema name or field list from memory.

> **CRITICAL**: The example JSONs in that repo are pre-v2.0.0 style (`bap_id`, Ack/Nack response
> envelopes, `message.order`). They are useful **only** to learn what concepts/fields a mobility
> flow needs (fare breakup, vehicle info, stops, driver details, cancellation reasons, etc.) — never
> copy their structure verbatim. Always re-express the concept inside the v2.0.0 LTS core shape
> (camelCase context, `resourceAttributes`/`offerAttributes`/`commitmentAttributes`/
> `performanceAttributes`/`considerationAttributes`, `Contract.participants[]` direct props).

## How to map a mobility concept onto the v2.0.0 LTS core

Same `*Attributes` extension pattern used everywhere else in this skill — the mapping below is by
concept **category**, so it stays valid even as the mobility repo's specific concept list evolves:

| Concept category (examples from the ontology) | Attaches to |
|---|---|
| The thing being offered — Vehicle, VehicleType, Route, Line, Stop, Trip Specification, Fare Product | `Item.resourceAttributes` |
| Pricing/availability of that thing — Fare, Tariff, System Pricing Plan, Sales Offer Package | `Offer.offerAttributes` |
| What the buyer actually selected/booked — Booking line details, seat/place request, selected leg(s) | `Commitment.commitmentAttributes` |
| Execution/tracking of the trip — Vehicle Position, Trip Update, ETA, driver+vehicle assignment, occupancy | `Fulfillment.performanceAttributes` |
| Fare breakdown, payment, refund/cancellation charges | `Consideration.considerationAttributes` |
| People/orgs involved — Passenger, Operator, Carrier, Driver, Authority | `Contract.participants[]` (direct props, no wrapper) |

## Before authoring a new mobility schema

Follow the same check-before-create rule as every other domain in this skill:
1. Search `https://schema.nfh.global` for an existing mobility schema first.
2. If nothing fits, read the relevant concept definition live from `docs/4_Beckn_Mobility_Concepts.md` / `docs/Mobility_Ontology.md` in the mobility repo to get the correct name and semantics before proposing a new `*Attributes` schema.
3. See the `beckn-schema-builder` skill for the full schema design/authoring process.
