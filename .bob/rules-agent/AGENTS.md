# Z Code Agent Rules (Non-Obvious Only)

## PL/I Source Editing

- **Column 73–80 contain sequence numbers** in `.inc` files (e.g. `00010000`). Do NOT modify or delete them. When adding new lines to `.inc` files, increment the sequence number in cols 73–80 consistently.
- `pli/` files: most programs do NOT have sequence numbers in cols 73–80; `plinc/` files DO.
- Line ending for all source: **LF only** (enforced by `.gitattributes`). Never CRLF.

## Include File Syntax

- Use `%INCLUDE filename;` (no path, no extension) — preprocessor resolves via `pliincludeSearch` = `plinc/*.inc`
- **Not** `%INCLUDE 'plinc/LGCMAREA.inc';` — that syntax will fail the DBB scanner

## COMMAREA Length Pattern

When adding fields to `LGCMAREA.inc` COMM_AREA UNION, the total raw size is fixed at 32500 bytes. All UNION branches (`CA_REQUEST_SPECIFIC`) must include a filler field to pad to exactly 32482 bytes (header is 18 bytes). Update filler sizes when adding fields.

## CICS LINK vs DYNAMIC_LINK

- Use `EXEC CICS LINK PROGRAM('LITERAL')` when the target program name is known at compile time
- Use `EXEC CICS LINK PROGRAM(variable)` (DYNAMIC_LINK) when the program name is in a variable — this is how the orchestrators call backends (e.g. `LGIPOL01` → `LGIPDB01`)

## Error Return Convention

- Set `CA_RETURN_CODE = '98'` for COMMAREA length errors, `'99'` for DB2/system errors, `'00'` for success
- After an error, always `EXEC CICS RETURN` immediately — do not fall through to normal processing

## DB2 Host Variables in PL/I

- Declare integer host variables as `FIXED BIN(31)` for DB2 INTEGER columns
- DB2 CHAR host variables must match the exact column length — no padding tolerance
- Always `EXEC SQL INCLUDE SQLCA;` before using `SQLCODE`

## TAZ Unit Test Files

- Test case programs in `pli/` follow naming `LGTESTxx.pli` and call production programs via CICS LINK
- Recording files (`.rec`) in `testcase/` are binary — never edit as text
