# Customer Domain Architecture Analysis

## Executive Summary

The **Customer Management Domain** in the GenApp (PL/I) application manages the full lifecycle of customer demographic and security records. This includes creating new customer profiles, retrieving customer details, and updating existing customer information. The domain coordinates across a relational store (DB2), an indexed file mirror (VSAM KSDS), and CICS infrastructure services (Named Counters).

This document details the DB2 tables, programs, CICS transactions, cross-domain functionalities, and boundary interfaces that define the Customer Domain.

---

## 1. Domain Component Architecture

The domain implements a strict **three-tier architecture** (Presentation &rarr; Orchestration &rarr; Backend Data Access):

```mermaid
graph TD
    subgraph Presentation_Domain["Presentation Domain (BMS)"]
        SSC1["CICS Transaction: SSC1\nProgram: LGTESTC1"]
    end

    subgraph Customer_Domain["Customer Management Domain"]
        direction TB
        subgraph Orchestration_Layer["Orchestration Layer (Gating & Validation)"]
            LGACUS01["LGACUS01\n(Add Customer)"]
            LGICUS01["LGICUS01\n(Inquire Customer)"]
            LGUCUS01["LGUCUS01\n(Update Customer)"]
        end

        subgraph DB2_Backend_Layer["DB2 Backend Layer (SQL & Transaction Coordination)"]
            LGACDB01["LGACDB01\n(Add Customer DB2)"]
            LGICDB01["LGICDB01\n(Inquire Customer DB2)"]
            LGUCDB01["LGUCDB01\n(Update Customer DB2)"]
            LGACDB02["LGACDB02\n(Add Customer Security)"]
        end

        subgraph VSAM_Layer["VSAM Mirror & Discovery Layer"]
            LGACVS01["LGACVS01\n(VSAM Insert)"]
            LGICVS01["LGICVS01\n(VSAM Key Discovery / Tx: LGCF)"]
            LGUCVS01["LGUCVS01\n(VSAM Read/Rewrite)"]
        end
    end

    subgraph Customer_Data_Stores["Customer Data Stores"]
        DB2_CUST[("DB2: GENASA1.CUSTOMER\n(PK: customerNumber)")]
        DB2_SEC[("DB2: GENASA1.CUSTOMER_SECURE\n(PK/FK: customerNumber)")]
        VSAM_CUST[("VSAM KSDS: KSDSCUST\n(Key: customerNumber)")]
        NC_CUST[("CICS Named Counter: GENACUSTNUM\n(Pool: GENA)")]
    end

    subgraph Cross_Domain_Consumers["Cross-Domain Integrations & Consumers"]
        DB2_POL[("DB2: GENASA1.POLICY\n(FK: customerNumber -> CUSTOMER)")]
        LGBATCH["LGBATCH / LGBATDB2\n(Batch Reporting Domain)"]
        LGSTSQ["LGSTSQ\n(Operations Error Logger)"]
    end

    SSC1 -->|CICS LINK (01ACUS)| LGACUS01
    SSC1 -->|CICS LINK (01ICUS)| LGICUS01
    SSC1 -->|CICS LINK (01UCUS)| LGUCUS01

    LGACUS01 -->|CICS LINK| LGACDB01
    LGICUS01 -->|CICS LINK| LGICDB01
    LGUCUS01 -->|CICS LINK| LGUCDB01

    LGACDB01 -->|CICS LINK| LGACVS01
    LGACDB01 -->|CICS LINK| LGACDB02
    LGUCDB01 -->|CICS LINK| LGUCVS01

    LGACDB01 -->|GET COUNTER| NC_CUST
    LGACDB01 -->|INSERT| DB2_CUST
    LGICDB01 -->|SELECT| DB2_CUST
    LGUCDB01 -->|UPDATE| DB2_CUST
    LGACDB02 -->|INSERT| DB2_SEC

    LGACVS01 -->|WRITE| VSAM_CUST
    LGUCVS01 -->|READ / REWRITE| VSAM_CUST
    LGICVS01 -->|GTEQ BROWSE| VSAM_CUST

    DB2_POL -.->|FK ON DELETE CASCADE| DB2_CUST
    LGBATCH -->|SELECT customerNumber| DB2_CUST
    Customer_Domain -->|CICS LINK on Error| LGSTSQ
```

---

## 2. Customer Domain DB2 Tables & Data Stores

| Data Store / Table | Type | Identifier / Location | Description & Structure |
|---|---|---|---|
| **`GENASA1.CUSTOMER`** | DB2 Relational Table | Tablespace `GENATS01` ([`jcl/GenAppDDL.jcl:131`](../../jcl/GenAppDDL.jcl:131)) | Primary customer master entity.<br/>• **Columns**: `customerNumber` (INTEGER, PK, IDENTITY), `firstName` (CHAR 10), `lastName` (CHAR 20), `dateOfBirth` (DATE), `houseName` (CHAR 20), `houseNumber` (CHAR 4), `postcode` (CHAR 8), `phonehome` (CHAR 20), `phonemobile` (CHAR 20), `emailaddress` (CHAR 100). |
| **`GENASA1.CUSTOMER_SECURE`** | DB2 Relational Table | Tablespace `GENATS0A` ([`jcl/GenAppDDL.jcl:151`](../../jcl/GenAppDDL.jcl:151)) | Customer security and credentials store.<br/>• **Columns**: `customerNumber` (INTEGER, PK), `customerPass` (CHAR 32 - MD5 Hash), `state_indicator` (CHAR 1), `pass_changes` (INTEGER).<br/>• **FK Constraint**: `customerNumber` references `GENASA1.CUSTOMER(customerNumber) ON DELETE CASCADE`. |
| **`KSDSCUST`** | VSAM KSDS Dataset | `IBMUSER.GENAPP.KSDSCUST` ([`jcl/CreateCSDDefs.jcl:168`](../../jcl/CreateCSDDefs.jcl:168)) | Keyed VSAM mirror store.<br/>• Record length: 82 bytes, Key length: 10 bytes (indexed by customer number). |
| **`GENACUSTNUM`** | CICS Named Counter | Pool `GENA` | CICS Named Counter used by [`LGACDB01.pli:127`](../../pli/LGACDB01.pli:127) for atomic customer sequence allocation. |

---

## 3. Customer Domain Programs & CICS Transactions

### 3.1 CICS Transactions

*   **`SSC1`** ([`jcl/CreateCSDDefs.jcl:46`](../../jcl/CreateCSDDefs.jcl:46)): Terminal transaction executing the Customer Menu program ([`LGTESTC1.pli`](../../pli/LGTESTC1.pli:8)).
*   **`LGCF`** ([`jcl/CreateCSDDefs.jcl:58`](../../jcl/CreateCSDDefs.jcl:58)): Standalone transaction invoking the VSAM Customer Discovery utility ([`LGICVS01.pli`](../../pli/LGICVS01.pli:22)).

### 3.2 Program Catalog

| Program | Architecture Layer | Request ID | Downstream Calls | Responsibilities |
|---|---|:---:|---|---|
| [`LGTESTC1.pli`](../../pli/LGTESTC1.pli:8) | Presentation (BMS Menu) | `01ACUS`<br/>`01ICUS`<br/>`01UCUS` | [`LGACUS01`](../../pli/LGACUS01.pli:29), [`LGICUS01`](../../pli/LGICUS01.pli:22), [`LGUCUS01`](../../pli/LGUCUS01.pli:20) | Handles BMS map `SSMAP` screens for adding, looking up, and editing customer records. |
| [`LGACUS01.pli`](../../pli/LGACUS01.pli:29) | Orchestrator (Add) | `01ACUS` | [`LGACDB01`](../../pli/LGACDB01.pli:21) | Validates COMMAREA length (min 90 bytes) and passes payload to DB2 backend. |
| [`LGICUS01.pli`](../../pli/LGICUS01.pli:22) | Orchestrator (Inquire) | `01ICUS` | [`LGICDB01`](../../pli/LGICDB01.pli:20) | Validates input customer number and routes to DB2 backend. |
| [`LGUCUS01.pli`](../../pli/LGUCUS01.pli:20) | Orchestrator (Update) | `01UCUS` | [`LGUCDB01`](../../pli/LGUCDB01.pli:18) | Gating check on `CA_REQUEST_ID='01UCUS'` and dispatches update to DB2 backend. |
| [`LGACDB01.pli`](../../pli/LGACDB01.pli:21) | DB2 Backend (Add) | `01ACUS` | [`LGACVS01`](../../pli/LGACVS01.pli:20), [`LGACDB02`](../../pli/LGACDB02.pli:21) | Obtains counter `GENACUSTNUM`, executes `INSERT INTO CUSTOMER`, then links to VSAM and Security backends. |
| [`LGICDB01.pli`](../../pli/LGICDB01.pli:20) | DB2 Backend (Inquire) | `01ICUS` | — | Executes `SELECT ... FROM CUSTOMER WHERE CUSTOMERNUMBER = :hv_custnum` and returns row. |
| [`LGUCDB01.pli`](../../pli/LGUCDB01.pli:18) | DB2 Backend (Update) | `01UCUS` | [`LGUCVS01`](../../pli/LGUCVS01.pli:20) | Executes `UPDATE CUSTOMER SET ... WHERE CUSTOMERNUMBER = :hv_custnum`, then links to VSAM mirror. |
| [`LGACDB02.pli`](../../pli/LGACDB02.pli:21) | DB2 Backend (Security Add) | `02ACUS` | — | Inserts default security credentials into `CUSTOMER_SECURE` (`INSERT INTO CUSTOMER_SECURE`). |
| [`LGACVS01.pli`](../../pli/LGACVS01.pli:20) | VSAM Backend (Add) | `01ACUS` | — | Writes customer record into VSAM dataset `KSDSCUST`. |
| [`LGICVS01.pli`](../../pli/LGICVS01.pli:22) | VSAM Key Discovery | `LGCF` / Menu | — | Reads `GENACNTL` TS queue and executes `STARTBR`/`READNEXT` on `KSDSCUST` to discover valid customer numbers. |
| [`LGUCVS01.pli`](../../pli/LGUCVS01.pli:20) | VSAM Backend (Update) | `01UCUS` | — | Executes `READ UPDATE` and `REWRITE` against `KSDSCUST`. |

---

## 4. Cross-Domain Functionalities

The Customer Domain interacts with several external application domains:

1. **Relational Referential Integrity with Policy Management**:
   * **Foreign Key Cascade**: The table `GENASA1.POLICY` contains a foreign key referencing `GENASA1.CUSTOMER(customerNumber)` with `ON DELETE CASCADE` ([`jcl/GenAppDDL.jcl:195`](../../jcl/GenAppDDL.jcl:195)).
   * **Cascaded Deletion Impact**: Deleting a record from `CUSTOMER` automatically cascades to delete all associated policies in `POLICY`, which further cascades down to delete product-specific policy records (`MOTOR`, `ENDOWMENT`, `HOUSE`, `COMMERCIAL`, `CLAIM`).
2. **Batch Reporting Direct Read**:
   * Batch programs [`LGBATCH.pli:19`](../../pli/LGBATCH.pli:19) and [`LGBATDB2.pli:19`](../../pli/LGBATDB2.pli:19) run outside CICS and execute direct SQL `SELECT` queries against `GENASA1.CUSTOMER` to produce customer activity reports via subroutine [`LGBATCHF.pli:18`](../../pli/LGBATCHF.pli:18).
3. **Shared COMMAREA Contract (`LGCMAREA.inc`)**:
   * All customer programs share the universal 32,500-byte structure defined in [`plinc/LGCMAREA.inc:10`](../../plinc/LGCMAREA.inc:10). The customer operations overlay the `CA_CUSTOMER_REQUEST` ([`plinc/LGCMAREA.inc:20`](../../plinc/LGCMAREA.inc:20)) and `CA_CUSTSECR_REQUEST` ([`plinc/LGCMAREA.inc:33`](../../plinc/LGCMAREA.inc:33)) fields.
4. **Shared Operations & Infrastructure Services**:
   * **Error Logging**: All customer programs link to [`LGSTSQ.pli:18`](../../pli/LGSTSQ.pli:18) on SQL errors or abnormal conditions to write messages to TDQ `CSMT` and TS queue `GENAERRS`.
   * **Monitoring & Statistics**: Named counters (`GENA01ACUS00/99`, `GENA01ICUS00/99`, `GENA01UCUS00/99`) initialized by [`LGSETUP.pli:41`](../../pli/LGSETUP.pli:41) are tracked across runtime execution by [`LGASTAT1.pli:20`](../../pli/LGASTAT1.pli:20) and [`LGWEBST5.pli:61`](../../pli/LGWEBST5.pli:61).

---

## 5. Domain Boundaries & Interfaces

| Boundary Point | Interfacing Domain | Mechanism | Data Contract / Payload | Isolation & Coupling Level |
|---|---|---|---|---|
| **Presentation &rarr; Customer** | Presentation &harr; Customer | `EXEC CICS LINK` | COMMAREA (`LGCMAREA.inc`) with Request IDs `01ACUS`, `01ICUS`, `01UCUS` | **High memory coupling** (strict byte-offset alignment across 32.5 KB buffer). |
| **Customer &rarr; Policy** | Customer &harr; Policy | DB2 Relational Engine | Relational FK (`POLICY.customerNumber` &rarr; `CUSTOMER.customerNumber`) | **Zero runtime code coupling**; **Strict relational database coupling**. |
| **Customer &rarr; Batch** | Customer &harr; Batch Reporting | DB2 SQL Engine | `SELECT ... FROM CUSTOMER` | **Read-only data coupling** (batch reads directly from customer table). |
| **Customer &rarr; Operations** | Customer &harr; Operations | `EXEC CICS LINK` / CICS API | `LGSTSQ` error record / `GENACUSTNUM` counter | **Service dependency** on shared error logger and named counter pool. |
