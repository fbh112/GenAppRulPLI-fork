# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project
Application platform: IBM Z. GenApp is a PL/I-based mainframe application (insurance domain: customer, policy, endowment, house, motor, commercial, claim). Source languages present: PL/I (`pli/`), JCL (`jcl/`), PL/I includes (`plinc/`), CICS CSD definitions (`Resources/`), Db2 DDL (`DDL/`).

## Build
Build is driven by zAppBuild Groovy scripts configured in `application-conf/`. `application.properties` sets `buildOrder` (includes `PLI.groovy`, `LinkEdit.groovy`), `pli_compilerVersion=V52`, `pli_compileParms=PP(INCLUDE('ID(++INCLUDE)'))`, `pli_linkEditParms=MAP,RENT,COMPAT(PM5)`, `runzTests=true`. JCL jobs: `jcl/GenAppDDL.jcl` (Db2 DDL), `jcl/GenAppBind.jcl` (DB2 BIND of packages into collection GENASA1, plan GENAONE), `jcl/CreateCSDDefs.jcl` (CICS CSD group GENA). No local test runner; zUnit tests run on z/OS via TazUnitTest.

## PL/I conventions
- PL/I source files live in `pli/`; shared include/copybook files live in `plinc/` and are pulled in with `%INCLUDE` (e.g. `%INCLUDE LGCMAREA;`). The central commarea copybook is `plinc/LGCMAREA.inc`.
- CICS transaction programs are coded as `Proc(COMM_AREA_PTR) Options(Main);` and communicate via `EXEC CICS LINK`, `EXEC CICS RETURN`, `EXEC CICS ABEND`, `EXEC CICS GET COUNTER`, `EXEC CICS ASKTIME/FORMATTIME`.
- Batch (non-CICS) programs read QSAM files (`FILE RECORD INPUT/OUTPUT SEQUENTIAL ENV(FB ...)`) and use embedded SQL (`EXEC SQL`).
- Embedded SQL uses `EXEC SQL INCLUDE SQLCA;` and `EXEC SQL INCLUDE LGCMAREA;`. Db2 tables are owned by schema `GENASA1`.
- Error handling pattern: programs define an `ERROR_MSG` structure and a `WRITE_ERROR_MESSAGE` procedure that writes to TDQ via `EXEC CICS LINK PROGRAM('LGSTSQ')`.
- Programs call each other via `EXEC CICS LINK PROGRAM(...)` (CICS) or `CALL` / `fetch` (batch). Some files carry sequence numbers in columns 73–80.

## Data dictionary
The data dictionary is stored at `bobz/DD.json` (does not yet exist). Local settings live in `.bobz/local-settings.json` with `databaseLocation` pointing to the SQLite scanner database created by `scan_program`. Run `scan_program` on the workspace to generate the local metadata database used by GraphQL analysis and control-flow/data-flow tools.

## Documentation
All documentation, analysis, plans, diagrams, and data-dictionary artifacts created in this workspace are saved under the `docs/` folder.

## Code style
- Follow the existing PL/I layout: comment banner at top, `DCL` blocks for working storage, `EXEC SQL INCLUDE SQLCA;` and `EXEC SQL INCLUDE LGCMAREA;` for DB2 programs, `EXEC CICS` for CICS programs.
- Name programs with the `LG<area><function><nn>` convention seen across `pli/`.
- Keep error handling consistent: set a return code, call `WRITE_ERROR_MESSAGE`, then `EXEC CICS RETURN`.
