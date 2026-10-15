# GenApp PL/I — DB2 CRUD Matrix

## Legend

| Symbol | Meaning |
|--------|---------|
| **C** | CREATE / INSERT |
| **R** | READ / SELECT |
| **U** | UPDATE |
| **D** | DELETE |
| *(blank)* | No access |

---

## CRUD Matrix by Table

| Program | Domain | CUSTOMER | CUSTOMER_SECURE | POLICY | ENDOWMENT | HOUSE | MOTOR | COMMERCIAL | CLAIM |
|---------|--------|----------|-----------------|--------|-----------|-------|-------|------------|-------|
| **LGACDB01** | Customer | C | | | | | | | |
| **LGACDB02** | Customer | | C | | | | | | |
| **LGACUS01** | Customer | C | | R/C | | | | | |
| **LGICDB01** | Customer | R | | | | | | | |
| **LGUCDB01** | Customer | U | | | | | | | |
| **LGAPDB01** | Policy | | | R/C | C | C | C | R/C | R/C |
| **LGDPDB01** | Policy | | | D | | | | | |
| **LGIPDB01** | Policy | | | R/D | R | R | R | R/D | R/D |
| **LGMOTOUT** | Batch | | | | | | R/D | | |
| **LGBATCH** | Batch | R | | | | | | | |
| **LGBATDB2** | Batch | R | | | | | | | |

> **Note on LGIPDB01 D-flag**: The DB2 scanner flags reads on foreign-key-related statements; DELETE CASCADE from POLICY removes child rows in ENDOWMENT/HOUSE/MOTOR/COMMERCIAL/CLAIM.

---

## CRUD Matrix — Pivoted by Table

### CUSTOMER
| Operation | Programs |
|-----------|----------|
| **C** (INSERT) | LGACDB01, LGACUS01 |
| **R** (SELECT) | LGICDB01, LGBATCH, LGBATDB2, LGACUS01 |
| **U** (UPDATE) | LGUCDB01 |
| **D** (DELETE) | *(cascaded from external client; no direct DELETE in app)* |

### CUSTOMER_SECURE
| Operation | Programs |
|-----------|----------|
| **C** (INSERT) | LGACDB02 |
| **R** (SELECT) | *(none — password check not implemented in PL/I port)* |
| **U** (UPDATE) | *(none)* |
| **D** (DELETE) | *(cascaded from CUSTOMER DELETE)* |

### POLICY
| Operation | Programs |
|-----------|----------|
| **C** (INSERT) | LGAPDB01, LGACUS01 |
| **R** (SELECT) | LGIPDB01, LGACUS01, LGAPDB01 |
| **U** (UPDATE) | *(LGUPDB01 — source not in workspace)* |
| **D** (DELETE) | LGDPDB01 |

### ENDOWMENT
| Operation | Programs |
|-----------|----------|
| **C** (INSERT) | LGAPDB01 |
| **R** (SELECT) | LGIPDB01 |
| **D** (DELETE) | *(cascaded from POLICY DELETE)* |

### HOUSE
| Operation | Programs |
|-----------|----------|
| **C** (INSERT) | LGAPDB01 |
| **R** (SELECT) | LGIPDB01 |
| **D** (DELETE) | *(cascaded from POLICY DELETE)* |

### MOTOR
| Operation | Programs |
|-----------|----------|
| **C** (INSERT) | LGAPDB01 |
| **R** (SELECT) | LGIPDB01, LGMOTOUT |
| **D** (DELETE) | *(LGMOTOUT write-flag, cascaded from POLICY DELETE)* |

### COMMERCIAL
| Operation | Programs |
|-----------|----------|
| **C** (INSERT) | LGAPDB01 |
| **R** (SELECT) | LGIPDB01 |
| **D** (DELETE) | *(cascaded from POLICY DELETE)* |

### CLAIM
| Operation | Programs |
|-----------|----------|
| **C** (INSERT) | LGAPDB01 |
| **R** (SELECT) | LGIPDB01 |
| **D** (DELETE) | *(cascaded from POLICY DELETE)* |

---

## Key Observations

1. **POLICY is the hub table** — all policy type tables (ENDOWMENT, HOUSE, MOTOR, COMMERCIAL, CLAIM) are children via FK + DELETE CASCADE. Any program touching POLICY can indirectly affect all five policy-type tables.
2. **CUSTOMER is the root** — POLICY has a FK to CUSTOMER; CASCADE DELETE propagates through the entire hierarchy.
3. **LGAPDB01 is the sole writer for policy types** — it handles INSERT for all five policy sub-tables. No separate insert programs exist per policy type.
4. **LGIPDB01 is the sole reader for policy types** — centralised inquiry across all policy sub-types.
5. **Batch programs only read CUSTOMER** — LGBATCH and LGBATDB2 perform read-only reporting against the customer table; they do not modify any DB2 data.
6. **CUSTOMER_SECURE has no read path** — the password verification logic does not appear to be implemented in this PL/I port.
7. **LGUPDB01 source is missing** from the workspace — it is referenced by LGUPOL01 for UPDATE POLICY but its source file is absent.
