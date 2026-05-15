# DEG and DDM Domain Schema Reference

Schemas for the Digital Energy Grid (DEG) sub-domains and the Decentralized Data Marketplace (DDM).

> **CRITICAL**: DEG `examples/ev-charging/v2/` uses an older EOS format (`bap_id`, `message.order`, `beckn:Order`).
> Those example payloads are INVALID for v2.0.0 LTS draft.
> Only use the DEG/DDM **specification/schema/** YAML files for domain field definitions.
> Always embed domain attributes inside the v2.0.0 draft core structure.

---

## DEG sub-domains

| Sub-domain | Flow type | Key schemas |
|---|---|---|
| EV charging | Session-based charging | EvChargingService, EvChargingOffer, EvChargingSession |
| P2P energy trade | Day-ahead slot trading | EnergyResource, EnergyTradeOffer |
| Demand flex | Utility DR event | DemandFlexNeed, DemandFlexBuyOffer |

---

## EV Charging

### EvChargingService
**Attaches to**: `Item.resourceAttributes`
**@type**: `beckn:EvChargingService`
**Use when**: Item is an EV charging connector/station

```json
"resourceAttributes": {
  "@context": "https://schema.beckn.io/EvChargingService/v2.0/context.jsonld",
  "@type": "beckn:EvChargingService",
  "evseId": "IN*ECO*01*CCS2*A",
  "connectorType": "CCS2",
  "maxPowerKW": 60,
  "minPowerKW": 5,
  "reservationSupported": true,
  "chargingStation": {
    "id": "IN-ECO-MDY-STATION-01",
    "serviceLocation": {
      "geo": { "type": "Point", "coordinates": [<lng>, <lat>] },
      "address": {
        "streetAddress": "<address>",
        "addressLocality": "<city>",
        "addressRegion": "<state>",
        "postalCode": "<pin>",
        "addressCountry": "IN"
      }
    }
  },
  "amenityFeature": ["WIFI", "RESTROOM", "PARKING"],
  "vehicleType": ["CAR", "2_WHEELER", "3_WHEELER"],
  "networkOperator": { "id": "<operator-id>", "name": "<Operator Name>" }
}
```

**Key fields**:
```yaml
evseId: string                 # OCPI/Hubject style e.g. IN*ECO*01*CCS2*A
connectorType: CCS2 | Type2 | CHAdeMO | GB_T
maxPowerKW: number             # 1–500 kW
minPowerKW: number
reservationSupported: boolean
chargingStation:
  id: string
  serviceLocation: Location
amenityFeature: [WIFI, RESTROOM, PARKING, CAFE, ...]
vehicleType: [CAR, 2_WHEELER, 3_WHEELER, BUS]
networkOperator: { id, name }
```

---

### EvChargingOffer
**Attaches to**: `Offer.offerAttributes`
**@type**: `beckn:EvChargingOffer`
**Use when**: Pricing tariff for an EV charging session

```json
"offerAttributes": {
  "@context": "https://schema.beckn.io/EvChargingOffer/v2.0/context.jsonld",
  "@type": "beckn:EvChargingOffer",
  "tariffModel": "PER_KWH",
  "pricePerKwh": 12.50,
  "idleFeePolicy": {
    "graceMinutes": 15,
    "feePerMinute": 1.00,
    "currency": "INR"
  },
  "buyerFinderFee": {
    "feeType": "PERCENTAGE",
    "feeValue": 2.0
  }
}
```

**Key fields**:
```yaml
tariffModel: PER_KWH | PER_MINUTE | FLAT | PER_SESSION
pricePerKwh: number
pricePerMinute: number
flatFee: number
idleFeePolicy:
  graceMinutes: integer
  feePerMinute: number
  currency: string
buyerFinderFee:
  feeType: PERCENTAGE | AMOUNT
  feeValue: number
```

---

### EvChargingSession
**Attaches to**: `Fulfillment.performanceAttributes`
**@type**: `beckn:EvChargingSession`
**Use when**: Active or completed EV charging session tracking

```json
"performanceAttributes": {
  "@context": "https://schema.beckn.io/EvChargingSession/v2.0/context.jsonld",
  "@type": "beckn:EvChargingSession",
  "sessionStatus": "ACTIVE",
  "connectorStatus": "PREPARING",
  "startTime": "2026-04-10T09:00:00Z",
  "endTime": null,
  "meteredEnergyKwh": 12.4,
  "sessionDurationMinutes": 45,
  "totalCost": {
    "currency": "INR",
    "value": 155.00
  },
  "chargingTelemetry": [
    {
      "timestamp": "2026-04-10T09:00:00Z",
      "powerKw": 48.5,
      "energyKwh": 0.0,
      "stateOfCharge": 22
    }
  ],
  "trackingUrl": "https://<bpp>/ev/session/<session-id>/track"
}
```

**Key fields**:
```yaml
sessionStatus: PENDING | ACTIVE | STOP | COMPLETED | INTERRUPTED
connectorStatus: AVAILABLE | PREPARING | UNAVAILABLE
startTime: date-time
endTime: date-time
meteredEnergyKwh: number
sessionDurationMinutes: integer
totalCost: { currency, value }
chargingTelemetry:
  - timestamp: date-time
    powerKw: number
    energyKwh: number           # cumulative
    stateOfCharge: integer      # battery %
trackingUrl: uri
```

---

## P2P Energy Trading

### EnergyResource
**Attaches to**: `Item.resourceAttributes`
**@type**: `beckn:EnergyResource`
**Use when**: Item is an energy resource (solar, battery, grid)

```json
"resourceAttributes": {
  "@context": "https://schema.beckn.io/EnergyResource/v2.0/context.jsonld",
  "@type": "beckn:EnergyResource",
  "sourceType": "SOLAR",
  "meterId": "der://meter/100200300"
}
```

**Key fields**:
```yaml
sourceType: SOLAR | BATTERY | GRID | HYBRID | RENEWABLE
meterId: string                  # DER address format der://meter/{id}
```

---

### EnergyTradeOffer
**Attaches to**: `Offer.offerAttributes`
**@type**: `beckn:EnergyTradeOffer`
**Use when**: Day-ahead P2P energy trade with slot-based pricing

Uses `BecknTimeSeries` for compact representation of 24-slot schedules.

```json
"offerAttributes": {
  "@context": "https://schema.beckn.io/EnergyTradeOffer/v2.0/context.jsonld",
  "@type": "beckn:EnergyTradeOffer",
  "validityWindow": {
    "startDate": "2026-04-10T00:00:00Z",
    "endDate": "2026-04-10T10:00:00Z"
  },
  "inputs": [
    {
      "role": "seller",
      "participantId": "<seller-meter-id>",
      "offerTimeseries": {
        "intervalPeriod": {
          "start": "2026-04-11T00:00:00Z",
          "duration": "PT1H"
        },
        "intervals": [
          { "id": 0, "payloads": [
            { "type": "PRICE_PER_KWH", "value": 6.50, "currency": "INR" },
            { "type": "AVAILABLE_QTY",  "value": 50,   "unit": "KWH" }
          ]},
          { "id": 1, "payloads": [
            { "type": "PRICE_PER_KWH", "value": 5.00, "currency": "INR" },
            { "type": "AVAILABLE_QTY",  "value": 45,   "unit": "KWH" }
          ]}
        ]
      }
    },
    {
      "role": "buyer",
      "participantId": "<buyer-meter-id>",
      "bidTimeseries": {
        "intervalPeriod": {
          "start": "2026-04-11T00:00:00Z",
          "duration": "PT1H"
        },
        "intervals": [
          { "id": 0, "payloads": [
            { "type": "REQUESTED_QTY", "value": 30, "unit": "KWH" }
          ]}
        ]
      }
    }
  ],
  "contractTerms": {
    "@context": "https://schema.beckn.io/DEGContract/v2.0/context.jsonld",
    "@type": "beckn:DEGContract",
    "policyUrl": "https://policies.deg.example/p2p-trade-v1.rego",
    "policyHash": "sha256:<hash>"
  }
}
```

**Key fields**:
```yaml
validityWindow: TimePeriod      # offer acceptance window
inputs:
  - role: seller | buyer
    participantId: string        # meter ID
    offerTimeseries: BecknTimeSeries   # seller: PRICE_PER_KWH + AVAILABLE_QTY
    bidTimeseries: BecknTimeSeries     # buyer: REQUESTED_QTY
contractTerms:
  "@context", "@type": DEGContract
  policyUrl: uri                 # Rego policy URL
  policyHash: string             # sha256 for integrity

BecknTimeSeries:
  intervalPeriod:
    start: date-time             # first slot start
    duration: string             # ISO 8601 e.g. PT1H
  intervals:
    - id: integer                # 0-based slot index
      payloads:
        - type: string           # PRICE_PER_KWH | AVAILABLE_QTY | REQUESTED_QTY
          value: number
          currency: string       # for PRICE types
          unit: string           # for QTY types (KWH, KW, ...)
```

---

### EnergyCustomer (Participant)
**Attaches to**: `Participant` (direct props — no wrapper)
**Use when**: Participant in a P2P energy trade has meter/utility identity

```json
{
  "@context": [
    "https://schema.beckn.io/Participant/v2.0",
    "https://schema.beckn.io/EnergyCustomer/v2.0"
  ],
  "@type": ["beckn:Participant", "beckn:EnergyCustomer"],
  "id": "der://meter/100200300",
  "displayName": "Arjun Sharma",
  "meterId": "der://meter/100200300",
  "sanctionedLoad": 10.0,
  "utilityCustomerId": "BESCOM-2024-001234",
  "utilityId": "BESCOM"
}
```

**Key fields**:
```yaml
meterId: string                  # DER address der://meter/{id}
sanctionedLoad: number           # kW
utilityCustomerId: string
utilityId: string
```

---

## Demand Flex

### DemandFlexNeed
**Attaches to**: `Item.resourceAttributes`
**@type**: `beckn:DemandFlexNeed`
**Use when**: Utility publishes a demand flex event for aggregators/prosumers

```json
"resourceAttributes": {
  "@context": "https://schema.beckn.io/DemandFlexNeed/v2.0/context.jsonld",
  "@type": "beckn:DemandFlexNeed",
  "direction": "REDUCE",
  "eventWindow": {
    "startDate": "2026-04-10T14:00:00Z",
    "endDate": "2026-04-10T16:00:00Z"
  },
  "capacityType": "CURTAILMENT",
  "maxCapacityKw": 500,
  "location": {
    "type": "Polygon",
    "coordinates": [[[<lng1>,<lat1>],[<lng2>,<lat2>],[<lng3>,<lat3>],[<lng1>,<lat1>]]]
  }
}
```

**Key fields**:
```yaml
direction: INCREASE | REDUCE
eventWindow:
  startDate: date-time           # UTC with Z suffix
  endDate: date-time
capacityType: CURTAILMENT | SHIFT | GENERATION
maxCapacityKw: number
location: GeoJSON Point or Polygon
```

---

### DemandFlexBuyOffer
**Attaches to**: `Offer.offerAttributes`
**@type**: `beckn:DemandFlexBuyOffer`
**Use when**: Offer for participating in a demand flex event

```json
"offerAttributes": {
  "@context": "https://schema.beckn.io/DemandFlexBuyOffer/v2.0/context.jsonld",
  "@type": "beckn:DemandFlexBuyOffer",
  "incentivePerKwh": 15.00,
  "currency": "INR",
  "minCommitmentKw": 5.0,
  "maxCommitmentKw": 200.0,
  "baselineMethodology": "ROLLING_7_DAY_AVERAGE",
  "contractTerms": {
    "@context": "https://schema.beckn.io/DEGContract/v2.0/context.jsonld",
    "@type": "beckn:DEGContract",
    "policyUrl": "https://policies.deg.example/demand-flex-v1.rego",
    "policyHash": "sha256:<hash>"
  }
}
```

**Key fields**:
```yaml
incentivePerKwh: number
currency: string
minCommitmentKw: number
maxCommitmentKw: number
baselineMethodology: ROLLING_7_DAY_AVERAGE | AMI_BASELINE | ...
contractTerms: DEGContract with Rego policy URL
```

---

## DDM — Decentralized Data Marketplace

### DatasetItem
**Attaches to**: `Item.resourceAttributes`
**@type**: `"DatasetItem"` (schema.org Dataset + Beckn extensions)
**Use when**: Item is a dataset product

```json
"resourceAttributes": {
  "@context": "https://schema.beckn.io/DatasetItem/v1/context.jsonld",
  "@type": "DatasetItem",
  "schema:identifier": "dataset-ems-hourly-2025",
  "schema:name": "EMS Hourly Energy Data 2025",
  "schema:description": "Hourly energy consumption data from 500 commercial buildings",
  "schema:temporalCoverage": "2025-01-01/2025-12-31",
  "schema:spatialCoverage": "Bangalore Metropolitan Region",
  "schema:license": "CC-BY-4.0",
  "schema:variableMeasured": ["energy_consumption_kwh", "peak_demand_kw"],
  "schema:measurementTechnique": "Smart meter AMI readings",
  "qualityFlags": {
    "gapFilledPercent": 1.2,
    "latencyMinutes": 60
  },
  "accessMethod": "DOWNLOAD",
  "schema:distribution": [
    {
      "schema:encodingFormat": "text/csv",
      "schema:contentSize": "2.3 GB"
    },
    {
      "schema:encodingFormat": "application/x-parquet"
    }
  ]
}
```

**Key fields**:
```yaml
schema:identifier: string
schema:name: string
schema:description: string
schema:temporalCoverage: string         # ISO 8601 interval or text
schema:spatialCoverage: string | object
schema:license: string                  # SPDX or URL
schema:variableMeasured: string[]
schema:measurementTechnique: string
qualityFlags:
  gapFilledPercent: number
  latencyMinutes: integer
accessMethod: INLINE | DOWNLOAD | DATA_ENCLAVE | OFF_CHANNEL | API | STREAM
schema:distribution: array
```

---

### DatasetFulfillment
**Attaches to**: `Fulfillment.performanceAttributes`
**@type**: `"DatasetFulfillment"`
**Use when**: Dataset access provisioning after order confirmation

```json
"performanceAttributes": {
  "@context": "https://schema.beckn.io/DatasetFulfillment/v1/context.jsonld",
  "@type": "DatasetFulfillment",
  "fulfillment:accessMethod": "DOWNLOAD",
  "fulfillment:accessUrl": "https://data.example.com/datasets/ems-hourly-2025/download",
  "fulfillment:accessStart": "2026-04-10T00:00:00Z",
  "fulfillment:accessEnd": "2026-07-10T00:00:00Z",
  "fulfillment:format": "Parquet",
  "fulfillment:fileSizeBytes": 2468000000,
  "fulfillment:maxDownloads": 5,
  "fulfillment:downloadsUsed": 0,
  "fulfillment:termsUrl": "https://data.example.com/terms/ems-hourly-2025",
  "fulfillment:attributionText": "Source: EMS Analytics Platform, 2025",
  "fulfillment:supportEmail": "data-support@example.com"
}
```

**Key fields**:
```yaml
fulfillment:accessMethod: DOWNLOAD | API | STREAM | DATA_ROOM | SFTP
fulfillment:accessUrl: uri
fulfillment:accessStart: date-time
fulfillment:accessEnd: date-time
fulfillment:format: string          # Parquet, CSV, JSON, GeoJSON …
fulfillment:fileSizeBytes: integer
fulfillment:maxDownloads: integer
fulfillment:downloadsUsed: integer
fulfillment:termsUrl: uri
fulfillment:attributionText: string
fulfillment:supportEmail: email
```

---

## Complete domain schema table

| Domain | Schema | Attaches to |
|---|---|---|
| F&B prepared item | FnBItem | Item.resourceAttributes, Commitment.commitmentAttributes |
| F&B customizable offer | FnBOffer | Offer.offerAttributes |
| F&B price breakdown | FnBPriceSpecification | Consideration.considerationAttributes |
| F&B/retail physical delivery | HyperlocalDelivery | Fulfillment.performanceAttributes |
| EV charging connector | EvChargingService | Item.resourceAttributes |
| EV charging tariff | EvChargingOffer | Offer.offerAttributes |
| EV charging session | EvChargingSession | Fulfillment.performanceAttributes |
| P2P energy source | EnergyResource | Item.resourceAttributes |
| P2P day-ahead offer | EnergyTradeOffer | Offer.offerAttributes |
| Energy buyer/seller | EnergyCustomer | Participant (direct props) |
| Demand flex event | DemandFlexNeed | Item.resourceAttributes |
| Demand flex incentive | DemandFlexBuyOffer | Offer.offerAttributes |
| Dataset product | DatasetItem | Item.resourceAttributes |
| Dataset access | DatasetFulfillment | Fulfillment.performanceAttributes |
