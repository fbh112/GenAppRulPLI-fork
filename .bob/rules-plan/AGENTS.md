# Z Architect / Plan Rules (Non-Obvious Only)

## Architectural Constraints

### Two parallel backends for every operation
Every CRUD operation has **both** a DB2 backend (`LGxxDB01`) and a VSAM backend (`LGxxVS01`). The orchestrator (`LGxxOL01`) calls only one path at runtime. The VSAM backends are present but may be dormant in DB2-configured environments.

### Orchestrators are thin pass-throughs
`LGAPOL01`, `LGDPOL01`, `LGIPOL01`, `LGUPOL01`, `LGACUS01`, `LGICUS01`, `LGUCUS01` contain **no DB2 SQL**. They only validate the COMMAREA, set `CA_REQUEST_ID`, and CICS LINK to the appropriate backend. Business logic lives in the `*DB01` / `*VS01` programs.

### COMMAREA is the only data contract
There are no shared global variables or TS queues between online programs. All data passes through the 32500-byte COMMAREA defined in `plinc/LGCMAREA.inc`. Changing field offsets within COMMAREA breaks all callers simultaneously.

### Named counters for customer number generation
Customer numbers come from a CICS named counter (`GENACUSTNUM`, pool `GENA`), not from a DB2 SEQUENCE or MAX()+1. If the counter is unavailable, `LGACDB01` sets `LGAC_NCS='NO'` and inserts customer 0 — a silent failure path.

### Statistics tracking via TS queues
`LGSTSQ` / `LGASTAT1` read/write 36 named counters (e.g. `GENA01ICUS00`, `GENA01ICUS99`) representing success/failure counts per transaction type. `LGSETUP` initializes all of these at deployment.

### Business rules are optional
`LGAPOL01` calls `LGAPBR01` (business rules) only for Endowment policies when `BUSINESS_RULES='Y'`. The stub `LGUPDB01` (ProgramTypeID=1, 0 statements) suggests this is a placeholder for future rules integration.

### Impact of COMMAREA changes
Modifying `plinc/LGCMAREA.inc` or `plinc/LGPOLICY.inc` field sizes requires recompiling ALL programs that `%INCLUDE` or `EXEC SQL INCLUDE` them — which is essentially the entire application. Use `execute_sql_query` to identify all affected programs before planning any such change.

### DB2 table ownership
- `CUSTOMER` and `CUSTOMER_SECURE` are owned by the Add-Customer flow (`LGACDB01` / `LGACDB02`)
- `POLICY` and policy-type tables (ENDOWMENT, HOUSE, MOTOR, COMMERCIAL, CLAIM) are managed by `LGAPDB01`
- No program other than `LGAPDB01` inserts into policy-type tables
