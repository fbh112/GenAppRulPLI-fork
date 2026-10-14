# Business rules: Overview

**Program:** LGAPDB01

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: Policy Request Intake and Routing](#2-function-policy-request-intake-and-routing)
  - [2.1 SubFunction: Request Identification and Validation](#21-subfunction-request-identification-and-validation)
  - [2.2 SubFunction: Policy Record Creation Gate](#22-subfunction-policy-record-creation-gate)
- [3. Function: Premium Calculation and Adjustment](#3-function-premium-calculation-and-adjustment)
  - [3.1 SubFunction: Location-Based Premium Loading (House)](#31-subfunction-location-based-premium-loading-house)
  - [3.2 SubFunction: Accident History Premium Loading (Motor)](#32-subfunction-accident-history-premium-loading-motor)
  - [3.3 SubFunction: Commercial Peril Zone Surcharges](#33-subfunction-commercial-peril-zone-surcharges)
  - [3.4 SubFunction: Multi-Policy Bundling Discount](#34-subfunction-multi-policy-bundling-discount)
- [4. Function: Broker Commission Management](#4-function-broker-commission-management)
  - [4.1 SubFunction: New Policy Commission Calculation](#41-subfunction-new-policy-commission-calculation)
  - [4.2 SubFunction: Claim-Driven Commission Penalty](#42-subfunction-claim-driven-commission-penalty)
- [5. Function: Policy and Claim Record Persistence](#5-function-policy-and-claim-record-persistence)
  - [5.1 SubFunction: Parent Policy Record Insertion](#51-subfunction-parent-policy-record-insertion)
  - [5.2 SubFunction: Policy Sub-Type Record Insertion](#52-subfunction-policy-sub-type-record-insertion)
  - [5.3 SubFunction: Claim Record Insertion](#53-subfunction-claim-record-insertion)

## 1. Purpose
This document presents a program-level functional view of the business logic in LGAPDB01. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: Policy Request Intake and Routing

### 2.1 SubFunction: Request Identification and Validation

#### 2.1.1 Business Rule: Map Request Identifier to Policy Type Code

##### 2.1.1.1 Purpose
Every inbound add-policy request carries a structured request identifier that encodes both the operation type and the insurance product being added. This rule validates the identifier and translates it into the single-character policy type code used throughout the DB2 schema. Unrecognised identifiers are rejected immediately before any database activity occurs.

##### 2.1.1.2 Rule Steps
1. **Evaluate the incoming request identifier against known policy product codes.**
   - Conditions: `CA_REQUEST_ID` is one of: `01AEND`, `01AHOU`, `01AMOT`, `01ACOM`, `01ACLM`.
   - Actions: Assign `DB2_POLICYTYPE` the corresponding code — `E` (Endowment), `H` (House), `M` (Motor), `C` (Commercial), or `X` (Claim).
   - Outcomes: A valid single-character policy type code is available for DB2 insertion and downstream routing.
   - Relevant Procedures: `LGAPDB01`

2. **Reject unrecognised request identifiers.**
   - Conditions: `CA_REQUEST_ID` does not match any known product code.
   - Actions: Set `CA_RETURN_CODE` to `99`; halt further processing.
   - Outcomes: The calling program receives an explicit invalid-request signal and no database operations are attempted.
   - Relevant Procedures: `LGAPDB01`

##### 2.1.1.3 Business Significance
Failure to enforce this gate would allow malformed or unsupported request types to propagate into DB2 insert logic, risking data corruption, incorrect policy type classification, or silent no-ops. The `99` return code provides an unambiguous signal to upstream orchestration for error handling and audit.

---

### 2.2 SubFunction: Policy Record Creation Gate

#### 2.2.1 Business Rule: Suppress Policy Table Insert for Claim Additions

##### 2.2.1.1 Purpose
Claims are not new insurance contracts; they are events against an existing policy. This rule enforces the structural distinction by bypassing the POLICY table insert when the request is a claim addition, ensuring that no orphan or duplicate policy record is created for a claim event.

##### 2.2.1.2 Rule Steps
1. **Determine whether the request requires a new POLICY table record.**
   - Conditions: `CA_REQUEST_ID` is not `01ACLM` (i.e., request is Endowment, House, Motor, or Commercial).
   - Actions: Invoke `INSERT_POLICY` to create a new parent record in the POLICY table.
   - Outcomes: A new policy record is created and a DB2-generated policy number is assigned for downstream sub-type inserts.
   - Relevant Procedures: `LGAPDB01`, `INSERT_POLICY`

2. **Bypass policy record creation for claim requests.**
   - Conditions: `CA_REQUEST_ID` = `01ACLM`.
   - Actions: Skip the `INSERT_POLICY` call; proceed directly to `INSERT_CLAIM`.
   - Outcomes: No new POLICY record is created; the claim is attached to an existing policy.
   - Relevant Procedures: `LGAPDB01`, `INSERT_CLAIM`

##### 2.2.1.3 Business Significance
Incorrectly inserting a POLICY record for a claim addition would create ghost policies with no real contractual basis, inflating policy counts, distorting customer and broker statistics, and corrupting commission calculations that depend on active policy counts.

---

## 3. Function: Premium Calculation and Adjustment

### 3.1 SubFunction: Location-Based Premium Loading (House)

#### 3.1.1 Business Rule: Apply Postcode Band Surcharge to House Insurance Premium

##### 3.1.1.1 Purpose
Properties located in high-risk postcode bands (600000–699999) attract elevated premiums reflecting greater underwriting exposure. The surcharge is tiered by property value to ensure that higher-value assets in risk zones carry a proportionally larger premium loading.

##### 3.1.1.2 Rule Steps
1. **Confirm the request is a house policy.**
   - Conditions: `CA_REQUEST_ID` = `01AHOU`.
   - Actions: Proceed to postcode evaluation; non-house requests bypass this logic entirely.
   - Outcomes: Location-based loading is scoped exclusively to house insurance products.
   - Relevant Procedures: `INSERT_POLICY`

2. **Evaluate the property's postcode against the high-risk band.**
   - Conditions: Property postcode falls within the range 600000–699999.
   - Actions: Proceed to property value tiering; postcodes outside this range receive no loading.
   - Outcomes: Only properties in the designated high-risk zone are subject to premium surcharge.
   - Relevant Procedures: `INSERT_POLICY`

3. **Apply the tiered surcharge based on property value.**
   - Conditions: Property value is £100,000–£150,000 → 20% surcharge; £150,000–£200,000 → 40% surcharge; above £200,000 → 50% surcharge.
   - Actions: Multiply the base premium by the applicable loading factor and store the result in `DB2_PAYMENT_INT`.
   - Outcomes: The adjusted premium stored in `DB2_PAYMENT_INT` reflects the full location and value risk loading before further discounts or commissions are calculated.
   - Relevant Procedures: `INSERT_POLICY`

##### 3.1.1.3 Business Significance
Omitting or miscalculating this surcharge would result in under-pricing of high-risk property policies, creating underwriting losses. Over-application to out-of-zone properties would make premiums uncompetitive and constitute a mis-pricing event subject to regulatory scrutiny.

---

### 3.2 SubFunction: Accident History Premium Loading (Motor)

#### 3.2.1 Business Rule: Load Motor Premium Based on Policyholder Accident Record

##### 3.2.1.1 Purpose
Motor insurance premiums are risk-adjusted based on the policyholder's declared accident history. A tiered multiplier structure ensures that high-risk drivers pay materially higher premiums, reflecting the actuarial relationship between accident frequency and future claim probability.

##### 3.2.1.2 Rule Steps
1. **Evaluate the declared accident count against loading tiers.**
   - Conditions: `CA_M_ACCIDENTS` is 0–2 → factor 1.00; 3–5 → factor 1.20; 6–8 → factor 1.50; greater than 8 → factor 3.00.
   - Actions: Multiply the base motor premium by the applicable factor and store the result in `CA_M_PREMIUM`.
   - Outcomes: The accident-adjusted premium is set and ready for insertion into the MOTOR table.
   - Relevant Procedures: `INSERT_MOTOR`

##### 3.2.1.3 Business Significance
Failure to apply accident-based loading would expose the insurer to systematic under-pricing of high-risk motor policies. The tripling of premium for policyholders with more than eight accidents represents a deliberate actuarial boundary; bypassing it would constitute a material pricing control failure.

---

### 3.3 SubFunction: Commercial Peril Zone Surcharges

#### 3.3.1 Business Rule: Classify Postcode as High-Risk Flood or Weather Zone and Apply Premium Surcharge

##### 3.3.1.1 Purpose
Commercial policies in postcodes with a high historical concentration of active flood or weather peril claims carry elevated risk. This rule queries existing commercial policies in the same postcode area, determines whether concentration thresholds are breached, and applies a 15% surcharge to the relevant peril premiums before the commercial policy record is persisted.

##### 3.3.1.2 Rule Steps
1. **Query historical flood peril concentration for the postcode.**
   - Conditions: Sum of `FLOODPERIL` values across all active commercial policies in the same postcode area is computed via `VALIDATE_PREV_PERIL`.
   - Actions: If the sum exceeds 3, set `WS_FLOOD_FLG` = `Y`; otherwise leave flag unset.
   - Outcomes: The postcode is classified as a high-risk flood zone when cumulative active flood exposure exceeds the threshold of 3.
   - Relevant Procedures: `VALIDATE_PREV_PERIL`, `INSERT_COMMERCIAL`

2. **Query historical weather peril concentration for the postcode.**
   - Conditions: Sum of weather peril values across all active commercial policies in the same postcode area is computed via `VALIDATE_PREV_PERIL`.
   - Actions: If the sum exceeds 3, set `WS_WEATHER_FLG` = `Y`; otherwise leave flag unset.
   - Outcomes: The postcode is classified as a high-risk weather zone when cumulative active weather exposure exceeds the threshold of 3.
   - Relevant Procedures: `VALIDATE_PREV_PERIL`, `INSERT_COMMERCIAL`

3. **Apply flood zone surcharge when flagged.**
   - Conditions: `WS_FLOOD_FLG` = `Y`.
   - Actions: Increase the flood premium component by 15%.
   - Outcomes: The flood premium stored for DB2 insertion reflects the high-risk zone loading.
   - Relevant Procedures: `INSERT_COMMERCIAL`

4. **Apply weather zone surcharge when flagged.**
   - Conditions: `WS_WEATHER_FLG` = `Y`.
   - Actions: Increase the weather premium component by 15%.
   - Outcomes: The weather premium stored for DB2 insertion reflects the high-risk zone loading.
   - Relevant Procedures: `INSERT_COMMERCIAL`

##### 3.3.1.3 Business Significance
Commercial peril surcharges protect the insurer from geographic risk concentration. Failure to detect a high-risk postcode cluster and apply appropriate loadings would result in systematic under-pricing of commercial policies in known loss hotspots, directly increasing loss ratios in those areas.

---

### 3.4 SubFunction: Multi-Policy Bundling Discount

#### 3.4.1 Business Rule: Apply 15% Discount for Customers Holding More Than Two Active Motor or House Policies

##### 3.4.1.1 Purpose
Customers who consolidate multiple Motor or House policies with the insurer are rewarded with a bundling discount as a customer retention incentive. The discount is applied to the payment amount prior to policy record insertion.

##### 3.4.1.2 Rule Steps
1. **Count the customer's currently active Motor or House policies.**
   - Conditions: A DB2 query via `BUNDLING_DISCOUNT` counts active Motor or House policies for `DB2_CUSTOMERNUM_INT`; the result is stored in `WS_CNT_POLICY`. The discount logic is only applied when the query completed successfully (SQLCODE = 0).
   - Actions: Proceed to threshold evaluation.
   - Outcomes: The active multi-policy count for the customer is available for discount eligibility assessment.
   - Relevant Procedures: `BUNDLING_DISCOUNT`, `INSERT_POLICY`

2. **Apply the 15% discount when the threshold is met.**
   - Conditions: `WS_CNT_POLICY` > 2.
   - Actions: Reduce `DB2_PAYMENT_INT` by 15%.
   - Outcomes: The discounted premium is stored in `DB2_PAYMENT_INT` for subsequent commission calculation and policy record insertion.
   - Relevant Procedures: `BUNDLING_DISCOUNT`

##### 3.4.1.3 Business Significance
Incorrectly applying this discount (e.g., to customers below the threshold) would reduce revenue without a qualifying business basis. Failing to apply it to eligible customers would constitute a breach of the pricing commitment to multi-policy holders and could affect customer retention metrics.

---

## 4. Function: Broker Commission Management

### 4.1 SubFunction: New Policy Commission Calculation

#### 4.1.1 Business Rule: Assign Tiered Commission Rate Based on Broker's Active Policy Portfolio

##### 4.1.1.1 Purpose
Broker commission is incentive-structured: brokers who have placed more active policies with the insurer earn progressively higher commission rates, up to a ceiling of 5%. The commission amount is calculated against the final (post-adjustment) payment and stored with the policy record.

##### 4.1.1.2 Rule Steps
1. **Query the broker's current active policy count.**
   - Conditions: A DB2 query via `CALCULATE_COMMISSION` retrieves the total active policies held by the broker; result is stored in `WS_CNT_POLICY`. Commission calculation proceeds only when SQLCODE = 0.
   - Actions: Proceed to rate tier selection.
   - Outcomes: The broker's active policy count is available to determine the applicable commission tier.
   - Relevant Procedures: `CALCULATE_COMMISSION`, `INSERT_POLICY`

2. **Select the commission rate from the tiered schedule and calculate commission amount.**
   - Conditions: `WS_CNT_POLICY` = 0 → 0%; = 1 → 1%; = 2 → 2%; = 3 → 3%; = 4 → 4%; ≥ 5 → 5%.
   - Actions: Apply the selected percentage to `DB2_PAYMENT_INT` and store the result in `WS_COMMISSION`.
   - Outcomes: The commission amount is determined and held in `WS_COMMISSION` for insertion into the POLICY table `COMMISSION` column.
   - Relevant Procedures: `CALCULATE_COMMISSION`

##### 4.1.1.3 Business Significance
Miscalculating commission rates would produce incorrect broker payments, damage broker relationships, and create financial reconciliation discrepancies. Under-rewarding high-volume brokers could jeopardise distribution relationships; over-rewarding low-volume brokers would inflate commission costs without a contractual basis.

---

### 4.2 SubFunction: Claim-Driven Commission Penalty

#### 4.2.1 Business Rule: Halve Broker Commission When Policy Exceeds Three Claims in the Current Year

##### 4.2.1.1 Purpose
Brokers are financially penalised when the policies they place generate excessive claims within a calendar year. When a policy accumulates more than three claims in the current year, the recorded broker commission for that policy is reduced by 50%, enforcing accountability for claim frequency at the broker level.

##### 4.2.1.2 Rule Steps
1. **Count current-year claims for the policy upon each new claim insertion.**
   - Conditions: A new claim is being inserted against a policy; `UPDATE_BROKER_COMM` queries the CLAIM table for claims on the same policy within the current calendar year.
   - Actions: Store the claim count in `WS_CLM_CNT`.
   - Outcomes: The current-year claim count for the policy is available for threshold evaluation.
   - Relevant Procedures: `UPDATE_BROKER_COMM`, `INSERT_CLAIM`

2. **Apply the 50% commission penalty when the claim threshold is exceeded.**
   - Conditions: `WS_CLM_CNT` > 3.
   - Actions: Execute a DB2 UPDATE on the POLICY table, halving the `COMMISSION` column value (`WS_COMMISSION` = current commission / 2).
   - Outcomes: The broker's commission for the policy is permanently reduced in the POLICY table, reflecting the claim-frequency penalty.
   - Relevant Procedures: `UPDATE_BROKER_COMM`

##### 4.2.1.3 Business Significance
This penalty mechanism is a core underwriting governance control. Failing to apply it would allow brokers to earn full commission regardless of claim performance, removing a financial incentive for brokers to exercise due diligence in client selection and risk assessment.

---

## 5. Function: Policy and Claim Record Persistence

### 5.1 SubFunction: Parent Policy Record Insertion

#### 5.1.1 Business Rule: Insert Policy Record and Capture System-Generated Policy Number

##### 5.1.1.1 Purpose
After all premium adjustments and commission calculations are complete, a parent POLICY table record is created to anchor all policy-type-specific and claim data. The DB2-assigned identity policy number is immediately retrieved and propagated back to the communication area for use by downstream sub-type insert operations.

##### 5.1.1.2 Rule Steps
1. **Execute the POLICY table INSERT with all finalised attributes.**
   - Conditions: All premium adjustments (location surcharge, bundling discount) and commission calculation have been completed; `DB2_POLICYTYPE`, `DB2_CUSTOMERNUM_INT`, `DB2_PAYMENT_INT`, and `WS_COMMISSION` are fully resolved.
   - Actions: INSERT into the POLICY table; the policy number is DB2-generated via an IDENTITY column DEFAULT.
   - Outcomes: A new parent policy record is created in the POLICY table with the adjusted payment and calculated commission recorded.
   - Relevant Procedures: `INSERT_POLICY`

2. **Evaluate INSERT outcome and set return code.**
   - Conditions: SQLCODE = 0 → success; SQLCODE = -530 → referential integrity failure (customer does not exist); any other SQLCODE → DB2 error.
   - Actions: Set `CA_RETURN_CODE` to `00` (success), `70` (invalid customer), or `90` (DB2 error). On `70` or `90`, invoke `WRITE_ERROR_MESSAGE` and halt further processing.
   - Outcomes: The calling program receives an unambiguous status code; processing continues only on success.
   - Relevant Procedures: `INSERT_POLICY`

3. **Retrieve the DB2-generated policy number and return it to the caller.**
   - Conditions: INSERT was successful (return code `00`).
   - Actions: Execute `SELECT IDENTITY_VAL_LOCAL()` into `DB2_POLICYNUM_INT`; copy value to `CA_POLICY_NUM`.
   - Outcomes: The new policy number is available in the communication area for subsequent sub-type table inserts (Endowment, House, Motor, or Commercial).
   - Relevant Procedures: `INSERT_POLICY`

##### 5.1.1.3 Business Significance
The policy number is the linchpin foreign key for all sub-type and claim records. Failure to capture and propagate it correctly would sever the referential link between the parent POLICY record and its domain-specific detail records, breaking policy data integrity across the entire schema.

---

### 5.2 SubFunction: Policy Sub-Type Record Insertion

#### 5.2.1 Business Rule: Insert Endowment Policy Detail Record

##### 5.2.1.1 Purpose
Following creation of the parent POLICY record, the endowment-specific attributes are persisted in the ENDOWMENT table. The insert path is conditionally varied to include optional variable-length padding data when present in the communication area.

##### 5.2.1.2 Rule Steps
1. **Determine whether variable-length padding data is present.**
   - Conditions: `WS_VARY_LEN` > 0 indicates additional padding data is present in the communication area.
   - Actions: If present, execute the ENDOWMENT INSERT including the `PADDINGDATA` varchar column; otherwise execute the INSERT without that column. In both cases, core endowment attributes (policy number, investment options, fund name, term, sum assured, life assured) are always included.
   - Outcomes: The ENDOWMENT record is created with or without padding data, linked to the parent POLICY record via `DB2_POLICYNUM_INT` as a foreign key.
   - Relevant Procedures: `INSERT_ENDOW`

##### 5.2.1.3 Business Significance
Omitting the padding data path when it is present, or attempting to insert it when absent, would cause DB2 errors or data truncation. The foreign key linkage via `DB2_POLICYNUM_INT` ensures referential integrity between the ENDOWMENT and POLICY tables.

---

#### 5.2.2 Business Rule: Insert House Policy Detail Record

##### 5.2.2.1 Purpose
Persists the property-specific attributes of a house insurance policy in the HOUSE table, linked to the parent POLICY record by the DB2-generated policy number.

##### 5.2.2.2 Rule Steps
1. **Insert all property attributes into the HOUSE table.**
   - Conditions: Request type is `01AHOU`; parent POLICY record has been successfully created and `DB2_POLICYNUM_INT` is populated.
   - Actions: INSERT into the HOUSE table with property type, bedrooms, value, house name, number, and postcode, using `DB2_POLICYNUM_INT` as the primary key linking to the POLICY table.
   - Outcomes: The house policy domain record is permanently stored and linked to the parent policy.
   - Relevant Procedures: `INSERT_HOUSE`

##### 5.2.2.3 Business Significance
Without the HOUSE detail record, the policy would exist at the parent level only, with no property information to support underwriting, valuation, or claims handling for the insured property.

---

#### 5.2.3 Business Rule: Insert Motor Policy Detail Record with Accident-Adjusted Premium

##### 5.2.3.1 Purpose
Persists all vehicle-specific attributes and the accident-history-adjusted premium in the MOTOR table, linked to the parent POLICY record. The accident-adjusted premium stored here is the authoritative premium of record for the motor policy.

##### 5.2.3.2 Rule Steps
1. **Insert vehicle attributes and adjusted premium into the MOTOR table.**
   - Conditions: Request type is `01AMOT`; accident-based premium loading has been applied and `CA_M_PREMIUM` reflects the adjusted value; `DB2_POLICYNUM_INT` is populated.
   - Actions: INSERT into the MOTOR table with make, model, value, registration, colour, engine size, year of manufacture, adjusted premium (`CA_M_PREMIUM`), and accident count (`CA_M_ACCIDENTS`), using `DB2_POLICYNUM_INT` as the foreign key.
   - Outcomes: The motor policy domain record is permanently stored with the risk-adjusted premium and accident history on file.
   - Relevant Procedures: `INSERT_MOTOR`

##### 5.2.3.3 Business Significance
Storing the pre-adjustment premium instead of the accident-adjusted premium would misrepresent the agreed premium of record, creating discrepancies between the policy, billing, and claims systems.

---

#### 5.2.4 Business Rule: Insert Commercial Policy Detail Record with Peril-Adjusted Premiums

##### 5.2.4.1 Purpose
Persists all commercial property attributes, peril premium values (inclusive of any flood or weather zone surcharges already applied), status, and geolocation data in the COMMERCIAL table, linked to the parent POLICY record.

##### 5.2.4.2 Rule Steps
1. **Insert all commercial attributes including risk-adjusted peril premiums into the COMMERCIAL table.**
   - Conditions: Request type is `01ACOM`; flood and weather surcharges have been evaluated and applied where applicable; `DB2_POLICYNUM_INT` is populated.
   - Actions: INSERT into the COMMERCIAL table with property details, adjusted flood and weather peril premiums, status, rejection reason, and geolocation fields, using `DB2_POLICYNUM_INT` as the foreign key.
   - Outcomes: The commercial policy domain record is permanently stored with all risk-zone-adjusted peril premiums and policy status on file.
   - Relevant Procedures: `INSERT_COMMERCIAL`

##### 5.2.4.3 Business Significance
Persisting unadjusted peril premiums when surcharges were due would understate the insurer's risk-adjusted income for the policy and misrepresent the commercial policy's underwriting basis for future claims assessment.

---

### 5.3 SubFunction: Claim Record Insertion

#### 5.3.1 Business Rule: Insert Claim Record and Trigger Broker Commission Review

##### 5.3.1.1 Purpose
When a new claim is added against an existing policy, a CLAIM table record is created with all claim details and the system-assigned claim number is returned to the caller. The insertion also triggers a broker commission penalty evaluation to enforce the claim-frequency accountability rule.

##### 5.3.1.2 Rule Steps
1. **Evaluate and apply broker commission penalty before inserting the claim.**
   - Conditions: A new claim is being added (`CA_REQUEST_ID` = `01ACLM`).
   - Actions: Invoke `UPDATE_BROKER_COMM`, which counts current-year claims for the policy and halves the POLICY table commission if the count exceeds 3.
   - Outcomes: The broker commission on the associated policy is penalised before the new claim is recorded, ensuring the penalty reflects the complete updated claim count.
   - Relevant Procedures: `INSERT_CLAIM`, `UPDATE_BROKER_COMM`

2. **Insert the claim record into the CLAIM table.**
   - Conditions: Broker commission review has been completed.
   - Actions: INSERT into the CLAIM table with claim number, policy number, claim date, paid amount, value, cause, and observations. If the INSERT fails, set `CA_RETURN_CODE` to `90`. On success, write the DB2-assigned claim number back to the communication area.
   - Outcomes: The claim is permanently recorded against the policy; the assigned claim number is available to the calling program.
   - Relevant Procedures: `INSERT_CLAIM`

##### 5.3.1.3 Business Significance
Inserting the claim before evaluating the commission penalty would produce an off-by-one error in the claim count used for the threshold check, potentially allowing a policy to exceed three claims without triggering the penalty. The ordering of these operations is therefore a business-critical sequencing requirement.

---

Generated by IBM Bob Premium Package for Z
