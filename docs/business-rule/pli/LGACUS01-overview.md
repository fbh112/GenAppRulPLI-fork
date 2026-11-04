# Business rules: Overview

**Program:** LGACUS01

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: Customer Onboarding and Identity Management](#2-function-customer-onboarding-and-identity-management)
  - [2.1 SubFunction: Customer Registration and Security Setup](#21-subfunction-customer-registration-and-security-setup)
- [3. Function: Customer Policy Lifecycle Administration](#3-function-customer-policy-lifecycle-administration)
  - [3.1 SubFunction: Policy Issuance and Transfer](#31-subfunction-policy-issuance-and-transfer)
  - [3.2 SubFunction: Policy Termination and Removal](#32-subfunction-policy-termination-and-removal)

## 1. Purpose
This document presents a program-level functional view of the business logic in LGACUS01. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: Customer Onboarding and Identity Management

### 2.1 SubFunction: Customer Registration and Security Setup

#### 2.1.1 Business Rule: Customer Account Creation and Identifier Assignment
##### 2.1.1.1 Purpose
Establishes a new customer profile within the system by assigning a unique customer number—either via an external named counter service or automatic database generation—and persisting demographic, contact, and address details.

##### 2.1.1.2 Rule Steps
1. Evaluate customer identification generation method and insert demographic record
   - Conditions: Action code `ACTION_CODE` is `'1'` (Request ID `CA_REQUEST_ID` = `'01ICUS'`).
   - Actions: If the named counter service is active, assign the pre-allocated customer number and insert the customer record containing `CA_FIRST_NAME`, `CA_LAST_NAME`, `CA_DOB`, `CA_HOUSE_NAME`, `CA_POSTCODE`, `CA_PHONE_MOBILE`, and `CA_EMAIL_ADDRESS`. If the named counter is inactive, execute the database insert to let the database generate the customer identifier and retrieve the generated key.
   - Outcomes: Customer master record is created with a unique identifier.
   - Relevant Procedures: `LGACUS01`, `ONBOARD_CUSTOMER`, `INSERT_CUSTOMER`
2. Handle customer record insertion failure
   - Conditions: Customer record database insertion returns a non-zero SQL error.
   - Actions: Log error details and set the return code to `'90'` to terminate the onboarding transaction.
   - Outcomes: Transaction terminates with an error status without creating an orphaned profile.
   - Relevant Procedures: `INSERT_CUSTOMER`, `WRITE_ERROR_MESSAGE`

##### 2.1.1.3 Business Significance
Improper customer number assignment or failure to accurately capture personal details can lead to duplicate identity records, data fragmentation, or complete failure of regulatory KYC (Know Your Customer) compliance.

#### 2.1.2 Business Rule: Initial Customer Security Profile Provisioning
##### 2.1.2.1 Purpose
Initializes security governance attributes for a newly registered customer by creating a baseline security profile with a clean authentication status and zero failed attempts.

##### 2.1.2.2 Rule Steps
1. Create default customer security record
   - Conditions: Customer master record has been successfully inserted during onboarding.
   - Actions: Insert a new security record linked to the customer identifier with an initial state of `'N'` and the failed-attempt count set to `'0000'`.
   - Outcomes: New customer is provisioned with an active, unlocked security status.
   - Relevant Procedures: `ONBOARD_CUSTOMER`

##### 2.1.2.3 Business Significance
Failing to provision default security controls exposes the new customer account to unauthorized access or prevents legitimate access due to missing baseline credentials.

---

## 3. Function: Customer Policy Lifecycle Administration

### 3.1 SubFunction: Policy Issuance and Transfer

#### 3.1.1 Business Rule: Customer Policy Issuance and Referential Integrity Verification
##### 3.1.1.1 Purpose
Issues and links a new insurance policy to an existing customer record, ensuring that policy terms, broker references, and payment amounts are recorded while verifying the customer entity exists.

##### 3.1.1.2 Rule Steps
1. Filter out incompatible request types
   - Conditions: Request identifier `CA_REQUEST_ID` matches a claim request (`'01ACLM'`).
   - Actions: Bypass policy creation.
   - Outcomes: Policy issuance is skipped for claim-specific workflows.
   - Relevant Procedures: `LGACUS01`, `OFFER_CUSTOMER`
2. Insert policy record and capture system-generated policy identifier
   - Conditions: `ACTION_CODE` is `'2'` (`CA_REQUEST_ID` = `'02OCUS'`) and `CA_REQUEST_ID` is not `'01ACLM'`.
   - Actions: Insert a new record into the `POLICY` table populated with issue date, expiry date, policy type, broker details, and payment amount, setting the last-changed timestamp to current system time and generating a new policy number (`CA_POLICY_NUM`).
   - Outcomes: New insurance policy is created and linked to the customer.
   - Relevant Procedures: `OFFER_CUSTOMER`, `INSERT_CUSTOMER_POLICY`
3. Validate policy creation outcome and enforce customer existence
   - Conditions: SQL execution returns a status code upon policy insertion.
   - Actions: If SQLCODE is 0, return status code `'00'`. If SQLCODE is -530 (referential integrity failure / customer does not exist), set return code to `'70'` and terminate. For any other SQL failure, set return code to `'90'`, log error details, and terminate.
   - Outcomes: Return code `'00'`, `'70'`, or `'90'` is returned to reflect the outcome.
   - Relevant Procedures: `INSERT_CUSTOMER_POLICY`, `WRITE_ERROR_MESSAGE`

##### 3.1.1.3 Business Significance
Prevents the creation of orphaned policies without a valid owning customer, avoiding uncollectible premiums and unserviced policy liabilities.

#### 3.1.2 Business Rule: Customer Policy Transfer Execution
##### 3.1.2.1 Purpose
Transfers an existing customer policy structure to create a newly assigned policy record under transfer governance rules, ensuring valid customer linkages and timestamping.

##### 3.1.2.2 Rule Steps
1. Validate request applicability for policy transfer
   - Conditions: Request identifier `CA_REQUEST_ID` is equal to `'01ACLM'`.
   - Actions: Bypass the policy transfer routine.
   - Outcomes: Transfer operation is skipped for claim-driven invocations.
   - Relevant Procedures: `LGACUS01`, `TRANSFER_CUSTOMER`
2. Insert transferred policy record with updated metadata
   - Conditions: `ACTION_CODE` is `'3'` (`CA_REQUEST_ID` = `'02UCUS'`) and `CA_REQUEST_ID` is not `'01ACLM'`.
   - Actions: Insert a new record into the `POLICY` table with transfer dates, policy type, broker information, and payment parameters using the database identity default for `CA_POLICY_NUM`, and stamp the current timestamp.
   - Outcomes: Transferred policy is established in the database.
   - Relevant Procedures: `TRANSFER_CUSTOMER`, `TRANSFER_CUSTOMER_POLICY`
3. Evaluate transfer integrity and handle database constraints
   - Conditions: Database returns an execution code following policy transfer insertion.
   - Actions: If SQLCODE is 0, set return code to `'00'`. If SQLCODE is -530 (invalid customer reference), set return code to `'70'` and end processing. For all other SQL failures, set return code to `'90'`, invoke error messaging, and end processing.
   - Outcomes: Transfer transaction completes successfully or aborts with an integrity error code.
   - Relevant Procedures: `TRANSFER_CUSTOMER_POLICY`, `WRITE_ERROR_MESSAGE`

##### 3.1.2.3 Business Significance
Ensures that transferred policies maintain accurate audit trails, correct broker attribution, and valid customer ownership, preventing policy loss during account reassignments.

---

### 3.2 SubFunction: Policy Termination and Removal

#### 3.2.1 Business Rule: Dual-Key Policy Record Deletion
##### 3.2.1.1 Purpose
Deletes an active policy record from the database only when both the policy number and the corresponding owning customer number match, ensuring that policy cancellations are strictly authorized by the policyholder relationship.

##### 3.2.1.2 Rule Steps
1. Evaluate deletion request eligibility
   - Conditions: Request identifier `CA_REQUEST_ID` is equal to `'01ACLM'`.
   - Actions: Bypass the policy deletion routine.
   - Outcomes: Policy deletion is skipped during claim operations.
   - Relevant Procedures: `LGACUS01`, `DELETE_CUSTOMER`
2. Execute policy record removal matching customer and policy identifiers
   - Conditions: `ACTION_CODE` is `'4'` (`CA_REQUEST_ID` = `'02DCUS'`) and `CA_REQUEST_ID` is not `'01ACLM'`.
   - Actions: Delete the record from the `POLICY` table where both customer number and `CA_POLICY_NUM` match the request parameters.
   - Outcomes: Target policy record is permanently removed from active storage.
   - Relevant Procedures: `DELETE_CUSTOMER`, `DELETE_CUSTOMER_POLICY`
3. Evaluate policy deletion execution result
   - Conditions: Database operation returns an execution status code.
   - Actions: If the deletion succeeds (or record is already absent), confirm successful deletion; on any database failure, set return code to `'90'`, write an error log message, and terminate.
   - Outcomes: System confirms policy removal or reports a database error.
   - Relevant Procedures: `DELETE_CUSTOMER_POLICY`, `WRITE_ERROR_MESSAGE`

##### 3.2.1.3 Business Significance
Enforces ownership validation prior to policy deletion, preventing unauthorized or accidental cancellation of policies belonging to other customers and mitigating legal and coverage dispute liabilities.

---

Generated by IBM Bob Premium Package for Z
