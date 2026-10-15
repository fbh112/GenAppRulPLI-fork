# GenApp PL/I — Application Inventory

## Overview

GenApp is a General Insurance application implemented in PL/I on z/OS CICS. It manages customers, insurance policies (endowment, house, motor, commercial), and claims. All CICS programs communicate via a shared COMMAREA defined in [`LGCMAREA.inc`](../../plinc/LGCMAREA.inc).

---

## DB2 Tables

| Table | Tablespace | Description |
|-------|------------|-------------|
| `CUSTOMER` | GENATS01 | Customer master: name, address, DOB, contact |
| `CUSTOMER_SECURE` | GENATS01 | Customer security: password hash, state, change counter |
| `POLICY` | GENATS02 | Policy header: type, dates, broker, payment |
| `ENDOWMENT` | GENATS03 | Endowment policy detail |
| `HOUSE` | GENATS04 | House insurance policy detail |
| `MOTOR` | GENATS05 | Motor insurance policy detail |
| `COMMERCIAL` | GENATS06 | Commercial property insurance detail |
| `CLAIM` | GENATS07 | Insurance claim records |

---

## VSAM Files

| Logical Name | Physical DSN | CICS File Type | Operations |
|---|---|---|---|
| `KSDSCUST` | ADAPPL.GENAPP.KSDSCUST | KSDS | READ, ADD, BROWSE, UPDATE |
| `KSDSPOLY` | ADAPPL.GENAPP.KSDSPOLY | KSDS | READ, ADD, BROWSE, UPDATE |
| `CUSTIN` | — | Sequential (batch input) | READ |
| `CUSTRPT` | — | Sequential (batch output) | WRITE |
| `MOTOROUT` | — | Sequential (batch output) | WRITE |

---

## CICS Transactions

| Transaction | Program | Description |
|---|---|---|
| `SSC1` | LGTESTC1 | Customer operations menu |
| `SSP1` | LGTESTP1 | Policy operations (Endowment) |
| `SSP2` | LGTESTP2 | Policy operations (House) |
| `SSP3` | LGTESTP3 | Policy operations (Motor) |
| `SSP4` | LGTESTP4 | Policy operations (Commercial) |
| `SSST` | LGWEBST5 | Statistics/monitoring |

---

## BMS Maps (SSMAP.inc)

| Map | Used By |
|---|---|
| `SSMAPC1` | LGTESTC1 — Customer screen |
| `SSMAPP1` | LGTESTP1 — Endowment policy screen |
| `SSMAPP2` | LGTESTP2 — House policy screen |
| `SSMAPP3` | LGTESTP3 — Motor policy screen |
| `SSMAPP4` | LGTESTP4 — Commercial policy screen |
| `SSMAPP5` | LGWEBST5 — Statistics screen |

---

## Include Files (Copybooks)

| File | Description | Used By |
|---|---|---|
| [`LGCMAREA.inc`](../../plinc/LGCMAREA.inc) | COMMAREA — shared parameter structure for all CICS programs | All programs |
| [`LGCMARER.inc`](../../plinc/LGCMARER.inc) | COMMAREA return variant | Selected programs |
| [`LGPOLICY.inc`](../../plinc/LGPOLICY.inc) | Policy data structure | Policy programs |
| [`SSMAP.inc`](../../plinc/SSMAP.inc) | BMS map copybook — all screen layouts | Menu/test programs |

---

## Program Inventory

### Customer Domain — Online CICS

| Program | Type | Role | DB2 Tables | VSAM | Calls | Called By |
|---|---|---|---|---|---|---|
| [`LGACUS01`](../../pli/LGACUS01.pli) | CICS Business Logic | Add Customer — orchestrates the add-customer flow | CUSTOMER, POLICY | — | LGACVS01, LGACDB02 | LGTESTC1 |
| [`LGACDB01`](../../pli/LGACDB01.pli) | CICS DB2 | Add Customer to DB2 CUSTOMER table | CUSTOMER | — | LGACVS01, LGACDB02 | LGACUS01 (alt entry) |
| [`LGACDB02`](../../pli/LGACDB02.pli) | CICS DB2 | Add Customer security row to CUSTOMER_SECURE | CUSTOMER_SECURE | — | — | LGACUS01, LGACDB01 |
| [`LGACVS01`](../../pli/LGACVS01.pli) | CICS VSAM | Add Customer record to KSDSCUST VSAM | — | KSDSCUST (WRITE) | LGSTSQ | LGACUS01, LGACDB01 |
| [`LGICUS01`](../../pli/LGICUS01.pli) | CICS Business Logic | Inquire Customer — orchestrates inquiry flow | — | — | LGICDB01, AAAAAAAA, LGSTSQ | LGTESTC1 |
| [`LGICDB01`](../../pli/LGICDB01.pli) | CICS DB2 | Inquire Customer from DB2 CUSTOMER table | CUSTOMER | — | LGSTSQ | LGICUS01 |
| [`LGICVS01`](../../pli/LGICVS01.pli) | CICS VSAM | Inquire Customer from KSDSCUST VSAM | — | KSDSCUST (READ) | LGSTSQ | (direct) |
| [`LGUCUS01`](../../pli/LGUCUS01.pli) | CICS Business Logic | Update Customer — orchestrates update flow | — | — | LGUCDB01, LGSTSQ | LGTESTC1 |
| [`LGUCDB01`](../../pli/LGUCDB01.pli) | CICS DB2 | Update Customer in DB2 CUSTOMER table | CUSTOMER | — | LGUCVS01, LGSTSQ | LGUCUS01 |
| [`LGUCVS01`](../../pli/LGUCVS01.pli) | CICS VSAM | Update Customer record in KSDSCUST VSAM | — | KSDSCUST (UPDATE) | LGSTSQ | LGUCDB01 |

### Policy Domain — Online CICS

| Program | Type | Role | DB2 Tables | VSAM | Calls | Called By |
|---|---|---|---|---|---|---|
| [`LGAPOL01`](../../pli/LGAPOL01.pli) | CICS Business Logic | Add Policy — routes to DB2 or VSAM | — | — | LGAPDB01 (via LINK), LGSTSQ | LGTESTP1-4 |
| [`LGAPDB01`](../../pli/LGAPDB01.pli) | CICS DB2 | Add Policy to DB2 (all types) | POLICY, ENDOWMENT, HOUSE, MOTOR, COMMERCIAL, CLAIM | — | LGSTSQ | LGAPOL01 |
| [`LGAPVS01`](../../pli/LGAPVS01.pli) | CICS VSAM | Add Policy record to KSDSPOLY VSAM | — | KSDSPOLY (WRITE) | LGSTSQ | LGAPOL01 |
| [`LGIPOL01`](../../pli/LGIPOL01.pli) | CICS Business Logic | Inquire Policy | — | — | LGIPDB01, LGSTSQ | LGTESTP1-4 |
| [`LGIPDB01`](../../pli/LGIPDB01.pli) | CICS DB2 | Inquire Policy from DB2 | POLICY, COMMERCIAL, CLAIM, ENDOWMENT, HOUSE, MOTOR | — | LGSTSQ | LGIPOL01 |
| [`LGIPVS01`](../../pli/LGIPVS01.pli) | CICS VSAM | Inquire Policy from KSDSPOLY VSAM | — | KSDSPOLY (READ) | — | — |
| [`LGDPOL01`](../../pli/LGDPOL01.pli) | CICS Business Logic | Delete Policy | — | — | LGDPDB01, LGSTSQ | LGTESTP1-4 |
| [`LGDPDB01`](../../pli/LGDPDB01.pli) | CICS DB2 | Delete Policy from DB2 | POLICY | — | LGDPVS01, LGSTSQ | LGDPOL01 |
| [`LGDPVS01`](../../pli/LGDPVS01.pli) | CICS VSAM | Delete Policy from KSDSPOLY VSAM | — | KSDSPOLY (DELETE) | LGSTSQ | LGDPDB01 |
| [`LGUPOL01`](../../pli/LGUPOL01.pli) | CICS Business Logic | Update Policy | — | — | LGUPDB01 (implicit), LGSTSQ | LGTESTP1-3 |
| `LGUPDB01` | CICS DB2 | Update Policy in DB2 *(source not in workspace)* | POLICY | — | LGUPVS01 | LGUPOL01 |
| [`LGUPVS01`](../../pli/LGUPVS01.pli) | CICS VSAM | Update Policy in KSDSPOLY VSAM | — | KSDSPOLY (UPDATE) | LGSTSQ | LGUPDB01 |

### Menu / Presentation Layer

| Program | Transaction | BMS Map | Role |
|---|---|---|---|
| [`LGTESTC1`](../../pli/LGTESTC1.pli) | SSC1 | SSMAPC1 | Customer operations menu — calls LGACUS01, LGICUS01, LGUCUS01 |
| [`LGTESTP1`](../../pli/LGTESTP1.pli) | SSP1 | SSMAPP1 | Endowment policy menu |
| [`LGTESTP2`](../../pli/LGTESTP2.pli) | SSP2 | SSMAPP2 | House policy menu |
| [`LGTESTP3`](../../pli/LGTESTP3.pli) | SSP3 | SSMAPP3 | Motor policy menu |
| [`LGTESTP4`](../../pli/LGTESTP4.pli) | SSP4 | SSMAPP4 | Commercial policy menu |
| [`LGWEBST5`](../../pli/LGWEBST5.pli) | SSST | SSMAPP5 | Statistics/monitoring dashboard |

### Utility / Shared Services

| Program | Type | Role |
|---|---|---|
| [`LGSTSQ`](../../pli/LGSTSQ.pli) | CICS Utility | Write TSQ error/status messages — called by nearly all programs |
| [`LGSETUP`](../../pli/LGSETUP.pli) | CICS Setup | Initialise Named Counters (GENACUSTNUM, GENAPOLICYNUM) |
| [`LGASTAT1`](../../pli/LGASTAT1.pli) | CICS Stats | Application statistics collector |
| [`LGMOTOUT`](../../pli/LGMOTOUT.pli) | Batch | Extract motor policy data to MOTOROUT flat file from DB2 MOTOR table |

### Batch Programs

| Program | Role | DB2 | Files | Calls |
|---|---|---|---|---|
| [`LGBATCH`](../../pli/LGBATCH.pli) | Batch customer processing (VSAM path) | CUSTOMER | CUSTIN (in), CUSTRPT (out) | LGBATCHF |
| [`LGBATDB2`](../../pli/LGBATDB2.pli) | Batch customer processing (DB2 path) | CUSTOMER | — | LGBATCHF |
| [`LGBATCHF`](../../pli/LGBATCHF.pli) | Batch formatting utility | — | — | — |
| `LGBATCF` | Batch control flow *(in DB only)* | — | — | — |
| [`LGMOTOUT`](../../pli/LGMOTOUT.pli) | Motor extract batch | MOTOR | MOTOROUT (out) | — |

### Test / Demo Programs

| Program | Role |
|---|---|
| `LGTESTC1` | Customer CRUD test harness (SSC1) |
| `LGTESTP1-4` | Policy CRUD test harnesses (SSP1-4) |

---

## JCL Jobs

| JCL | Description |
|---|---|
| [`jcl/CreateCSDDefs.jcl`](../../jcl/CreateCSDDefs.jcl) | Load CICS CSD definitions |
| [`jcl/GenAppBind.jcl`](../../jcl/GenAppBind.jcl) | DB2 bind for GenApp plans |
| [`jcl/GenAppDDL.jcl`](../../jcl/GenAppDDL.jcl) | Run DDL to create DB2 tables |
| [`DDL/db2cre.jcl`](../../DDL/db2cre.jcl) | Create DB2 tablespaces, tables, indexes, insert test data |

---

## Key Dependencies Summary

- **LGCMAREA.inc** — universal COMMAREA used by all CICS programs as the parameter passing contract
- **LGSTSQ** — universal error-logging utility called by virtually every program
- **CUSTOMER table** — accessed by Customer domain programs AND batch programs (LGBATCH, LGBATDB2)
- **POLICY table** — shared across all policy types (endowment, house, motor, commercial)
- **KSDSCUST** VSAM — parallel customer store alongside DB2 CUSTOMER table
- **KSDSPOLY** VSAM — parallel policy store alongside DB2 POLICY table
