# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Overview

**GenApp (PL/I variant)** — IBM General Insurance Application implemented in PL/I. CICS online transactions + batch programs running on z/OS. Built using IBM zAppBuild (DBB/Groovy pipeline).

## Repository Structure

| Directory | Contents |
|-----------|----------|
| `pli/` | 35 PL/I source programs (`.pli`) |
| `plinc/` | 4 PL/I include files (`.inc`) — equivalent of COBOL copybooks |
| `jcl/` | JCL for DB2 DDL, CSD definitions, bind |
| `application-conf/` | zAppBuild build configuration properties |

## Build System

Build is via **IBM zAppBuild** (Groovy/DBB), not a local command. There is no local `make`/`gradle`/`npm`. All compilation happens on z/OS.

- PLI compiler version: `V52` (configured in [`application-conf/PLI.properties`](application-conf/PLI.properties))
- Default compile parms: `PP(INCLUDE('ID(++INCLUDE)'))` for plain; `SYSTEM(CICS),PP(MACRO,CICS)` for CICS programs
- Link edit parms: `MAP,RENT,COMPAT(PM5)`
- CICS programs deploy to `CICSLOAD`; batch programs to `LOAD`
- `pli_compileMaxRC=4` — RC=4 (warnings) is acceptable; link edit must be RC=0

## Testing

- TAZ unit tests run via `TazUnitTest.groovy` triggered by `runzTests=true` in [`application-conf/application.properties`](application-conf/application.properties)
- Test recording files (`.rec`) are binary — committed as binary in `.gitattributes`
- Test case programs: `**/testcase/*.pli` (set `pli_testcase=true` via [`application-conf/file.properties`](application-conf/file.properties))
- TAZ playback uses `EQAPPLAY`, parms: `STOP=E,REPORT=XML`

## Encoding — CRITICAL

All mainframe source files are stored in UTF-8 in Git and automatically converted to EBCDIC (IBM-1047) when transferred to z/OS. Controlled by [`.gitattributes`](.gitattributes):
- `.pli`, `.inc`, `.jcl`, `.properties`, `.cbl`, `.bms`, `.asm` → `zos-working-tree-encoding=ibm-1047 git-encoding=utf-8`
- `.rec`, `.plbck` → `binary` (never convert)

**Do not change line endings or encoding** of source files manually.

## PL/I Code Patterns

### Include files
- Programs use **both** `%INCLUDE` (compile-time macro preprocessor) and `EXEC SQL INCLUDE`:
  - `%INCLUDE LGCMAREA;` — COMMAREA structure (all CICS programs)
  - `%INCLUDE SSMAP;` — BMS map structures (menu programs LGTESTP1–4, LGTESTC1)
  - `%INCLUDE LGCMARER;` — Business rule request area (LGAPOL01 → LGAPBR01)
  - `EXEC SQL INCLUDE SQLCA;` + `EXEC SQL INCLUDE LGCMAREA;` — DB2 programs
- Include search path: `plinc/*.inc` (configured in [`application-conf/application.properties`](application-conf/application.properties) as `pliincludeSearch`)

### COMMAREA convention
- **All CICS programs** receive `COMM_AREA_PTR` as the procedure parameter: `Proc(COMM_AREA_PTR) Options(Main)`
- Menu programs additionally receive `DFHEIPTR`: `Proc(DFHEIPTR,COMM_AREA_PTR) Options(Main,Reentrant)`
- `CA_REQUEST_ID` (6 chars) encodes the operation: e.g. `'01IMOT'` = Inquire Motor policy
- `CA_RETURN_CODE` = `'00'` for success, `'98'` for bad COMMAREA length, `'99'` for DB2/system errors
- COMMAREA is validated for minimum length at program entry; abend `LGCA` if EIBCALEN=0

### Error handling pattern
- Every program declares a `WS_EYECATCHER` initialized to `'PROGNAMExxxxxx-WS'` for dump identification
- Error messages written to CICS TS queue (not ABEND) via internal `WRITE_ERROR_MESSAGE` procedure
- DB2 errors: check `SQLCODE` after every SQL statement; non-zero → write error and `EXEC CICS RETURN`

### Program naming convention
```
LG + operation(A=Add,D=Delete,I=Inquire,U=Update) + entity(C=Customer,P=Policy) + backend(DB=DB2,VS=VSAM,US=Combined) + 01
```
- `LGACDB01` = **L**ife**G**eneral + **A**dd **C**ustomer + **D**B2 + instance 01
- `LGAPOL01` = Add Policy (orchestrator); calls `LGAPDB01` and optionally `LGAPBR01` (business rules)
- `LGTESTP1-4` = Menu programs (Motor, Endowment, House, Commercial)
- `LGTESTC1` = Customer menu

### Batch programs
- `LGBATCH` / `LGBATDB2` — non-CICS; use `Proc Options(Main)` without COMMAREA parameter
- Files declared with `DCL filename FILE RECORD INPUT SEQUENTIAL ENV(FB RECSIZE(n))`
- `LGBATCHF` is a subprogram called via static `CALL` (not CICS LINK)

## DB2 Tables

| Table | Programs that write | Programs that read |
|-------|--------------------|--------------------|
| CUSTOMER | LGACDB01, LGACUS01 | LGBATCH, LGBATDB2, LGICDB01 |
| CUSTOMER_SECURE | LGACDB02 | — |
| POLICY | LGACUS01, LGAPDB01 | LGDPDB01, LGIPDB01 |
| ENDOWMENT/HOUSE/MOTOR/COMMERCIAL/CLAIM | LGAPDB01 | LGIPDB01 |
| MOTOR | LGMOTOUT (read/write) | — |

## CICS Program Call Architecture

```
Menu (LGTESTP1-4 / LGTESTC1)
  └─ CICS LINK ──► Policy orchestrator (LGAPOL01 / LGDPOL01 / LGIPOL01 / LGUPOL01)
                      └─ CICS DYNAMIC_LINK ──► DB2 backend (LGAPDB01 / LGDPDB01 / etc.)
                      └─ CICS LINK ──► Business rules (LGAPBR01) [optional]
  └─ CICS LINK ──► Customer orchestrator (LGACUS01 / LGICUS01 / LGUCUS01)
                      └─ CICS DYNAMIC_LINK ──► DB2 backend (LGICDB01 / LGUCDB01)
```

- `LGAPVS01`, `LGIPVS01`, etc. = VSAM counterparts (parallel to DB2 backends)
- `LGACDB01` also calls `LGACVS01` (CICS LINK) and `LGACDB02` (customer security, CICS LINK)

## Scanned Database

Program metadata is stored in `.bobz/local-settings.json` (`databaseLocation` field). Use `execute_sql_query` for cross-program analysis (call chains, SQL table access, dependencies).

- **Database path**: `/Users/tingwu/Library/Application Support/IBM Bob/User/workspaceStorage/7bc8556a20a7f43f7939e63ed44f592e/IBM.bob-z-extension/.tmi/WCA4ZTMIOutput/ScannerOutput.db`
- **Programs scanned**: 35 PL/I source files from `pli/`

## Workspace Type
IBM Z


## Documentation

All generated documentation (program explanations, data dictionaries, architecture diagrams, business rules, wiki pages, etc.) must be saved under the `docs/` folder at the workspace root.

| Documentation type | Output path |
|--------------------|-------------|
| Program explanations | `docs/programs/` |
| Data dictionary | `docs/data-dictionary/` |
| Architecture / diagrams | `docs/architecture/` |
| Business rules | `docs/business-rules/` |
| Wiki / application docs | `docs/wiki/` |

Create subdirectories as needed. Do not save generated documentation directly in the workspace root or alongside source files.

### Architecture Analysis Documents

The following architecture analysis files have been generated and are stored under `docs/architecture/`:

| File | Description |
|------|-------------|
| [`docs/architecture/domain-map.md`](docs/architecture/domain-map.md) | High-level domain map of the application. Identifies the 6 functional domains (Presentation, Customer Management, Policy Management, Business Rules, Batch Reporting, Operations & Infrastructure), their programs, data stores, and inter-domain dependencies. Includes a Mermaid domain diagram. |
| [`docs/architecture/customer-domain-analysis.md`](docs/architecture/customer-domain-analysis.md) | Deep-dive analysis of the Customer Management domain. Covers the three-tier component structure (orchestrators → DB2 backends → VSAM backends), sequence diagrams for Add/Inquire/Update flows, shared resources, inbound/outbound dependencies, return code catalogue, and key risk findings. |
| [`docs/architecture/customer-domain-migration-analysis.md`](docs/architecture/customer-domain-migration-analysis.md) | Migration effort analysis for moving the Customer Management domain off the mainframe. Identifies 10 migration items, ranks risks from CRITICAL to LOW, covers shared modules (LGCMAREA.inc, LGSTSQ), shared data (CUSTOMER table, VSAM KSDSCUST), cross-domain coupling (LGACUS01→POLICY), CICS/DB2 construct migration mappings, and a recommended 8-step migration sequence. |
| [`docs/business-rules/customer-domain-business-rules.md`](docs/business-rules/customer-domain-business-rules.md) | 16 business rules and key behaviours the migration team must preserve for the Customer Management domain. Covers customer identity and lifecycle (BR-01–BR-04), data model and field rules (BR-05–BR-06), request routing and dormant operations (BR-07–BR-08), COMMAREA validation (BR-09–BR-10), error handling semantics (BR-11–BR-14), ordering and concurrency rules (BR-15–BR-16), and a return code to HTTP status mapping appendix. |
|      |             |
|      |             |
