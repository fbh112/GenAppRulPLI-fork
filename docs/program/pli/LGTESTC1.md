## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Inputs](#2-inputs)
  - [2.1 BMS Terminal Screen Input (CICS RECEIVE MAP)](#21-bms-terminal-screen-input-cics-receive-map)
  - [2.2 CICS COMMAREA (Inter-Program Communication)](#22-cics-commarea-inter-program-communication)
  - [2.3 CICS Temporary Storage Queue (External State)](#23-cics-temporary-storage-queue-external-state)
  - [2.4 Program Entry Parameters](#24-program-entry-parameters)
- [3. Outputs](#3-outputs)
  - [3.1 BMS Screen Output (CICS SEND MAP — SSMAPC1)](#31-bms-screen-output-cics-send-map--ssmapc1)
  - [3.2 CICS RETURN (Transaction Continuation)](#32-cics-return-transaction-continuation)
  - [3.3 CICS LINK Outputs (Backend Program Communication via COMM_AREA)](#33-cics-link-outputs-backend-program-communication-via-comm_area)
  - [3.4 CICS Temporary Storage Queue Output (GENACNTL)](#34-cics-temporary-storage-queue-output-genacntl)
  - [3.5 CICS ENQ/DEQ (Resource Serialization Side Effect)](#35-cics-enqdeq-resource-serialization-side-effect)
- [4. Processing Logic](#4-processing-logic)
  - [4.1 Program Entry and Initialization](#41-program-entry-and-initialization)
  - [4.2 Screen Input and AID Key Handling](#42-screen-input-and-aid-key-handling)
  - [4.3 Option Dispatch (SELECT on ENT1OPTO)](#43-option-dispatch-select-on-ent1opto)
  - [4.4 Option 1 — Customer Inquiry](#44-option-1--customer-inquiry)
  - [4.5 Option 2 — Customer Add](#45-option-2--customer-add)
  - [4.6 Option 4 — Customer Update (Two-Phase)](#46-option-4--customer-update-two-phase)
  - [4.7 Invalid Option Handling](#47-invalid-option-handling)
  - [4.8 Error Handling Labels](#48-error-handling-labels)
  - [4.9 Terminal Session Control Labels](#49-terminal-session-control-labels)
  - [4.10 WRITE_GENACNTL Internal Procedure — TS Queue Maintenance](#410-write_genacntl-internal-procedure--ts-queue-maintenance)
- [5. Paragraphs](#5-paragraphs)
- [6. Dependencies](#6-dependencies)
  - [6.1 CICS Transaction & Runtime](#61-cics-transaction--runtime)
  - [6.2 BMS Maps & Mapset](#62-bms-maps--mapset)
  - [6.3 Copybook / Include Members](#63-copybook--include-members)
  - [6.4 External Programs (CICS LINK targets)](#64-external-programs-cics-link-targets)
  - [6.5 CICS Temporary Storage (TS) Queue](#65-cics-temporary-storage-ts-queue)
  - [6.6 CICS Enqueue / Serialisation Resource](#66-cics-enqueue--serialisation-resource)
  - [6.7 CICS AID Key & Condition Handlers](#67-cics-aid-key--condition-handlers)
  - [6.8 Communication Area (COMMAREA)](#68-communication-area-commarea)
- [7. Constraints](#7-constraints)
  - [7.1 Menu Option Validation](#71-menu-option-validation)
  - [7.2 COMMAREA Presence Constraint (EIBCALEN = 0 Check)](#72-commarea-presence-constraint-eibcalen--0-check)
  - [7.3 COMMAREA Size Constraint](#73-commarea-size-constraint)
  - [7.4 Customer Number Format Constraint](#74-customer-number-format-constraint)
  - [7.5 Null-Byte Sanitisation Constraint (Add and Update Only)](#75-null-byte-sanitisation-constraint-add-and-update-only)
  - [7.6 Postcode Uppercase Constraint (Add and Update Only)](#76-postcode-uppercase-constraint-add-and-update-only)
  - [7.7 Backend Return-Code Gate](#77-backend-return-code-gate)
  - [7.8 Update Sequencing Constraint (Two-Step Verify-Then-Modify)](#78-update-sequencing-constraint-two-step-verify-then-modify)
  - [7.9 TS Queue Serialisation Constraint (WRITE_GENACNTL)](#79-ts-queue-serialisation-constraint-write_genacntl)
  - [7.10 TS Queue Record-Length Constraints (WRITE_GENACNTL)](#710-ts-queue-record-length-constraints-write_genacntl)
  - [7.11 TS Queue Search Constraint (HIGH CUSTOMER Token)](#711-ts-queue-search-constraint-high-customer-token)
  - [7.12 AID Key and Map-Failure Constraints](#712-aid-key-and-map-failure-constraints)
  - [7.13 State Reset on Error](#713-state-reset-on-error)
  - [7.14 Field-Width (Buffer-Size) Constraints](#714-field-width-buffer-size-constraints)
- [8. Error Handling](#8-error-handling)
  - [8.1 Backend Return Code Checks](#81-backend-return-code-checks)
  - [8.2 Transaction Rollback on Add Failure](#82-transaction-rollback-on-add-failure)
  - [8.3 Centralised Error Output and State Reset](#83-centralised-error-output-and-state-reset)
  - [8.4 CICS Attention Identifier (AID) and Condition Handling](#84-cics-attention-identifier-aid-and-condition-handling)
  - [8.5 Invalid Option Handling](#85-invalid-option-handling)
  - [8.6 First-Call / Missing COMMAREA Guard](#86-first-call--missing-commarea-guard)
  - [8.7 Graceful Transaction Termination](#87-graceful-transaction-termination)
  - [8.8 TS Queue Serialisation and Conditional Write Logic in `WRITE_GENACNTL`](#88-ts-queue-serialisation-and-conditional-write-logic-in-write_genacntl)
- [9. Examples](#9-examples)
  - [9.1 Example 1 — Customer Inquiry (Option 1)](#91-example-1--customer-inquiry-option-1)
  - [9.2 Example 2 — Add New Customer (Option 2)](#92-example-2--add-new-customer-option-2)
  - [9.3 Example 3 — Update Customer (Option 4)](#93-example-3--update-customer-option-4)
  - [9.4 Example 4 — Invalid Option](#94-example-4--invalid-option)

## 1. Purpose

`LGTESTC1` is a CICS-based PL/I program that serves as the interactive customer maintenance menu for the General Insurance (GenApp) application, running under CICS transaction `SSC1`. It presents a BMS-mapped screen to terminal users and allows them to perform three types of customer record operations — inquiry (option 1), add (option 2), and update (option 4) — by collecting customer details such as name, date of birth, address, phone numbers, and email address from the screen, then delegating the actual data access work to dedicated backend programs (`LGICUS01` for inquiry, `LGACUS01` for add, and `LGUCUS01` for update) via `EXEC CICS LINK` calls using a shared communication area. After a successful customer addition, the program also maintains a CICS temporary storage queue (`GENACNTL`) to track the highest assigned customer number, using ENQ/DEQ serialization to prevent concurrent update conflicts. Error conditions returned by backend programs are surfaced back to the user through an on-screen error message field, and the program ends gracefully on PF3 or CLEAR key input.

## 2. Inputs

### 2.1 BMS Terminal Screen Input (CICS RECEIVE MAP)

- **ENT1OPTO** (`SSMAPC1O.ENT1OPTO`, CHAR(1)) — Menu option selected by the user on the customer screen (`SSMAPC1`/`SSMAP`). Drives the main SELECT dispatch: `'1'` = Inquire, `'2'` = Add, `'4'` = Update; any other value triggers an invalid-option error path.
- **ENT1CNOO** (`SSMAPC1O.ENT1CNOO`, CHAR(10)) — Customer number entered on screen. Read on option `'1'` (inquiry) and option `'4'` (update pre-fetch) to identify which customer record to retrieve.
- **ENT1FNAI** (`SSMAPC1I.ENT1FNAI`, CHAR(10)) — First name entered on screen. Copied into `CA_FIRST_NAME` for Add (option `'2'`) and Update (option `'4'`) operations.
- **ENT1LNAI** (`SSMAPC1I.ENT1LNAI`, CHAR(20)) — Last name entered on screen. Copied into `CA_LAST_NAME` for Add and Update operations.
- **ENT1DOBI** (`SSMAPC1I.ENT1DOBI`, CHAR(10)) — Date of birth entered on screen. Copied into `CA_DOB` for Add and Update operations.
- **ENT1HNMI** (`SSMAPC1I.ENT1HNMI`, CHAR(20)) — House name entered on screen. Copied into `CA_HOUSE_NAME` for Add and Update operations.
- **ENT1HNOI** (`SSMAPC1I.ENT1HNOI`, CHAR(4)) — House number entered on screen. Copied into `CA_HOUSE_NUM` for Add and Update operations; also re-read after the second RECEIVE MAP in the Update path to carry `CA_CUSTOMER_NUM`.
- **ENT1HPCI** (`SSMAPC1I.ENT1HPCI`, CHAR(8)) — Postcode entered on screen. Copied into `CA_POSTCODE` (then uppercased) for Add and Update operations.
- **ENT1HP1I** (`SSMAPC1I.ENT1HP1I`, CHAR(20)) — Home phone number entered on screen. Copied into `CA_PHONE_HOME` for Add and Update operations.
- **ENT1HP2I** (`SSMAPC1I.ENT1HP2I`, CHAR(20)) — Mobile phone number entered on screen. Copied into `CA_PHONE_MOBILE` for Add and Update operations.
- **ENT1HMOI** (`SSMAPC1I.ENT1HMOI`, CHAR(27)) — Email address entered on screen. Copied into `CA_EMAIL_ADDRESS` for Add and Update operations.
- **ENT1CNOI** (`SSMAPC1I.ENT1CNOI`, CHAR(10)) — Customer number read back from screen on the second RECEIVE MAP within the Update path (option `'4'`). Used to set `CA_CUSTOMER_NUM` before linking to `LGUCUS01`.

### 2.2 CICS COMMAREA (Inter-Program Communication)

- **COMM_AREA** (UNION, 32500 bytes, via `COMM_AREA_PTR`) — The full communication area passed to and returned from all linked backend programs. It carries the request identifier, return code, customer number, and all customer detail fields. It is received as a procedure parameter (`COMM_AREA_PTR`) and passed back to `EXEC CICS RETURN … COMMAREA(COMM_AREA)` so that state persists across pseudo-conversational transaction cycles.
  - **CA_REQUEST_ID** (CHAR(6)) — Set by this program before each `EXEC CICS LINK` call to specify the backend operation: `'01ICUS'` (inquire customer), `'01ACUS'` (add customer), `'01UCUS'` (update customer).
  - **CA_RETURN_CODE** (PIC `'99'`) — Populated by the linked backend programs (`LGICUS01`, `LGACUS01`, `LGUCUS01`). A non-zero value causes the program to branch to the corresponding error label (`NO_DATA`, `NO_ADD`, `NO_UPD`).
  - **CA_CUSTOMER_NUM** (PIC `'9999999999'`) — The 10-digit customer identifier. Supplied by screen input for inquiry/update; returned by `LGACUS01` after a successful add, and subsequently displayed back on the screen.
  - **CA_REQUEST_INITIALISER** (CHAR(32482)) — The bulk overlay of the request-specific portion of COMM_AREA; reset to spaces to clear stale data between transactions.
  - **CA_FIRST_NAME** (CHAR(10)) — Customer first name exchanged with backend programs.
  - **CA_LAST_NAME** (CHAR(20)) — Customer last name exchanged with backend programs.
  - **CA_DOB** (CHAR(10)) — Customer date of birth exchanged with backend programs.
  - **CA_HOUSE_NAME** (CHAR(20)) — Customer house name exchanged with backend programs.
  - **CA_HOUSE_NUM** (CHAR(4)) — Customer house number exchanged with backend programs.
  - **CA_POSTCODE** (CHAR(8)) — Customer postcode exchanged with backend programs (converted to uppercase before linking).
  - **CA_PHONE_HOME** (CHAR(20)) — Customer home phone number exchanged with backend programs.
  - **CA_PHONE_MOBILE** (CHAR(20)) — Customer mobile phone number exchanged with backend programs.
  - **CA_EMAIL_ADDRESS** (CHAR(100)) — Customer email address exchanged with backend programs.
  - **COMM_AREA_RAW** (CHAR(32500)) — Byte-level overlay of the entire COMM_AREA; used to bulk-translate null bytes (`'00'X`) to spaces before linking to `LGACUS01` or `LGUCUS01`.

### 2.3 CICS Temporary Storage Queue (External State)

- **STSQ_NAME / `GENACNTL` queue** (CHAR(8), static) — The CICS TS queue named `GENACNTL` is read and written by the `WRITE_GENACNTL` procedure after a successful customer add. It stores the high and low customer number range records and acts as an external counter/control area. The queue contents (specifically items whose first 13 characters match `'HIGH CUSTOMER'`) provide the existing high-water mark and are updated with the newly assigned customer number.
  - **READ_MSG / `READ_MSG_MSG`** (CHAR(80)) — Buffer into which each TS queue item is read. The first 13 characters are tested to locate the `'HIGH CUSTOMER'` record.

### 2.4 Program Entry Parameters

- **DFHEIPTR** — CICS-supplied pointer passed as the first procedure parameter, required by the CICS macro preprocessor for EIB addressability in programs compiled with `SYSTEM(CICS)`.
- **COMM_AREA_PTR** — Pointer passed as the second procedure parameter pointing to the CICS COMMAREA. When `EIBCALEN = 0` (first invocation) the program self-initialises a local base area; on subsequent pseudo-conversational returns the pointer addresses the commarea passed back via `EXEC CICS RETURN … COMMAREA`.

## 3. Outputs

### 3.1 BMS Screen Output (CICS SEND MAP — SSMAPC1)

- **SSMAPC1O / SSMAPC1I (BMS map `SSMAPC1`, mapset `SSMAP`)** — The primary user-facing output channel. The customer menu screen is sent to the terminal in multiple scenarios:
  - **Initial display** — on first entry (`EIBCALEN = 0`), the cleared map is sent with `ENT1CNOO` initialised to `'0000000000'`
  - **Option 1 (Customer Inquiry)** — after a successful `LGICUS01` link, customer data fields are populated on the map and sent:
    - `ENT1FNAI` ← `CA_FIRST_NAME`
    - `ENT1LNAI` ← `CA_LAST_NAME`
    - `ENT1DOBI` ← `CA_DOB`
    - `ENT1HNMI` ← `CA_HOUSE_NAME`
    - `ENT1HNOI` ← `CA_HOUSE_NUM`
    - `ENT1HPCI` ← `CA_POSTCODE`
    - `ENT1HP1I` ← `CA_PHONE_HOME`
    - `ENT1HP2I` ← `CA_PHONE_MOBILE`
    - `ENT1HMOI` ← `CA_EMAIL_ADDRESS`
  - **Option 2 (Customer Add)** — after a successful `LGACUS01` link, the map is sent with:
    - `ENT1CNOI` ← `CA_CUSTOMER_NUM` (newly assigned customer number)
    - `ENT1OPTI` ← `' '` (option field cleared)
    - `ERRFLDO` ← `'New Customer Inserted'` (confirmation message)
  - **Option 4 (Customer Update)** — first send populates existing data for review (same fields as inquiry); after user edits are received and `LGUCUS01` succeeds, a second send is issued with:
    - `ENT1CNOI` ← `CA_CUSTOMER_NUM`
    - `ENT1OPTI` ← `' '`
    - `ERRFLDO` ← `'Customer details updated'`
  - **Invalid option (OTHERWISE)** — the map is sent with:
    - `ERRFLDO` ← `'Please enter a valid option'`
    - `ENT1OPTL` ← `-1` (cursor positioning attribute)
  - **Error paths**:
    - `NO_UPD` → `ERRFLDO` ← `'Error Updating Customer'`, then map sent via `ERROR_OUT`
    - `NO_ADD` → `ERRFLDO` ← `'Error Adding Customer'`, then map sent via `ERROR_OUT`
    - `NO_DATA` → `ERRFLDO` ← `'No data was returned.'`, then map sent via `ERROR_OUT`
  - **CLEARIT** — the map is sent `MAPONLY` (blank screen) when the CLEAR key is pressed
  - **ENDIT** — a plain text message `'Transaction ended'` (`MSGEND`) is sent via `EXEC CICS SEND TEXT` with `ERASE` and `FREEKB` when PF3 is pressed or a MAPFAIL condition occurs

### 3.2 CICS RETURN (Transaction Continuation)

- **`EXEC CICS RETURN TRANSID('SSC1') COMMAREA(COMM_AREA)`** — issued at `ENDIT_STARTIT` and `CLEARIT` to pass the entire `COMM_AREA` back to the CICS task manager, keeping the transaction alive for the next user interaction. The `COMM_AREA` at this point contains:
  - `CA_REQUEST_ID` — the last-used request type (`'01ICUS'`, `'01ACUS'`, `'01UCUS'`, or cleared)
  - `CA_RETURN_CODE` — return code from the last backend call (or `0` after error reset)
  - `CA_CUSTOMER_NUM` — the current customer number (new number after add, cleared after error)
  - `CA_REQUEST_SPECIFIC` / `CA_CUSTOMER_REQUEST` fields — customer details populated from the last successful backend call or cleared after error

### 3.3 CICS LINK Outputs (Backend Program Communication via COMM_AREA)

- **`EXEC CICS LINK PROGRAM('LGICUS01')`** — sends `COMM_AREA` with `CA_REQUEST_ID = '01ICUS'` and `CA_CUSTOMER_NUM` for inquiry; receives back all `CA_CUSTOMER_REQUEST` fields and `CA_RETURN_CODE`
- **`EXEC CICS LINK PROGRAM('LGACUS01')`** — sends `COMM_AREA` with `CA_REQUEST_ID = '01ACUS'` and all customer detail fields for customer creation; receives back `CA_CUSTOMER_NUM` (assigned) and `CA_RETURN_CODE`
- **`EXEC CICS LINK PROGRAM('LGUCUS01')`** — sends `COMM_AREA` with `CA_REQUEST_ID = '01UCUS'` and updated customer detail fields for customer update; receives back `CA_RETURN_CODE`

### 3.4 CICS Temporary Storage Queue Output (GENACNTL)

- **`EXEC CICS WRITEQ TS QUEUE('GENACNTL')`** — written during `WRITE_GENACNTL` procedure after a successful customer add. Three write scenarios occur:
  - **Update of existing `HIGH CUSTOMER` record** — rewrites the existing TS queue item with `WRITE_MSG_H` (24 bytes), updating `WRITE_MSG_HIGH` ← `CA_CUSTOMER_NUM`
  - **New queue initialisation** (if no `HIGH CUSTOMER` entry exists):
    - Writes `WRITE_MSG_E` (`'**** GENAPP CNTL    '`, 20 bytes) — header record
    - Writes `WRITE_MSG_L` (23 bytes) — `'LOW CUSTOMER='` followed by `WRITE_MSG_LOW` set to `CA_CUSTOMER_NUM`
    - Writes `WRITE_MSG_H` (24 bytes) — `'HIGH CUSTOMER='` followed by `WRITE_MSG_HIGH` set to `CA_CUSTOMER_NUM`

### 3.5 CICS ENQ/DEQ (Resource Serialization Side Effect)

- **`EXEC CICS ENQ RESOURCE('GENACNTL')`** / **`EXEC CICS DEQ RESOURCE('GENACNTL')`** — bracket the TS queue update in `WRITE_GENACNTL` to serialize access to the `GENACNTL` queue across concurrent transactions. This is an observable runtime side effect that can block other tasks attempting to enqueue the same resource.

## 4. Processing Logic

### 4.1 Program Entry and Initialization

- On the very first invocation, `EIBCALEN = 0` (no COMMAREA passed), indicating the transaction has just started
  - `COMM_AREA_PTR` is set to point at `BASE_COMM_AREA`, a local CHAR area whose size matches the COMM_AREA UNION
  - Both the input map (`SSMAPC1I`) and output map (`SSMAPC1O`) structures are cleared to spaces
  - `CA_REQUEST_ID`, `CA_RETURN_CODE`, `CA_CUSTOMER_NUM`, and `CA_REQUEST_INITIALISER` are all initialized to their zero/space values
  - The customer number output field `ENT1CNOO` is preset to `'0000000000'`
  - The initial customer menu screen (BMS map `SSMAPC1` from mapset `SSMAP`) is sent to the terminal with `ERASE`, presenting a blank form to the user
- On subsequent pseudo-conversational entries, the program skips the initialization block and jumps directly to label `A_GAIN`

---

### 4.2 Screen Input and AID Key Handling

- Before reading the screen, two CICS attention-identifier (AID) and condition handlers are registered:
  - `EXEC CICS HANDLE AID CLEAR(CLEARIT)` — pressing the CLEAR key routes control to the `CLEARIT` label
  - `EXEC CICS HANDLE AID PF3(ENDIT)` — pressing PF3 routes control to the `ENDIT` label to end the transaction
  - `EXEC CICS HANDLE CONDITION MAPFAIL(ENDIT)` — if the RECEIVE MAP operation fails (e.g., no data entered), control also goes to `ENDIT`
- `EXEC CICS RECEIVE MAP('SSMAPC1') INTO(SSMAPC1I) ASIS TERMINAL MAPSET('SSMAP')` reads the user's input from the BMS screen into the `SSMAPC1I` structure; `ASIS` preserves the raw data without attribute stripping

---

### 4.3 Option Dispatch (SELECT on ENT1OPTO)

- The value of `ENT1OPTO` (the option field from the output overlay `SSMAPC1O`) is used as the selector of a PL/I `SELECT` statement to branch to one of three functional paths or an error path:
  - `'1'` → Customer Inquiry
  - `'2'` → Customer Add
  - `'4'` → Customer Update
  - `OTHERWISE` → Invalid option handling

---

### 4.4 Option 1 — Customer Inquiry

- `CA_REQUEST_ID` is set to `'01ICUS'` and `CA_CUSTOMER_NUM` is loaded from `ENT1CNOO` (the customer number currently shown on screen)
- `EXEC CICS LINK PROGRAM('LGICUS01')` is called with the 32500-byte COMMAREA, transferring control to the customer inquiry back-end
- If `CA_RETURN_CODE > 0` upon return, control jumps to `NO_DATA` (error path)
- On success, the returned customer data fields are mapped from the COMMAREA to the screen input structure:
  - `CA_FIRST_NAME` → `ENT1FNAI`
  - `CA_LAST_NAME` → `ENT1LNAI`
  - `CA_DOB` → `ENT1DOBI`
  - `CA_HOUSE_NAME` → `ENT1HNMI`
  - `CA_HOUSE_NUM` → `ENT1HNOI`
  - `CA_POSTCODE` → `ENT1HPCI`
  - `CA_PHONE_HOME` → `ENT1HP1I`
  - `CA_PHONE_MOBILE` → `ENT1HP2I`
  - `CA_EMAIL_ADDRESS` → `ENT1HMOI`
- The populated screen map is sent back to the terminal via `EXEC CICS SEND MAP('SSMAPC1')`
- Control then goes to `ENDIT_STARTIT` for pseudo-conversational return

---

### 4.5 Option 2 — Customer Add

- `CA_REQUEST_ID` is set to `'01ACUS'` and `CA_CUSTOMER_NUM` is set to `0` (new customer, no number yet)
- All customer fields are copied from the screen input structure into the COMMAREA:
  - `ENT1FNAI` → `CA_FIRST_NAME`, `ENT1LNAI` → `CA_LAST_NAME`, `ENT1DOBI` → `CA_DOB`
  - `ENT1HNMI` → `CA_HOUSE_NAME`, `ENT1HNOI` → `CA_HOUSE_NUM`, `ENT1HPCI` → `CA_POSTCODE`
  - `ENT1HP1I` → `CA_PHONE_HOME`, `ENT1HP2I` → `CA_PHONE_MOBILE`, `ENT1HMOI` → `CA_EMAIL_ADDRESS`
- Before linking, two data-cleansing steps are performed:
  - `COMM_AREA_RAW = TRANSLATE(COMM_AREA_RAW,' ','00'X)` — replaces all null bytes (`X'00'`) with spaces across the entire 32500-byte COMMAREA
  - `CA_POSTCODE = UPPERCASE(CA_POSTCODE)` — forces the postcode to uppercase
- `EXEC CICS LINK PROGRAM('LGACUS01')` is called to perform the actual customer add
- If `CA_RETURN_CODE > 0`, a `EXEC CICS SYNCPOINT ROLLBACK` is issued to undo any partial database changes, then control goes to `NO_ADD`
- On success:
  - `CALL WRITE_GENACNTL` is invoked to update the GENACNTL TS queue with the new customer number
  - The assigned customer number (`CA_CUSTOMER_NUM`) is written back to `ENT1CNOI`
  - The option field `ENT1OPTI` is cleared; `ERRFLDO` is set to `'New Customer Inserted'`
  - The updated screen is sent and the transaction enters pseudo-conversational wait

---

### 4.6 Option 4 — Customer Update (Two-Phase)

**Phase 1 — Fetch and Display Existing Data:**
- Identical to Option 1: `CA_REQUEST_ID = '01ICUS'`, `CA_CUSTOMER_NUM` loaded from `ENT1CNOO`, `EXEC CICS LINK PROGRAM('LGICUS01')` called
- If `CA_RETURN_CODE > 0`, goes to `NO_DATA`
- On success, all retrieved fields are mapped to the screen input structure and sent to the terminal

**Phase 2 — Receive Edits and Submit Update:**
- Immediately after sending the inquiry result, a second `EXEC CICS RECEIVE MAP` reads the user's amended data back from the terminal (within the same task activation — no pseudo-conversational break between display and re-read)
- `CA_REQUEST_ID` is changed to `'01UCUS'`; `CA_CUSTOMER_NUM` is refreshed from `ENT1CNOI` (the field the user may have corrected)
- All customer fields are copied back from the screen to the COMMAREA (same mapping as Option 2)
- Null-byte replacement and postcode uppercase conversion are performed again
- `EXEC CICS LINK PROGRAM('LGUCUS01')` is called for the update back-end
- If `CA_RETURN_CODE > 0`, control goes to `NO_UPD`
- On success, `ENT1CNOI` is refreshed, `ENT1OPTI` cleared, `ERRFLDO` set to `'Customer details updated'`, and the screen is re-sent before entering the pseudo-conversational return

---

### 4.7 Invalid Option Handling

- If `ENT1OPTO` does not match `'1'`, `'2'`, or `'4'`, the `OTHERWISE` branch executes:
  - `ERRFLDO` is set to `'Please enter a valid option'`
  - `ENT1OPTL` is set to `-1` (highlights the option field on the BMS screen)
  - The screen is re-sent with the `CURSOR` option to position the cursor at the option field
  - Control goes to `ENDIT_STARTIT` for pseudo-conversational return

---

### 4.8 Error Handling Labels

- **`NO_DATA`** — sets `ERRFLDO = 'No data was returned.'`, then falls through to `ERROR_OUT`
- **`NO_ADD`** — sets `ERRFLDO = 'Error Adding Customer'`, then falls through to `ERROR_OUT`
- **`NO_UPD`** — sets `ERRFLDO = 'Error Updating Customer'`, then falls through to `ERROR_OUT`
- **`ERROR_OUT`** — common error exit:
  - Sends the current map (with the error message in `ERRFLDO`) to the terminal
  - Clears both screen map structures (`SSMAPC1I`, `SSMAPC1O`)
  - Resets the entire COMMAREA raw area, `CA_REQUEST_ID`, `CA_RETURN_CODE`, `CA_CUSTOMER_NUM`, and `CA_REQUEST_INITIALISER` to zero/spaces, wiping any partial data
  - Branches to `ENDIT_STARTIT` for pseudo-conversational return

---

### 4.9 Terminal Session Control Labels

- **`ENDIT_STARTIT`** — `EXEC CICS RETURN TRANSID('SSC1') COMMAREA(COMM_AREA)` suspends the task but re-specifies transaction `SSC1` and saves the COMMAREA so the next user action re-enters this program with its state intact (pseudo-conversational design)
- **`ENDIT`** — sends the static text `'Transaction ended'` to the terminal with `ERASE FREEKB`, then issues a plain `EXEC CICS RETURN` to end the transaction entirely; reached via PF3, CLEAR+PF3, or MAPFAIL
- **`CLEARIT`** — clears `SSMAPC1I` to spaces, sends the map with `MAPONLY` (screen definition only, no data), then issues `EXEC CICS RETURN TRANSID('SSC1') COMMAREA(COMM_AREA)` to stay in the transaction with a blank screen

---

### 4.10 WRITE_GENACNTL Internal Procedure — TS Queue Maintenance

- Called only after a successful customer add to record the new customer number in the `GENACNTL` temporary storage queue
- **Serialization**: `EXEC CICS ENQ RESOURCE('GENACNTL')` acquires an exclusive enqueue on the queue name before any read/write; `EXEC CICS DEQ` releases it at the end, preventing concurrent updates from colliding
- **Initialization**: `WS_FLAG_TSQH = 'Y'` (flag indicating the HIGH CUSTOMER record has not yet been found/updated); `WS_ITEM_COUNT = 1`
- **Read and search loop**:
  - The first item (`ITEM(1)`) of the `GENACNTL` queue is read; if successful (`DFHRESP(NORMAL)`), a `DO WHILE (WS_RESP = 0)` loop iterates through subsequent items using `READQ TS NEXT`
  - Inside each iteration, `WS_ITEM_COUNT` is incremented; if the item's first 13 characters match `'HIGH CUSTOMER'`, the high-customer field is found:
    - `WRITE_MSG_HIGH` is set to `CA_CUSTOMER_NUM` (the newly assigned customer number)
    - `WS_FLAG_TSQH` is cleared to `' '` to mark the record as found
    - `EXEC CICS WRITEQ TS ... REWRITE ITEM(WS_ITEM_COUNT)` overwrites that specific queue item in place with 24 bytes of updated high-customer data
    - `WS_RESP` is forced to `99` to break out of the `DO WHILE` loop
- **New queue initialization** (if the HIGH CUSTOMER record was never found, `WS_FLAG_TSQH` still `'Y'`):
  - Three new items are written sequentially with `NOSUSPEND`:
    1. A header record (`WRITE_MSG_E`: `'**** GENAPP CNTL    '`, 20 bytes)
    2. A LOW CUSTOMER record (`WRITE_MSG_L`: `'LOW CUSTOMER='` + the new number, 23 bytes); both `WRITE_MSG_LOW` and `WRITE_MSG_HIGH` are set to `CA_CUSTOMER_NUM` first
    3. A HIGH CUSTOMER record (`WRITE_MSG_H`: `'HIGH CUSTOMER='` + the new number, 24 bytes)
- **Release**: `EXEC CICS DEQ RESOURCE('GENACNTL')` unconditionally releases the enqueue

## 5. Paragraphs

- **Main Procedure Entry / First-Call Initialization (lines 709–731)**
  - Executed only when `EIBCALEN = 0`, meaning the program is being invoked for the very first time (no existing COMMAREA from a prior transaction cycle).
  - Sets `COMM_AREA_PTR` to the address of a local base area, initialises both BMS map structures (`SSMAPC1I` and `SSMAPC1O`) to spaces, clears `CA_REQUEST_ID`, zeros `CA_RETURN_CODE` and `CA_CUSTOMER_NUM`, spaces out `CA_REQUEST_INITIALISER`, and pre-fills the customer number output field `ENT1CNOO` with ten zeros.
  - Sends the customer menu BMS map (`SSMAPC1` from mapset `SSMAP`) with the ERASE option to paint a clean screen, then falls through to `A_GAIN`.

---

- **A_GAIN — Main Input / Dispatch Loop (lines 733–869)**
  - This is the primary re-entry point for the pseudo-conversational transaction `SSC1`. Every time the user presses a key, CICS re-invokes the program and control arrives here.
  - Registers attention identifier (AID) handlers: CLEAR key routes to `CLEARIT`; PF3 routes to `ENDIT`. Registers a MAPFAIL condition handler routing to `ENDIT` in case no data is returned from the screen.
  - Issues `EXEC CICS RECEIVE MAP` to read the `SSMAPC1` map from the terminal into `SSMAPC1I`, capturing all customer field inputs and the option code (`ENT1OPTO`).
  - Uses a `SELECT (ENT1OPTO)` statement to dispatch on the option entered by the user:
    - **Option '1' — Customer Inquiry:**
      - Sets `CA_REQUEST_ID = '01ICUS'` and loads the customer number from `ENT1CNOO` into `CA_CUSTOMER_NUM`.
      - Issues `EXEC CICS LINK PROGRAM('LGICUS01')` passing the full 32,500-byte COMMAREA.
      - If `CA_RETURN_CODE > 0`, branches via `GO TO NO_DATA`.
      - On success, maps all returned customer fields (name, DOB, address, phone, email) from COMMAREA back into screen input fields, sends the refreshed map, then transfers via `GO TO ENDIT_STARTIT`.
    - **Option '2' — Customer Add:**
      - Sets `CA_REQUEST_ID = '01ACUS'`, zeros `CA_CUSTOMER_NUM`, and copies all screen input fields (first name, last name, DOB, house name/number, postcode, phones, email) into their COMMAREA counterparts.
      - Performs a bulk null-to-space conversion via `TRANSLATE(COMM_AREA_RAW,' ','00'X)` and uppercases `CA_POSTCODE` using the `UPPERCASE` built-in.
      - Links to `LGACUS01`. If the return code is non-zero, issues `EXEC CICS SYNCPOINT ROLLBACK` to undo any partial DB2 updates, then branches to `NO_ADD`.
      - On success, calls the internal `WRITE_GENACNTL` procedure to update the GENACNTL TS queue, maps the newly assigned customer number back to `ENT1CNOI`, clears the option field, sets a confirmation message in `ERRFLDO`, sends the map, and transfers via `GO TO ENDIT_STARTIT`.
    - **Option '4' — Customer Update:**
      - Performs a two-step interaction. First sets `CA_REQUEST_ID = '01ICUS'` and links to `LGICUS01` to fetch the existing customer record. If that fails (`CA_RETURN_CODE > 0`), branches to `NO_DATA`.
      - Populates the screen with current customer data and sends the map, then immediately issues a second `EXEC CICS RECEIVE MAP` to wait for the user's edited submission.
      - Sets `CA_REQUEST_ID = '01UCUS'`, reloads COMMAREA with the newly entered values, applies null-to-space translation and postcode uppercasing, then links to `LGUCUS01`. If `CA_RETURN_CODE > 0`, branches to `NO_UPD`.
      - On success, maps the customer number to the screen, sets a confirmation message, sends the map, and transfers via `GO TO ENDIT_STARTIT`.
    - **OTHERWISE — Invalid Option:**
      - Writes `'Please enter a valid option'` into `ERRFLDO`, sets `ENT1OPTL = -1` (marks the option field for cursor positioning), sends the map with the CURSOR option, and transfers via `GO TO ENDIT_STARTIT`.

---

- **ENDIT_STARTIT — Pseudo-Conversational Return (line 875–878)**
  - Issues `EXEC CICS RETURN TRANSID('SSC1') COMMAREA(COMM_AREA)` to terminate the current task and schedule reactivation of transaction `SSC1` when the user next presses a key, passing the COMMAREA forward so state is preserved across the pseudo-conversational cycle.

---

- **ENDIT — Terminal Session End (lines 880–886)**
  - Triggered when the user presses PF3 or when a MAPFAIL condition occurs (no user input).
  - Sends the static text message `'Transaction ended'` to the terminal with the ERASE and FREEKB options (frees the keyboard).
  - Issues a plain `EXEC CICS RETURN` with no TRANSID, terminating the transaction session entirely without re-scheduling.

---

- **CLEARIT — Screen Clear Handler (lines 888–897)**
  - Triggered when the user presses the CLEAR key.
  - Initialises `SSMAPC1I` to spaces and sends the map using the MAPONLY option, which repaints the screen from the map definition only (no application data merged in), effectively presenting a blank customer menu.
  - Issues `EXEC CICS RETURN TRANSID('SSC1') COMMAREA(COMM_AREA)` to remain in the pseudo-conversational cycle.

---

- **NO_UPD — Update Error Handler (lines 899–901)**
  - Sets the error message text `'Error Updating Customer'` into `ERRFLDO` and falls through to `ERROR_OUT` via `GO TO ERROR_OUT`.

---

- **NO_ADD — Add Error Handler (lines 903–905)**
  - Sets the error message text `'Error Adding Customer'` into `ERRFLDO` and falls through to `ERROR_OUT` via `GO TO ERROR_OUT`.

---

- **NO_DATA — Inquiry Error Handler (lines 907–909)**
  - Sets the error message text `'No data was returned.'` into `ERRFLDO` and falls through to `ERROR_OUT` via `GO TO ERROR_OUT`.

---

- **ERROR_OUT — Centralised Error Recovery and Display (lines 911–924)**
  - Common exit point reached from `NO_UPD`, `NO_ADD`, and `NO_DATA` after an appropriate error message has been set in `ERRFLDO`.
  - Sends the current `SSMAPC1O` map back to the terminal so the user sees the error message alongside the data they entered.
  - Resets both BMS map structures, `COMM_AREA_RAW`, `CA_REQUEST_ID`, `CA_RETURN_CODE`, `CA_CUSTOMER_NUM`, and `CA_REQUEST_INITIALISER` all to their initial/zero values, clearing any tainted state.
  - Branches to `ENDIT_STARTIT` to keep the transaction alive and await the next user interaction.

---

- **WRITE_GENACNTL — GENACNTL TS Queue Update Procedure (lines 929–984)**
  - An internal `PROCEDURE` (subroutine) called after a successful customer add to record the newly assigned customer number in the `GENACNTL` CICS temporary storage queue.
  - Acquires exclusive access to the queue by issuing `EXEC CICS ENQ RESOURCE(STSQ_NAME)` using `STSQ_NAME = 'GENACNTL'` as the enqueue resource name, preventing concurrent updates.
  - Sets `WS_FLAG_TSQH = 'Y'` as a "not yet found" indicator, then reads item 1 of the TS queue. If the read is successful (`DFHRESP(NORMAL)`), enters a `DO WHILE` loop that reads subsequent items using the NEXT option.
    - For each item read, increments `WS_ITEM_COUNT`. If the record begins with `'HIGH CUSTOMER'`, it updates `WRITE_MSG_HIGH` with `CA_CUSTOMER_NUM`, clears the flag to `' '`, and rewrites that specific item back to the queue using `EXEC CICS WRITEQ TS … REWRITE ITEM(WS_ITEM_COUNT)`. Sets `WS_RESP = 99` to force loop exit.
  - If after the loop `WS_FLAG_TSQH` is still `'Y'` (the HIGH CUSTOMER record was never found, i.e., the queue was empty or did not contain the expected record), it writes three new queue entries: a header record (`WRITE_MSG_E = '**** GENAPP CNTL    '`), a LOW CUSTOMER record, and a HIGH CUSTOMER record — both low and high are initialised to `CA_CUSTOMER_NUM`.
  - Releases the enqueue lock with `EXEC CICS DEQ RESOURCE(STSQ_NAME)` before returning.

## 6. Dependencies

### 6.1 CICS Transaction & Runtime

- **CICS Transaction `SSC1`** — The owning transaction ID under which the program executes. On each conversational return (`EXEC CICS RETURN TRANSID('SSC1')`) the transaction is re-initiated, maintaining state through the COMMAREA.
- **EIBCALEN (Execute Interface Block field)** — Read at program entry to determine whether this is the first invocation (length = 0) or a subsequent pass-through; drives the initialisation versus normal-processing path.
- **DFHRESP built-in value (`DFHRESP(NORMAL)`)** — Used to test the response code from CICS TS queue reads inside `WRITE_GENACNTL`.

---

### 6.2 BMS Maps & Mapset

- **Mapset `SSMAP`** — The BMS mapset containing the customer menu screen definitions. Every `EXEC CICS SEND MAP` and `EXEC CICS RECEIVE MAP` references this mapset name.
  - **Map `SSMAPC1`** — The customer menu map (input structure `SSMAPC1I`, output overlay `SSMAPC1O`) used for all customer-screen interactions (send, receive, send maponly, cursor positioning).
  - *Additional maps* (`SSMAPP1`–`SSMAPP5`) — Declared via the inline expansion of `%INCLUDE SSMAP` (`plinc/SSMAP.inc`); their input/output structures (`SSMAPP1I/O` through `SSMAPP5I/O`) are defined in the program but not directly used in the current logic flow.

---

### 6.3 Copybook / Include Members

- **`SSMAP` (`plinc/SSMAP.inc`)** — BMS symbolic map include; supplies the `SSMAPC1I/O` and `SSMAPP1I/O`–`SSMAPP5I/O` structure declarations mapped to the terminal screen fields.
- **`LGCMAREA` (`plinc/LGCMAREA.inc`)** — Communication-area copybook; defines the `COMM_AREA` UNION structure (32 500 bytes) used as the interface contract between this front-end program and all backend programs.

---

### 6.4 External Programs (CICS LINK targets)

- **`LGICUS01`** — Customer inquiry back-end program. Called with request ID `01ICUS` to retrieve an existing customer record by customer number; returns customer details in `CA_CUSTOMER_REQUEST` fields and a `CA_RETURN_CODE` indicating success or failure.
- **`LGACUS01`** — Customer add back-end program. Called with request ID `01ACUS` to insert a new customer record; returns the newly assigned `CA_CUSTOMER_NUM` on success or a non-zero `CA_RETURN_CODE` on failure (triggering a `SYNCPOINT ROLLBACK`).
- **`LGUCUS01`** — Customer update back-end program. Called with request ID `01UCUS` to update an existing customer's details; returns a non-zero `CA_RETURN_CODE` on failure.
- *(Commented-out)* **`ADDIPGM1`** — An initialisation program that was originally called on the first transaction invocation to set up counters; currently disabled in the source.

---

### 6.5 CICS Temporary Storage (TS) Queue

- **TS Queue `GENACNTL`** (variable `STSQ_NAME`)** — A CICS auxiliary temporary-storage queue used to track the high-water customer number range. Read and written by the internal `WRITE_GENACNTL` procedure after a successful customer add; contains `**** GENAPP CNTL`, `LOW CUSTOMER=`, and `HIGH CUSTOMER=` records.

---

### 6.6 CICS Enqueue / Serialisation Resource

- **ENQ/DEQ Resource `GENACNTL`** — The same 8-character name is used as a CICS enqueue resource (via `EXEC CICS ENQ` / `EXEC CICS DEQ`) to serialise concurrent updates to the `GENACNTL` TS queue during customer-add operations.

---

### 6.7 CICS AID Key & Condition Handlers

- **AID key `CLEAR`** — Mapped to label `CLEARIT`; clears the screen and re-displays the customer menu map, then returns with transaction `SSC1`.
- **AID key `PF3`** — Mapped to label `ENDIT`; terminates the transaction by sending a plain text end-of-transaction message and issuing `EXEC CICS RETURN`.
- **Condition `MAPFAIL`** — Handled by `EXEC CICS HANDLE CONDITION MAPFAIL(ENDIT)`; routes to the normal end path when no data is entered on the screen.

---

### 6.8 Communication Area (COMMAREA)

- **`COMM_AREA` / `COMM_AREA_PTR`** — A 32 500-byte structure passed on every `EXEC CICS LINK` and every `EXEC CICS RETURN COMMAREA(...)` call. It carries the request ID, return code, customer number, and all customer data fields between this program and its callers/callees. Defined by the `LGCMAREA` copybook.

## 7. Constraints

### 7.1 Menu Option Validation

- The user-entered option field `ENT1OPTO` (CHAR(1)) is evaluated via a `SELECT` statement; only values `'1'`, `'2'`, and `'4'` are accepted as valid operations.
  - Option `'1'` routes to customer inquiry (links to `LGICUS01`).
  - Option `'2'` routes to customer add (links to `LGACUS01`).
  - Option `'4'` routes to customer update (links to `LGUCUS01`).
  - Any other value falls into the `OTHERWISE` branch, sets `ERRFLDO = 'Please enter a valid option'`, highlights the option field (`ENT1OPTL = -1`), and re-displays the map without forwarding to any backend program. Options `'3'` and `'5'`–`'9'` (and any non-numeric character) are explicitly rejected this way.

### 7.2 COMMAREA Presence Constraint (EIBCALEN = 0 Check)

- The program tests `EIBCALEN = 0` immediately at procedure entry (line 709).
  - If `EIBCALEN = 0`, the transaction is treated as its very first invocation: a local `BASE_COMM_AREA` buffer is used as the backing store (`COMM_AREA_PTR = ADDR(BASE_COMM_AREA)`), all COMMAREA fields are initialized to zero/spaces, `ENT1CNOO` is set to `'0000000000'`, and the map is sent with `ERASE` to clear the screen.
  - Subsequent invocations pass a non-zero `EIBCALEN` with a real COMMAREA (carried via `EXEC CICS RETURN TRANSID('SSC1') COMMAREA(COMM_AREA)`), and initialization is skipped.
  - This ensures the program never operates against an uninitialized COMMAREA on a cold start.

### 7.3 COMMAREA Size Constraint

- Every `EXEC CICS LINK` call to the three backend programs (`LGICUS01`, `LGACUS01`, `LGUCUS01`) specifies a fixed `LENGTH(32500)`.
  - The COMMAREA structure `COMM_AREA` is declared with `COMM_AREA_RAW CHAR(32500)` as its raw overlay, meaning exactly 32,500 bytes are always passed.
  - Backends that receive a shorter COMMAREA would not see the complete data; the hard-coded length enforces that no partial buffer is ever transmitted.

### 7.4 Customer Number Format Constraint

- `CA_CUSTOMER_NUM` is declared as `PIC '9999999999'` — a 10-digit numeric picture — enforcing that only non-negative integer values in the range 0–9,999,999,999 can be stored.
  - For inquiry (option `'1'`) and the first phase of update (option `'4'`), the customer number is taken directly from the screen field `ENT1CNOO` (CHAR(10)); no separate numeric-content validation is performed in the program before passing it to the backend.
  - For add (option `'2'`), `CA_CUSTOMER_NUM` is reset to `0` before calling `LGACUS01`, meaning the program does not allow the user to supply a customer number on an add operation — the number is assigned by the backend and returned.

### 7.5 Null-Byte Sanitisation Constraint (Add and Update Only)

- Before linking to `LGACUS01` (add, line 784) and `LGUCUS01` (update, line 841), the entire `COMM_AREA_RAW CHAR(32500)` buffer is passed through `TRANSLATE(COMM_AREA_RAW,' ','00'X)`, replacing every null byte (`'00'X`) with a space.
  - This constraint is **not** applied for option `'1'` (inquiry), because the inquiry path sends the customer number only and the returned data is copied field-by-field.
  - Failing to translate nulls would corrupt the COMMAREA seen by the backend DB2/VSAM programs that process character fields.

### 7.6 Postcode Uppercase Constraint (Add and Update Only)

- `CA_POSTCODE = UPPERCASE(CA_POSTCODE)` is executed after the null-translation step for both add (line 785) and update (line 842).
  - The postcode received from screen field `ENT1HPCI` (CHAR(8)) is unconditionally converted to uppercase before being passed to the backend.
  - No lowercase postcode value is ever stored via this menu; the constraint is structural and cannot be bypassed by the terminal user.

### 7.7 Backend Return-Code Gate

- After each `EXEC CICS LINK`, `CA_RETURN_CODE` (declared `PIC '99'`, a 2-digit numeric picture) is tested: if it is greater than zero, processing diverges to an error label before any screen update or further data manipulation occurs.
  - Inquiry failure (`CA_RETURN_CODE > 0` after `LGICUS01`) → `GO TO NO_DATA`; the map data from the backend is discarded and an error message is shown.
  - Add failure (`CA_RETURN_CODE > 0` after `LGACUS01`) → `EXEC CICS SYNCPOINT ROLLBACK` is issued first, then `GO TO NO_ADD`; this ensures any uncommitted database changes are rolled back before the error response is sent.
  - Update failure (`CA_RETURN_CODE > 0` after `LGUCUS01`) → `GO TO NO_UPD`; no explicit rollback is coded here (rollback is implied or handled by the backend).
  - In all error cases `WRITE_GENACNTL` is not called; the TS queue tracking the high customer number is only updated on a confirmed successful add.

### 7.8 Update Sequencing Constraint (Two-Step Verify-Then-Modify)

- Option `'4'` (update) enforces a mandatory two-step sequence:
  1. An inquiry is first performed by linking to `LGICUS01` with `CA_REQUEST_ID = '01ICUS'`; if it returns `CA_RETURN_CODE > 0` the update is aborted with `GO TO NO_DATA` before any edits are attempted.
  2. Only after a successful inquiry are the current record values sent to the screen, a second `EXEC CICS RECEIVE MAP` is issued to collect edits, the COMMAREA is repopulated with updated values, and `LGUCUS01` is called with `CA_REQUEST_ID = '01UCUS'`.
  - This means it is impossible to submit an update for a customer that cannot be found; the record must be verified as existing before the update LINK is issued.

### 7.9 TS Queue Serialisation Constraint (WRITE_GENACNTL)

- The `WRITE_GENACNTL` procedure wraps all reads and writes to the `GENACNTL` TS queue inside an `EXEC CICS ENQ … RESOURCE(STSQ_NAME)` / `EXEC CICS DEQ … RESOURCE(STSQ_NAME)` pair.
  - No other task can update the GENACNTL queue entries while this task holds the enqueue; this prevents two concurrent add transactions from writing the same "HIGH CUSTOMER" value.
  - `WRITE_GENACNTL` is called exclusively after a confirmed successful add (non-zero `CA_RETURN_CODE` causes `GO TO NO_ADD` before the call), so the queue is never updated for failed transactions.

### 7.10 TS Queue Record-Length Constraints (WRITE_GENACNTL)

- When writing to the GENACNTL TS queue, three fixed record lengths are enforced:
  - Header record `WRITE_MSG_E` is written with `LENGTH(20)` (value `'**** GENAPP CNTL    '`).
  - Low-customer record `WRITE_MSG_L` (header + 10-digit number) is written with `LENGTH(23)`.
  - High-customer record `WRITE_MSG_H` (header + 10-digit number) is written with `LENGTH(24)`.
  - Rewriting an existing high-customer entry also uses `LENGTH(24)`. Any mismatch between these lengths and the actual structure widths would corrupt the queue record.

### 7.11 TS Queue Search Constraint (HIGH CUSTOMER Token)

- The loop in `WRITE_GENACNTL` identifies the high-customer record by testing `SUBSTR(READ_MSG_MSG,1,13) = 'HIGH CUSTOMER'`.
  - Only a queue item whose first 13 characters match this literal exactly is eligible for rewrite; all other items are skipped.
  - If no such item is found (`WS_FLAG_TSQH` remains `'Y'` after the loop), all three records (header, low, high) are written fresh using `NOSUSPEND`, meaning the write fails silently rather than suspending the task if the queue is full.

### 7.12 AID Key and Map-Failure Constraints

- `EXEC CICS HANDLE AID CLEAR(CLEARIT) PF3(ENDIT)` intercepts two special terminal actions before the map is received:
  - Pressing **CLEAR** routes to `CLEARIT`, which blanks the map data and re-displays the map using `MAPONLY` before returning with `TRANSID('SSC1')` — effectively restarting the screen without processing any input.
  - Pressing **PF3** routes to `ENDIT`, which sends the "Transaction ended" text and issues `EXEC CICS RETURN` without a `TRANSID`, ending the transaction entirely.
- `EXEC CICS HANDLE CONDITION MAPFAIL(ENDIT)` ensures that if `EXEC CICS RECEIVE MAP` finds no modified fields (e.g., the user pressed Enter on an empty screen), the program exits cleanly via `ENDIT` rather than attempting to process blank input.

### 7.13 State Reset on Error

- After displaying an error message at `ERROR_OUT`, the program resets the following fields before re-entering the pseudo-conversational loop:
  - `SSMAPC1I` and `SSMAPC1O` cleared to spaces.
  - `COMM_AREA_RAW` cleared to spaces (wiping all COMMAREA content).
  - `CA_REQUEST_ID` cleared to spaces.
  - `CA_RETURN_CODE` reset to `0`.
  - `CA_CUSTOMER_NUM` reset to `0`.
  - `CA_REQUEST_INITIALISER` cleared to spaces.
  - The transaction then returns via `GO TO ENDIT_STARTIT` (which issues `EXEC CICS RETURN TRANSID('SSC1') COMMAREA(COMM_AREA)`), ensuring a clean COMMAREA is passed to the next invocation.

### 7.14 Field-Width (Buffer-Size) Constraints

- Screen fields impose maximum lengths on data passed to the backend:
  - First name (`ENT1FNAI` / `CA_FIRST_NAME`): 10 characters.
  - Last name (`ENT1LNAI` / `CA_LAST_NAME`): 20 characters.
  - Date of birth (`ENT1DOBI` / `CA_DOB`): 10 characters.
  - House name (`ENT1HNMI` / `CA_HOUSE_NAME`): 20 characters.
  - House number (`ENT1HNOI` / `CA_HOUSE_NUM`): 4 characters.
  - Postcode (`ENT1HPCI` / `CA_POSTCODE`): 8 characters.
  - Home phone (`ENT1HP1I` / `CA_PHONE_HOME`): 20 characters.
  - Mobile phone (`ENT1HP2I` / `CA_PHONE_MOBILE`): 20 characters.
  - Email address (`ENT1HMOI` / `CA_EMAIL_ADDRESS`): declared 27 characters in the BMS map (`ENT1HMOI CHAR(27)`) but 100 characters in the COMMAREA (`CA_EMAIL_ADDRESS CHAR(100)`); only the first 27 characters visible on screen are ever populated from the map — longer email addresses cannot be entered or displayed via this interface.
  - The option field (`ENT1OPTI` / `ENT1OPTO`): 1 character, restricting the selectable option to a single character.

## 8. Error Handling

### 8.1 Backend Return Code Checks

- **`CA_RETURN_CODE` inspection after EXEC CICS LINK** — After each call to a backend program (LGICUS01, LGACUS01, LGUCUS01), the value of `CA_RETURN_CODE` is tested with an `IF CA_RETURN_CODE > 0 THEN` condition. A non-zero value indicates that the backend encountered a processing error. Control is transferred via `GO TO` to one of three dedicated error labels depending on the operation:
  - `NO_DATA` — triggered when the customer inquiry (LGICUS01) returns no results, for both option '1' (inquiry) and option '4' (update pre-check)
  - `NO_ADD` — triggered when the customer add (LGACUS01) fails
  - `NO_UPD` — triggered when the customer update (LGUCUS01) fails

### 8.2 Transaction Rollback on Add Failure

- **`EXEC CICS SYNCPOINT ROLLBACK` on add error** — When a non-zero `CA_RETURN_CODE` is detected after calling LGACUS01, the program issues an `EXEC CICS SYNCPOINT ROLLBACK` before branching to `NO_ADD`. This rolls back any recoverable resources updated within the current unit of work, preventing partial or corrupt data from being committed as a result of a failed add operation.

### 8.3 Centralised Error Output and State Reset

- **Shared `ERROR_OUT` label** — The three error labels (`NO_DATA`, `NO_ADD`, `NO_UPD`) each set a descriptive error message string in the BMS output field `ERRFLDO` and then fall through via `GO TO ERROR_OUT` to a single shared error-handling block. This centralises error display and recovery:
  - The error message is sent to the terminal by issuing `EXEC CICS SEND MAP` so the user sees the reason for failure on the customer menu screen
  - The entire communication area and screen structures are reset to their initialised state: `SSMAPC1I`, `SSMAPC1O`, and `COMM_AREA_RAW` are set to spaces; `CA_REQUEST_ID`, `CA_REQUEST_INITIALISER` are blanked; `CA_RETURN_CODE` and `CA_CUSTOMER_NUM` are set to zero
  - Control is then passed to `ENDIT_STARTIT`, which issues `EXEC CICS RETURN TRANSID('SSC1')`, keeping the transaction alive for the next user interaction

### 8.4 CICS Attention Identifier (AID) and Condition Handling

- **`EXEC CICS HANDLE AID CLEAR(CLEARIT)` and `PF3(ENDIT)`** — Registered at the `A_GAIN` label before each map receive. If the user presses the CLEAR key, control is passed to the `CLEARIT` label, which blanks the screen and returns the transaction to await a fresh interaction. If the user presses PF3, control transfers to the `ENDIT` label, which ends the transaction gracefully.
- **`EXEC CICS HANDLE CONDITION MAPFAIL(ENDIT)`** — Established alongside the AID handler. If the subsequent `EXEC CICS RECEIVE MAP` raises a MAPFAIL condition (e.g., no data entered by the user, or the map cannot be matched), control is automatically routed to `ENDIT`, preventing an unhandled CICS exception and cleanly terminating the transaction.

### 8.5 Invalid Option Handling

- **`OTHERWISE` branch in the `SELECT` statement** — When the value of `ENT1OPTO` (the option field from the screen) does not match any of the valid values ('1', '2', '4'), the `OTHERWISE` block executes. It sets `ERRFLDO` to the message `'Please enter a valid option'`, sets the cursor to the option field by writing a `-1` into `ENT1OPTL`, and re-sends the map so the user can correct their input. The transaction is then kept alive via `ENDIT_STARTIT`.

### 8.6 First-Call / Missing COMMAREA Guard

- **`IF EIBCALEN = 0` check at program entry** — When the program is first invoked without a passed communication area (EIBCALEN equals zero), the program initialises all working-storage fields and COMMAREA overlays to their default values (spaces or zero), and displays the initial customer menu. This guards against attempting to use uninitialised or absent COMMAREA data on a cold start.

### 8.7 Graceful Transaction Termination

- **`ENDIT` label** — Reached either via PF3 or MAPFAIL, this label sends a `'Transaction ended'` text message to the terminal using `EXEC CICS SEND TEXT` with the `ERASE` and `FREEKB` options, then issues `EXEC CICS RETURN` with no TRANSID, fully ending the transaction. This acts as a clean shutdown path.
- **`CLEARIT` label** — Reached via the CLEAR key, this path clears the screen and returns the transaction control to the user by issuing `EXEC CICS RETURN TRANSID('SSC1')` with the COMMAREA, allowing a fresh entry without terminating the transaction.

### 8.8 TS Queue Serialisation and Conditional Write Logic in `WRITE_GENACNTL`

- **`EXEC CICS ENQ` / `EXEC CICS DEQ` for mutual exclusion** — The `WRITE_GENACNTL` internal procedure acquires an exclusive enqueue on the `GENACNTL` TS queue resource name before performing any read or write operations, and releases it via DEQ upon completion. This prevents concurrent transactions from corrupting the high customer number record simultaneously.
- **`RESP(WS_RESP)` and `DFHRESP(NORMAL)` checks on TS queue reads** — After the initial `EXEC CICS READQ TS` call, `WS_RESP` is compared to `DFHRESP(NORMAL)` to determine whether the queue exists and could be read successfully. The read loop continues only while `WS_RESP = 0` (i.e., NORMAL), preventing iteration over failed or end-of-queue responses.
- **`WS_FLAG_TSQH` fallback for missing queue records** — The flag is initialised to `'Y'` at the start of `WRITE_GENACNTL`. It is only cleared to a space if the 'HIGH CUSTOMER' record is found and successfully rewritten. If the flag remains `'Y'` after the read loop (meaning the queue was empty or the record was not found), the procedure falls back to creating fresh queue entries for the low and high customer number records. This ensures the TS queue is always left in a consistent state.

## 9. Examples

### 9.1 Example 1 — Customer Inquiry (Option 1)

**Input:**
| Screen Field | Value |
|---|---|
| `ENT1OPTO` (option) | `'1'` |
| `ENT1CNOO` (customer number) | `0000000042` |

**Processing:**
1. The `SELECT (ENT1OPTO)` branches to the `WHEN ('1')` block.
2. `CA_REQUEST_ID` is set to `'01ICUS'` and `CA_CUSTOMER_NUM` is loaded from `ENT1CNOO` (`42`).
3. `EXEC CICS LINK PROGRAM('LGICUS01')` is issued with the 32,500-byte COMMAREA.
4. `LGICUS01` locates customer 42 and returns `CA_RETURN_CODE = 00` along with the customer's data.
5. The returned fields are mapped back to screen output fields (`ENT1FNAI`, `ENT1LNAI`, `ENT1DOBI`, address, phone, and email).
6. `EXEC CICS SEND MAP ('SSMAPC1')` refreshes the screen with the retrieved data.
7. `EXEC CICS RETURN TRANSID('SSC1')` suspends the task, passing the COMMAREA forward.

**Expected Output (screen):**
| Screen Field | Value (illustrative) |
|---|---|
| `ENT1FNAO` | `John` |
| `ENT1LNAO` | `Smith` |
| `ENT1DOBO` | `1980-05-12` |
| `ENT1HPCO` | `SW1A 1AA` |
| `ENT1HP1O` | `02071234567` |
| `ENT1HP2O` | `07700900123` |
| `ENT1HMOO` | `john.smith@example.com` |

If `CA_RETURN_CODE > 0` is returned by `LGICUS01`, the program branches to `NO_DATA`, sets `ERRFLDO = 'No data was returned.'`, and redisplays the map before resetting all COMMAREA fields.

---

### 9.2 Example 2 — Add New Customer (Option 2)

**Input:**
| Screen Field | Value |
|---|---|
| `ENT1OPTO` (option) | `'2'` |
| `ENT1FNAI` | `Jane` |
| `ENT1LNAI` | `Doe` |
| `ENT1DOBI` | `1995-03-22` |
| `ENT1HNMI` | `Rose Cottage` |
| `ENT1HNOI` | `10` |
| `ENT1HPCI` | `ec1a 1bb` *(lowercase)* |
| `ENT1HP1I` | `01234567890` |
| `ENT1HP2I` | `07911123456` |
| `ENT1HMOI` | `jane.doe@example.com` |

**Processing:**
1. `SELECT (ENT1OPTO)` branches to `WHEN ('2')`.
2. `CA_REQUEST_ID = '01ACUS'`, `CA_CUSTOMER_NUM = 0`.
3. All screen fields are copied into the COMMAREA customer request fields.
4. `TRANSLATE(COMM_AREA_RAW, ' ', '00'X)` replaces any null bytes in the 32,500-byte area with spaces to avoid issues in the downstream program.
5. `CA_POSTCODE = UPPERCASE(CA_POSTCODE)` converts `'ec1a 1bb'` → `'EC1A 1BB'`.
6. `EXEC CICS LINK PROGRAM('LGACUS01')` inserts the new customer. On success (`CA_RETURN_CODE = 0`), the program calls `WRITE_GENACNTL` to update the `GENACNTL` TS queue with the newly assigned customer number.
7. The new `CA_CUSTOMER_NUM` (assigned by the backend) is written back to `ENT1CNOI`, the option field is blanked, and `ERRFLDO` is set to `'New Customer Inserted'`.
8. The map is sent and the transaction re-starts with `TRANSID('SSC1')`.

**Expected Output (screen):**
| Screen Field | Value |
|---|---|
| `ENT1CNOO` | `0000000099` *(new customer number assigned by LGACUS01)* |
| `ERRFLDO` | `New Customer Inserted` |
| `ENT1HPCO` | `EC1A 1BB` *(uppercased)* |

If `LGACUS01` returns `CA_RETURN_CODE > 0`, a `SYNCPOINT ROLLBACK` is issued, `ERRFLDO` is set to `'Error Adding Customer'`, and the map is redisplayed with all COMMAREA fields reset.

---

### 9.3 Example 3 — Update Customer (Option 4)

**Input (first screen interaction):**
| Screen Field | Value |
|---|---|
| `ENT1OPTO` | `'4'` |
| `ENT1CNOO` | `0000000099` |

**Processing:**
1. `WHEN ('4')` first performs an inquiry: `CA_REQUEST_ID = '01ICUS'`, links to `LGICUS01` to fetch current data for customer 99.
2. The current customer data is populated into the screen fields and the map is sent back so the user can review and modify values.
3. A second `EXEC CICS RECEIVE MAP` reads the user's edited fields.
4. `CA_REQUEST_ID = '01UCUS'` is set and the modified field values are loaded back into the COMMAREA. Null-byte translation and `UPPERCASE` conversion of the postcode are applied.
5. `EXEC CICS LINK PROGRAM('LGUCUS01')` performs the update. On success, `ERRFLDO = 'Customer details updated'` is displayed.

**Expected Output (screen after update):**
| Screen Field | Value |
|---|---|
| `ENT1CNOO` | `0000000099` |
| `ERRFLDO` | `Customer details updated` |

If `LGICUS01` returns a non-zero return code at the inquiry step, the program jumps to `NO_DATA` and displays `'No data was returned.'`. If `LGUCUS01` fails, it jumps to `NO_UPD` and displays `'Error Updating Customer'`.

---

### 9.4 Example 4 — Invalid Option

**Input:**
| Screen Field | Value |
|---|---|
| `ENT1OPTO` | `'9'` |

**Processing:**
The `OTHERWISE` branch of the `SELECT` is taken. `ERRFLDO` is set to `'Please enter a valid option'`, `ENT1OPTL = -1` (cursor positioned to the option field), and the map is resent with the `CURSOR` option. The transaction loops back via `ENDIT_STARTIT` (`EXEC CICS RETURN TRANSID('SSC1')`), allowing the user to correct the entry.

**Expected Output (screen):**
| Screen Field | Value |
|---|---|
| `ERRFLDO` | `Please enter a valid option` |
| Cursor position | Option input field |

---

Generated by IBM Bob Premium Package for Z
