# Z Ask Rules (Non-Obvious Only)

## Documentation Context

- `plinc/` is the **PL/I include directory** — equivalent to COBOL copybooks. Files have `.inc` extension.
- `LGCMAREA.inc` defines the **master COMMAREA** as a `UNION` so all policy types (Endowment, House, Motor, Commercial, Claim) share the same 32500-byte buffer via overlapping structures.
- `LGPOLICY.inc` defines DB2 host variable structures mapping to the actual DB2 tables; lengths in `WS_POLICY_LENGTHS` must match the DB2 column definitions exactly.
- `SSMAP.inc` is a PL/I representation of the BMS map (SSMAP mapset) — it is **not** a BMS source file; the BMS source lives elsewhere (not in this repo).

## Program Naming Decoder

```
LG = Life General
  A = Add    D = Delete    I = Inquire    U = Update
  C = Customer    P = Policy
  DB = DB2 backend    VS = VSAM backend    US = Combined orchestrator
  01 = instance number
```

- `LGAPOL01` is the **Add Policy orchestrator** — it does NOT access DB2 directly; it delegates to `LGAPDB01`
- `LGAPBR01` is the **Business Rules** program (referenced but source is a COBOL stub `LGUPDB01` — stub with 0 statements)

## CICS Transaction Mapping

- `LGTESTP1` = Motor policy menu
- `LGTESTP2` = Endowment policy menu  
- `LGTESTP3` = House policy menu
- `LGTESTP4` = Commercial policy menu
- `LGTESTC1` = Customer menu
- `LGSETUP` = GenApp environment initializer (sets up TS queues and named counters)
- `LGSTSQ` = Statistics TS queue reader

## Batch vs CICS

- `LGBATCH` and `LGBATDB2` are **non-CICS batch** programs; they read `CUSTIN` (FB RECSIZE 10) and write to `CUSTRPT` (FB RECSIZE 80)
- `LGBATCF` is a companion batch program; `LGBATCHF` is a batch submodule (static CALL, not CICS LINK)
- All other `LGxx` programs are CICS online transactions
