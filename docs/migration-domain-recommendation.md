# GenApp — Migration Domain Recommendation (Step 5)

> Based on functional domain analysis, program inventory, CRUD matrix, and dependency graph.

---

## Recommendation: Migrate the **Motor** Domain

For a demo migration off the mainframe, the **Motor sub-domain** is the best choice. Here is the full reasoning.

---

## 1. Evaluation Criteria

Each domain was scored across five migration-friendliness dimensions:

| Criterion | Weight | Rationale |
|---|---|---|
| **Self-containment** | High | Fewer external dependencies = cleaner boundary cut |
| **Complete source code available** | High | Missing source files (COBOL stubs) block migration |
| **No shared-data coupling** | High | Exclusive table ownership avoids dual-write complexity |
| **Small scope** | Medium | Smaller scope = faster demo, lower risk |
| **Visible business value** | Medium | Domain must be meaningful enough to demonstrate value |

---

## 2. Domain Comparison Table

| Domain | Self-contained | Source available | Exclusive tables | Scope | Recommended? |
|---|---|---|---|---|---|
| **Customer** | ❌ Shares POLICY via LGACUS01 | ⚠️ AAAAAAAA stub absent | ⚠️ CUSTOMER shared with Batch | Large (11 programs) | ❌ Too coupled |
| **Policy** | ❌ Customer domain writes POLICY | ❌ LGAPBR01, LGUPDB01 absent | ❌ POLICY, MOTOR shared | Large (15 programs) | ❌ Missing stubs + coupling |
| **Motor** | ✅ Only reads MOTOR table | ✅ LGMOTOUT.pli present | ✅ Only consumer of MOTOROUT | **Small** (1 program) | ✅ **Best choice** |
| **Batch Reporting** | ⚠️ Reads CUSTOMER | ✅ All source present | ✅ Owns CUSTIN, CUSTRPT | Small (3 programs) | ⚠️ No business logic |
| **Infrastructure** | ✅ Standalone | ✅ All source present | ✅ No tables | Small (4 programs) | ❌ No business domain |

---

## 3. Why Motor is the Best Choice

### 3.1 Clean boundary
`LGMOTOUT` is the sole program in this sub-domain. It has **one inbound dependency** (reads the `MOTOR` Db2 table owned by the Policy domain) and **one outbound output** (writes `MOTOROUT` QSAM file). There are no CICS transactions, no VSAM files, and no programs calling it from other domains.

```
MOTOR table (Db2) ──► LGMOTOUT ──► MOTOROUT (QSAM output file)
```

### 3.2 Complete source available
[`pli/LGMOTOUT.pli`](pli/LGMOTOUT.pli) is present in the workspace. No missing stubs, no COBOL dependencies, no external references that are absent.

### 3.3 No write-back to shared tables
`LGMOTOUT` only **reads** the `MOTOR` table — it does not write to any shared Db2 table. This eliminates the dual-write synchronisation problem that would arise if the migrated service needed to write back to a mainframe-hosted table.

### 3.4 Realistic data contract
The migration requires agreeing on a single data contract: the schema of the `MOTOR` table plus the format of the output file. Both are well-defined in [`DDL/db2cre.jcl`](DDL/db2cre.jcl) and the program source.

### 3.5 Demonstrates the key migration patterns
Although small, this domain illustrates the three core patterns needed for a real migration:
- **Db2 table access from the cloud** (replace embedded SQL with JDBC/REST API call to mainframe data)
- **QSAM file replacement** (replace MOTOROUT with a cloud-native output: S3, Kafka topic, REST response)
- **Batch job scheduling** (replace JCL/CICS invocation with a cloud job scheduler or serverless function)

---

## 4. Why Other Domains Were Ruled Out

### Customer
- `LGACUS01` directly inserts and deletes rows in the **POLICY** table — a table owned by a different domain. Moving Customer to the cloud would require either (a) keeping LGACUS01 on-prem or (b) giving the cloud service write access to a mainframe Db2 table used by Policy programs. Both options are complex.
- The inquiry path calls `AAAAAAAA`, a COBOL stub whose source is absent.

### Policy
- Two critical programs (`LGAPBR01` for business rules, `LGUPDB01` for Db2 update) are COBOL and have **no source in this workspace** — they cannot be migrated.
- The **POLICY** table is written by both the Policy domain and the Customer domain (`LGACUS01`), making table ownership ambiguous.

### Batch Reporting (LGBATCH / LGBATDB2)
- These programs read the **CUSTOMER** table, which is owned by the Customer domain and written by multiple CICS programs. Moving the batch to the cloud creates a cross-platform read dependency on a hot OLTP table.
- The business logic is thin (format + print), which limits the demo's ability to illustrate meaningful business rule migration.

### Infrastructure
- `LGSTSQ`, `LGSETUP`, `LGASTAT1`, `LGWEBST5` are pure infrastructure. Migrating them is a plumbing exercise, not a business-domain migration — it would not demonstrate the value proposition clearly.

---

## 5. Target Architecture Sketch

When the Motor domain is migrated:

```
┌─────────────────────────────────────────────────────┐
│  z/OS Mainframe                                     │
│                                                     │
│  CICS Policy programs ──► MOTOR table (Db2)  ◄──────┼──┐
│  (LGAPDB01, LGIPDB01 — unchanged)                   │  │ read
└─────────────────────────────────────────────────────┘  │
                                                          │
┌─────────────────────────────────────────────────────┐  │
│  Cloud Platform                                     │  │
│                                                     │──┘
│  Motor Report Service ──► Motor Report (cloud store/│
│  (replaces LGMOTOUT)       S3 / DB / REST API)      │
│                                                     │
│  Triggered by: Cloud scheduler (replaces JCL/CICS)  │
└─────────────────────────────────────────────────────┘
```

The integration point is a **read-only Db2 connection** from the cloud service to the mainframe MOTOR table (via Db2 Connect, REST API, or CDC replication). No write-back is needed.

---

## 6. Summary

| Factor | Detail |
|---|---|
| **Recommended domain** | Motor |
| **Entry program** | [`LGMOTOUT`](pli/LGMOTOUT.pli) |
| **Db2 table accessed** | `MOTOR` (read-only) |
| **Output** | `MOTOROUT` QSAM |
| **Source availability** | 100% — single PL/I file |
| **External couplings** | 1 (MOTOR table, read-only) |
| **Missing stubs** | None |
| **Migration complexity** | Low |
| **Demo value** | Illustrates Db2 access, batch → cloud job, file → cloud output |
