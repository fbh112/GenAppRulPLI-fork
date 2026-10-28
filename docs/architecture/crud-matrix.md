# GenApp — Db2 CRUD Matrix

> **Database**: `GENASA1`  
> **Source**: derived from scan database via SQL analysis of all embedded `EXEC SQL` statements  
> Legend: **C** = INSERT &nbsp;|&nbsp; **R** = SELECT / FETCH &nbsp;|&nbsp; **U** = UPDATE &nbsp;|&nbsp; **D** = DELETE

---

## Program × Table Matrix

| Program | Layer | CUSTOMER | CUSTOMER_SECURE | POLICY | ENDOWMENT | HOUSE | MOTOR | COMMERCIAL | CLAIM |
|---------|-------|:--------:|:---------------:|:------:|:---------:|:-----:|:-----:|:----------:|:-----:|
| **LGACDB01** | DB2 Backend | **C** | | | | | | | |
| **LGACDB02** | DB2 Backend | | **C** | | | | | | |
| **LGICDB01** | DB2 Backend | **R** | | | | | | | |
| **LGUCDB01** | DB2 Backend | **U** | | | | | | | |
| **LGAPDB01** | DB2 Backend | | | **CRU** | **C** | **C** | **C** | **CR** | **CR** |
| **LGIPDB01** | DB2 Backend | | | **R** | **R** | **R** | **R** | **R** | **R** |
| **LGDPDB01** | DB2 Backend | | | **D** | | | | | |
| **LGUPDB01** | DB2 Backend | | | **U** | | | | | |
| **LGACUS01** | Orchestration | **C** | | **CRD** | | | | | |
| **LGBATCH** | Batch | **R** | | | | | | | |
| **LGBATDB2** | Batch | **R** | | | | | | | |
| **LGMOTOUT** | Batch | | | | | | **R** | | |

---

## Table Dependency Diagrams

Each diagram shows the **full call chain** from BMS menu down to the Db2 table.
Reading left-to-right: **Menu → Orchestrator → DB2 Backend → Table**.
Every program in a diagram must be changed or adapted if the table is migrated off the mainframe.

Node colour = architectural layer:

| Colour | Layer |
|--------|-------|
| 🟫 Dark grey `#37474f` | Presentation (BMS Menu) |
| 🟩 Forest green `#1b5e20` | Business Orchestration |
| 🟦 Steel blue `#1565c0` | DB2 Backend |
| 🟥 Crimson `#b71c1c` | Batch (non-CICS) |
| 🟪 Deep purple `#4a148c` | Db2 Table |

---

### CUSTOMER

**6 programs impacted** across 3 layers (+ 2 batch programs).

```mermaid
flowchart LR
    %% Presentation
    LGTESTC1["LGTESTC1\nMenu"]

    %% Orchestration
    LGACUS01["LGACUS01\nOrchestration"]
    LGICUS01["LGICUS01\nOrchestration"]
    LGUCUS01["LGUCUS01\nOrchestration"]

    %% DB2 Backends
    LGACDB01["LGACDB01\nDB2 Backend"]
    LGICDB01["LGICDB01\nDB2 Backend"]
    LGUCDB01["LGUCDB01\nDB2 Backend"]

    %% Batch
    LGBATCH["LGBATCH\nBatch"]
    LGBATDB2["LGBATDB2\nBatch"]

    %% Table
    TBL[("CUSTOMER")]

    %% Call chain — online
    LGTESTC1 -->|"CICS LINK"| LGACUS01
    LGTESTC1 -->|"CICS LINK"| LGICUS01
    LGTESTC1 -->|"CICS LINK"| LGUCUS01

    LGACUS01 -->|"CICS LINK"| LGACDB01
    LGICUS01 -->|"CICS LINK"| LGICDB01
    LGUCUS01 -->|"CICS LINK"| LGUCDB01

    LGACDB01 -->|"C — INSERT"| TBL
    LGICDB01 -->|"R — SELECT"| TBL
    LGUCDB01 -->|"U — UPDATE"| TBL

    %% Direct SQL from orchestrator (bypasses backend)
    LGACUS01 -->|"C — INSERT\n(direct SQL)"| TBL

    %% Batch — no call chain
    LGBATCH  -->|"R — SELECT"| TBL
    LGBATDB2 -->|"R — SELECT"| TBL

    style TBL      fill:#4a148c,color:#ffffff,stroke:#38006b
    style LGTESTC1 fill:#37474f,color:#ffffff,stroke:#263238
    style LGACUS01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGICUS01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGUCUS01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGACDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGICDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGUCDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGBATCH  fill:#b71c1c,color:#ffffff,stroke:#7f0000
    style LGBATDB2 fill:#b71c1c,color:#ffffff,stroke:#7f0000
```

---

### CUSTOMER_SECURE

**3 programs impacted** across 3 layers.

```mermaid
flowchart LR
    %% Presentation
    LGTESTC1["LGTESTC1\nMenu"]

    %% Orchestration
    LGACUS01["LGACUS01\nOrchestration"]

    %% DB2 Backend
    LGACDB02["LGACDB02\nDB2 Backend"]

    %% Table
    TBL[("CUSTOMER_SECURE")]

    LGTESTC1 -->|"CICS LINK"| LGACUS01
    LGACUS01 -->|"CICS LINK"| LGACDB02
    LGACDB02 -->|"C — INSERT"| TBL

    style TBL      fill:#4a148c,color:#ffffff,stroke:#38006b
    style LGTESTC1 fill:#37474f,color:#ffffff,stroke:#263238
    style LGACUS01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGACDB02 fill:#1565c0,color:#ffffff,stroke:#0d47a1
```

---

### POLICY

**10 programs impacted** across 3 layers.

```mermaid
flowchart LR
    %% Presentation
    LGTESTC1["LGTESTC1\nMenu"]
    LGTESTP1["LGTESTP1\nMenu — Motor"]
    LGTESTP2["LGTESTP2\nMenu — Endowment"]
    LGTESTP3["LGTESTP3\nMenu — House"]
    LGTESTP4["LGTESTP4\nMenu — Commercial"]

    %% Orchestration
    LGAPOL01["LGAPOL01\nOrchestration"]
    LGIPOL01["LGIPOL01\nOrchestration"]
    LGDPOL01["LGDPOL01\nOrchestration"]
    LGUPOL01["LGUPOL01\nOrchestration"]
    LGACUS01["LGACUS01\nOrchestration"]

    %% DB2 Backends
    LGAPDB01["LGAPDB01\nDB2 Backend"]
    LGIPDB01["LGIPDB01\nDB2 Backend"]
    LGDPDB01["LGDPDB01\nDB2 Backend"]
    LGUPDB01["LGUPDB01\nDB2 Backend"]

    %% Table
    TBL[("POLICY")]

    %% Menu → Orchestrator
    LGTESTP1 -->|"CICS LINK"| LGAPOL01
    LGTESTP1 -->|"CICS LINK"| LGIPOL01
    LGTESTP1 -->|"CICS LINK"| LGDPOL01
    LGTESTP1 -->|"CICS LINK"| LGUPOL01
    LGTESTP2 -->|"CICS LINK"| LGAPOL01
    LGTESTP2 -->|"CICS LINK"| LGIPOL01
    LGTESTP2 -->|"CICS LINK"| LGDPOL01
    LGTESTP2 -->|"CICS LINK"| LGUPOL01
    LGTESTP3 -->|"CICS LINK"| LGAPOL01
    LGTESTP3 -->|"CICS LINK"| LGIPOL01
    LGTESTP3 -->|"CICS LINK"| LGDPOL01
    LGTESTP3 -->|"CICS LINK"| LGUPOL01
    LGTESTP4 -->|"CICS LINK"| LGAPOL01
    LGTESTP4 -->|"CICS LINK"| LGIPOL01
    LGTESTP4 -->|"CICS LINK"| LGDPOL01
    LGTESTP4 -->|"CICS LINK"| LGUPOL01
    LGTESTC1 -->|"CICS LINK"| LGACUS01

    %% Orchestrator → DB2 Backend
    LGAPOL01 -->|"CICS LINK"| LGAPDB01
    LGIPOL01 -->|"CICS LINK"| LGIPDB01
    LGDPOL01 -->|"CICS LINK"| LGDPDB01
    LGUPOL01 -->|"CICS LINK"| LGUPDB01

    %% DB2 Backend → Table
    LGAPDB01 -->|"C — INSERT\nR — SELECT\nU — UPDATE"| TBL
    LGIPDB01 -->|"R — SELECT / FETCH"| TBL
    LGDPDB01 -->|"D — DELETE"| TBL
    LGUPDB01 -->|"U — UPDATE"| TBL

    %% Orchestrator direct SQL
    LGACUS01 -->|"C/R/D\n(direct SQL)"| TBL

    style TBL      fill:#4a148c,color:#ffffff,stroke:#38006b
    style LGTESTC1 fill:#37474f,color:#ffffff,stroke:#263238
    style LGTESTP1 fill:#37474f,color:#ffffff,stroke:#263238
    style LGTESTP2 fill:#37474f,color:#ffffff,stroke:#263238
    style LGTESTP3 fill:#37474f,color:#ffffff,stroke:#263238
    style LGTESTP4 fill:#37474f,color:#ffffff,stroke:#263238
    style LGAPOL01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGIPOL01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGDPOL01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGUPOL01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGACUS01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGAPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGIPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGDPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGUPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
```

---

### ENDOWMENT

**7 programs impacted** across 3 layers.

```mermaid
flowchart LR
    %% Presentation
    LGTESTP2["LGTESTP2\nMenu — Endowment"]

    %% Orchestration
    LGAPOL01["LGAPOL01\nOrchestration"]
    LGIPOL01["LGIPOL01\nOrchestration"]

    %% DB2 Backends
    LGAPDB01["LGAPDB01\nDB2 Backend"]
    LGIPDB01["LGIPDB01\nDB2 Backend"]

    %% Table
    TBL[("ENDOWMENT")]

    LGTESTP2 -->|"CICS LINK"| LGAPOL01
    LGTESTP2 -->|"CICS LINK"| LGIPOL01
    LGAPOL01 -->|"CICS LINK"| LGAPDB01
    LGIPOL01 -->|"CICS LINK"| LGIPDB01
    LGAPDB01 -->|"C — INSERT"| TBL
    LGIPDB01 -->|"R — SELECT"| TBL

    style TBL      fill:#4a148c,color:#ffffff,stroke:#38006b
    style LGTESTP2 fill:#37474f,color:#ffffff,stroke:#263238
    style LGAPOL01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGIPOL01 fill:#1b5e20,color:#ffffff,stroke:#0d47a1
    style LGAPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGIPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
```

---

### HOUSE

**7 programs impacted** across 3 layers.

```mermaid
flowchart LR
    %% Presentation
    LGTESTP3["LGTESTP3\nMenu — House"]

    %% Orchestration
    LGAPOL01["LGAPOL01\nOrchestration"]
    LGIPOL01["LGIPOL01\nOrchestration"]

    %% DB2 Backends
    LGAPDB01["LGAPDB01\nDB2 Backend"]
    LGIPDB01["LGIPDB01\nDB2 Backend"]

    %% Table
    TBL[("HOUSE")]

    LGTESTP3 -->|"CICS LINK"| LGAPOL01
    LGTESTP3 -->|"CICS LINK"| LGIPOL01
    LGAPOL01 -->|"CICS LINK"| LGAPDB01
    LGIPOL01 -->|"CICS LINK"| LGIPDB01
    LGAPDB01 -->|"C — INSERT"| TBL
    LGIPDB01 -->|"R — SELECT"| TBL

    style TBL      fill:#4a148c,color:#ffffff,stroke:#38006b
    style LGTESTP3 fill:#37474f,color:#ffffff,stroke:#263238
    style LGAPOL01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGIPOL01 fill:#1b5e20,color:#ffffff,stroke:#0d47a1
    style LGAPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGIPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
```

---

### MOTOR

**8 programs impacted** across 3 layers (+ 1 batch program).

```mermaid
flowchart LR
    %% Presentation
    LGTESTP1["LGTESTP1\nMenu — Motor"]

    %% Orchestration
    LGAPOL01["LGAPOL01\nOrchestration"]
    LGIPOL01["LGIPOL01\nOrchestration"]

    %% DB2 Backends
    LGAPDB01["LGAPDB01\nDB2 Backend"]
    LGIPDB01["LGIPDB01\nDB2 Backend"]

    %% Batch
    LGMOTOUT["LGMOTOUT\nBatch"]

    %% Table
    TBL[("MOTOR")]

    LGTESTP1 -->|"CICS LINK"| LGAPOL01
    LGTESTP1 -->|"CICS LINK"| LGIPOL01
    LGAPOL01 -->|"CICS LINK"| LGAPDB01
    LGIPOL01 -->|"CICS LINK"| LGIPDB01
    LGAPDB01 -->|"C — INSERT"| TBL
    LGIPDB01 -->|"R — SELECT"| TBL
    LGMOTOUT -->|"R — cursor FETCH"| TBL

    style TBL      fill:#4a148c,color:#ffffff,stroke:#38006b
    style LGTESTP1 fill:#37474f,color:#ffffff,stroke:#263238
    style LGAPOL01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGIPOL01 fill:#1b5e20,color:#ffffff,stroke:#0d47a1
    style LGAPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGIPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGMOTOUT fill:#b71c1c,color:#ffffff,stroke:#7f0000
```

---

### COMMERCIAL

**8 programs impacted** across 3 layers.

```mermaid
flowchart LR
    %% Presentation
    LGTESTP4["LGTESTP4\nMenu — Commercial"]

    %% Orchestration
    LGAPOL01["LGAPOL01\nOrchestration"]
    LGIPOL01["LGIPOL01\nOrchestration"]

    %% DB2 Backends
    LGAPDB01["LGAPDB01\nDB2 Backend"]
    LGIPDB01["LGIPDB01\nDB2 Backend"]

    %% Table
    TBL[("COMMERCIAL")]

    LGTESTP4 -->|"CICS LINK"| LGAPOL01
    LGTESTP4 -->|"CICS LINK"| LGIPOL01
    LGAPOL01 -->|"CICS LINK"| LGAPDB01
    LGIPOL01 -->|"CICS LINK"| LGIPDB01
    LGAPDB01 -->|"C — INSERT\nR — SELECT"| TBL
    LGIPDB01 -->|"R — SELECT / FETCH"| TBL

    style TBL      fill:#4a148c,color:#ffffff,stroke:#38006b
    style LGTESTP4 fill:#37474f,color:#ffffff,stroke:#263238
    style LGAPOL01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGIPOL01 fill:#1b5e20,color:#ffffff,stroke:#0d47a1
    style LGAPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGIPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
```

---

### CLAIM

**8 programs impacted** across 3 layers.

```mermaid
flowchart LR
    %% Presentation
    LGTESTP1["LGTESTP1\nMenu — Motor"]
    LGTESTP2["LGTESTP2\nMenu — Endowment"]
    LGTESTP3["LGTESTP3\nMenu — House"]
    LGTESTP4["LGTESTP4\nMenu — Commercial"]

    %% Orchestration
    LGAPOL01["LGAPOL01\nOrchestration"]
    LGIPOL01["LGIPOL01\nOrchestration"]

    %% DB2 Backends
    LGAPDB01["LGAPDB01\nDB2 Backend"]
    LGIPDB01["LGIPDB01\nDB2 Backend"]

    %% Table
    TBL[("CLAIM")]

    LGTESTP1 -->|"CICS LINK"| LGAPOL01
    LGTESTP2 -->|"CICS LINK"| LGAPOL01
    LGTESTP3 -->|"CICS LINK"| LGAPOL01
    LGTESTP4 -->|"CICS LINK"| LGAPOL01
    LGTESTP1 -->|"CICS LINK"| LGIPOL01
    LGTESTP2 -->|"CICS LINK"| LGIPOL01
    LGTESTP3 -->|"CICS LINK"| LGIPOL01
    LGTESTP4 -->|"CICS LINK"| LGIPOL01
    LGAPOL01 -->|"CICS LINK"| LGAPDB01
    LGIPOL01 -->|"CICS LINK"| LGIPDB01
    LGAPDB01 -->|"C — INSERT\nR — SELECT"| TBL
    LGIPDB01 -->|"R — SELECT / FETCH"| TBL

    style TBL      fill:#4a148c,color:#ffffff,stroke:#38006b
    style LGTESTP1 fill:#37474f,color:#ffffff,stroke:#263238
    style LGTESTP2 fill:#37474f,color:#ffffff,stroke:#263238
    style LGTESTP3 fill:#37474f,color:#ffffff,stroke:#263238
    style LGTESTP4 fill:#37474f,color:#ffffff,stroke:#263238
    style LGAPOL01 fill:#1b5e20,color:#ffffff,stroke:#145a32
    style LGIPOL01 fill:#1b5e20,color:#ffffff,stroke:#0d47a1
    style LGAPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style LGIPDB01 fill:#1565c0,color:#ffffff,stroke:#0d47a1
```

---

## Operations Detail

### CUSTOMER

| Program | C | R | U | D | Notes |
|---------|:-:|:-:|:-:|:-:|-------|
| `LGACDB01` | ✓ | | | | Inserts new customer row |
| `LGICDB01` | | ✓ | | | Point SELECT by customer number |
| `LGUCDB01` | | | ✓ | | Updates customer details |
| `LGACUS01` | ✓ | | | | Direct INSERT (combined customer+policy orchestrator) |
| `LGBATCH`  | | ✓ | | | Batch customer report — SELECTs each row driven by CUSTIN |
| `LGBATDB2` | | ✓ | | | DB2 test driver — SELECTs customer 1 |

### CUSTOMER_SECURE

| Program | C | R | U | D | Notes |
|---------|:-:|:-:|:-:|:-:|-------|
| `LGACDB02` | ✓ | | | | Inserts password hash and state indicator for new customer |

### POLICY

| Program | C | R | U | D | Notes |
|---------|:-:|:-:|:-:|:-:|-------|
| `LGAPDB01` | ✓ | ✓ | ✓ | | INSERT on add; SELECT to verify; UPDATE on claim processing |
| `LGIPDB01` | | ✓ | | | Point SELECT + cursor FETCH for policy list |
| `LGDPDB01` | | | | ✓ | DELETE — cascades to all child policy-type tables |
| `LGUPDB01` | | | ✓ | | Updates policy header fields |
| `LGACUS01` | ✓ | ✓ | | ✓ | INSERTs linked policy, SELECTs it back, DELETEs on rollback path |

### ENDOWMENT

| Program | C | R | U | D | Notes |
|---------|:-:|:-:|:-:|:-:|-------|
| `LGAPDB01` | ✓ | | | | Inserts endowment-specific details after POLICY row |
| `LGIPDB01` | | ✓ | | | Point SELECT for endowment fields |

### HOUSE

| Program | C | R | U | D | Notes |
|---------|:-:|:-:|:-:|:-:|-------|
| `LGAPDB01` | ✓ | | | | Inserts house-specific details after POLICY row |
| `LGIPDB01` | | ✓ | | | Point SELECT for house fields |

### MOTOR

| Program | C | R | U | D | Notes |
|---------|:-:|:-:|:-:|:-:|-------|
| `LGAPDB01` | ✓ | | | | Inserts motor-specific details after POLICY row |
| `LGIPDB01` | | ✓ | | | Point SELECT for motor fields |
| `LGMOTOUT` | | ✓ | | | Batch export — cursor over all MOTOR rows → MOTOROUT file |

### COMMERCIAL

| Program | C | R | U | D | Notes |
|---------|:-:|:-:|:-:|:-:|-------|
| `LGAPDB01` | ✓ | ✓ | | | INSERT; SELECT back to verify / retrieve generated key |
| `LGIPDB01` | | ✓ | | | Point SELECT + cursor FETCH |

### CLAIM

| Program | C | R | U | D | Notes |
|---------|:-:|:-:|:-:|:-:|-------|
| `LGAPDB01` | ✓ | ✓ | | | INSERT; SELECT back to verify / retrieve generated claim number |
| `LGIPDB01` | | ✓ | | | Point SELECT + cursor FETCH |

---

## Observations

- **`LGAPDB01`** is the most data-intensive program — it writes to all six child tables (POLICY, ENDOWMENT, HOUSE, MOTOR, COMMERCIAL, CLAIM) and is the sole **Create** path for policy data.
- **`LGIPDB01`** is the sole **Read** path for all policy-type detail tables. It uses cursors for CLAIM and COMMERCIAL to handle multiple rows per policy.
- **No program performs UPDATE or DELETE on policy-type detail tables** (ENDOWMENT, HOUSE, MOTOR, COMMERCIAL, CLAIM). Deletion is handled entirely by the `ON DELETE CASCADE` foreign key constraint when a POLICY row is deleted via `LGDPDB01`.
- **`CUSTOMER_SECURE`** is written only once (`LGACDB02`) and never read back by any scanned program — it exists purely for authentication purposes outside the GenApp core transaction flow.
- **Batch programs** (`LGBATCH`, `LGBATDB2`, `LGMOTOUT`) are **read-only** against Db2 — no inserts, updates, or deletes.
- **`LGACUS01`** (orchestration layer) contains its own embedded SQL against CUSTOMER and POLICY, bypassing the dedicated DB2 backend programs for the combined add-customer-and-policy use case.
