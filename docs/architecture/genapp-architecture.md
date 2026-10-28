# GenApp (PL/I) — Architecture Diagram

> **Application**: IBM General Insurance Application (GenApp), PL/I variant  
> **Platform**: z/OS — CICS online transactions + DB2 + VSAM + Batch  
> **Build system**: IBM zAppBuild (DBB/Groovy)

---

## Application Architecture Overview

```mermaid
flowchart TB
    %% ─────────────────────────────────────────────
    %% LAYER 0: External channels & services
    %% ─────────────────────────────────────────────
    subgraph EXT["External Channels & Services"]
        direction LR
        TERM["🖥️  3270 Terminal"]
        BFILES["📄  Batch Files\n(CUSTIN / MOTOROUT)"]
        ODM["⚙️  IBM ODM\nBusiness Rules Engine"]
    end

    %% ─────────────────────────────────────────────
    %% LAYER 1: Presentation
    %% ─────────────────────────────────────────────
    subgraph PRES["Layer 1 — Presentation  (BMS Maps + Menu Programs)"]
        direction LR
        MENUS["Customer Menu  SSC1\nMotor Menu  SSP1\nEndowment Menu  SSP2\nHouse Menu  SSP3\nCommercial Menu  SSP4"]
    end

    %% ─────────────────────────────────────────────
    %% LAYER 2: Business Orchestration
    %% ─────────────────────────────────────────────
    subgraph ORCH["Layer 2 — Business Orchestration"]
        direction LR
        CUS_ORCH["Customer\nLGACUS01 · LGICUS01 · LGUCUS01"]
        POL_ORCH["Policy\nLGAPOL01 · LGIPOL01\nLGDPOL01 · LGUPOL01"]
    end

    %% ─────────────────────────────────────────────
    %% LAYER 3: Data Access
    %% ─────────────────────────────────────────────
    subgraph ACCESS["Layer 3 — Data Access"]
        direction LR
        subgraph DB2BE["DB2 Backends"]
            DB2_CUS["Customer\nLGACDB01 · LGACDB02\nLGICDB01 · LGUCDB01"]
            DB2_POL["Policy\nLGAPDB01 · LGIPDB01\nLGDPDB01 · LGUPDB01"]
        end
        subgraph VSAMBE["VSAM Backends"]
            VS_CUS["Customer\nLGACVS01 · LGICVS01 · LGUCVS01"]
            VS_POL["Policy\nLGAPVS01 · LGIPVS01\nLGDPVS01 · LGUPVS01"]
        end
    end

    %% ─────────────────────────────────────────────
    %% LAYER 4: Data Storage
    %% ─────────────────────────────────────────────
    subgraph DATA["Layer 4 — Data Storage"]
        direction LR
        subgraph DB2["Db2  GENASA1"]
            direction TB
            TCUST["CUSTOMER"]
            TCSEC["CUSTOMER_SECURE"]
            TPOL["POLICY"]
            TPOL_DET["ENDOWMENT · HOUSE\nMOTOR · COMMERCIAL · CLAIM"]
        end
        subgraph VSAM["VSAM  (CICS)"]
            KSDSCUST["KSDSCUST"]
            KSDSPOLY["KSDSPOLY"]
        end
        subgraph TSQS["CICS Temp Storage"]
            TSQDATA["GENACNTL  control queue\nGENA* named counters"]
        end
    end

    %% ─────────────────────────────────────────────
    %% LAYER 5: Batch
    %% ─────────────────────────────────────────────
    subgraph BATCH["Layer 5 — Batch (non-CICS)"]
        direction LR
        BGMS["LGBATCH · LGBATDB2\nLGBATCHF · LGMOTOUT"]
    end

    %% ─────────────────────────────────────────────
    %% LAYER 6: Infrastructure / Utilities
    %% ─────────────────────────────────────────────
    subgraph INFRA["Layer 6 — Infrastructure & Utilities"]
        direction LR
        UTILS["LGSETUP  env setup\nLGSTSQ  error writer\nLGASTAT1  stats adapter\nLGWEBST5  stats collector"]
    end

    %% ─────────────────────────────────────────────
    %% FLOW
    %% ─────────────────────────────────────────────
    TERM    -->|"3270 / BMS"| PRES
    PRES    -->|"EXEC CICS LINK\n(COMMAREA)"| ORCH
    ORCH    -.->|"EXEC CICS LINK\n(Endowment only, optional)"| ODM
    ORCH    -->|"EXEC CICS LINK"| ACCESS
    ACCESS  -->|"EXEC SQL"| DB2
    ACCESS  -->|"EXEC CICS file ctrl"| VSAM
    ORCH    -->|"EXEC CICS LINK\n(error logging)"| UTILS
    UTILS   <-->|"TS queue / named counters"| TSQS
    BFILES  -->|"sequential read"| BATCH
    BATCH   -->|"EXEC SQL"| DB2
    BATCH   -->|"sequential write"| BFILES

    %% ─────────────────────────────────────────────
    %% COLOR CODING per layer
    %% ─────────────────────────────────────────────
    %% Layer 0 — External  #2d2d2d bg, white text
    style EXT   fill:#2d2d2d,color:#ffffff,stroke:#111111
    style TERM  fill:#3a3a3a,color:#ffffff,stroke:#555555
    style BFILES fill:#3a3a3a,color:#ffffff,stroke:#555555
    style ODM   fill:#3a3a3a,color:#ffffff,stroke:#555555

    %% Layer 1 — Presentation  steel-blue
    style PRES  fill:#1565c0,color:#ffffff,stroke:#0d47a1
    style MENUS fill:#1e88e5,color:#ffffff,stroke:#1565c0

    %% Layer 2 — Business Orchestration  teal-green
    style ORCH     fill:#1b5e20,color:#ffffff,stroke:#145a32
    style CUS_ORCH fill:#2e7d32,color:#ffffff,stroke:#1b5e20
    style POL_ORCH fill:#2e7d32,color:#ffffff,stroke:#1b5e20

    %% Layer 3 — Data Access  amber/gold
    style ACCESS  fill:#e65100,color:#ffffff,stroke:#bf360c
    style DB2BE   fill:#ef6c00,color:#ffffff,stroke:#e65100
    style DB2_CUS fill:#f57c00,color:#ffffff,stroke:#ef6c00
    style DB2_POL fill:#f57c00,color:#ffffff,stroke:#ef6c00
    style VSAMBE  fill:#ef6c00,color:#ffffff,stroke:#e65100
    style VS_CUS  fill:#f57c00,color:#ffffff,stroke:#ef6c00
    style VS_POL  fill:#f57c00,color:#ffffff,stroke:#ef6c00

    %% Layer 4 — Data Storage  deep-purple
    style DATA     fill:#4a148c,color:#ffffff,stroke:#38006b
    style DB2      fill:#6a1b9a,color:#ffffff,stroke:#4a148c
    style TCUST    fill:#7b1fa2,color:#ffffff,stroke:#6a1b9a
    style TCSEC    fill:#7b1fa2,color:#ffffff,stroke:#6a1b9a
    style TPOL     fill:#7b1fa2,color:#ffffff,stroke:#6a1b9a
    style TPOL_DET fill:#7b1fa2,color:#ffffff,stroke:#6a1b9a
    style VSAM     fill:#6a1b9a,color:#ffffff,stroke:#4a148c
    style KSDSCUST fill:#7b1fa2,color:#ffffff,stroke:#6a1b9a
    style KSDSPOLY fill:#7b1fa2,color:#ffffff,stroke:#6a1b9a
    style TSQS     fill:#6a1b9a,color:#ffffff,stroke:#4a148c
    style TSQDATA  fill:#7b1fa2,color:#ffffff,stroke:#6a1b9a

    %% Layer 5 — Batch  crimson-red
    style BATCH fill:#b71c1c,color:#ffffff,stroke:#7f0000
    style BGMS  fill:#c62828,color:#ffffff,stroke:#b71c1c

    %% Layer 6 — Infrastructure  slate-grey
    style INFRA fill:#37474f,color:#ffffff,stroke:#263238
    style UTILS fill:#455a64,color:#ffffff,stroke:#37474f
```

---

## Functional Layers Summary

| Layer | Programs | Description |
|-------|----------|-------------|
| **Presentation** | `LGTESTC1`, `LGTESTP1`–`4` | 3270 BMS menu programs; one per domain (customer + 4 policy types). Entry via CICS transactions `SSC1`, `SSP1`–`SSP4`. |
| **Business Orchestration** | `LGACUS01`, `LGICUS01`, `LGUCUS01`, `LGAPOL01`, `LGIPOL01`, `LGDPOL01`, `LGUPOL01` | CICS-linked orchestrators. Accept COMMAREA, validate length, route to DB2 and/or VSAM backends. |
| **DB2 Backend** | `LGAC/IC/UC/AP/IP/DP/UPxx DB01/DB02` | Single-purpose DB2 programs. Execute embedded SQL (INSERT / SELECT / UPDATE / DELETE) against `GENASA1` tables. |
| **VSAM Backend** | `LGAC/IC/UC/AP/IP/DP/UPxx VS01` | Mirror of DB2 layer using CICS file control (`WRITE`, `READ`, `REWRITE`, `DELETE`) against KSDS files. |
| **Infrastructure** | `LGSETUP`, `LGSTSQ`, `LGASTAT1`, `LGWEBST5` | Environment initialisation, error TS-queue writer, statistics named-counter adapter, statistics collector. |
| **Batch** | `LGBATCH`, `LGBATDB2`, `LGBATCHF`, `LGMOTOUT` | Non-CICS; read sequential files or drive DB2 cursors; use static `CALL` for subprograms. |

---

## CICS Transaction Definitions

| Transaction ID | Program | Description |
|----------------|---------|-------------|
| `SSC1` | `LGTESTC1` | Customer menu |
| `SSP1` | `LGTESTP1` | Motor policy menu |
| `SSP2` | `LGTESTP2` | Endowment policy menu |
| `SSP3` | `LGTESTP3` | House policy menu |
| `SSP4` | `LGTESTP4` | Commercial policy menu |
| `LGSE` | `LGSETUP`  | Environment setup |
| `LGCF` | `LGICVS01` | Direct VSAM customer inquire |
| `LGPF` | `LGIPVS01` | Direct VSAM policy inquire |

---

## BMS Map — `SSMAP`

| Map name | Used by | Purpose |
|----------|---------|---------|
| `SSMAPP1` | `LGTESTP1` | Motor policy fields |
| `SSMAPP2` | `LGTESTP2` | Endowment policy fields |
| `SSMAPP3` | `LGTESTP3` | House policy fields |
| `SSMAPP4` | `LGTESTP4` | Commercial policy fields |
| `SSMAPC1` | `LGTESTC1` | Customer fields |

All maps are defined in the single BMS mapset `SSMAP` (compiled as program `SSMAP` in CSD group `GENASAP`). The PL/I include [`plinc/SSMAP.inc`](../../plinc/SSMAP.inc) provides the corresponding data-structure declarations.

---

## Db2 Schema — `GENASA1`

| Table | Tablespace | Key | Relates to |
|-------|-----------|-----|-----------|
| `CUSTOMER` | `GENATS01` | `customerNumber` (identity) | — |
| `CUSTOMER_SECURE` | `GENATS0A` | `customerNumber` | → CUSTOMER (cascade delete) |
| `POLICY` | `GENATS02` | `policyNumber` (identity) | → CUSTOMER (cascade delete) |
| `ENDOWMENT` | `GENATS03` | `policyNumber` | → POLICY (cascade delete) |
| `HOUSE` | `GENATS04` | `policyNumber` | → POLICY (cascade delete) |
| `MOTOR` | `GENATS05` | `policyNumber` | → POLICY (cascade delete) |
| `COMMERCIAL` | `GENATS06` | `policyNumber` | → POLICY (cascade delete) |
| `CLAIM` | `GENATS07` | `claimNumber` (identity) | → POLICY (cascade delete) |

Policy type is encoded in `POLICY.policyType` (M=Motor, E=Endowment, H=House, C=Commercial).

---

## PL/I Include Files

| Include | Used by | Purpose |
|---------|---------|---------|
| [`LGCMAREA.inc`](../../plinc/LGCMAREA.inc) | All CICS programs | 32 500-byte COMMAREA with `CA_REQUEST_ID`, `CA_RETURN_CODE`, `CA_CUSTOMER_NUM`, and UNION branches for each policy type |
| [`LGCMARER.inc`](../../plinc/LGCMARER.inc) | `LGAPOL01` → `LGAPBR01` | Compact 152-byte request/response area for IBM ODM business rules |
| [`SSMAP.inc`](../../plinc/SSMAP.inc) | Menu programs | BMS map I/O structures (`SSMAPP1I/O`, `SSMAPC1I/O`, etc.) |
| [`DCLPOLIC.inc`](../../plinc/DCLPOLIC.inc) | Policy backends | Policy field declarations |
| [`DCLENDOW.inc`](../../plinc/DCLENDOW.inc) | Endowment backend | Endowment-specific declarations |
| [`LGPOLICY.inc`](../../plinc/LGPOLICY.inc) | Policy programs | Policy data structure |

---

## External Services & Infrastructure

| Service | Type | Connected via | Used by |
|---------|------|--------------|---------|
| **IBM ODM** (LGAPBR01) | External business rules engine | `EXEC CICS LINK` | `LGAPOL01` (optional, Endowment only) |
| **Db2 (DBD1)** | RDBMS | Embedded `EXEC SQL` + CICS DB2CONN `JKEDB2`/`DBD1` | All DB2 backend + batch programs |
| **VSAM KSDS** | File system | `EXEC CICS` file control | All VSAM backend programs |
| **CICS TS Queues** | Temp storage | `EXEC CICS WRITEQ TS` / `READQ TS` | `LGSTSQ`, `LGWEBST5`, `LGSETUP`, `LGTESTC1` |
| **CICS Named Counters** | Atomic counter pool `GENA` | `EXEC CICS INCREMENT COUNTER` | `LGASTAT1`, `LGWEBST5`, `LGACUS01`, `LGSETUP` |

---

## COMMAREA Request ID Convention

```
CA_REQUEST_ID = XX + VERB + ENTITY (total 6 chars)

XX   = '01' (standard operation)
VERB = A(dd) | I(nquire) | D(elete) | U(pdate)
ENTITY = CUS(tomer) | MOT(or) | END(owment) | HOU(se) | COM(mercial)

Examples:
  '01ACUS' — Add Customer
  '01IMOT' — Inquire Motor
  '01DEND' — Delete Endowment
  '01UHOU' — Update House
```

Return code `'00'` = success, `'98'` = bad COMMAREA length, `'99'` = DB2/system error.
