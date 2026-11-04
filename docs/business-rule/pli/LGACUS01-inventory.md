# Business rules: Inventory

**Program:** LGACUS01

**Total rules extracted:** 14

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Procedure: LGACUS01](#21-procedure-lgacus01)
  - [2.2 Procedure: ONBOARD_CUSTOMER](#22-procedure-onboard_customer)
  - [2.3 Procedure: INSERT_CUSTOMER](#23-procedure-insert_customer)
  - [2.4 Procedure: TRANSFER_CUSTOMER](#24-procedure-transfer_customer)
  - [2.5 Procedure: DELETE_CUSTOMER](#25-procedure-delete_customer)
  - [2.6 Procedure: OFFER_CUSTOMER](#26-procedure-offer_customer)
  - [2.7 Procedure: INSERT_CUSTOMER_POLICY](#27-procedure-insert_customer_policy)
  - [2.8 Procedure: TRANSFER_CUSTOMER_POLICY](#28-procedure-transfer_customer_policy)
  - [2.9 Procedure: DELETE_CUSTOMER_POLICY](#29-procedure-delete_customer_policy)

## 1. Purpose

This document is an inventory of all business rules extracted from LGACUS01, organised at the Procedure level. Each Procedure contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Procedures called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Procedure: LGACUS01

#### 2.1.1 Customer action dispatch and request identification

**Description:** Selects which customer business operation to run based on the action code. Each action sets the matching request identifier and invokes the corresponding routine: onboard a customer, offer a policy, transfer a customer with its policy, or delete a customer with its policy. Any other action code performs no operation.

**Core decision logic:**
- Action code '1' onboards a new customer with request ID '01ICUS'
- Action code '2' offers a policy to a customer with request ID '02OCUS'
- Action code '3' transfers a customer and its policy with request ID '02UCUS'
- Action code '4' deletes a customer and removes its policy with request ID '02DCUS'
- Any other action code results in no business operation

**Code:**
```pl1
   SELECT;                                                                      
     WHEN (ACTION_CODE = '1') DO;                                               
  /* Call routine to Insert row in DB2 Customer table */                        
         CA_REQUEST_ID = '01ICUS';                                              
         CALL ONBOARD_CUSTOMER;                                                 
     END;                                                                       
     WHEN (ACTION_CODE = '2') DO;                                               
  /* Call routine to offer a policy to a given customer */                      
         CA_REQUEST_ID = '02OCUS';                                              
         CALL OFFER_CUSTOMER;                                                   
     END;                                                                       
     WHEN (ACTION_CODE = '3') DO;                                               
  /* Call routine to transfer customer and its policy */                        
         CA_REQUEST_ID = '02UCUS';                                              
         CALL TRANSFER_CUSTOMER;                                                
     END;                                                                       
     WHEN (ACTION_CODE = '4') DO;                                               
  /* Call routine to delete customer and remove its policy */                   
         CA_REQUEST_ID = '02DCUS';                                              
         CALL DELETE_CUSTOMER;                                                  
     END;                                                                       
     OTHERWISE;                                                                 
   END;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `ACTION_CODE` | input | Selector that determines which customer business operation is dispatched. |
| `CA_REQUEST_ID` | output | Set to the request code identifying the selected business operation. |

**Procedures:**

* ONBOARD_CUSTOMER
* OFFER_CUSTOMER
* TRANSFER_CUSTOMER
* DELETE_CUSTOMER
### 2.2 Procedure: ONBOARD_CUSTOMER

#### 2.2.1 Obtain and insert new customer record

**Description:** Assigns a new customer number and creates the customer record in the customer table as part of onboarding.

**Core decision logic:**
- A new customer number is obtained before the customer record is created
- A customer record is created as part of onboarding

**Code:**
```pl1
   CALL OBTAIN_CUSTOMER_NUMBER;                                                 
   CALL INSERT_CUSTOMER;                                                        
```

**Procedures:**

* OBTAIN_CUSTOMER_NUMBER
* INSERT_CUSTOMER
#### 2.2.2 Create customer security record

**Description:** Creates the security record for the newly onboarded customer with an initial count of zero and state 'N'.

**Core decision logic:**
- A new customer's security record is created with state 'N'
- The security failed-attempt count starts at '0000'

**Code:**
```pl1
   D2_CUSTOMER_NUM    = DB2_CUSTOMERNUM_INT;                                    
   D2_REQUEST_ID      = '02ACUS';                                               
   D2_CUSTSECR_COUNT  = '0000';                                                 
   D2_CUSTSECR_STATE  = 'N';                                                    
                                                                                
   EXEC CICS LINK PROGRAM(LGACDB02)                                             
        COMMAREA(CDB2AREA)                                                      
        LENGTH(32500);                                                          
```

### 2.3 Procedure: INSERT_CUSTOMER

#### 2.3.1 Insert customer with pre-assigned customer number

**Description:** When the named counter service is on, the customer is inserted into the customer table using the customer number previously obtained from the counter.

**Core decision logic:**
- If the named counter is active, the pre-assigned customer number is used for the new customer record
- A failed insert terminates the request with return code '90'

**Code:**
```pl1
   IF (LGAC_NCS = 'ON') THEN DO;                                                
     EXEC SQL                                                                   
       INSERT INTO CUSTOMER                                                     
                 ( CUSTOMERNUMBER,                                              
                   FIRSTNAME,                                                   
                   LASTNAME,                                                    
                   DATEOFBIRTH,                                                 
                   HOUSENAME,                                                   
                   HOUSENUMBER,                                                 
                   POSTCODE,                                                    
                   PHONEMOBILE,                                                 
                   PHONEHOME,                                                   
                   EMAILADDRESS )                                               
          VALUES ( :DB2_CUSTOMERNUM_INT,                                        
                   :CA_FIRST_NAME,                                              
                   :CA_LAST_NAME,                                               
                   :CA_DOB,                                                     
                   :CA_HOUSE_NAME,                                              
                   :CA_HOUSE_NUM,                                               
                   :CA_POSTCODE,                                                
                   :CA_PHONE_MOBILE,                                            
                   :CA_PHONE_HOME,                                              
                   :CA_EMAIL_ADDRESS );                                         
     IF (SQLCODE <> 0) THEN DO;                                                 
       CA_RETURN_CODE = '90';                                                   
       CALL WRITE_ERROR_MESSAGE;                                                
       EXEC CICS RETURN;                                                        
     END;                                                                       
   END;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_FIRST_NAME` | input | Supplies the customer's given name for the new record. |
| `CA_LAST_NAME` | input | Supplies the customer's family name for the new record. |
| `CA_DOB` | input | Supplies the customer's date of birth for the new record. |
| `CA_HOUSE_NAME` | input | Supplies the house name of the customer's address. |
| `CA_POSTCODE` | input | Supplies the postal code of the customer's address. |
| `CA_PHONE_MOBILE` | input | Supplies the customer's mobile phone number. |
| `CA_EMAIL_ADDRESS` | input | Supplies the customer's email address. |

**Procedures:**

* WRITE_ERROR_MESSAGE
#### 2.3.2 Insert customer with database-generated customer number

**Description:** When the named counter is not active, the customer is inserted letting the database generate the customer number, and the generated number is then retrieved.

**Core decision logic:**
- If the named counter is not active, the database assigns the customer number
- The generated customer number is captured for use in the rest of onboarding

**Code:**
```pl1
   ELSE DO;                                                                     
     EXEC SQL                                                                   
       INSERT INTO CUSTOMER                                                     
                 ( CUSTOMERNUMBER,                                              
                   FIRSTNAME,                                                   
                   LASTNAME,                                                    
                   DATEOFBIRTH,                                                 
                   HOUSENAME,                                                   
                   HOUSENUMBER,                                                 
                   POSTCODE,                                                    
                   PHONEMOBILE,                                                 
                   PHONEHOME,                                                   
                   EMAILADDRESS )                                               
          VALUES ( DEFAULT,                                                     
                   :CA_FIRST_NAME,                                              
                   :CA_LAST_NAME,                                               
                   :CA_DOB,                                                     
                   :CA_HOUSE_NAME,                                              
                   :CA_HOUSE_NUM,                                               
                   :CA_POSTCODE,                                                
                   :CA_PHONE_MOBILE,                                            
                   :CA_PHONE_HOME,                                              
                   :CA_EMAIL_ADDRESS );                                         
     IF (SQLCODE <> 0) THEN DO;                                                 
       CA_RETURN_CODE = '90';                                                   
       CALL WRITE_ERROR_MESSAGE;                                                
       EXEC CICS RETURN;                                                        
     END;                                                                       
  /* get value of assigned customer number */                                   
     EXEC SQL                                                                   
       SET :DB2_CUSTOMERNUM_INT = IDENTITY_VAL_LOCAL();                         
   END;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_FIRST_NAME` | input | Supplies the customer's given name for the new record. |
| `CA_LAST_NAME` | input | Supplies the customer's family name for the new record. |
| `CA_DOB` | input | Supplies the customer's date of birth for the new record. |
| `CA_HOUSE_NAME` | input | Supplies the house name of the customer's address. |
| `CA_POSTCODE` | input | Supplies the postal code of the customer's address. |
| `CA_PHONE_MOBILE` | input | Supplies the customer's mobile phone number. |
| `CA_EMAIL_ADDRESS` | input | Supplies the customer's email address. |

**Procedures:**

* WRITE_ERROR_MESSAGE
### 2.4 Procedure: TRANSFER_CUSTOMER

#### 2.4.1 Transfer customer policy unless claim request

**Description:** The customer policy transfer is performed only when the request is not a claim request.

**Core decision logic:**
- Policy transfer is skipped for claim requests ('01ACLM')
- Policy transfer runs for all other request types

**Code:**
```pl1
   IF (CA_REQUEST_ID ^= '01ACLM') THEN                                          
     CALL TRANSFER_CUSTOMER_POLICY;                                             
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_REQUEST_ID` | input | Compared with the claim request code to decide whether the policy transfer runs. |

**Procedures:**

* TRANSFER_CUSTOMER_POLICY
### 2.5 Procedure: DELETE_CUSTOMER

#### 2.5.1 Delete customer policy unless claim request

**Description:** The customer policy deletion is performed only when the request is not a claim request.

**Core decision logic:**
- Policy deletion is skipped for claim requests ('01ACLM')
- Policy deletion runs for all other request types

**Code:**
```pl1
   IF (CA_REQUEST_ID ^= '01ACLM') THEN                                          
     CALL DELETE_CUSTOMER_POLICY;                                               
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_REQUEST_ID` | input | Compared with the claim request code to decide whether the policy deletion runs. |

**Procedures:**

* DELETE_CUSTOMER_POLICY
### 2.6 Procedure: OFFER_CUSTOMER

#### 2.6.1 Offer customer policy unless claim request

**Description:** A policy is offered to the customer only when the request is not a claim request.

**Core decision logic:**
- Policy creation is skipped for claim requests ('01ACLM')
- Policy creation runs for all other request types

**Code:**
```pl1
   IF (CA_REQUEST_ID ^= '01ACLM') THEN                                          
     CALL INSERT_CUSTOMER_POLICY;                                               
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_REQUEST_ID` | input | Compared with the claim request code to decide whether the policy is offered. |

**Procedures:**

* INSERT_CUSTOMER_POLICY
### 2.7 Procedure: INSERT_CUSTOMER_POLICY

#### 2.7.1 Insert policy record for customer

**Description:** Creates a new policy for the customer with issue and expiry dates, policy type, broker details and payment, and stamps it with the current timestamp.

**Core decision logic:**
- A new policy is linked to the customer by customer number
- The policy number is generated by the database
- The last-changed timestamp is set to the current time

**Code:**
```pl1
   EM_SQLREQ = ' INSERT POLICY  ';                                              
   EXEC SQL                                                                     
     INSERT INTO POLICY                                                         
               ( POLICYNUMBER,                                                  
                 CUSTOMERNUMBER,                                                
                 ISSUEDATE,                                                     
                 EXPIRYDATE,                                                    
                 POLICYTYPE,                                                    
                 LASTCHANGED,                                                   
                 BROKERID,                                                      
                 BROKERSREFERENCE,                                              
                 PAYMENT           )                                            
        VALUES ( DEFAULT,                                                       
                 :DB2_CUSTOMERNUM_INT,                                          
                 :CA_ISSUE_DATE,                                                
                 :CA_EXPIRY_DATE,                                               
                 :DB2_POLICYTYPE,                                               
                 CURRENT TIMESTAMP,                                             
                 :DB2_BROKERID_INT,                                             
                 :CA_BROKERSREF,                                                
                 :DB2_PAYMENT_INT      );                                       
```

#### 2.7.2 Evaluate policy insert outcome

**Description:** Maps the policy insert result to a business return code; a -530 (referential integrity violation, i.e. the customer does not exist) is reported as '70'.

**Core decision logic:**
- Success yields return code '00'
- SQLCODE -530 (customer reference not valid) yields return code '70' and ends the request
- Any other failure yields return code '90' and ends the request

**Code:**
```pl1
   SELECT (SQLCODE);                                                            
     WHEN (0)                                                                   
         CA_RETURN_CODE = '00';                                                 
     WHEN (-530) DO;                                                            
         CA_RETURN_CODE = '70';                                                 
         CALL WRITE_ERROR_MESSAGE;                                              
         EXEC CICS RETURN;                                                      
     END;                                                                       
     OTHERWISE DO;                                                              
         CA_RETURN_CODE = '90';                                                 
         CALL WRITE_ERROR_MESSAGE;                                              
         EXEC CICS RETURN;                                                      
     END;                                                                       
   END;                                                                         
```

**Procedures:**

* WRITE_ERROR_MESSAGE
### 2.8 Procedure: TRANSFER_CUSTOMER_POLICY

#### 2.8.1 Insert transferred policy record for customer

**Description:** Creates a new policy record in the POLICY table for the customer being transferred, with the issue and expiry dates, policy type, broker details and payment amount. A new policy number is generated automatically and the last-changed timestamp is set to the current time.

**Core decision logic:**
- A new policy record is created for the customer as a domain state change
- The policy number is system-generated through the DEFAULT identity value
- The last-changed timestamp is set to the current time at creation

**Code:**
```pl1
   EM_SQLREQ = ' INSERT POLICY  ';                                              
   EXEC SQL                                                                     
     INSERT INTO POLICY                                                         
               ( POLICYNUMBER,                                                  
                 CUSTOMERNUMBER,                                                
                 ISSUEDATE,                                                     
                 EXPIRYDATE,                                                    
                 POLICYTYPE,                                                    
                 LASTCHANGED,                                                   
                 BROKERID,                                                      
                 BROKERSREFERENCE,                                              
                 PAYMENT           )                                            
        VALUES ( DEFAULT,                                                       
                 :DB2_CUSTOMERNUM_INT,                                          
                 :CA_ISSUE_DATE,                                                
                 :CA_EXPIRY_DATE,                                               
                 :DB2_POLICYTYPE,                                               
                 CURRENT TIMESTAMP,                                             
                 :DB2_BROKERID_INT,                                             
                 :CA_BROKERSREF,                                                
                 :DB2_PAYMENT_INT      );
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_POLICY_NUM` | output | Policy number field that later receives the generated policy number; the insert relies on the DEFAULT identity to produce it. |

#### 2.8.2 Policy insert outcome handling with duplicate/constraint check

**Description:** Evaluates the result of the policy insert. Success returns code '00'. A foreign-key violation (-530), meaning the referenced customer does not exist, returns '70'. Any other failure returns '90'. Failures are logged and processing stops.

**Core decision logic:**
- SQLCODE 0 means the policy was created successfully, return code '00'
- SQLCODE -530 means the customer reference is invalid, return code '70' and stop processing
- Any other SQL failure returns '90' and stops processing

**Code:**
```pl1
   SELECT (SQLCODE);                                                            
     WHEN (0)                                                                   
         CA_RETURN_CODE = '00';                                                 
     WHEN (-530) DO;                                                            
         CA_RETURN_CODE = '70';                                                 
         CALL WRITE_ERROR_MESSAGE;                                              
         EXEC CICS RETURN;                                                      
     END;                                                                       
     OTHERWISE DO;                                                              
         CA_RETURN_CODE = '90';                                                 
         CALL WRITE_ERROR_MESSAGE;                                              
         EXEC CICS RETURN;                                                      
     END;                                                                       
   END;
```

**Procedures:**

* WRITE_ERROR_MESSAGE
### 2.9 Procedure: DELETE_CUSTOMER_POLICY

#### 2.9.1 Delete customer policy record

**Description:** Removes the policy record that matches both the given customer number and policy number from the POLICY table. Both must match, so a customer's policy can only be deleted by its owner.

**Core decision logic:**
- A policy is deleted only when both the customer number and the policy number match
- Deleting the policy removes the domain record

**Code:**
```pl1
   EM_SQLREQ = ' DELETE POLICY  ';                                              
   EXEC SQL                                                                     
     DELETE                                                                     
       FROM POLICY                                                              
       WHERE ( CUSTOMERNUMBER = :DB2_CUSTOMERNUM_INT AND                        
               POLICYNUMBER  = :DB2_POLICYNUM_INT      );
```

#### 2.9.2 Delete outcome acceptance rule

**Description:** Checks the result of the policy delete. The comment in the source states that both SQLCODE 0 and 100 (record not found) are treated as successful because the end result is that the record no longer exists. Any other failure returns code '90', logs the error and stops processing.

**Core decision logic:**
- Any non-zero SQLCODE leads to return code '90' and termination
- Not-found handling is described in the source comment as a success case

**Code:**
```pl1
   IF (SQLCODE <> 0) THEN DO;                                                   
       CA_RETURN_CODE = '90';                                                   
       CALL WRITE_ERROR_MESSAGE;                                                
       EXEC CICS RETURN;                                                        
   END;
```

**Procedures:**

* WRITE_ERROR_MESSAGE

---

Generated by IBM Bob Premium Package for Z
