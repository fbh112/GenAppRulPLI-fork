# GenApp PL/I Application — Complete Program Inventory

> Generated from workspace analysis of `/pli/` (35 programs) and `/plinc/` (6 include files).

---

## Application Architecture Overview

GenApp is a general insurance application running on z/OS. It exposes CICS online transactions for managing customers and insurance policies (Motor, Endowment, House, Commercial), and includes batch programs for reporting and data extraction. The architecture follows a strict three-tier layering:

```
┌──────────────────────────────────────────────────────────────────────┐
│  TIER 1 — Presentation (BMS Menu programs)                           │
│  LGTESTP1  LGTESTP2  LGTESTP3  LGTESTP4  LGTESTC1                   │
└──────────────────────┬───────────────────────────────────────────────┘
                       │ CICS LINK
┌──────────────────────▼───────────────────────────────────────────────┐
│  TIER 2 — Orchestration (Business logic / policy routers)            │
│  LGAPOL01  LGIPOL01  LGDPOL01  LGUPOL01                              │
│  LGACUS01  LGICUS01  LGUCUS01                                        │
└──────────────────────┬───────────────────────────────────────────────┘
                       │ CICS LINK (dynamic)
┌──────────────────────▼───────────────────────────────────────────────┐
│  TIER 3 — Backend (DB2 and VSAM I/O programs)                        │
│  DB2:   LGAPDB01  LGIPDB01  LGDPDB01  LGUPDB01                       │
│         LGACDB01  LGACDB02  LGICDB01  LGUCDB01                       │
│  VSAM:  LGAPVS01  LGIPVS01  LGDPVS01  LGUPVS01                       │
│         LGACVS01  LGICVS01  LGUCVS01                                  │
└──────────────────────────────────────────────────────────────────────┘

Supporting CICS programs:  LGSTSQ  LGASTAT1  LGWEBST5  LGSETUP
Optional business rules:   LGAPBR01  (external — not in repository)
Batch programs:            LGBATCH  LGBATDB2  LGMOTOUT  LGBATCHF
```

---

## Program Inventory

### Tier 1 — Presentation / BMS Menu Programs

These programs receive control directly from CICS transactions. They present BMS maps to the terminal, collect user input, and dispatch to the orchestration tier via `EXEC CICS LINK`.

---

#### [`LGTESTP1`](pli/LGTESTP1.pli) — Motor Policy Menu
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — BMS Menu |
| **Entry** | `Proc(DFHEIPTR, COMM_AREA_PTR) Options(Main, Reentrant)` |
| **CICS Transaction** | SSAM (Motor) |
| **Role** | Presents the Motor policy BMS screen (`SSMAPP1`). Handles Inquire, Add, Delete, and Update policy operations for Motor policies. |
| **Calls (CICS LINK)** | `LGIPOL01`, `LGAPOL01`, `LGDPOL01`, `LGUPOL01` |
| **Includes** | `%INCLUDE SSMAP`, `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | None |

---

#### [`LGTESTP2`](pli/LGTESTP2.pli) — Endowment Policy Menu
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — BMS Menu |
| **Entry** | `Proc(DFHEIPTR, COMM_AREA_PTR) Options(Main, Reentrant)` |
| **Role** | Presents the Endowment policy BMS screen (`SSMAPP2`). Handles Inquire, Add, Delete, and Update operations for Endowment policies. |
| **Calls (CICS LINK)** | `LGIPOL01`, `LGAPOL01`, `LGDPOL01`, `LGUPOL01` |
| **Includes** | `%INCLUDE SSMAP`, `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | None |

---

#### [`LGTESTP3`](pli/LGTESTP3.pli) — House Policy Menu
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — BMS Menu |
| **Entry** | `Proc(DFHEIPTR, COMM_AREA_PTR) Options(Main, Reentrant)` |
| **Role** | Presents the House policy BMS screen (`SSMAPP3`). Handles Inquire, Add, Delete, and Update operations for House policies. |
| **Calls (CICS LINK)** | `LGIPOL01`, `LGAPOL01`, `LGDPOL01`, `LGUPOL01` |
| **Includes** | `%INCLUDE SSMAP`, `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | None |

---

#### [`LGTESTP4`](pli/LGTESTP4.pli) — Commercial Policy Menu
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — BMS Menu |
| **Entry** | `Proc(DFHEIPTR, COMM_AREA_PTR) Options(Main, Reentrant)` |
| **Role** | Presents the Commercial policy BMS screen (`SSMAPP4`). Handles Inquire, Add, and Delete operations for Commercial policies. |
| **Calls (CICS LINK)** | `LGIPOL01`, `LGAPOL01`, `LGDPOL01` |
| **Includes** | `%INCLUDE SSMAP`, `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | None |

---

#### [`LGTESTC1`](pli/LGTESTC1.pli) — Customer Menu
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — BMS Menu |
| **Entry** | `Proc(DFHEIPTR, COMM_AREA_PTR) Options(Main, Reentrant)` |
| **Role** | Presents the Customer BMS screen (`SSMAPC1`). Handles Inquire, Add, and Update operations for Customers. Also reads/writes `GENACNTL` TS queue for customer number ranges. On first call initialises counters via external `ADDIPGM1`. |
| **Calls (CICS LINK)** | `LGICUS01`, `LGACUS01`, `LGUCUS01`, `ADDIPGM1` (external) |
| **Includes** | `%INCLUDE SSMAP`, `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | None |
| **TS Queues** | `GENACNTL` (read/write) |

---

### Tier 2 — Orchestration / Business Logic Programs

These programs validate the COMMAREA, apply business rules, and dispatch dynamically to the appropriate backend program using `EXEC CICS LINK` with a program name variable.

---

#### [`LGAPOL01`](pli/LGAPOL01.pli) — Add Policy (Orchestrator)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Policy Orchestrator |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Add Policy business logic. Validates the COMMAREA request for all policy types (Endowment, House, Motor, Commercial). Conditionally invokes business rules (`LGAPBR01`) when applicable, then routes to the DB2 backend (`LGAPDB01`). |
| **Calls (CICS LINK)** | `LGAPBR01` (optional — business rules), `LGAPDB01`, `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None (delegates to LGAPDB01) |
| **VSAM** | None |

---

#### [`LGIPOL01`](pli/LGIPOL01.pli) — Inquire Policy (Orchestrator)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Policy Orchestrator |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Inquire Policy business logic. Routes the policy inquiry (Endowment, House, Motor, Commercial, Claim) to the DB2 backend. |
| **Calls (CICS LINK)** | `LGIPDB01` (dynamic — variable `LGIPDB01`), `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGPOLICY`, `%INCLUDE LGCMAREA` |
| **DB2** | None (delegates to LGIPDB01) |
| **VSAM** | None |

---

#### [`LGDPOL01`](pli/LGDPOL01.pli) — Delete Policy (Orchestrator)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Policy Orchestrator |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Delete Policy business logic. Routes the delete request to the DB2 backend (`LGDPDB01`). |
| **Calls (CICS LINK)** | `LGDPDB01` (dynamic), `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None (delegates to LGDPDB01) |
| **VSAM** | None |

---

#### [`LGUPOL01`](pli/LGUPOL01.pli) — Update Policy (Orchestrator)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Policy Orchestrator |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Update Policy business logic. Routes the update request to the DB2 backend (`LGUPDB01`). |
| **Calls (CICS LINK)** | `LGUPDB01` (hardcoded string `'LGUPDB01'`), `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None (delegates to LGUPDB01) |
| **VSAM** | None |

---

#### [`LGACUS01`](pli/LGACUS01.pli) — Add Customer (Orchestrator)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Customer Orchestrator |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Add Customer orchestrator. Inserts customer and policy records directly via embedded DB2 (`INSERT INTO CUSTOMER`, `INSERT INTO POLICY`), then calls `LGACVS01` for VSAM mirroring and `LGACDB02` for customer security record creation. |
| **Calls (CICS LINK)** | `LGACVS01` (dynamic), `LGACDB02` (dynamic), `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | `CUSTOMER` (INSERT), `POLICY` (INSERT) |
| **VSAM** | None (via LGACVS01) |

---

#### [`LGICUS01`](pli/LGICUS01.pli) — Inquire Customer (Orchestrator)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Customer Orchestrator |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Inquire Customer orchestrator. Routes inquiries to the DB2 backend (`LGICDB01`). |
| **Calls (CICS LINK)** | `LGICDB01` (dynamic — variable `LGICDB01`), `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None (delegates to LGICDB01) |
| **VSAM** | None |

---

#### [`LGUCUS01`](pli/LGUCUS01.pli) — Update Customer (Orchestrator)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Customer Orchestrator |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Update Customer orchestrator. Dispatches to `LGUCDB01` for DB2 update. |
| **Calls (CICS LINK)** | `LGUCDB01` (dynamic — variable `LGUCDB01`), `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None (delegates to LGUCDB01) |
| **VSAM** | None |

---

### Tier 3 — Backend DB2 Programs

These programs perform all embedded SQL operations. They communicate entirely via COMMAREA.

---

#### [`LGAPDB01`](pli/LGAPDB01.pli) — Add Policy (DB2)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — DB2 Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Inserts new policy records into DB2 for all policy types: Endowment, House, Motor, Commercial, and Claim. Also calls `LGAPVS01` for VSAM policy write. |
| **Calls (CICS LINK)** | `LGAPVS01`, `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2 Tables** | `POLICY` (INSERT), `ENDOWMENT` (INSERT), `HOUSE` (INSERT), `MOTOR` (INSERT), `COMMERCIAL` (INSERT), `CLAIM` (INSERT) |
| **VSAM** | Via LGAPVS01 → `KSDSPOLY` |

---

#### [`LGIPDB01`](pli/LGIPDB01.pli) — Inquire Policy (DB2)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — DB2 Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Reads full policy details from DB2. Uses multiple cursors (`Cust_Cursor`, `Zip_Cursor`, `CusClaim_Cursor`) to retrieve Endowment, House, Motor, Commercial, and Claim details. |
| **Calls (CICS LINK)** | `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2 Tables** | `CUSTOMER`, `POLICY`, `ENDOWMENT`, `HOUSE`, `MOTOR`, `COMMERCIAL`, `CLAIM` (SELECT via cursors) |
| **VSAM** | None |

---

#### [`LGDPDB01`](pli/LGDPDB01.pli) — Delete Policy (DB2)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — DB2 Backend |
| **Entry** | `Proc(DFHEIPTR, COMM_AREA_PTR) Options(Main, Reentrant)` |
| **Role** | Deletes a policy record from DB2. Also calls `LGDPVS01` for VSAM policy delete. |
| **Calls (CICS LINK)** | `LGDPVS01`, `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2 Tables** | `POLICY` (DELETE) |
| **VSAM** | Via LGDPVS01 → `KSDSPOLY` |

---

#### [`LGUPDB01`](pli/LGUPDB01.pli) — Update Policy (DB2)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — DB2 Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Updates policy records in DB2. Uses a cursor (`POLICY_CURSOR`) for policy selection with hold, then updates the appropriate sub-type table (Endowment, House, Motor). Also calls `LGUPVS01` for VSAM update. |
| **Calls (CICS LINK)** | `LGUPVS01`, `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGPOLICY`, `%INCLUDE LGCMAREA` |
| **DB2 Tables** | `POLICY` (SELECT cursor, UPDATE), `ENDOWMENT` (UPDATE), `HOUSE` (UPDATE), `MOTOR` (UPDATE) |
| **VSAM** | Via LGUPVS01 → `KSDSPOLY` |

---

#### [`LGACDB01`](pli/LGACDB01.pli) — Add Customer (DB2)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — DB2 Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Inserts a new customer record into DB2 `CUSTOMER` table. Also calls `LGACVS01` (VSAM customer write) and `LGACDB02` (customer security insert). |
| **Calls (CICS LINK)** | `LGACVS01` (dynamic), `LGACDB02` (dynamic), `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2 Tables** | `CUSTOMER` (INSERT) |
| **VSAM** | Via LGACVS01 → `KSDSCUST` |

---

#### [`LGACDB02`](pli/LGACDB02.pli) — Add Customer Security (DB2)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — DB2 Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Inserts a customer security record into the `CUSTOMER_SECURE` table. Called by both `LGACDB01` and `LGACUS01`. |
| **Calls (CICS LINK)** | `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2 Tables** | `CUSTOMER_SECURE` (INSERT) |
| **VSAM** | None |

---

#### [`LGICDB01`](pli/LGICDB01.pli) — Inquire Customer (DB2)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — DB2 Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Selects customer details from the DB2 `CUSTOMER` table using the customer number from the COMMAREA. |
| **Calls (CICS LINK)** | `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2 Tables** | `CUSTOMER` (SELECT) |
| **VSAM** | None |

---

#### [`LGUCDB01`](pli/LGUCDB01.pli) — Update Customer (DB2)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — DB2 Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Updates customer details in the DB2 `CUSTOMER` table. Also calls `LGUCVS01` for VSAM customer update. |
| **Calls (CICS LINK)** | `LGUCVS01` (dynamic — variable), `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2 Tables** | `CUSTOMER` (UPDATE) |
| **VSAM** | Via LGUCVS01 → `KSDSCUST` |

---

### Tier 3 — Backend VSAM Programs

These programs handle CICS File Control operations against the VSAM KSDS datasets (`KSDSPOLY` for policies, `KSDSCUST` for customers).

---

#### [`LGAPVS01`](pli/LGAPVS01.pli) — Add Policy (VSAM)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — VSAM Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Writes a new policy record to the VSAM KSDS dataset `KSDSPOLY` via `EXEC CICS Write File`. |
| **Calls (CICS LINK)** | `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | `KSDSPOLY` (WRITE) |

---

#### [`LGIPVS01`](pli/LGIPVS01.pli) — Inquire Policy (VSAM Browse)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — VSAM Backend |
| **Entry** | `Proc(COMMA_PTR) Options(Main)` |
| **Role** | Performs a generic GTEQ key browse against `KSDSPOLY`. Accepts a partial policy key (type + customer number) from a COMMAREA or terminal input and returns the matching policy record. |
| **Calls (CICS LINK)** | None |
| **Includes** | None |
| **DB2** | None |
| **VSAM** | `KSDSPOLY` (READ GTEQ) |

---

#### [`LGDPVS01`](pli/LGDPVS01.pli) — Delete Policy (VSAM)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — VSAM Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Deletes a policy record from the VSAM KSDS dataset `KSDSPOLY` via `EXEC CICS Delete File`. |
| **Calls (CICS LINK)** | `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | `KSDSPOLY` (DELETE) |

---

#### [`LGUPVS01`](pli/LGUPVS01.pli) — Update Policy (VSAM)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — VSAM Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Updates a policy record in the VSAM KSDS dataset `KSDSPOLY` via `EXEC CICS Read File` (with UPDATE) followed by `EXEC CICS ReWrite File`. |
| **Calls (CICS LINK)** | `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | `KSDSPOLY` (READ UPDATE + REWRITE) |

---

#### [`LGACVS01`](pli/LGACVS01.pli) — Add Customer (VSAM)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — VSAM Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Writes a new customer record to the VSAM KSDS dataset `KSDSCUST` via `EXEC CICS Write File`. Called by both `LGACDB01` and `LGACUS01`. |
| **Calls (CICS LINK)** | `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | `KSDSCUST` (WRITE) |

---

#### [`LGICVS01`](pli/LGICVS01.pli) — Inquire Customer (VSAM)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — VSAM Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Reads the `GENACNTL` TS queue for the customer number range, then performs a GTEQ read against `KSDSCUST` to retrieve the nearest customer record. Can be invoked by CICS LINK or started as a transaction. |
| **Calls (CICS LINK)** | None |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | `KSDSCUST` (READ GTEQ) |
| **TS Queues** | `GENACNTL` (read) |

---

#### [`LGUCVS01`](pli/LGUCVS01.pli) — Update Customer (VSAM)
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — VSAM Backend |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Updates a customer record in the VSAM KSDS dataset `KSDSCUST` via `EXEC CICS Read File` (with UPDATE) followed by `EXEC CICS ReWrite File`. |
| **Calls (CICS LINK)** | `LGSTSQ` (error logging) |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | `KSDSCUST` (READ UPDATE + REWRITE) |

---

### Supporting CICS Programs

These programs provide cross-cutting infrastructure services used by programs across all tiers.

---

#### [`LGSTSQ`](pli/LGSTSQ.pli) — Error Message Logger
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Shared Service |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Centralised error message writer. Receives up to 90 bytes of message text via COMMAREA and writes it to both the `CSMT` TDQ and the `GENAERRS` TS queue (or a custom queue if started with `Q=nnnn`). Called by virtually every CICS program on error. |
| **Calls (CICS LINK)** | None |
| **Includes** | None |
| **DB2** | None |
| **VSAM** | None |
| **TDQ / TSQ** | `CSMT` (TDQ write), `GENAERRS` (TSQ write) |

---

#### [`LGASTAT1`](pli/LGASTAT1.pli) — Statistics Counter Update
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Event Processing Adapter |
| **Entry** | `Proc(COMM_AREA_PTR) Options(Main)` |
| **Role** | Event-processing adapter target. Reads the request ID and return code from a DFHEP channel (`DFHEP.DATA.00001`, `DFHEP.DATA.00002`) or from the COMMAREA, and increments the matching named counter `GENA<request><rc>` in pool `GENA`. Also reads `GENASTRT` TS queue. |
| **Calls (CICS LINK)** | None |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | None |
| **Named Counters** | `GENA` pool (increment) |
| **TS Queues** | `GENASTRT` (read) |

---

#### [`LGWEBST5`](pli/LGWEBST5.pli) — Statistics Collector
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Statistics Daemon |
| **Entry** | `Proc Options(Main)` (no COMMAREA) |
| **Role** | Queries the `GENA` named counters, computes per-minute transaction rates (delta of current minus previous values), stores previous and current values in TS queues `GENA<code>V`, and re-starts itself every minute via transaction `SSST`. PL/I port of the COBOL version; drives 34 counter blocks from an internal table rather than repeating code. |
| **Calls (CICS LINK)** | None |
| **Includes** | None |
| **DB2** | None |
| **VSAM** | None |
| **Named Counters** | `GENA` pool (QUERY) |
| **TS Queues** | `GENA<code>V` (read/write) |

---

#### [`LGSETUP`](pli/LGSETUP.pli) — GenApp Environment Setup
| Attribute | Value |
|-----------|-------|
| **Type** | CICS — Administrative Utility |
| **Entry** | `Proc Options(Main)` (no COMMAREA) |
| **Role** | One-time environment initialisation. Deletes and recreates the GenApp TS queues (`GENAERRS`, `GENASTRT`) and all 36 named transaction counters in the `GENA` pool. Accepts the high customer number from terminal input (default 11). |
| **Calls (CICS LINK)** | None |
| **Includes** | None |
| **DB2** | None |
| **VSAM** | None |
| **Named Counters** | `GENA` pool (36 counters — define/reset) |
| **TS Queues** | `GENAERRS`, `GENASTRT` (DELETE), `GENACNTL` (WRITE) |

---

### Batch Programs

These programs run outside CICS with no EXEC CICS statements.

---

#### [`LGBATCH`](pli/LGBATCH.pli) — Batch Customer Report
| Attribute | Value |
|-----------|-------|
| **Type** | Batch — Main |
| **Entry** | `Proc Options(Main)` |
| **Role** | Reads customer numbers sequentially from the `CUSTIN` input file (FB, RECSIZE 10), selects each customer from DB2 CUSTOMER table, and writes a formatted 80-byte report line to the `CUSTRPT` output file (FB, RECSIZE 80) via the `LGBATCHF` subroutine. |
| **Static CALL** | `LGBATCHF` |
| **Includes** | `EXEC SQL INCLUDE SQLCA`, `EXEC SQL INCLUDE LGCMAREA` |
| **DB2 Tables** | `CUSTOMER` (SELECT) |
| **Input Files** | `CUSTIN` (sequential, FB/10) |
| **Output Files** | `CUSTRPT` (sequential, FB/80) |

---

#### [`LGBATDB2`](pli/LGBATDB2.pli) — Batch DB2 Test Driver
| Attribute | Value |
|-----------|-------|
| **Type** | Batch — Main |
| **Entry** | `Proc Options(Main)` |
| **Role** | Minimal DB2 test driver. Selects customer number 1 from DB2 and displays the report line built by `LGBATCHF`. Intended for verifying DB2 connectivity in batch. |
| **Static CALL** | `LGBATCHF` |
| **Includes** | `EXEC SQL INCLUDE SQLCA`, `EXEC SQL INCLUDE LGCMAREA` |
| **DB2 Tables** | `CUSTOMER` (SELECT) |
| **Input Files** | None |
| **Output Files** | DISPLAY (console) |

---

#### [`LGMOTOUT`](pli/LGMOTOUT.pli) — Motor Table Extract
| Attribute | Value |
|-----------|-------|
| **Type** | Batch — Main |
| **Entry** | `Proc Options(Main)` |
| **Role** | Selects all rows from the DB2 `MOTOR` table using cursor `MOTOR_CSR` and writes each as a formatted 132-byte record to the `MOTOROUT` sequential output file. Returns RC=0 (ok), RC=8 (fetch error), RC=12 (open/cursor error). |
| **Static CALL** | None |
| **Includes** | `EXEC SQL INCLUDE SQLCA` |
| **DB2 Tables** | `MOTOR` (SELECT via cursor) |
| **Output Files** | `MOTOROUT` (sequential, FB/132) |

---

#### [`LGBATCHF`](pli/LGBATCHF.pli) — Format Customer Report Line (Subroutine)
| Attribute | Value |
|-----------|-------|
| **Type** | Batch — Subroutine (non-Main) |
| **Entry** | `LGBATCF: Proc(CUSTNUMBER, COMM_PTR, LS_LINE)` — note internal name is `LGBATCF` |
| **Role** | Batch subroutine called statically by `LGBATCH` and `LGBATDB2`. Accepts a customer number, a pointer to a populated LGCMAREA COMMAREA, and an 80-byte output buffer. Formats the customer first name, last name, and customer number into the report line. |
| **Called by** | `LGBATCH`, `LGBATDB2` |
| **Includes** | `%INCLUDE LGCMAREA` |
| **DB2** | None |
| **VSAM** | None |

---

## Include Files (plinc/)

| File | Type | Used by |
|------|------|---------|
| [`LGCMAREA.inc`](plinc/LGCMAREA.inc) | COMMAREA structure — customer and policy fields | All CICS programs + `LGBATCH`, `LGBATDB2`, `LGBATCHF` |
| [`SSMAP.inc`](plinc/SSMAP.inc) | BMS map structures for all policy and customer screens | `LGTESTP1–4`, `LGTESTC1` |
| [`LGCMARER.inc`](plinc/LGCMARER.inc) | Business rule request area structure | `LGAPBR01` (external) |
| [`LGPOLICY.inc`](plinc/LGPOLICY.inc) | Policy data structure definitions | `LGIPOL01`, `LGUPDB01` |
| [`DCLPOLIC.inc`](plinc/DCLPOLIC.inc) | DB2 DECLARE TABLE for POLICY | DB2 precompiler |
| [`DCLENDOW.inc`](plinc/DCLENDOW.inc) | DB2 DECLARE TABLE for ENDOWMENT | DB2 precompiler |

---

## DB2 Table Access Summary

| Table | INSERT | SELECT | UPDATE | DELETE | Programs |
|-------|--------|--------|--------|--------|---------|
| `CUSTOMER` | ✓ | ✓ | ✓ | — | LGACDB01 (I), LGACUS01 (I), LGICDB01 (S), LGBATCH (S), LGBATDB2 (S), LGUCDB01 (U) |
| `CUSTOMER_SECURE` | ✓ | — | — | — | LGACDB02 (I) |
| `POLICY` | ✓ | ✓ | ✓ | ✓ | LGAPDB01 (I), LGACUS01 (I), LGIPDB01 (S), LGUPDB01 (S+U), LGDPDB01 (D) |
| `ENDOWMENT` | ✓ | ✓ | ✓ | — | LGAPDB01 (I), LGIPDB01 (S), LGUPDB01 (U) |
| `HOUSE` | ✓ | ✓ | ✓ | — | LGAPDB01 (I), LGIPDB01 (S), LGUPDB01 (U) |
| `MOTOR` | ✓ | ✓ | ✓ | — | LGAPDB01 (I), LGIPDB01 (S), LGUPDB01 (U), LGMOTOUT (S) |
| `COMMERCIAL` | ✓ | ✓ | — | — | LGAPDB01 (I), LGIPDB01 (S) |
| `CLAIM` | ✓ | ✓ | — | — | LGAPDB01 (I), LGIPDB01 (S) |

---

## VSAM Dataset Access Summary

| Dataset | Operation | Programs |
|---------|-----------|---------|
| `KSDSPOLY` | WRITE | LGAPVS01 |
| `KSDSPOLY` | READ GTEQ | LGIPVS01 |
| `KSDSPOLY` | DELETE | LGDPVS01 |
| `KSDSPOLY` | READ UPDATE + REWRITE | LGUPVS01 |
| `KSDSCUST` | WRITE | LGACVS01 |
| `KSDSCUST` | READ GTEQ | LGICVS01 |
| `KSDSCUST` | READ UPDATE + REWRITE | LGUCVS01 |

---

## External Program Dependencies (not in repository)

| Program | Called by | Purpose |
|---------|-----------|---------|
| `LGAPBR01` | LGAPOL01 (optional) | Business rules evaluation for Add Policy |
| `ADDIPGM1` | LGTESTC1 (first-call only) | Counter initialisation on first customer menu invocation |

---

## Program Count Summary

| Category | Count |
|----------|-------|
| CICS BMS Menu | 5 |
| CICS Policy Orchestrators | 4 |
| CICS Customer Orchestrators | 3 |
| CICS DB2 Backends | 8 |
| CICS VSAM Backends | 7 |
| CICS Supporting Services | 4 |
| Batch Main Programs | 3 |
| Batch Subroutines | 1 |
| **Total PL/I programs** | **35** |
| Include files | 6 |
