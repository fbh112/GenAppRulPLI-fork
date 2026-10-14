# GenApp — Application-Wide Migration Hotspots (Step 8)

> Ranked by breadth of impact (most programs / domains first).  
> Source: local scanner database, program inventory, domain analysis.

---

## 1. Methodology

A hotspot is any resource — program, Db2 table, VSAM file, or shared utility — whose removal, replacement, or change would require modifications in **multiple programs across multiple domains**. Hotspots are ranked first by the number of domains affected, then by the number of programs.

---

## 2. Hotspot Ranking

### Rank 1 — LGSTSQ (Shared Error-Logger Program)

| Attribute | Detail |
|---|---|
| **Type** | PL/I CICS program |
| **Programs depending on it** | Every CICS program in the application (Customer, Policy, Motor, Infrastructure domains) |
| **Domains affected** | **All 5 domains** |
| **Cyclomatic complexity** | 5 |

**Why it is critical**  
`LGSTSQ` is the universal error and message logger. All Db2-access programs call it via `EXEC CICS LINK PROGRAM('LGSTSQ')` whenever a DB2 or business error occurs. It writes structured messages to a CICS Temporary Storage Queue (TSQ). Its source confirmed in `pli/LGSTSQ.pli`.

Any migration scenario in which a domain moves off the mainframe requires a replacement strategy for this dependency:
- If the migrated program still runs in CICS (hybrid), it can continue to link to LGSTSQ on the mainframe.
- If the program runs entirely off-mainframe, the `EXEC CICS LINK` call must be replaced with a cloud-native logging mechanism (structured log, observability platform, MQ message, REST call to a logging microservice).

**Anomaly**: LGSTSQ is never called from off-mainframe. When any domain migrates, the calling convention (`EXEC CICS LINK`) no longer applies — the logging contract must be entirely re-implemented.

---

### Rank 2 — LGCMAREA.inc (Central COMMAREA Contract)

| Attribute | Detail |
|---|---|
| **Type** | PL/I include file (copybook equivalent) |
| **Programs depending on it** | All CICS programs: LGAPOL01, LGIPOL01, LGDPOL01, LGUPOL01, LGAPDB01, LGIPDB01, LGDPDB01, LGACUS01, LGACDB01, LGICUS01, LGUCUS01, LGUCDB01, LGWEBST5, all LGTESTP* |
| **Domains affected** | Customer, Policy, Infrastructure — **3+ domains** |
| **File** | `plinc/LGCMAREA.inc` |

**Why it is critical**  
`LGCMAREA.inc` defines the shared COMMAREA data structure exchanged between every CICS program via `EXEC CICS LINK`. It is the **inter-program API contract** for the entire CICS tier. Any change to its layout — adding fields, widening fields, reordering — requires recompilation and regression testing of every program that includes it.

When a domain migrates off the mainframe, the COMMAREA structure must be translated into the target API contract (JSON schema, Protobuf, OpenAPI spec). The COMMAREA becomes the "source of truth" for the interface definition.

**Anomaly**: There is no version control or length check enforcement built into most programs beyond a minimum-length guard. Expanding the COMMAREA without coordinating all callers risks silent data truncation.

---

### Rank 3 — CUSTOMER Table (Db2)

| Attribute | Detail |
|---|---|
| **Type** | Db2 table (`GENASA1.CUSTOMER`) |
| **Programs accessing it** | LGACDB01, LGACUS01, LGBATCH, LGBATDB2, LGICDB01, LGUCDB01 — **6 programs** |
| **Domains affected** | Customer (owner), Batch Reporting (reader) — **2 domains** |
| **Access modes** | C (create), R (read), U (update) |

**Why it is critical**  
CUSTOMER is the root entity of the entire application. Every POLICY row has a FK to CUSTOMER (`customerNumber`). Batch reporting reads it directly. The Customer domain owns it but 6 programs across 2 domains depend on it. Any schema change (adding a column, renaming, changing a type) requires changes in every program listed.

**Anomaly**: `LGACUS01` (Customer orchestrator) writes to the **POLICY** table in addition to CUSTOMER — a cross-domain write that creates a hidden coupling. This is not obvious from the Customer domain name alone.

---

### Rank 4 — POLICY Table (Db2)

| Attribute | Detail |
|---|---|
| **Type** | Db2 table (`GENASA1.POLICY`) |
| **Programs accessing it** | LGAPDB01, LGIPDB01, LGDPDB01, LGACUS01 — **4 programs** |
| **Domains affected** | Policy (owner), Customer (writes via LGACUS01) — **2 domains** |
| **Access modes** | C, R, U, D |

**Why it is critical**  
POLICY is the parent entity for every insurance product. All six product-type tables (MOTOR, HOUSE, ENDOWMENT, COMMERCIAL, CLAIM, and the base POLICY row) are linked through it. Any migration that touches POLICY must coordinate with all FK-child tables. The FK cascade-delete from CUSTOMER also passes through POLICY, making it the structural spine of the data model.

**Anomaly**: `LGACUS01` (Customer domain) also writes to POLICY — the most significant cross-domain write coupling in the application.

---

### Rank 5 — KSDSPOLY (VSAM KSDS — Policy VSAM Store)

| Attribute | Detail |
|---|---|
| **Type** | VSAM KSDS file (`ADAPPL.GENAPP.KSDSPOLY`) |
| **Programs accessing it** | LGAPVS01, LGIPVS01, LGDPVS01, LGUPVS01 — **4 programs** |
| **Domains affected** | Policy domain — **1 domain (but all 4 VSAM sub-programs)** |
| **Access modes** | C, R, U, D (full CRUD) |

**Why it is critical**  
KSDSPOLY is the VSAM parallel storage path for policy data. All four policy lifecycle operations (add, inquire, delete, update) have a VSAM-backed program in addition to the Db2 path. This dual-store architecture means that when migrating the Policy domain, both the Db2 path and the VSAM path must be accounted for. The VSAM store has no cloud-native equivalent without a migration strategy (e.g., VSAM to S3, VSAM to managed database, or elimination of the VSAM path entirely).

---

### Rank 6 — LGAPOL01 (Add Policy Orchestrator)

| Attribute | Detail |
|---|---|
| **Type** | PL/I CICS orchestrator program |
| **Callers** | LGTESTP1, LGTESTP2, LGTESTP3, LGTESTP4 — **4 programs** |
| **Callees** | LGAPBR01 (business rules stub) |
| **Domains affected** | Policy domain — **1 domain** |
| **Cyclomatic complexity** | 9 |

**Why it is critical**  
`LGAPOL01` is the add-policy entry point called by all four BMS menu programs. It acts as the policy type router before dispatching to `LGAPDB01`. Any change to the add-policy interface ripples immediately into all four BMS menus. It also calls `LGAPBR01`, a COBOL stub whose source is absent from the workspace.

**Anomaly**: `LGAPBR01` is a COBOL program with no visible source. Its business logic is a black box — a migration blocker until its source is recovered or its behaviour is reverse-engineered.

---

### Rank 7 — LGAPDB01 / LGIPDB01 (Policy Db2 Programs)

| Attribute | Detail |
|---|---|
| **Type** | PL/I CICS Db2 programs |
| **Tables accessed** | POLICY, MOTOR, HOUSE, ENDOWMENT, COMMERCIAL, CLAIM — **6 tables each** |
| **Domains affected** | Policy domain + Motor sub-domain (MOTOR table shared) |
| **Cyclomatic scores** | LGIPDB01: **70** (highest in the application), LGAPDB01: **53** (second highest) |

**Why it is critical**  
These two programs contain the most complex business logic in the entire application (premium loading, commission calculation, bundling discounts, peril surcharges — all in `LGAPDB01`; all five product-type SELECTs in `LGIPDB01`). Their high cyclomatic complexity means migration testing will require significant test coverage. They are also the only writers to the MOTOR, HOUSE, ENDOWMENT, COMMERCIAL, and CLAIM tables.

**Anomaly**: `LGIPDB01` has cyclomatic complexity **70** — the highest in the application by a wide margin. This makes it the highest-risk single program for migration equivalence testing.

---

### Rank 8 — KSDSCUST (VSAM KSDS — Customer VSAM Store)

| Attribute | Detail |
|---|---|
| **Type** | VSAM KSDS file (`ADAPPL.GENAPP.KSDSCUST`) |
| **Programs accessing it** | LGACVS01, LGICVS01, LGUCVS01 — **3 programs** |
| **Domains affected** | Customer domain — **1 domain** |
| **Access modes** | C, R, U |

**Why it is critical**  
Same dual-store pattern as KSDSPOLY. Customer data is mirrored between Db2 and VSAM. The VSAM store is the legacy persistence path and must be either migrated or decommissioned as part of any Customer domain migration.

---

### Rank 9 — LGBATCHF (Shared Batch Formatter)

| Attribute | Detail |
|---|---|
| **Type** | PL/I batch sub-program |
| **Callers** | LGBATCH, LGBATDB2 — **2 programs** |
| **Domains affected** | Batch Reporting domain |

**Why it is critical**  
`LGBATCHF` is the shared output formatter for both batch reporting programs. Any change to the report layout must be made here, and both callers must be retested. In a cloud migration it would need to be either embedded into each migrated program or exposed as a shared library/service.

---

## 3. Hotspot Summary Table

| Rank | Hotspot | Type | Programs | Domains | Risk Level |
|---|---|---|---|---|---|
| 1 | **LGSTSQ** | Shared program | All CICS programs | All 5 | 🔴 Critical |
| 2 | **LGCMAREA.inc** | PL/I include | All CICS programs | 3+ | 🔴 Critical |
| 3 | **CUSTOMER table** | Db2 table | 6 | 2 | 🟠 High |
| 4 | **POLICY table** | Db2 table | 4 | 2 | 🟠 High |
| 5 | **KSDSPOLY** | VSAM KSDS | 4 | 1 (Policy) | 🟠 High |
| 6 | **LGAPOL01** | CICS orchestrator | 4 callers | 1 (Policy) | 🟡 Medium |
| 7 | **LGAPDB01 / LGIPDB01** | Db2 programs | 6 tables each | 2 | 🟡 Medium |
| 8 | **KSDSCUST** | VSAM KSDS | 3 | 1 (Customer) | 🟡 Medium |
| 9 | **LGBATCHF** | Batch sub-program | 2 | 1 (Batch) | 🟢 Low |

---

## 4. Key Anomalies Flagged

| # | Anomaly | Impact |
|---|---|---|
| A1 | `LGACUS01` (Customer domain) writes the **POLICY table** (Policy domain) | Cross-domain DB write coupling — must coordinate both domains when migrating either |
| A2 | `LGAPBR01` (COBOL, no source) is called by every policy add | Black-box business rules gate — migration cannot proceed without source recovery or behaviour documentation |
| A3 | `LGIPDB01` cyclomatic complexity = **70** | Highest-risk single program for equivalence testing in any migration |
| A4 | Dual VSAM+Db2 storage for both Customer and Policy | VSAM stores must be migrated or decommissioned — adds significant effort to Customer and Policy domain migrations |
| A5 | `LGSTSQ` uses `EXEC CICS LINK` — no off-platform equivalent | Every migrated program must re-implement its error logging strategy |
