## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Inputs](#2-inputs)
  - [2.1 CICS Communication Area (COMMAREA)](#21-cics-communication-area-commarea)
  - [2.2 CICS Execution Interface Block (EIB)](#22-cics-execution-interface-block-eib)
  - [2.3 Linked Program Names (Static Configuration)](#23-linked-program-names-static-configuration)
- [3. Outputs](#3-outputs)
- [4. Processing Logic](#4-processing-logic)
  - [4.1 Initialization and Runtime Diagnostics](#41-initialization-and-runtime-diagnostics)
  - [4.2 COMMAREA Validation](#42-commarea-validation)
  - [4.3 Request Identification and Routing](#43-request-identification-and-routing)
  - [4.4 DB2 Delegation — `DELETE_POLICY_DB2_INFO` Procedure](#44-db2-delegation--delete_policy_db2_info-procedure)
  - [4.5 Error Logging — `WRITE_ERROR_MESSAGE` Procedure](#45-error-logging--write_error_message-procedure)
  - [4.6 Program Termination](#46-program-termination)
- [5. Paragraphs](#5-paragraphs)
- [6. Dependencies](#6-dependencies)
  - [6.1 CICS Runtime Environment](#61-cics-runtime-environment)
  - [6.2 Invoked Programs (CICS LINK)](#62-invoked-programs-cics-link)
  - [6.3 Include File / Copybook](#63-include-file--copybook)
  - [6.4 COMMAREA / Input Data](#64-commarea--input-data)
  - [6.5 DB2 Database (Indirect)](#65-db2-database-indirect)
  - [6.6 Declaring Program / Caller](#66-declaring-program--caller)
- [7. Constraints](#7-constraints)
  - [7.1 Communication Area (COMMAREA) Constraints](#71-communication-area-commarea-constraints)
  - [7.2 Request Identifier Constraints](#72-request-identifier-constraints)
  - [7.3 Return Code Constraints](#73-return-code-constraints)
  - [7.4 Data Logging / Error Reporting Constraints](#74-data-logging--error-reporting-constraints)
  - [7.5 Sequencing and Ordering Constraints](#75-sequencing-and-ordering-constraints)
  - [7.6 Policy-Type-Specific Data Structure Constraints](#76-policy-type-specific-data-structure-constraints)
- [8. Error Handling](#8-error-handling)
  - [8.1 Communication Area Validation](#81-communication-area-validation)
  - [8.2 Request Identifier Validation](#82-request-identifier-validation)
  - [8.3 Post-Processing Return Code Check](#83-post-processing-return-code-check)
  - [8.4 Error Logging and Notification](#84-error-logging-and-notification)
  - [8.5 Abend-Based Termination](#85-abend-based-termination)
- [9. Examples](#9-examples)
  - [9.1 Example 1 — Delete a Motor Policy (Successful)](#91-example-1--delete-a-motor-policy-successful)
  - [9.2 Example 2 — Unknown Request Identifier](#92-example-2--unknown-request-identifier)
  - [9.3 Example 3 — COMMAREA Too Small](#93-example-3--commarea-too-small)

## 1. Purpose

`LGDPOL01` is a CICS-hosted PL/I program that acts as the business-logic front-end for deleting insurance policies from the General Insurance Application (GenApp) system. It receives a communication area identifying the policy type to be deleted — Endowment (`01DEND`), House (`01DHOU`), Commercial (`01DCOM`), or Motor (`01DMOT`) — along with the associated customer and policy numbers, validates the communication area is present and of sufficient length, and then routes the request to the downstream DB2 delete program `LGDPDB01` via an `EXEC CICS LINK` call, which performs the actual removal of rows from the Policy and policy-type-specific DB2 tables. It returns a standardised return code (`00` for success, `98` for an undersized communication area, or `99` for an unrecognised request identifier) to the calling program, and logs diagnostic error messages — including timestamp, customer number, policy number, and communication area content — to a transient data queue via the `LGSTSQ` error-logging program when fatal conditions are encountered.

## 2. Inputs

### 2.1 CICS Communication Area (COMMAREA)

The primary input to `LGDPOL01` is the CICS COMMAREA, passed by pointer (`COMM_AREA_PTR`) as the program's procedure parameter. It is a based union structure (`COMM_AREA`) that carries all data from the calling program. The following fields within it serve as external inputs:

- **`CA_REQUEST_ID`** *(CHAR(6))* — Identifies the type of policy delete operation to perform. Recognised values are `'01DEND'` (Endowment), `'01DHOU'` (House), `'01DCOM'` (Commercial), and `'01DMOT'` (Motor). Drives the main routing logic via a `SELECT` statement.
- **`CA_RETURN_CODE`** *(PIC '99')* — Initialized to `'00'` on entry; read back by the caller after return to determine success or failure.
- **`CA_CUSTOMER_NUM`** *(PIC '9999999999')* — Customer identifier supplied by the caller; copied into the error message structure for diagnostic output.
- **`CA_POLICY_NUM`** *(PIC '9999999999')* — Policy identifier supplied by the caller; copied into the error message structure for diagnostic output.
- **`CA_POLICY_COMMON`** — Common policy attributes shared across all policy types, passed through to the DB2 delete program `LGDPDB01`:
  - **`CA_ISSUE_DATE`** *(CHAR(10))* — Date the policy was originally issued.
  - **`CA_EXPIRY_DATE`** *(CHAR(10))* — Date the policy expires.
  - **`CA_LASTCHANGED`** *(CHAR(26))* — Timestamp of the last modification to the policy.
  - **`CA_BROKERID`** *(PIC '9999999999')* — Unique identifier of the broker associated with the policy.
  - **`CA_BROKERSREF`** *(CHAR(10))* — Broker's own reference for the policy.
  - **`CA_PAYMENT`** *(PIC '999999')* — Payment amount associated with the policy.
- **`CA_ENDOWMENT`** — Policy-type-specific fields populated when `CA_REQUEST_ID = '01DEND'`:
  - **`CA_E_WITH_PROFITS`**, **`CA_E_EQUITIES`**, **`CA_E_MANAGED_FUND`** *(CHAR(1))* — Fund type flags.
  - **`CA_E_FUND_NAME`** *(CHAR(10))* — Name of the investment fund.
  - **`CA_E_TERM`** *(PIC '99')* — Policy term in years.
  - **`CA_E_SUM_ASSURED`** *(PIC '999999')* — Insured sum.
  - **`CA_E_LIFE_ASSURED`** *(CHAR(31))* — Name of the life assured.
- **`CA_HOUSE`** — Policy-type-specific fields populated when `CA_REQUEST_ID = '01DHOU'`:
  - **`CA_H_PROPERTY_TYPE`** *(CHAR(15))* — Type of property.
  - **`CA_H_BEDROOMS`** *(PIC '999')* — Number of bedrooms.
  - **`CA_H_VALUE`** *(PIC '99999999')* — Property value.
  - **`CA_H_HOUSE_NAME`** *(CHAR(20))*, **`CA_H_HOUSE_NUMBER`** *(CHAR(4))*, **`CA_H_POSTCODE`** *(CHAR(8))* — Property address details.
- **`CA_MOTOR`** — Policy-type-specific fields populated when `CA_REQUEST_ID = '01DMOT'`:
  - **`CA_M_MAKE`** *(CHAR(15))*, **`CA_M_MODEL`** *(CHAR(15))* — Vehicle make and model.
  - **`CA_M_VALUE`** *(PIC '999999')* — Vehicle value.
  - **`CA_M_REGNUMBER`** *(CHAR(7))* — Vehicle registration number.
  - **`CA_M_COLOUR`** *(CHAR(8))* — Vehicle colour.
  - **`CA_M_CC`** *(PIC '9999')* — Engine cubic capacity.
  - **`CA_M_MANUFACTURED`** *(CHAR(10))* — Year of manufacture.
  - **`CA_M_PREMIUM`** *(PIC '999999')* — Motor premium amount.
  - **`CA_M_ACCIDENTS`** *(PIC '999999')* — Number of accidents recorded.
- **`CA_COMMERCIAL`** — Policy-type-specific fields populated when `CA_REQUEST_ID = '01DCOM'`:
  - **`CA_B_Address`** *(CHAR(255))*, **`CA_B_Postcode`** *(CHAR(8))* — Commercial property address.
  - **`CA_B_Latitude`** *(CHAR(11))*, **`CA_B_Longitude`** *(CHAR(11))* — Geographic coordinates.
  - **`CA_B_Customer`** *(CHAR(255))* — Customer details for the commercial policy.
  - **`CA_B_PropType`** *(CHAR(255))* — Property type description.
  - **`CA_B_FirePeril`/`CA_B_FirePremium`**, **`CA_B_CrimePeril`/`CA_B_CrimePremium`**, **`CA_B_FloodPeril`/`CA_B_FloodPremium`**, **`CA_B_WeatherPeril`/`CA_B_WeatherPremium`** — Peril indicators and associated premiums for each risk category.
  - **`CA_B_Status`** *(PIC '9999')* — Policy status code.
  - **`CA_B_RejectReason`** *(CHAR(255))* — Reason for policy rejection, if applicable.

### 2.2 CICS Execution Interface Block (EIB)

These are implicit CICS-supplied inputs available at runtime:

- **`EIBCALEN`** — Length of the received COMMAREA. Used to validate that a COMMAREA was passed (`EIBCALEN = 0` triggers an abend) and that it meets the minimum header length (`WS_CA_HEADER_LEN = 28`).
- **`EIBTRNID`** — CICS transaction identifier; captured into `WS_TRANSID` for diagnostic context.
- **`EIBTRMID`** — CICS terminal identifier; captured into `WS_TERMID` for diagnostic context.
- **`EIBTASKN`** — CICS task number; captured into `WS_TASKNUM` for diagnostic context.

### 2.3 Linked Program Names (Static Configuration)

- **`LGDPDB01`** *(CHAR(8), initialised to `'LGDPDB01'`)* — Name of the DB2 delete backend program, used as the target of an `EXEC CICS LINK` call to perform the actual deletion from the DB2 Policy tables.

## 3. Outputs

**COMMAREA returned to the caller (`EXEC CICS RETURN`)**

- `CA_RETURN_CODE` — The primary output of the program. Written back to the caller via the COMMAREA on every `EXEC CICS RETURN` path:
  - `'00'` — Policy delete delegated to `LGDPDB01` completed without error
  - `'98'` — COMMAREA received is smaller than the minimum required header length (`WS_CA_HEADER_LEN` = 28 bytes); no DB2 processing was attempted
  - `'99'` — Unrecognised `CA_REQUEST_ID`; no delete was performed
  - Any non-zero value propagated back from `LGDPDB01` — DB2-level failure reported by the downstream program

- `COMM_AREA` (full communication area) — The entire COMMAREA structure, including all policy fields, is passed by reference to `LGDPDB01` via `EXEC CICS LINK` and is returned in-place; any fields modified by `LGDPDB01` (e.g. `CA_RETURN_CODE`, policy-specific fields) are therefore visible to the original caller after `EXEC CICS RETURN`

**Error log written to CICS TD queue via `LGSTSQ`**

- `ERROR_MSG` — Structured diagnostic message written to the CICS transient data queue by linking to `LGSTSQ`. Contains:
  - `EM_DATE` / `EM_TIME` — Timestamp of the error (obtained via `EXEC CICS ASKTIME` / `EXEC CICS FORMATTIME`)
  - Program identifier literal `' LGDPOL01'`
  - `EM_CUSNUM` — Customer number copied from `CA_CUSTOMER_NUM`
  - `EM_POLNUM` — Policy number copied from `CA_POLICY_NUM`
  - `EM_MSG_TEXT` — Free-text error description (e.g. `' NO COMMAREA RECEIVED'`)
  - Written only on the no-COMMAREA error path (when `EIBCALEN = 0`)

- `CA_ERROR_MSG` — Second log entry written to the same TD queue by `LGSTSQ`, containing up to 90 bytes of the raw COMMAREA (`COMM_AREA_RAW`) prefixed by the literal `'COMMAREA='`. Written immediately after `ERROR_MSG` when `EIBCALEN > 0`, providing a hex dump of the COMMAREA at the point of failure

**CICS abnormal termination**

- `EXEC CICS ABEND ABCODE('LGCA') NODUMP` — Issued when no COMMAREA is received (`EIBCALEN = 0`). Terminates the CICS task with abend code `LGCA` without producing a system dump. This is an observable side effect recorded in the CICS transaction log / CSMT queue

## 4. Processing Logic

### 4.1 Initialization and Runtime Diagnostics

- At program entry, the `WS_HEADER` structure is populated with diagnostic identifiers for dump analysis:
  - `WS_TRANSID` is assigned from `EIBTRNID` (CICS transaction identifier of the current task)
  - `WS_TERMID` is assigned from `EIBTRMID` (CICS terminal identifier)
  - `WS_TASKNUM` is assigned from `EIBTASKN` (CICS task number)
  - `WS_ADDR_DFHCOMMAREA` is later assigned the pointer to the communication area for diagnostics
  - `WS_EYECATCHER` is pre-initialized to `'LGDPOL01------WS'` to make the working storage block identifiable in a storage dump

### 4.2 COMMAREA Validation

- `EIBCALEN` (the CICS Executive Interface Block field holding the communication area length) is checked first:
  - If `EIBCALEN = 0`, no communication area was passed at all:
    - The error message text is set to `' NO COMMAREA RECEIVED'`
    - `WRITE_ERROR_MESSAGE` is called to log the error
    - `EXEC CICS ABEND ABCODE('LGCA') NODUMP` is issued to terminate the task immediately with abend code `LGCA`, without producing a system dump
  - `CA_RETURN_CODE` is initialized to `'00'` (success) before any further processing
  - `WS_CALEN` captures `EIBCALEN` and `WS_ADDR_DFHCOMMAREA` captures the pointer, both for later diagnostic use
  - If `EIBCALEN < WS_CA_HEADER_LEN` (minimum header length of 28 bytes):
    - `CA_RETURN_CODE` is set to `'98'` (COMMAREA too small)
    - `EXEC CICS RETURN` is issued immediately, returning control to the caller without any deletion attempt

### 4.3 Request Identification and Routing

- `CA_CUSTOMER_NUM` and `CA_POLICY_NUM` are copied into `EM_CUSNUM` and `EM_POLNUM` in the error message structure for pre-emptive population, ensuring diagnostic output is accurate if an error occurs later
- `CA_REQUEST_ID` is converted to uppercase using the Enterprise PL/I `UPPERCASE` built-in function, normalizing any mixed-case input before evaluation
- A `SELECT` statement branches on the value of `CA_REQUEST_ID`:
  - `WHEN ('01DEND', '01DHOU', '01DCOM', '01DMOT')` — all four recognized delete request identifiers (Endowment, House, Commercial, Motor) are handled by a single branch:
    - `DELETE_POLICY_DB2_INFO` procedure is called
    - After the call returns, if `CA_RETURN_CODE > 0` (indicating an error was set by the DB2 backend), `EXEC CICS RETURN` is issued immediately to stop further processing and return the error to the caller
  - `OTHERWISE` — any unrecognized request identifier:
    - `CA_RETURN_CODE` is set to `'99'` (unrecognized request)
    - Processing falls through to the terminal `EXEC CICS RETURN`

### 4.4 DB2 Delegation — `DELETE_POLICY_DB2_INFO` Procedure

- Issues `EXEC CICS LINK PROGRAM(LGDPDB01)` passing the entire `COMM_AREA` (32,500 bytes) as the COMMAREA to the DB2 delete back-end program `LGDPDB01`
- This delegates all actual DB2 row deletion — from both the `POLICY` table and the policy-type-specific table (`ENDOWMENT`, `HOUSE`, `MOTOR`, or `COMMERCIAL`) — to `LGDPDB01`, which exploits DB2 foreign key cascade rules to handle both rows
- The full COMMAREA (containing request identifier, customer number, policy number, and all policy-specific fields) is passed unmodified, so `LGDPDB01` has complete context to identify and delete the correct rows
- `CA_RETURN_CODE` is communicated back through the shared COMMAREA; the calling logic checks it immediately upon return

### 4.5 Error Logging — `WRITE_ERROR_MESSAGE` Procedure

- Obtains the current system time via `EXEC CICS ASKTIME ABSTIME(WS_ABSTIME)`, which returns an absolute time value
- Formats the absolute time into a human-readable date (MM/DD/YYYY into `WS_DATE`) and time (`WS_TIME`) via `EXEC CICS FORMATTIME`
- Stamps `EM_DATE` and `EM_TIME` in the `ERROR_MSG` structure with the formatted values
- Issues `EXEC CICS LINK PROGRAM('LGSTSQ')` passing `ERROR_MSG` as the COMMAREA to the shared error-logging program `LGSTSQ`, which writes the structured message (date, time, program name `LGDPOL01`, customer number, policy number) to the CICS transient data queue
- Conditionally dumps COMMAREA content to the same queue for further diagnosis:
  - If `EIBCALEN > 0` and `EIBCALEN < 91`: copies exactly `EIBCALEN` bytes from the raw COMMAREA into `CA_DATA` using the `LEFT` built-in, then links to `LGSTSQ` again with `CA_ERROR_MSG`
  - If `EIBCALEN >= 91`: copies the first 90 bytes of the raw COMMAREA into `CA_DATA`, then links to `LGSTSQ` — capping the dump at 90 bytes to stay within the 90-character `CA_DATA` field

### 4.6 Program Termination

- On normal completion (successful delete with `CA_RETURN_CODE = '00'`), control falls through the `SELECT` and reaches the terminal `EXEC CICS RETURN`, passing the result back to the caller through the shared COMMAREA
- On all error paths (`CA_RETURN_CODE = '98'`, `CA_RETURN_CODE = '99'`, or non-zero return from `LGDPDB01`), `EXEC CICS RETURN` is issued at the earliest possible point, returning the populated error code to the calling program without performing any destructive operations

## 5. Paragraphs

- **Main Procedure Body (LGDPOL01)**
  - Serves as the program entry point and top-level orchestrator for all policy delete operations. It is invoked by CICS as a linked program, receiving the COMMAREA pointer as its sole parameter.
  - Begins by capturing the current CICS execution context into working-storage diagnostic fields: `WS_TRANSID` is set from `EIBTRNID`, `WS_TERMID` from `EIBTRMID`, and `WS_TASKNUM` from `EIBTASKN`. These values identify the active transaction, terminal, and task number for error reporting purposes.
  - **COMMAREA presence check:** Evaluates `EIBCALEN` (the length of the incoming COMMAREA as recorded in the CICS Execute Interface Block). If it equals zero, no COMMAREA was passed — the error message text is set to `' NO COMMAREA RECEIVED'`, `WRITE_ERROR_MESSAGE` is called to log the condition, and `EXEC CICS ABEND ABCODE('LGCA') NODUMP` terminates the task abnormally with a four-character abend code `LGCA` without producing a system dump.
  - **Return code initialization:** Sets `CA_RETURN_CODE` to `'00'` (success), saves `EIBCALEN` into `WS_CALEN`, and captures the COMMAREA pointer address into `WS_ADDR_DFHCOMMAREA` for diagnostic use.
  - **COMMAREA length validation:** Compares `EIBCALEN` against `WS_CA_HEADER_LEN` (28 bytes minimum). If the COMMAREA is shorter than the required header, `CA_RETURN_CODE` is set to `'98'` and `EXEC CICS RETURN` is issued immediately to return control to the caller without further processing.
  - **Error context capture:** Copies `CA_CUSTOMER_NUM` and `CA_POLICY_NUM` into `EM_CUSNUM` and `EM_POLNUM` within the error message structure so they are available for any subsequent error logging.
  - **Request routing (SELECT statement):** Converts `CA_REQUEST_ID` to uppercase via the `UPPERCASE` built-in function, then evaluates it with a PL/I `SELECT` statement:
    - `WHEN ('01DEND','01DHOU','01DCOM','01DMOT')` — any recognized delete request (Endowment, House, Commercial, or Motor) calls `DELETE_POLICY_DB2_INFO`. If the resulting `CA_RETURN_CODE` is greater than zero (indicating a downstream failure), `EXEC CICS RETURN` is issued to return the error condition to the caller immediately.
    - `OTHERWISE` — any unrecognized request identifier sets `CA_RETURN_CODE` to `'99'` to signal an invalid request.
  - **Normal termination:** Concludes with `EXEC CICS RETURN` to hand control back to the CICS caller, followed by a PL/I `RETURN` statement.

- **DELETE_POLICY_DB2_INFO**
  - An internal procedure responsible for delegating the actual DB2 policy deletion to the subordinate program `LGDPDB01`.
  - Issues a single `EXEC CICS LINK PROGRAM(LGDPDB01) COMMAREA(COMM_AREA) LENGTH(32500)` call. This passes the full 32,500-byte COMMAREA — containing the request identifier, customer number, policy number, and all policy-type-specific fields — to `LGDPDB01`, which performs the DB2 DELETE against the Policy table (with cascade propagation to the appropriate policy-type table enforced by foreign key constraints).
  - Contains no conditional logic or loops; it is a thin delegation wrapper. Any error indication is communicated back through `CA_RETURN_CODE` in the shared COMMAREA, which the calling main body then inspects.
  - Interacts with the external DB2 subsystem indirectly through the linked program `LGDPDB01`.

- **WRITE_ERROR_MESSAGE**
  - An internal procedure that constructs a formatted diagnostic message and writes it to the CICS transient data queue (TDQ) via the error-logging program `LGSTSQ`.
  - **Timestamp acquisition:** Calls `EXEC CICS ASKTIME ABSTIME(WS_ABSTIME)` to obtain the current absolute time, then `EXEC CICS FORMATTIME ABSTIME(WS_ABSTIME) MMDDYYYY(WS_DATE) TIME(WS_TIME)` to format the result into a human-readable date (MM/DD/YYYY) and time (HH:MM:SS) string. The formatted values are stored into `EM_DATE` and `EM_TIME` within the `ERROR_MSG` structure.
  - **Primary error message write:** Calls `EXEC CICS LINK PROGRAM('LGSTSQ') COMMAREA(ERROR_MSG) LENGTH(STG(CA_ERROR_MSG))` to write the full error message record — which includes date, time, program name (`LGDPOL01`), customer number, policy number, and SQLCODE context — to the TDQ.
  - **COMMAREA dump (conditional logic):** Checks `EIBCALEN` to decide whether to also log a copy of the raw COMMAREA bytes:
    - If `EIBCALEN` is between 1 and 90 bytes inclusive, it copies exactly `EIBCALEN` bytes from `COMM_AREA_RAW` into `CA_DATA` using the `LEFT` built-in.
    - If `EIBCALEN` exceeds 90 bytes, it copies the first 90 bytes instead.
    - In both cases, a second `EXEC CICS LINK PROGRAM('LGSTSQ')` call is made with `CA_ERROR_MSG` as the COMMAREA to write the COMMAREA content snapshot to the TDQ.
    - If `EIBCALEN` is zero the COMMAREA dump is skipped entirely.
  - Terminates with a PL/I `RETURN` statement back to the caller.

## 6. Dependencies

### 6.1 CICS Runtime Environment

- **CICS Transaction Runtime** — `LGDPOL01` runs as a CICS program and relies on the CICS runtime to:
  - Provide the **Execute Interface Block (EIB)** fields consumed at program entry:
    - `EIBTRNID` — the 4-character CICS transaction identifier under which the program executes
    - `EIBTRMID` — the 4-character terminal identifier of the invoking terminal
    - `EIBTASKN` — the 7-digit task number assigned by CICS to the current transaction
    - `EIBCALEN` — the length of the COMMAREA passed by the caller; used to validate that a COMMAREA was received and that it meets the minimum header length of 28 bytes
  - Process `EXEC CICS RETURN` to hand control back to the calling program or transaction
  - Raise abend code `LGCA` (via `EXEC CICS ABEND ABCODE('LGCA') NODUMP`) when no COMMAREA is present
  - Provide time services via `EXEC CICS ASKTIME` and `EXEC CICS FORMATTIME` within the `WRITE_ERROR_MESSAGE` procedure

### 6.2 Invoked Programs (CICS LINK)

- **`LGDPDB01`** — DB2 delete backend program
  - Invoked via `EXEC CICS LINK PROGRAM(LGDPDB01) COMMAREA(COMM_AREA) LENGTH(32500)` inside the `DELETE_POLICY_DB2_INFO` internal procedure
  - Responsible for performing the actual deletion of the relevant row from the DB2 `POLICY` table and the corresponding policy-type-specific table (`ENDOWMENT`, `HOUSE`, `MOTOR`, or `COMMERCIAL`); leverages DB2 foreign key cascade semantics
  - Called for all four recognised request types: `01DEND`, `01DHOU`, `01DCOM`, `01DMOT`
- **`LGSTSQ`** — Transient Data Queue (TDQ) logging utility program
  - Invoked via `EXEC CICS LINK PROGRAM('LGSTSQ')` twice inside `WRITE_ERROR_MESSAGE`:
    - First call passes `ERROR_MSG` (date, time, program name, customer number, policy number, SQL code) as the COMMAREA
    - Second call passes `CA_ERROR_MSG` (up to 90 bytes of raw COMMAREA content) as the COMMAREA
  - Writes diagnostic messages to the CICS TD queue `CSMT` for error logging and problem determination
  - Triggered only when no COMMAREA is received at program entry

### 6.3 Include File / Copybook

- **`LGCMAREA`** (resolved from `plinc/LGCMAREA.inc`) — COMMAREA structure definition
  - Included via `%INCLUDE LGCMAREA;` (compile-time preprocessor)
  - Defines the `COMM_AREA` based union structure mapped over `COMM_AREA_PTR`, covering all request types: customer requests, customer security requests, and all policy-type requests (Endowment, House, Motor, Commercial, Claim)
  - Used by every CICS program in the application; ensures a consistent COMMAREA layout across the call chain

### 6.4 COMMAREA / Input Data

- **`COMM_AREA` passed by the caller** — the single input/output interface for `LGDPOL01`
  - Passed as the procedure parameter `COMM_AREA_PTR`
  - Must be at least 28 bytes (header length defined by `WS_CA_HEADER_LEN`)
  - Key fields driving execution:
    - `CA_REQUEST_ID` (6 chars) — identifies the policy type to delete (`01DEND`, `01DHOU`, `01DCOM`, `01DMOT`); any other value causes return code `99`
    - `CA_RETURN_CODE` (2-digit PIC) — set to `00` on entry; updated to `98` (COMMAREA too small), `99` (unrecognised request), or propagated from `LGDPDB01`
    - `CA_CUSTOMER_NUM` (10-digit PIC) — customer identifier; captured into error message structure
    - `CA_POLICY_NUM` (10-digit PIC) — policy identifier; captured into error message structure
    - `CA_POLICY_COMMON` — common policy attributes (issue date, expiry date, last-changed date, broker ID, broker's reference, payment amount) forwarded to `LGDPDB01`
    - `CA_ENDOWMENT` / `CA_HOUSE` / `CA_MOTOR` / `CA_COMMERCIAL` — policy-type-specific data union members forwarded to `LGDPDB01`

### 6.5 DB2 Database (Indirect)

- **DB2 `POLICY` table and policy-type tables (`ENDOWMENT`, `HOUSE`, `MOTOR`, `COMMERCIAL`)** — accessed indirectly
  - `LGDPOL01` itself contains no `EXEC SQL` statements; all DB2 interaction is delegated to `LGDPDB01`
  - The foreign key definitions on these tables drive cascaded deletion of the policy-type row when the parent `POLICY` row is deleted

### 6.6 Declaring Program / Caller

- **Calling program (caller)** — any CICS program that `EXEC CICS LINK`s to `LGDPOL01`
  - Per the application architecture, the typical caller is a CICS menu program (`LGTESTP1`–`LGTESTC1`) or an orchestrating layer
  - The caller is responsible for constructing a valid `COMM_AREA` of at least 28 bytes and populating `CA_REQUEST_ID`, `CA_CUSTOMER_NUM`, `CA_POLICY_NUM`, and the relevant policy-specific fields before linking

## 7. Constraints

### 7.1 Communication Area (COMMAREA) Constraints

- **COMMAREA must be present on entry**: `EIBCALEN` is checked at program startup (line 190). If it equals zero — meaning no COMMAREA was passed by the caller — the program writes an error message (`' NO COMMAREA RECEIVED'`) to the transient data queue via `WRITE_ERROR_MESSAGE` and immediately issues `EXEC CICS ABEND ABCODE('LGCA') NODUMP`, preventing any processing from occurring without a valid communication area.

- **COMMAREA minimum length of 28 bytes**: After confirming the COMMAREA is present, `EIBCALEN` is compared against `WS_CA_HEADER_LEN` (initialized to 28, line 57). If the COMMAREA length is less than 28 bytes, `CA_RETURN_CODE` is set to `'98'` and the program returns immediately to the caller (lines 202–205). No policy data is read or processed until this structural minimum is satisfied.

- **COMMAREA maximum raw capacity is 32,500 bytes**: The `COMM_AREA_RAW` field is declared as `CHAR(32500)` (line 81), defining the absolute upper bound of data the program can handle in a single COMMAREA. The `EXEC CICS LINK` to `LGDPDB01` passes `LENGTH(32500)` (line 242), enforcing this ceiling on data passed to the downstream DB2 program.

### 7.2 Request Identifier Constraints

- **`CA_REQUEST_ID` must match a recognized value**: The 6-character `CA_REQUEST_ID` field is forced to uppercase via `UPPERCASE()` (line 215) and then evaluated in a `SELECT` statement (lines 217–227). Only the four values `'01DEND'` (Endowment), `'01DHOU'` (House), `'01DCOM'` (Commercial), and `'01DMOT'` (Motor) are accepted. Any other value falls into the `OTHERWISE` branch, which sets `CA_RETURN_CODE` to `'99'` and returns without performing any deletion.

- **Case normalization is mandatory before routing**: The `UPPERCASE()` conversion is unconditionally applied to `CA_REQUEST_ID` before the `SELECT` (line 215). Mixed- or lower-case request identifiers are silently normalized; the program never rejects a request purely on case, but the routing table only recognizes uppercase forms.

### 7.3 Return Code Constraints

- **`CA_RETURN_CODE` is initialized to `'00'` before processing**: The return code is set to `'00'` at line 197 before any validation or routing logic runs, ensuring a clean state.
- **Non-zero return code from downstream DB2 link halts further processing**: After calling `DELETE_POLICY_DB2_INFO`, the program checks `CA_RETURN_CODE > 0` (line 220). If the DB2 backend returned any non-zero code, the program issues `EXEC CICS RETURN` immediately, propagating the error back to the caller without additional processing.
- **Only three defined return code values are produced by this program**:
  - `'00'` — successful completion (initial default)
  - `'98'` — COMMAREA too small (header length check failed)
  - `'99'` — unrecognized `CA_REQUEST_ID`

### 7.4 Data Logging / Error Reporting Constraints

- **Error message COMMAREA dump is capped at 90 bytes**: Inside `WRITE_ERROR_MESSAGE`, when `EIBCALEN > 0`, only up to 90 bytes of `COMM_AREA_RAW` are written to the transient data queue (lines 267–279). If `EIBCALEN < 91`, exactly `EIBCALEN` bytes are captured; otherwise the dump is truncated to 90 bytes using `LEFT(COMM_AREA_RAW, 90)`.

- **Error messages are written only when COMMAREA is present**: The secondary log write (lines 267–280) is guarded by `IF ( EIBCALEN > 0 )`, meaning the raw COMMAREA dump is only attempted when a non-empty COMMAREA exists.

### 7.5 Sequencing and Ordering Constraints

- **Validation must precede routing**: The program enforces a strict sequence: (1) check COMMAREA presence → (2) check COMMAREA minimum length → (3) normalize and evaluate `CA_REQUEST_ID` → (4) delegate to DB2 backend. No step can be bypassed; each prior guard returns or abends on failure before the next step executes.

- **DB2 deletion is fully delegated and must complete before return**: The actual row deletion is performed exclusively by `LGDPDB01` via `EXEC CICS LINK` (line 240). `LGDPOL01` itself performs no direct DB2 operations; it is constrained to be an orchestrator that only proceeds to `EXEC CICS RETURN` after receiving control back from `LGDPDB01`.

- **Working storage fields are captured before routing**: `EM_CUSNUM` and `EM_POLNUM` are populated from `CA_CUSTOMER_NUM` and `CA_POLICY_NUM` (lines 208–209) before the `SELECT` routing block, ensuring that if an error occurs at any subsequent point, the diagnostic message already contains the correct customer and policy identifiers.

### 7.6 Policy-Type-Specific Data Structure Constraints

- **Policy-type fields are mutually exclusive within a union**: `CA_POLICY_SPECIFIC` is declared as a `UNION` (line 119) containing `CA_ENDOWMENT`, `CA_HOUSE`, `CA_MOTOR`, `CA_COMMERCIAL`, and `CA_CLAIM`. Only one policy-type layout is active for a given invocation, determined entirely by `CA_REQUEST_ID`. Overlapping the same storage means supplying data for the wrong policy type would be silently misinterpreted.

- **Each policy-type sub-structure has fixed-length fields with implicit format rules**:
  - Endowment (`CA_ENDOWMENT`): single-character flag fields (`CA_E_WITH_PROFITS`, `CA_E_EQUITIES`, `CA_E_MANAGED_FUND`); term is a 2-digit numeric picture (`PIC '99'`); sum assured is a 6-digit numeric picture (`PIC '999999'`).
  - House (`CA_HOUSE`): bedrooms is a 3-digit numeric picture (`PIC '999'`); property value is an 8-digit numeric picture (`PIC '99999999'`); postcode is fixed at 8 characters.
  - Motor (`CA_MOTOR`): vehicle value, premium, and accident count are all 6-digit numeric pictures; engine CC is a 4-digit numeric picture; registration number is fixed at 7 characters.
  - Commercial (`CA_COMMERCIAL`): address, customer, property type, and reject reason fields are each fixed at 255 characters; postcode is 8 characters; all four peril codes are 4-digit numeric pictures; all four premiums are 8-digit numeric pictures.

## 8. Error Handling

### 8.1 Communication Area Validation

- **Missing COMMAREA check (EIBCALEN = 0)**
  - At program entry, the CICS-provided field `EIBCALEN` is tested to determine whether any communication area was passed to the program
  - If `EIBCALEN` equals zero, no COMMAREA was received; this is treated as a fatal error
  - An error message text `NO COMMAREA RECEIVED` is placed into the error message structure, the `WRITE_ERROR_MESSAGE` procedure is invoked to log the error, and then `EXEC CICS ABEND ABCODE('LGCA') NODUMP` is issued to terminate the task abnormally with a user-defined abend code (`LGCA`), suppressing a system dump

- **Undersized COMMAREA check (EIBCALEN < WS_CA_HEADER_LEN)**
  - After the null check, the actual COMMAREA length `EIBCALEN` is compared against the minimum header length constant `WS_CA_HEADER_LEN` (initialized to 28)
  - If the COMMAREA is shorter than the required minimum, the return code field `CA_RETURN_CODE` is set to `'98'` and `EXEC CICS RETURN` is issued immediately, returning control to the caller with the error code set — no further processing is attempted

---

### 8.2 Request Identifier Validation

- **Unknown request type detection via SELECT/OTHERWISE**
  - `CA_REQUEST_ID` is first normalized to uppercase using the `UPPERCASE` built-in
  - A `SELECT` statement evaluates `CA_REQUEST_ID` against the four known valid values (`'01DEND'`, `'01DHOU'`, `'01DCOM'`, `'01DMOT'`)
  - If none of the recognized values match, the `OTHERWISE` branch fires, setting `CA_RETURN_CODE` to `'99'` to signal an unrecognized request to the caller
  - No further processing or database linkage is performed for unrecognized request types

---

### 8.3 Post-Processing Return Code Check

- **Non-zero return code after DB2 deletion**
  - After the `DELETE_POLICY_DB2_INFO` procedure is called (which issues `EXEC CICS LINK` to the DB2 delete program `LGDPDB01`), the return code `CA_RETURN_CODE` is tested
  - If `CA_RETURN_CODE` is greater than zero, indicating that the downstream DB2 program reported a failure, `EXEC CICS RETURN` is issued immediately to pass the error code back to the caller without attempting any further processing

---

### 8.4 Error Logging and Notification

- **Centralized error logging via `WRITE_ERROR_MESSAGE` procedure**
  - The `WRITE_ERROR_MESSAGE` procedure is the single error reporting mechanism in the program, invoked when a fatal error is detected (currently triggered only on a missing COMMAREA)
  - Before logging, the current timestamp is obtained using `EXEC CICS ASKTIME` and formatted into a human-readable date and time using `EXEC CICS FORMATTIME`
  - The formatted date and time are stamped into the error message structure alongside the program name (`LGDPOL01`), customer number (`EM_CUSNUM`), and policy number (`EM_POLNUM`), which are pre-populated before any call to this procedure
  - The error message is written to a transient data queue by calling the logging program `LGSTSQ` via `EXEC CICS LINK`, passing the `ERROR_MSG` structure as the COMMAREA

- **COMMAREA content dumping to the log**
  - Within `WRITE_ERROR_MESSAGE`, a secondary log write captures the raw COMMAREA content for diagnostic purposes
  - If `EIBCALEN` is greater than zero and less than 91, the actual COMMAREA bytes (up to `EIBCALEN` in length) are extracted and written via a second `EXEC CICS LINK` to `LGSTSQ`
  - If `EIBCALEN` is 91 or greater, the first 90 bytes of the raw COMMAREA are written instead, providing a consistent maximum diagnostic snapshot
  - This conditional sizing prevents overrunning the `CA_DATA` buffer (90 characters) when logging COMMAREA content

---

### 8.5 Abend-Based Termination

- **Task abend on unrecoverable error**
  - When a fatal condition is detected (missing COMMAREA), the program issues `EXEC CICS ABEND ABCODE('LGCA') NODUMP` after logging the error
  - The `NODUMP` option suppresses the generation of a system transaction dump, reducing overhead while still producing an identifiable abend code for problem determination
  - This terminates the CICS task immediately; control is not returned to the caller in this path

## 9. Examples

### 9.1 Example 1 — Delete a Motor Policy (Successful)

**Input COMMAREA:**

| Field | Value |
|---|---|
| `CA_REQUEST_ID` | `01DMOT` |
| `CA_RETURN_CODE` | `00` |
| `CA_CUSTOMER_NUM` | `0000001234` |
| `CA_POLICY_NUM` | `0000009876` |
| `CA_ISSUE_DATE` | `2019-06-15` |
| `CA_EXPIRY_DATE` | `2024-06-15` |
| `CA_PAYMENT` | `001200` |
| `CA_M_MAKE` | `Toyota` |
| `CA_M_MODEL` | `Corolla` |
| `CA_M_REGNUMBER` | `AB12CDE` |
| COMMAREA length | 32500 bytes |

**Expected Output:**

- `CA_RETURN_CODE` = `00`
- Program returns to caller via `EXEC CICS RETURN`.
- `LGDPDB01` has been linked and has deleted the matching row from the DB2 Policy table (and cascading foreign key deletes remove the Motor-specific row).

**Explanation:**

1. COMMAREA length ≥ 28 (`WS_CA_HEADER_LEN`), so the size check passes.
2. `CA_REQUEST_ID` (`01DMOT`) is converted to uppercase and matched in the `SELECT` block against the `WHEN ('01DEND','01DHOU','01DCOM','01DMOT')` clause.
3. `DELETE_POLICY_DB2_INFO` is called, which issues an `EXEC CICS LINK` to `LGDPDB01`, passing the full COMMAREA.
4. `LGDPDB01` returns with `CA_RETURN_CODE = 00`, so no early return is triggered and the program exits normally.

---

### 9.2 Example 2 — Unknown Request Identifier

**Input COMMAREA:**

| Field | Value |
|---|---|
| `CA_REQUEST_ID` | `01DTRV` |
| `CA_RETURN_CODE` | `00` |
| `CA_CUSTOMER_NUM` | `0000005555` |
| `CA_POLICY_NUM` | `0000001111` |
| COMMAREA length | 32500 bytes |

**Expected Output:**

- `CA_RETURN_CODE` = `99`
- Program returns to caller via `EXEC CICS RETURN`.
- No link to `LGDPDB01` is made; no database rows are deleted.

**Explanation:**

1. COMMAREA length is sufficient, so the header check passes.
2. `CA_REQUEST_ID` (`01DTRV`) does not match any of `01DEND`, `01DHOU`, `01DCOM`, or `01DMOT`.
3. The `OTHERWISE` branch in the `SELECT` statement fires, setting `CA_RETURN_CODE = '99'`.
4. The program returns the error code to the caller without performing any delete.

---

### 9.3 Example 3 — COMMAREA Too Small

**Input COMMAREA:**

| Field | Value |
|---|---|
| `CA_REQUEST_ID` | `01DHOU` |
| COMMAREA length | 20 bytes (< 28) |

**Expected Output:**

- `CA_RETURN_CODE` = `98`
- Program returns immediately via `EXEC CICS RETURN`.
- No policy type routing or database call is attempted.

**Explanation:**

1. `EIBCALEN` (20) is less than `WS_CA_HEADER_LEN` (28), so the minimum-length guard fires.
2. `CA_RETURN_CODE` is set to `'98'` and `EXEC CICS RETURN` is issued immediately.
3. Processing stops before the `SELECT` on `CA_REQUEST_ID` is ever reached, protecting downstream programs from an undersized buffer.

---

Generated by IBM Bob Premium Package for Z
