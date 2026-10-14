# GenApp — Db2 Table CRUD Matrix

> Generated from local metadata database (ScannerOutput.db).  
> Schema owner: `GENASA1`. Access modes derived from SQL statement types in the scanner.  
> **C** = CREATE (INSERT) · **R** = READ (SELECT/FETCH) · **U** = UPDATE · **D** = DELETE

---

## 1. CRUD Matrix — Programs × Tables

| Program | Layer | CUSTOMER | CUSTOMER_SECURE | POLICY | CLAIM | COMMERCIAL | ENDOWMENT | HOUSE | MOTOR |
|---|---|---|---|---|---|---|---|---|---|
| **LGACDB01** | CICS online | **C** | — | — | — | — | — | — | — |
| **LGACDB02** | CICS online | — | **C** | — | — | — | — | — | — |
| **LGACUS01** | CICS online | **C** | — | **C R D** | — | — | — | — | — |
| **LGICDB01** | CICS online | **R** | — | — | — | — | — | — | — |
| **LGUCDB01** | CICS online | **U** | — | — | — | — | — | — | — |
| **LGAPDB01** | CICS online | — | — | **C R U** | **C R** | **C R** | **C** | **C** | **C** |
| **LGIPDB01** | CICS online | — | — | **R** | **R** | **R** | **R** | **R** | **R** |
| **LGDPDB01** | CICS online | — | — | **D** | — | — | — | — | — |
| **LGMOTOUT** | CICS / batch | — | — | — | — | — | — | — | **R** |
| **LGBATCH** | Batch | **R** | — | — | — | — | — | — | — |
| **LGBATDB2** | Batch | **R** | — | — | — | — | — | — | — |

---

## 2. CRUD Matrix — Tables × Programs (inverted view)

### `CUSTOMER`
| Program | C | R | U | D | Notes |
|---|---|---|---|---|---|
| LGACDB01 | ✔ | | | | Insert new customer row; obtains ID via CICS GET COUNTER |
| LGACUS01 | ✔ | ✔ | | ✔ | Orchestrates customer add; also reads/deletes POLICY rows |
| LGICDB01 | | ✔ | | | SELECT by customer number |
| LGUCDB01 | | | ✔ | | UPDATE customer details |
| LGBATCH | | ✔ | | | Batch: SELECT all customers for report |
| LGBATDB2 | | ✔ | | | Batch: SELECT customer 1 for Db2 test report |

### `CUSTOMER_SECURE`
| Program | C | R | U | D | Notes |
|---|---|---|---|---|---|
| LGACDB02 | ✔ | | | | INSERT customer password/security record |

### `POLICY`
| Program | C | R | U | D | Notes |
|---|---|---|---|---|---|
| LGACUS01 | ✔ | ✔ | | ✔ | Creates initial policy row during customer add; also deletes on rollback |
| LGAPDB01 | ✔ | ✔ | ✔ | | INSERT new policy; SELECT for validation; UPDATE policy header |
| LGIPDB01 | | ✔ | | | SELECT policy by policy number |
| LGDPDB01 | | | | ✔ | DELETE policy row (cascades to sub-type deletion via LGDPVS01) |

### `CLAIM`
| Program | C | R | U | D | Notes |
|---|---|---|---|---|---|
| LGAPDB01 | ✔ | ✔ | | | INSERT claim record; SELECT for validation |
| LGIPDB01 | | ✔ | | | SELECT claim details |

### `COMMERCIAL`
| Program | C | R | U | D | Notes |
|---|---|---|---|---|---|
| LGAPDB01 | ✔ | ✔ | | | INSERT commercial policy details |
| LGIPDB01 | | ✔ | | | SELECT commercial policy details |

### `ENDOWMENT`
| Program | C | R | U | D | Notes |
|---|---|---|---|---|---|
| LGAPDB01 | ✔ | | | | INSERT life/endowment policy details |
| LGIPDB01 | | ✔ | | | SELECT life/endowment policy details |

### `HOUSE`
| Program | C | R | U | D | Notes |
|---|---|---|---|---|---|
| LGAPDB01 | ✔ | | | | INSERT house policy details |
| LGIPDB01 | | ✔ | | | SELECT house policy details |

### `MOTOR`
| Program | C | R | U | D | Notes |
|---|---|---|---|---|---|
| LGAPDB01 | ✔ | | | | INSERT motor policy details |
| LGIPDB01 | | ✔ | | | SELECT motor policy details |
| LGMOTOUT | | ✔ | | | SELECT all motor policies for output report |

---

## 3. Table Summary

| Table | Total Programs | C | R | U | D | Description |
|---|---|---|---|---|---|---|
| CUSTOMER | 6 | 2 | 3 | 1 | 1 | Core customer master — name, address, date of birth |
| CUSTOMER_SECURE | 1 | 1 | 0 | 0 | 0 | Customer security credentials (password) — accessed only by LGACDB02 |
| POLICY | 4 | 2 | 3 | 1 | 1 | Policy header — type code, customer number, start/end date, premium |
| CLAIM | 2 | 1 | 2 | 0 | 0 | Claim records linked to policies |
| COMMERCIAL | 2 | 1 | 2 | 0 | 0 | Commercial property policy details |
| ENDOWMENT | 2 | 1 | 2 | 0 | 0 | Life/endowment policy details |
| HOUSE | 2 | 1 | 2 | 0 | 0 | House/building policy details |
| MOTOR | 3 | 1 | 3 | 0 | 0 | Motor vehicle policy details (also reported in batch) |

---

## 4. Key Observations

### Single-writer tables
- **CUSTOMER_SECURE** is written only by `LGACDB02` — it is completely isolated from update and delete paths.
- **ENDOWMENT**, **HOUSE**, **COMMERCIAL**, **CLAIM** are written only by `LGAPDB01`; no update or delete path exists for the sub-type records (policy delete removes only the POLICY header + VSAM, leaving orphan sub-type rows).

### Shared tables — highest coupling
- **CUSTOMER** is accessed by 6 programs across both online and batch — the most shared table in the application.
- **POLICY** is accessed by 4 programs including the orchestrator `LGACUS01`, making it a cross-domain coupling point between Customer and Policy domains.

### Missing UPDATE / DELETE paths for policy sub-types
`MOTOR`, `HOUSE`, `ENDOWMENT`, `COMMERCIAL`, and `CLAIM` have no UPDATE or DELETE statements in any program. This means policy sub-type data can only be created (via `LGAPDB01`) or read (via `LGIPDB01`). Updating a policy sub-type requires deleting and re-adding the policy.

### Dual-storage architecture
Every customer and policy entity is stored in **both** Db2 and VSAM. The VSAM files (`KSDSCUST`, `KSDSPOLY`) mirror the Db2 tables as a parallel storage tier, likely for performance or legacy reasons. The Db2 programs and VSAM programs are coordinated by the orchestrator programs (`LGxxUS01`, `LGxxOL01`).
