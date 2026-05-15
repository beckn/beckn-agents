# Canonical Payload Templates

Based on: `protocol-specifications-v2` draft branch canonical pizza-delivery-2.0 examples.
Placeholders use `<angle-bracket>` notation. Replace with scenario-specific values.

---

## discover

**Caller**: BAP → CDS/BPP  
**Purpose**: Broadcast intent to find catalogs  
**Note**: `bppId`/`bppUri` are absent (broadcast)

```json
{
  "context": {
    "version": "2.0.0",
    "action": "discover",
    "bapId": "food-app.example.com",
    "bapUri": "https://food-app.example.com/beckn",
    "networkId": "beckn:retail-network:in",
    "ttl": "PT30S",
    "messageId": "<uuid-new>",
    "timestamp": "<ISO8601-UTC>",
    "transactionId": "<uuid-new-for-flow>"
  },
  "message": {
    "intent": {
      "textSearch": "<free text e.g. 'veg pizza bangalore'>"
    }
  }
}
```

With spatial filter:
```json
{
  "context": { "...same, action: discover..." },
  "message": {
    "intent": {
      "textSearch": "<query>",
      "spatial": [
        {
          "op": "S_DWITHIN",
          "targets": "$['provider']['locations'][*]['geo']",
          "geometry": { "type": "Point", "coordinates": [<lng>, <lat>] },
          "distanceMeters": 5000
        }
      ]
    }
  }
}
```

With JSONPath filter:
```json
{
  "context": { "...action: discover..." },
  "message": {
    "intent": {
      "textSearch": "<query>",
      "filters": {
        "type": "jsonpath",
        "expression": "$[?(@.resourceAttributes.food.classification == 'VEG')]"
      }
    }
  }
}
```

---

## on_discover

**Caller**: BPP/CDS → BAP  
**Purpose**: Return matching catalogs with items and offers

```json
{
  "context": {
    "version": "2.0.0",
    "action": "on_discover",
    "bapId": "food-app.example.com",
    "bapUri": "https://food-app.example.com/beckn",
    "bppId": "tomato.com",
    "bppUri": "https://tomato.com/beckn",
    "networkId": "beckn:retail-network:in",
    "ttl": "PT30S",
    "messageId": "<uuid-new>",
    "timestamp": "<ISO8601-UTC>",
    "transactionId": "<same-as-discover>"
  },
  "message": {
    "catalogs": [
      {
        "id": "<catalog-id>",
        "bppId": "tomato.com",
        "bppUri": "https://tomato.com/beckn",
        "providerId": "<provider-id>",
        "descriptor": {
          "name": "<Provider Name>",
          "shortDesc": "<brief description>",
          "thumbnailImage": "<logo-url>"
        },
        "resources": [
          {
            "id": "<resource-id>",
            "descriptor": {
              "name": "<Item Name>",
              "shortDesc": "<description>",
              "thumbnailImage": "<image-url>"
            },
            "provider": {
              "id": "<provider-id>",
              "descriptor": { "name": "<Provider Name>" },
              "locations": [
                {
                  "id": "<location-id>",
                  "geo": { "type": "Point", "coordinates": [<lng>, <lat>] },
                  "address": {
                    "streetAddress": "<street>",
                    "addressLocality": "<city>",
                    "addressRegion": "<state>",
                    "postalCode": "<pin>",
                    "addressCountry": "IN"
                  }
                }
              ]
            },
            "price": { "currency": "INR", "value": <base-price> },
            "isActive": true,
            "resourceAttributes": {
              "@context": "https://schema.beckn.io/FnBItem/v2.1/context.jsonld",
              "@type": "beckn:FnBItem",
              "classification": "VEG",
              "cuisine": "Italian",
              "allergenInfo": { "contains": ["GLUTEN", "MILK"] },
              "preparation": { "instructions": "<instructions>", "storage": "<storage>" }
            }
          }
        ],
        "offers": [
          {
            "id": "<offer-id>",
            "resourceIds": ["<resource-id>"],
            "price": { "currency": "INR", "value": <price> },
            "offerAttributes": {
              "@context": "https://schema.beckn.io/FnBOffer/v2.1/context.jsonld",
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
                      { "code": "CAPSICUM", "name": "Capsicum", "priceDelta": { "type": "FIXED", "value": 30 } }
                    ]
                  }
                ]
              }
            }
          }
        ]
      }
    ]
  }
}
```

---

## select

**Caller**: BAP → BPP  
**Purpose**: Choose item+offer, create DRAFT contract  
**Note**: BAP sends minimal commitments — BPP echoes back full item/offer detail in on_select

```json
{
  "context": {
    "version": "2.0.0",
    "action": "select",
    "bapId": "food-app.example.com",
    "bapUri": "https://food-app.example.com/beckn",
    "bppId": "tomato.com",
    "bppUri": "https://tomato.com/beckn",
    "networkId": "beckn:retail-network:in",
    "ttl": "PT30S",
    "messageId": "<uuid-new>",
    "timestamp": "<ISO8601-UTC>",
    "transactionId": "<same-as-discover>"
  },
  "message": {
    "contract": {
      "@context": "https://schema.beckn.io/Contract/v2.0",
      "@type": "beckn:Contract",
      "participants": [
        { "id": "<session-or-user-id>" },
        { "id": "<store-id>", "displayName": "<Store Name>" }
      ],
      "commitments": [
        {
          "id": "<commitment-id>",
          "status": { "descriptor": { "code": "DRAFT" } },
          "resources": [{ "id": "<resource-id>", "quantity": { "unitCode": "EA", "unitQuantity": <qty> } }],
          "offer": { "id": "<offer-id>", "resourceIds": ["<resource-id>"] },
          "commitmentAttributes": {
            "@context": "https://schema.beckn.io/FnBItem/v2.1/context.jsonld",
            "@type": "beckn:FnBItem",
            "lineId": "line-001",
            "offerId": "<offer-id>",
            "quantity": { "unitCode": "EA", "unitQuantity": <qty> },
            "resourceId": "<resource-id>"
          }
        }
      ]
    }
  }
}
```

---

## on_select

**Caller**: BPP → BAP  
**Purpose**: Return contract with prices, full resource/offer detail, performance placeholder

```json
{
  "context": {
    "version": "2.0.0",
    "action": "on_select",
    "bapId": "food-app.example.com",
    "bapUri": "https://food-app.example.com/beckn",
    "bppId": "tomato.com",
    "bppUri": "https://tomato.com/beckn",
    "networkId": "beckn:retail-network:in",
    "ttl": "PT30S",
    "messageId": "<same-as-select>",
    "timestamp": "<ISO8601-UTC>",
    "transactionId": "<same-as-discover>"
  },
  "message": {
    "contract": {
      "@context": "https://schema.beckn.io/Contract/v2.0",
      "@type": "beckn:Contract",
      "participants": [
        { "id": "<session-or-user-id>" },
        {
          "id": "<store-id>",
          "displayName": "<Store Name>",
          "descriptor": { "name": "<Store Name>", "shortDesc": "<tagline>" },
          "location": {
            "id": "<store-id>",
            "geo": { "type": "Point", "coordinates": [<lng>, <lat>] },
            "address": { "streetAddress": "<addr>", "addressLocality": "<city>", "addressRegion": "<state>", "postalCode": "<pin>", "addressCountry": "IN" }
          },
          "rating": { "ratingValue": 4.3, "ratingCount": 2847 }
        }
      ],
      "commitments": [
        {
          "id": "<commitment-id>",
          "status": { "descriptor": { "code": "DRAFT" } },
          "resources": [{ "id": "<resource-id>", "quantity": { "unitCode": "EA", "unitQuantity": <qty> } }],
          "offer": { "id": "<offer-id>", "resourceIds": ["<resource-id>"] },
          "commitmentAttributes": {
            "@context": "https://schema.beckn.io/FnBItem/v2.1/context.jsonld",
            "@type": "beckn:FnBItem",
            "lineId": "line-001",
            "offerId": "<offer-id>",
            "quantity": { "unitCode": "EA", "unitQuantity": <qty> },
            "price": {
              "currency": "INR",
              "value": <line-total>,
              "components": [
                { "type": "BASE_ITEM", "value": <unit-price>, "currency": "INR", "description": "<Item Name>" }
              ]
            },
            "resourceId": "<resource-id>",
            "classification": "VEG",
            "cuisine": "Italian",
            "allergenInfo": { "contains": ["GLUTEN", "MILK"] }
          }
        }
      ],
      "consideration": [
        {
          "id": "<consideration-id>",
          "status": { "descriptor": { "code": "PENDING" } },
          "considerationAttributes": {
            "@context": "https://schema.beckn.io/FnBPriceSpecification/v2.1/context.jsonld",
            "@type": "beckn:FnBPriceSpecification",
            "currency": "INR",
            "value": <total>,
            "components": [
              { "type": "BASE_ITEM",   "value": <items-total>,  "currency": "INR", "description": "<items>" },
              { "type": "DELIVERY_FEE","value": <delivery-fee>, "currency": "INR", "description": "Delivery fee" }
            ]
          }
        }
      ],
      "performance": [
        {
          "id": "<performance-id>",
          "status": { "descriptor": { "code": "PENDING" } },
          "performanceAttributes": {
            "@context": "https://schema.beckn.io/HyperlocalDelivery/v2.0/context.jsonld",
            "@type": "beckn:HyperlocalDelivery",
            "pickupLocation": {
              "id": "<store-id>",
              "geo": { "type": "Point", "coordinates": [<lng>, <lat>] },
              "address": { "streetAddress": "<store-address>", "addressLocality": "<city>", "addressRegion": "<state>", "postalCode": "<pin>", "addressCountry": "IN" }
            },
            "deliveryLocation": {
              "geo": { "type": "Point", "coordinates": [<lng>, <lat>] }
            },
            "itemsShipped": [
              { "resourceId": "<resource-id>", "offerId": "<offer-id>", "quantity": { "unitCode": "EA", "unitQuantity": <qty> }, "lineId": "line-001" }
            ]
          }
        }
      ]
    }
  }
}
```

---

## init

**Caller**: BAP → BPP  
**Purpose**: Add full buyer details and complete delivery address

Same contract as `on_select`, with:
- Consumer participant gains `displayName`, `telephone`, `email`
- `deliveryLocation` gets full address

```json
{
  "context": { "...action: init, same transactionId..." },
  "message": {
    "contract": {
      "@context": "https://schema.beckn.io/Contract/v2.0",
      "@type": "beckn:Contract",
      "participants": [
        { "id": "<user@example.com>", "displayName": "<Buyer Name>", "telephone": "+91<phone>", "email": "<buyer@example.com>" },
        { "...provider participant same as on_select..." }
      ],
      "commitments": ["<same as on_select>"],
      "consideration": ["<same as on_select>"],
      "performance": [
        {
          "id": "<performance-id>",
          "status": { "descriptor": { "code": "PENDING" } },
          "performanceAttributes": {
            "@context": "https://schema.beckn.io/HyperlocalDelivery/v2.0/context.jsonld",
            "@type": "beckn:HyperlocalDelivery",
            "pickupLocation": { "...same store location..." },
            "deliveryLocation": {
              "geo": { "type": "Point", "coordinates": [<lng>, <lat>] },
              "address": {
                "streetAddress": "<Buyer Building, Street>",
                "addressLocality": "<City>",
                "addressRegion": "<State>",
                "postalCode": "<PIN>",
                "addressCountry": "IN"
              }
            },
            "itemsShipped": ["<same as on_select>"]
          }
        }
      ]
    }
  }
}
```

---

## on_init

**Caller**: BPP → BAP  
**Purpose**: Confirm payment terms, finalize SLA

Same as `init` response body — BPP echoes back with confirmation. No contract `id` yet (assigned on on_confirm).

```json
{
  "context": { "...action: on_init, same messageId as init..." },
  "message": { "contract": { "<same as init, fully populated>" } }
}
```

---

## confirm

**Caller**: BAP → BPP  
**Purpose**: Finalise contract; include payment proof in entitlements

```json
{
  "context": {
    "version": "2.0.0",
    "action": "confirm",
    "bapId": "food-app.example.com",
    "bapUri": "https://food-app.example.com/beckn",
    "bppId": "tomato.com",
    "bppUri": "https://tomato.com/beckn",
    "networkId": "beckn:retail-network:in",
    "ttl": "PT30S",
    "messageId": "<uuid-new>",
    "timestamp": "<ISO8601-UTC>",
    "transactionId": "<same-as-discover>"
  },
  "message": {
    "contract": {
      "@context": "https://schema.beckn.io/Contract/v2.0",
      "@type": "beckn:Contract",
      "participants": ["<fully populated consumer + restaurant>"],
      "commitments": ["<same as on_init>"],
      "consideration": ["<same as on_init>"],
      "performance": ["<same as init — includes full deliveryLocation>"],
      "entitlements": [
        {
          "descriptor": {
            "name": "Payment Reference",
            "shortDesc": "Payment ref: <UTR-or-reference>"
          },
          "type": "PAYMENT_PROOF",
          "id": "<UTR-or-payment-reference>"
        }
      ]
    }
  }
}
```

---

## on_confirm

**Caller**: BPP → BAP  
**Purpose**: Contract confirmed — status becomes ACTIVE, contract gets id + displayId

```json
{
  "context": {
    "version": "2.0.0",
    "action": "on_confirm",
    "bapId": "food-app.example.com",
    "bapUri": "https://food-app.example.com/beckn",
    "bppId": "tomato.com",
    "bppUri": "https://tomato.com/beckn",
    "networkId": "beckn:retail-network:in",
    "ttl": "PT30S",
    "messageId": "<same-as-confirm>",
    "timestamp": "<ISO8601-UTC>",
    "transactionId": "<same-as-discover>"
  },
  "message": {
    "contract": {
      "@context": "https://schema.beckn.io/Contract/v2.0",
      "@type": "beckn:Contract",
      "id": "<contract-uuid>",
      "displayId": "<ORD-20260310-001>",
      "status": { "descriptor": { "code": "ACTIVE" } },
      "participants": ["<fully populated consumer + provider>"],
      "commitments": ["<same as confirm>"],
      "consideration": [
        {
          "id": "<consideration-id>",
          "status": { "descriptor": { "code": "PENDING" } },
          "considerationAttributes": {
            "@context": "https://schema.beckn.io/FnBPriceSpecification/v2.1/context.jsonld",
            "@type": "beckn:FnBPriceSpecification",
            "currency": "INR",
            "value": <total>,
            "components": [
              { "type": "BASE_ITEM",    "value": <items-total>,  "currency": "INR", "description": "<items>" },
              { "type": "DELIVERY_FEE", "value": <delivery-fee>, "currency": "INR", "description": "Delivery fee" }
            ]
          }
        }
      ],
      "performance": [
        {
          "id": "<performance-id>",
          "status": { "descriptor": { "code": "ACTIVE", "name": "Order Received", "shortDesc": "Being prepared" } },
          "performanceAttributes": {
            "@context": "https://schema.beckn.io/HyperlocalDelivery/v2.0/context.jsonld",
            "@type": "beckn:HyperlocalDelivery",
            "pickupLocation": { "...store location..." },
            "deliveryLocation": { "...buyer address..." },
            "itemsShipped": ["<same as confirm>"]
          }
        }
      ],
      "entitlements": ["<same as confirm>"]
    }
  }
}
```

---

## status / on_status

```json
// status (BAP → BPP)
{
  "context": { "...action: status, same transactionId..." },
  "message": { "contract": { "id": "<contract-uuid>" } }
}

// on_status (BPP → BAP)
{
  "context": { "...action: on_status, same transactionId..." },
  "message": {
    "contract": {
      "@context": "https://schema.beckn.io/Contract/v2.0",
      "@type": "beckn:Contract",
      "id": "<contract-uuid>",
      "status": { "descriptor": { "code": "ACTIVE" } },
      "performance": [
        {
          "id": "<performance-id>",
          "status": { "descriptor": { "code": "ACTIVE", "name": "Out for delivery", "shortDesc": "Your order is on the way" } },
          "performanceAttributes": { "...updated delivery state..." }
        }
      ]
    }
  }
}
```

---

## cancel / on_cancel

```json
// cancel preview (try=true)
{
  "context": { "...action: cancel, try: true, same transactionId..." },
  "message": { "contract": { "id": "<contract-uuid>" } }
}

// on_cancel preview — returns policy
{
  "context": { "...action: on_cancel, try: true..." },
  "message": {
    "contract": {
      "@context": "https://schema.beckn.io/Contract/v2.0",
      "@type": "beckn:Contract",
      "id": "<contract-uuid>",
      "status": { "descriptor": { "code": "ACTIVE" } }
    }
  }
}

// cancel commit
{
  "context": { "...action: cancel..." },
  "message": { "contract": { "id": "<contract-uuid>" } }
}

// on_cancel commit
{
  "context": { "...action: on_cancel..." },
  "message": {
    "contract": {
      "@context": "https://schema.beckn.io/Contract/v2.0",
      "@type": "beckn:Contract",
      "id": "<contract-uuid>",
      "status": { "descriptor": { "code": "CANCELLED" } }
    }
  }
}
```

---

## track / on_track

```json
// track
{
  "context": { "...action: track, same transactionId..." },
  "message": { "tracking": { "id": "<performance-id>" } }
}

// on_track
{
  "context": { "...action: on_track, same transactionId..." },
  "message": {
    "tracking": {
      "id": "<performance-id>",
      "url": "https://<bpp>/track/<contract-uuid>",
      "websocketUrl": "wss://<bpp>/track/<contract-uuid>/live",
      "status": { "descriptor": { "code": "ACTIVE" } }
    }
  }
}
```

---

## rate / on_rate

```json
// rate
{
  "context": { "...action: rate, same transactionId..." },
  "message": {
    "ratingInputs": [
      {
        "refId": "<contract-uuid>",
        "refType": "CONTRACT",
        "value": 4,
        "maxValue": 5,
        "feedback": "Great food, fast delivery!"
      }
    ]
  }
}

// on_rate
{
  "context": { "...action: on_rate..." },
  "message": {
    "ratings": [
      { "refId": "<contract-uuid>", "refType": "CONTRACT", "value": 4, "maxValue": 5 }
    ]
  }
}
```

---

## Payload completeness checklist

Before outputting any payload set, verify:

- [ ] `context.version: "2.0.0"` on every payload
- [ ] All context fields camelCase (`bapId`, `messageId`, `transactionId`, `networkId`)
- [ ] `bppId`/`bppUri` absent only from `discover`
- [ ] `transactionId` same UUID across discover → on_confirm
- [ ] `messageId` unique per request; on_* mirrors the request's messageId
- [ ] `message.catalogs[].resources[]` (not `items[]`)
- [ ] `resourceAttributes` on Resource (not `itemAttributes`)
- [ ] `performance[]` in Contract (not `fulfillments[]`)
- [ ] `performanceAttributes` on Performance (not `fulfillmentAttributes`)
- [ ] Contract has `"@context": "https://schema.beckn.io/Contract/v2.0"` at top level
- [ ] Contract `status.code: "ACTIVE"` on on_confirm (not "CONFIRMED")
- [ ] Participants use array `@context`/`@type`, direct props (no `participantAttributes` wrapper)
- [ ] `considerationAttributes` uses `components[]` (not `breakup[]`), has `value` (not `totalAmount`)
- [ ] Every `*Attributes` block has `@context` and `@type`
