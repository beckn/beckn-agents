---
name: beckn-schema-builder
description: 'Guides developers through designing and publishing Beckn 2.0 schemas — from deciding whether a new schema is needed, through authoring, to registry contribution. Covers the four core mental models: check-before-create, abstraction level, inheritance vs composition, and AI-first authoring.'
metadata:
  tags: beckn,schema,design,jsonld,extension,registry,vocabulary,linked-data
---


## Authoritative reference

The full schema design guide lives in the protocol-specifications-v2 repo:
→ GitHub: https://github.com/beckn/protocol-specifications-v2/blob/draft/docs/Schema_Design_Guide.md

**Always read that document first.** This skill captures the mental models and decision framework on top of it — not a replacement.

Related specs:
- Core schema: `api/v2.0.0/beckn.yaml` in https://github.com/beckn/protocol-specifications-v2
- Beckn Schema Registry: https://schema.beckn.io
- Community schemas: https://github.com/beckn/schemas
- Energy/DEG schemas: https://github.com/beckn/DEG

---

## Step 1 — Check before you create

**Before authoring anything**, search the Beckn Schema Registry.

> Go to https://schema.beckn.io and search for terms related to your use case.

Ask yourself:
- Does an existing schema cover this domain? Can I reuse it with minor extension?
- Is there a parent-level schema I can extend rather than fork?
- Has another network or domain already solved this problem?

If a schema exists → **use or extend it, do not duplicate**.
If a schema is close but missing fields → **propose an extension via PR to `beckn/schemas`**.
Only if nothing fits → proceed to author a new schema.

---

## Step 2 — Identify the right abstraction level

The most important design question: **how generic should this schema be?**

### The spectrum

```
Too specific                              Too generic
─────────────────────────────────────────────────────
 HalalCertifiedFreshChickenInDubai  ←→  Product  ←→  Thing
```

The sweet spot is a **domain-level abstraction** that:
- Covers the class of thing (e.g. `GroceryItem`, `EvChargingService`, `DatasetItem`)
- Leaves region/use-case variations to `vocab.jsonld` vocabulary terms and network policy
- Can be reused by multiple networks without modification

### Red flags for over-specificity
- Schema name contains a city, country, regulatory body, or network name
- Schema name contains `With`, `And`, or `Plus` joining two concept names
- Schema is authored to express "X offered together with Y" (use `Offer.addOns[]` instead)
- Schema duplicates fields already on `Offer.considerations`, `Offer.addOns`, `Offer.resourceIds`, or `Resource.resourceAttributes`

### Red flags for over-genericity
- Schema has no domain-specific fields — it just restates core Beckn primitives
- Every domain vertical would need to override every field

### Abstracting region/usecase variants

When use cases differ by region or regulation (e.g. Halal certification in UAE vs organic labeling in EU), the pattern is:
1. Author a **generic parent schema** (e.g. `GroceryItem` with `regulatoryCategory`)
2. Define **vocabulary terms** in `vocab.jsonld` that extend the parent's enum/class (e.g. `HalalCertified rdfs:subClassOf beckn:productCategory`)
3. Express regional requirements via **network policy-as-code** (Rego), not schema fields

This keeps the shared schema stable while allowing each network to enforce its own rules.

---

## Step 3 — Inheritance vs composition: when to use each

### Inherit (extend via `*Attributes`)

Use JSON-LD schema extension when:
- You are adding **domain-specific properties** to a core Beckn entity (`Resource`, `Offer`, `Commitment`, `Consideration`, `Performance`)
- The properties belong to one entity type and one domain
- You want the schema to be independently reusable

Pattern:
```yaml
# attributes.yaml
type: object
properties:
  powerRating:
    type: object
    description: "Rated power output of the charging connector in kilowatts."
```

Attaches to the core entity via the `*Attributes` extension bag:

| Extension field | Attaches to |
|---|---|
| `resourceAttributes` | `Catalog.resources[]` |
| `offerAttributes` | `Catalog.offers[]` |
| `commitmentAttributes` | `Contract.commitments[]` |
| `considerationAttributes` | `Contract.consideration[]` |
| `performanceAttributes` | `Contract.performance[]` |
| `contractAttributes` | `Contract` |

### Compose (use Beckn primitives)

Use composition when you are expressing a **relationship between resources**, not properties of a single resource.

The core primitives already model most relationships:

| Relationship | Use |
|---|---|
| Resource offered for sale | `Offer.resourceIds[]` |
| Add-ons bundled with an offer | `Offer.addOns[]` |
| Bundle price | `Offer.considerations[]` |
| One resource covers/is compatible with another | cross-reference via `resourceAttributes` field pointing to `Resource.id` |

Only create a new **relationship schema** when:
- The relationship cannot be expressed as an ID reference
- The relationship carries its own metadata not placeable in `offerAttributes` without burdening unrelated use cases
- The relationship is reusable across multiple resource types

If you do author a relationship schema, it MUST describe only the relationship — never the properties of the resources it links.

---

## Step 4 — Design principles checklist

From the Schema Design Guide:

- [ ] **Search first** — `schema.beckn.io` checked before authoring
- [ ] **No conjoined names** — no `With`, `And`, `Plus` in schema names
- [ ] **No mandatory fields** — all fields optional by default; mandatoriness via network policy
- [ ] **Descriptor-first** — if semantics fit in `Descriptor.name/shortDesc/longDesc`, no schema needed
- [ ] **Structured only for machine use** — only add structured fields when needed for arithmetic, filtering, or cross-resource reference; replace restrictive enums with JSON-LD vocabulary terms
- [ ] **AI-readable descriptions** — every field description reads as standalone semantic prose; term names align with industry vocabulary
- [ ] **Vocabulary linkage** — every domain term in `vocab.jsonld` carries `rdfs:subClassOf`, `skos:broader`, or `owl:sameAs` back to the domain-agnostic vocabulary
- [ ] **Single `@context` URL on wire** — `Attributes` container `@context` MUST be a single string URL, never an array
- [ ] **No core field redefinition** — extensions MUST NOT alter the meaning of inherited core fields

---

## Step 5 — Schema pack structure

Every schema published to `beckn/schemas` or `beckn/DEG` must include:

```
SchemaName/
  v1.0/
    attributes.yaml    ← JSON Schema / OpenAPI fragment for the Attributes object
    schema.json        ← JSON Schema (standalone, for validators)
    context.jsonld     ← JSON-LD context mapping terms to IRIs
    vocab.jsonld       ← vocabulary graph (rdfs:Class / owl:ObjectProperty entries)
    README.md          ← human description, usage examples, conformance notes
```

Versioning: Semantic Versioning. Breaking changes → MAJOR bump + 90-day deprecation notice. Published version directories MUST NOT be modified in place.

---

## Step 6 — Contribution flow

```
Discussion (GitHub Discussions)
  → Issue filed in beckn/schemas or beckn/DEG
    → PR to `draft` branch
      → PR to `release` branch
        → PR to `main`
```

PRs MUST NOT be raised directly to `main`. NFO collaborators with write access MAY merge conforming PRs without CWG sign-off.

---

## Step 7 — Output format when helping a developer

1. **Registry check** — confirm search result from `schema.beckn.io`; name any close matches
2. **Abstraction decision** — one paragraph: what level of generality, why, and what gets pushed to vocab/policy
3. **Inheritance vs composition ruling** — which `*Attributes` extension point(s) to use, or which primitives to compose
4. **Draft `attributes.yaml`** — minimal, no mandatory fields, AI-readable descriptions
5. **Draft `vocab.jsonld` entries** — for any new vocabulary terms with `rdfs:subClassOf` / `skos:broader` links
6. **Conformance checklist** — run through Step 4 against the draft

---

## Common mistakes to flag

| Mistake | Correct approach |
|---|---|
| New schema for "Product X sold with Warranty" | Use `Offer.addOns[]` — no new schema needed |
| Mandatory fields in schema | All fields optional; enforce via Rego policy-as-code |
| `@context` array in `resourceAttributes` on the wire | Publish a combined context doc; reference as single URL |
| Schema named after a city or network | Abstract to domain level; express regional terms in `vocab.jsonld` |
| Duplicating core `Descriptor` fields | Use `Descriptor.name/shortDesc/longDesc` — no schema extension needed |
| `items[]` instead of `resources[]` | v2.0.0 uses `resources[]` everywhere |
