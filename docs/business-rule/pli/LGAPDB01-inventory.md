# Business rules: Inventory

**Program:** LGAPDB01

**Total rules extracted:** 25

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Procedure: LGAPDB01](#21-procedure-lgapdb01)
  - [2.2 Procedure: INSERT_POLICY](#22-procedure-insert_policy)
  - [2.3 Procedure: BUNDLING_DISCOUNT](#23-procedure-bundling_discount)
  - [2.4 Procedure: CALCULATE_COMMISSION](#24-procedure-calculate_commission)
  - [2.5 Procedure: INSERT_ENDOW](#25-procedure-insert_endow)
  - [2.6 Procedure: INSERT_HOUSE](#26-procedure-insert_house)
  - [2.7 Procedure: INSERT_MOTOR](#27-procedure-insert_motor)
  - [2.8 Procedure: INSERT_COMMERCIAL](#28-procedure-insert_commercial)
  - [2.9 Procedure: VALIDATE_PREV_PERIL](#29-procedure-validate_prev_peril)
  - [2.10 Procedure: INSERT_CLAIM](#210-procedure-insert_claim)
  - [2.11 Procedure: UPDATE_BROKER_COMM](#211-procedure-update_broker_comm)

## 1. Purpose

This document is an inventory of all business rules extracted from LGAPDB01, organised at the Procedure level. Each Procedure contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Procedures called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Procedure: LGAPDB01

#### 2.1.1 Route Request to Policy Type Handler and Assign Policy Type Code

**Description:** Evaluates the incoming request identifier to determine the type of policy addition being processed. Assigns the corresponding single-character policy type code for DB2 insertion and rejects unrecognised request identifiers with return code '99'.

**Core decision logic:**
- Request ID '01AEND' maps to policy type 'E' (Endowment)
- Request ID '01AHOU' maps to policy type 'H' (House)
- Request ID '01AMOT' maps to policy type 'M' (Motor)
- Request ID '01ACOM' maps to policy type 'C' (Commercial)
- Request ID '01ACLM' maps to policy type 'X' (Claim)
- Unrecognised request IDs are rejected with return code '99'

**Code:**
```pl1
  SELECT (CA_REQUEST_ID);

    WHEN ('01AEND') DO;
      WS_REQUIRED_CA_LEN = WS_FULL_ENDOW_LEN + WS_REQUIRED_CA_LEN;
      DB2_POLICYTYPE = 'E';
    END;

    WHEN ('01AHOU') DO;
      WS_REQUIRED_CA_LEN = WS_FULL_HOUSE_LEN + WS_REQUIRED_CA_LEN;
      DB2_POLICYTYPE = 'H';
    END;

    WHEN ('01AMOT') DO;
      WS_REQUIRED_CA_LEN = WS_FULL_MOTOR_LEN + WS_REQUIRED_CA_LEN;
      DB2_POLICYTYPE = 'M';
    END;

    WHEN ('01ACOM') DO;
      DB2_POLICYTYPE = 'C';
    END;

    WHEN ('01ACLM') DO;
      DB2_POLICYTYPE = 'X';
    END;

    OTHERWISE DO;
      CA_RETURN_CODE = '99';
      EXEC CICS RETURN;
    END;

  END; /* SELECT (CA_REQUEST_ID) */
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_REQUEST_ID` | input | Drives the SELECT chain to determine which policy type is being added and routes execution accordingly |
| `DB2_POLICYTYPE` | output | Receives the single-character policy type code ('E', 'H', 'M', 'C', or 'X') that will be stored in the DB2 POLICY table |
| `CA_RETURN_CODE` | output | Set to '99' when the request identifier is not recognised, signalling an invalid request to the calling program |

#### 2.1.2 Conditionally Insert Policy Record for Non-Claim Requests

**Description:** Enforces the business rule that a new POLICY table record must be created for all policy additions except claims. Claims reference an existing policy and therefore bypass the policy insert step.

**Core decision logic:**
- A new policy record is inserted for Endowment, House, Motor, and Commercial requests
- Claim additions do not trigger a new policy record insert, as they attach to an existing policy

**Code:**
```pl1
  If (CA_REQUEST_ID <> '01ACLM') THEN DO;
    CALL INSERT_POLICY;
  END;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_REQUEST_ID` | input | Checked to determine whether the request is a claim ('01ACLM'); if not, INSERT_POLICY is called to create a new policy record |

**Procedures:**

* INSERT_POLICY
#### 2.1.3 Dispatch Insert to Policy-Type-Specific Table

**Description:** Routes execution to the appropriate policy-type-specific INSERT procedure based on the request identifier, ensuring that detailed policy data is stored in the correct domain table (Endowment, House, Motor, Commercial, or Claim).

**Core decision logic:**
- Endowment requests are handled by INSERT_ENDOW
- House requests are handled by INSERT_HOUSE
- Motor requests are handled by INSERT_MOTOR
- Commercial requests are handled by INSERT_COMMERCIAL
- Claim requests are handled by INSERT_CLAIM
- Unrecognised request IDs result in return code '99'

**Code:**
```pl1
  SELECT (CA_REQUEST_ID);

    WHEN ('01AEND') DO;
      CALL INSERT_ENDOW;
    END;

    WHEN ('01AHOU') DO;
      CALL INSERT_HOUSE;
    END;

    WHEN ('01AMOT') DO;
      CALL INSERT_MOTOR;
    END;

    WHEN ('01ACOM') DO;
      CALL INSERT_COMMERCIAL;
    END;

    WHEN ('01ACLM') DO;
      CALL INSERT_CLAIM;
    END;

    OTHERWISE DO;
      CA_RETURN_CODE = '99';
    END;

  END; /* SELECT (CA_REQUEST_ID) */
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_REQUEST_ID` | input | Determines which policy-type-specific INSERT procedure is called to persist the detailed policy data |
| `CA_RETURN_CODE` | output | Set to '99' in the OTHERWISE branch when no matching policy type handler exists for the given request ID |

**Procedures:**

* INSERT_ENDOW
* INSERT_HOUSE
* INSERT_MOTOR
* INSERT_COMMERCIAL
* INSERT_CLAIM
### 2.2 Procedure: INSERT_POLICY

#### 2.2.1 Location-Based House Premium Loading

**Description:** For house insurance policies, applies a location-based premium surcharge when the property is situated in a high-risk postcode band (600000–699999). The surcharge rate is tiered by property value: 20% for properties valued between £100,000–£150,000, 40% for £150,000–£200,000, and 50% for properties valued above £200,000.

**Core decision logic:**
- Only applies to house policy requests (CA_REQUEST_ID = '01AHOU')
- Premium loading is triggered only for properties in postcode range 600000–699999
- Property value band £100,000–£150,000 incurs a 20% premium surcharge
- Property value band £150,000–£200,000 incurs a 40% premium surcharge
- Property value above £200,000 incurs a 50% premium surcharge

**Code:**
```pl1
  /* Increase premium based on house location and value */                      
  IF (CA_REQUEST_ID = '01AHOU') THEN DO;                                        
    DB2_H_VALUE_INT = CA_H_VALUE;                                               
    IF (CA_H_POSTCODE > '600000' & CA_H_POSTCODE < '699999') THEN DO;           
      IF (DB2_H_VALUE_INT > 10000000 & DB2_H_VALUE_INT < 15000000)              
        THEN DB2_PAYMENT_INT = DB2_PAYMENT_INT + DB2_PAYMENT_INT * 0.2;         
      IF (DB2_H_VALUE_INT > 15000000 & DB2_H_VALUE_INT < 20000000)              
        THEN DB2_PAYMENT_INT = DB2_PAYMENT_INT + DB2_PAYMENT_INT * 0.4;         
      IF (DB2_H_VALUE_INT > 20000000)                                           
        THEN DB2_PAYMENT_INT = DB2_PAYMENT_INT + DB2_PAYMENT_INT * 0.5;         
    END;                                                                        
  END;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_REQUEST_ID` | input | Identifies the request type as a house policy ('01AHOU') to determine whether location-based premium loading logic should be applied. |
| `DB2_PAYMENT_INT` | output | Receives the adjusted payment amount after the location-based surcharge percentage is added to the base premium. |

#### 2.2.2 Apply Bundling Discount for Motor and House Policies

**Description:** Invokes the bundling discount procedure to evaluate whether the customer qualifies for a 15% discount on their premium based on holding more than two active Motor or House policies.

**Core decision logic:**
- Customers with more than two active Motor or House policies are eligible for a 15% bundling discount on the new policy payment

**Code:**
```pl1
  /* Bundling discount for motor and house policies */                          
  CALL BUNDLING_DISCOUNT;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DB2_PAYMENT_INT` | output | May be reduced by 15% within BUNDLING_DISCOUNT if the customer meets the multi-policy bundling eligibility threshold. |
| `DB2_CUSTOMERNUM_INT` | input | Passed to BUNDLING_DISCOUNT to query active Motor or House policies belonging to this customer. |

**Procedures:**

* BUNDLING_DISCOUNT
#### 2.2.3 Calculate Broker Commission

**Description:** Invokes the commission calculation procedure to determine the broker's commission amount for this policy, based on the number of active policies the broker currently holds, applying tiered commission rates from 0% to 5%.

**Core decision logic:**
- Broker commission rate is tiered based on total active policies held by the broker
- Commission must be calculated and set before the POLICY table INSERT is executed

**Code:**
```pl1
  /* Broker commission based on number of policies held */                      
  CALL CALCULATE_COMMISSION;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS_COMMISSION` | output | Receives the calculated commission value from CALCULATE_COMMISSION for subsequent insertion into the POLICY table COMMISSION column. |
| `DB2_PAYMENT_INT` | input | Used within CALCULATE_COMMISSION as the base amount against which the commission percentage is applied. |

**Procedures:**

* CALCULATE_COMMISSION
#### 2.2.4 Insert New Policy Record into POLICY Table

**Description:** Inserts a new policy record into the DB2 POLICY table with all associated attributes including the customer number, policy type, issue and expiry dates, broker details, the (possibly adjusted) payment amount, and the calculated commission. The policy number is system-generated.

**Core decision logic:**
- Policy number is DB2-generated via DEFAULT (IDENTITY column)
- Payment stored reflects any location-based surcharges and bundling discounts already applied
- Commission stored reflects the broker's tiered commission rate
- Policy type is derived from the request identifier

**Code:**
```pl1
  EM_SQLREQ = ' INSERT POLICY';                                                 
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
                    PAYMENT,                                                    
                    COMMISSION       )                                          
           VALUES ( DEFAULT,                                                    
                    :DB2_CUSTOMERNUM_INT,                                       
                    :CA_ISSUE_DATE,                                             
                    :CA_EXPIRY_DATE,                                            
                    :DB2_POLICYTYPE,                                            
                    CURRENT TIMESTAMP,                                          
                    :DB2_BROKERID_INT,                                          
                    :CA_BROKERSREF,                                             
                    :DB2_PAYMENT_INT,                                           
                    :WS_COMMISSION     );
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DB2_CUSTOMERNUM_INT` | input | Supplies the customer number as a host variable for the POLICY table INSERT to associate the policy with the correct customer. |
| `DB2_POLICYTYPE` | input | Supplies the single-character policy type code for the POLICYTYPE column of the POLICY table INSERT. |
| `DB2_PAYMENT_INT` | input | Supplies the final adjusted payment amount (after surcharges and discounts) for the PAYMENT column of the POLICY table INSERT. |
| `WS_COMMISSION` | input | Supplies the broker commission amount for the COMMISSION column of the POLICY table INSERT. |

#### 2.2.5 Handle Policy Insert Outcome and Set Return Code

**Description:** Evaluates the outcome of the POLICY table INSERT and sets the communication area return code accordingly: '00' for success, '70' for a referential integrity violation (foreign key constraint failure indicating the customer does not exist), and '90' for any other DB2 error.

**Core decision logic:**
- A successful INSERT sets return code '00' to signal success to the caller
- SQLCODE -530 (referential integrity violation) sets return code '70', indicating the customer number is invalid
- Any other DB2 error sets return code '90' and terminates processing

**Code:**
```pl1
  SELECT (SQLCODE);                                                             
                                                                                
    When (0) DO;                                                                
      CA_RETURN_CODE = '00';                                                    
    END;                                                                        
                                                                                
    When (-530) DO;                                                             
      CA_RETURN_CODE = '70';                                                    
      CALL WRITE_ERROR_MESSAGE;                                                 
      EXEC CICS RETURN;                                                         
    END;                                                                        
                                                                                
    OTHERWISE DO;                                                               
      CA_RETURN_CODE = '90';                                                    
      CALL WRITE_ERROR_MESSAGE;                                                 
      EXEC CICS RETURN;                                                         
    END;                                                                        
                                                                                
  END; /* SELECT (SQLCODE) */
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_RETURN_CODE` | output | Receives the outcome code ('00', '70', or '90') based on the POLICY INSERT result to communicate processing status back to the caller. |

**Procedures:**

* WRITE_ERROR_MESSAGE
#### 2.2.6 Retrieve DB2-Generated Policy Number and Store in Communication Area

**Description:** Retrieves the DB2-generated policy number assigned during the POLICY INSERT via IDENTITY_VAL_LOCAL() and stores it back into the communication area field CA_POLICY_NUM, making the new policy number available to the calling program for subsequent processing such as inserting into sub-type tables.

**Core decision logic:**
- The DB2-assigned policy number must be captured immediately after INSERT and returned to the caller via the communication area
- CA_POLICY_NUM is set to the system-generated policy number for use in downstream policy sub-type inserts

**Code:**
```pl1
 /*    get value of assigned policy number */                                   
  EXEC SQL                                                                      
        SET :DB2_POLICYNUM_INT = IDENTITY_VAL_LOCAL();                          
                                                                                
  CA_POLICY_NUM = DB2_POLICYNUM_INT;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DB2_POLICYNUM_INT` | output | Receives the DB2-generated policy number from IDENTITY_VAL_LOCAL() for storage into CA_POLICY_NUM. |
| `CA_POLICY_NUM` | output | Receives the DB2-assigned policy number to make it available to the calling program for subsequent sub-type table inserts. |

### 2.3 Procedure: BUNDLING_DISCOUNT

#### 2.3.1 Apply 15% Bundling Discount for Multi-Policy Customers

**Description:** Applies a 15% discount to the policy payment amount when the customer currently holds more than two active Motor or House policies, rewarding multi-policy customers with a bundling discount.

**Core decision logic:**
- A customer must hold more than 2 active Motor or House policies to qualify for the bundling discount
- The bundling discount reduces the payment amount by 15%
- The discount is only applied when the DB2 query completed successfully (SQLCODE = 0)

**Code:**
```pl1
  IF (SQLCODE = 0 & WS_CNT_POLICY > 2) THEN                                     
    DB2_PAYMENT_INT = DB2_PAYMENT_INT - (DB2_PAYMENT_INT * 0.15);
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS_CNT_POLICY` | input | Holds the count of active Motor or House policies for the customer; determines whether the 15% bundling discount threshold is met. |
| `DB2_PAYMENT_INT` | output | Receives the reduced payment amount after the 15% bundling discount is subtracted. |
| `DB2_CUSTOMERNUM_INT` | input | Used in the preceding SELECT to count active Motor or House policies belonging to the customer being assessed for bundling eligibility. |

### 2.4 Procedure: CALCULATE_COMMISSION

#### 2.4.1 Determine Broker Commission Rate Based on Active Policy Count

**Description:** Calculates the broker commission amount using a tiered rate structure based on the total number of active policies the broker currently holds: 0 policies = no commission, 1 policy = 1%, 2 policies = 2%, 3 policies = 3%, 4 policies = 4%, and 5 or more policies = 5% of the payment amount.

**Core decision logic:**
- Brokers with 0 active policies receive 0% commission
- Brokers with 1 active policy receive 1% commission
- Brokers with 2 active policies receive 2% commission
- Brokers with 3 active policies receive 3% commission
- Brokers with 4 active policies receive 4% commission
- Brokers with 5 or more active policies receive 5% commission (maximum rate)
- Commission is calculated only when the DB2 policy count query succeeded (SQLCODE = 0)

**Code:**
```pl1
  IF (SQLCODE = 0) THEN DO;                                                     
    SELECT (WS_CNT_POLICY);                                                     
      WHEN (0) WS_COMMISSION = 0;                                               
      WHEN (1) WS_COMMISSION = DB2_PAYMENT_INT * 0.01;                          
      WHEN (2) WS_COMMISSION = DB2_PAYMENT_INT * 0.02;                          
      WHEN (3) WS_COMMISSION = DB2_PAYMENT_INT * 0.03;                          
      WHEN (4) WS_COMMISSION = DB2_PAYMENT_INT * 0.04;                          
      OTHERWISE WS_COMMISSION = DB2_PAYMENT_INT * 0.05;                         
    END;                                                                        
  END;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS_CNT_POLICY` | input | Holds the count of active policies for the broker, used to select the appropriate commission rate tier. |
| `WS_COMMISSION` | output | Receives the calculated commission amount based on the broker's active policy count and the applicable tiered percentage of the payment. |
| `DB2_PAYMENT_INT` | input | Provides the base payment amount against which the tiered commission percentage is applied to derive the commission value. |

### 2.5 Procedure: INSERT_ENDOW

#### 2.5.1 Insert Endowment Policy Record with Optional Padding Data

**Description:** Inserts a new endowment policy record into the ENDOWMENT table. When the communication area contains variable-length padding data (WS_VARY_LEN > 0), the insert includes the PADDINGDATA varchar column; otherwise the insert omits that column. Both paths store all core endowment attributes including policy number, investment options, fund name, term, sum assured, and life assured.

**Core decision logic:**
- When the communication area length exceeds the required minimum, the endowment insert includes the variable-length PADDINGDATA field
- When no additional padding data is present, the endowment insert proceeds without the PADDINGDATA column
- The endowment record is linked to the parent policy via DB2_POLICYNUM_INT as a foreign key

**Code:**
```pl1
  IF (WS_VARY_LEN > 0) THEN DO;                                                 
 /*       Commarea contains data for Varchar field */                           
     SUBSTR(WS_VARY_CHAR,1,WS_VARY_LEN) = CA_E_PADDING_DATA;                    
                                                                                
       INSERT INTO ENDOWMENT                                                    
                 ( POLICYNUMBER,                                                
                   WITHPROFITS,                                                 
                   EQUITIES,                                                    
                   MANAGEDFUND,                                                 
                   FUNDNAME,                                                    
                   TERM,                                                        
                   SUMASSURED,                                                  
                   LIFEASSURED,                                                 
                   PADDINGDATA    )                                             
          VALUES ( :DB2_POLICYNUM_INT,                                          
                   :CA_E_WITH_PROFITS,                                          
                   :CA_E_EQUITIES,                                              
                   :CA_E_MANAGED_FUND,                                          
                   :CA_E_FUND_NAME,                                             
                   :DB2_E_TERM_SINT,                                            
                   :DB2_E_SUMASSURED_INT,                                       
                   :CA_E_LIFE_ASSURED,                                          
                   :WS_VARY_FIELD );                                            
  END;                                                                          
  ELSE DO;                                                                      
     EXEC SQL                                                                   
       INSERT INTO ENDOWMENT                                                    
                 ( POLICYNUMBER,                                                
                   WITHPROFITS,                                                 
                   EQUITIES,                                                    
                   MANAGEDFUND,                                                 
                   FUNDNAME,                                                    
                   TERM,                                                        
                   SUMASSURED,                                                  
                   LIFEASSURED    )                                             
          VALUES ( :DB2_POLICYNUM_INT,                                          
                   :CA_E_WITH_PROFITS,                                          
                   :CA_E_EQUITIES,                                              
                   :CA_E_MANAGED_FUND,                                          
                   :CA_E_FUND_NAME,                                             
                   :DB2_E_TERM_SINT,                                            
                   :DB2_E_SUMASSURED_INT,                                       
                   :CA_E_LIFE_ASSURED );                                        
  END;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DB2_POLICYNUM_INT` | input | Supplies the DB2-generated policy number as the foreign key linking the ENDOWMENT record to its parent POLICY record. |

### 2.6 Procedure: INSERT_HOUSE

#### 2.6.1 Insert House Policy Record into HOUSE Table

**Description:** Creates a new house insurance policy record in the HOUSE table, associating property details such as type, bedrooms, value, address, and postcode with the DB2-generated policy number.

**Core decision logic:**
- A house policy record must be created in the HOUSE table linked to the DB2-assigned policy number
- All property attributes including type, bedrooms, value, house name, number, and postcode are persisted as part of the house policy domain record

**Code:**
```pl1
  EM_SQLREQ = ' INSERT HOUSE ';                                                 
  EXEC SQL                                                                      
        INSERT INTO HOUSE                                                       
                  ( POLICYNUMBER,                                               
                    PROPERTYTYPE,                                               
                    BEDROOMS,                                                   
                    VALUE,                                                      
                    HOUSENAME,                                                  
                    HOUSENUMBER,                                                
                    POSTCODE          )                                         
           VALUES ( :DB2_POLICYNUM_INT,                                         
                    :CA_H_PROPERTY_TYPE,                                        
                    :DB2_H_BEDROOMS_SINT,                                       
                    :DB2_H_VALUE_INT,                                           
                    :CA_H_HOUSE_NAME,                                           
                    :CA_H_HOUSE_NUMBER,                                         
                    :CA_H_POSTCODE      );
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DB2_POLICYNUM_INT` | input | Supplies the DB2-generated policy number as the primary key linking the HOUSE record to the POLICY table |

### 2.7 Procedure: INSERT_MOTOR

#### 2.7.1 Adjust Motor Premium Based on Accident History

**Description:** Calculates the motor insurance premium loading based on the policyholder's accident history. No surcharge applies for 0–2 accidents; a 20% increase for 3–5 accidents; a 50% increase for 6–8 accidents; and the premium is tripled (300%) for more than 8 accidents.

**Core decision logic:**
- 0–2 accidents: no premium adjustment (factor 1.00)
- 3–5 accidents: 20% premium surcharge applied (factor 1.20)
- 6–8 accidents: 50% premium surcharge applied (factor 1.50)
- More than 8 accidents: premium tripled, i.e. 200% surcharge (factor 3.00)
- Adjusted premium and accident count are stored in integer host variables for DB2 insertion

**Code:**
```pl1
  /* Adjust premium based on accident history */                                
  IF (CA_M_ACCIDENTS <= 2) THEN                                                 
    CA_M_PREMIUM = CA_M_PREMIUM * 1.00;                                         
  IF (CA_M_ACCIDENTS > 2 & CA_M_ACCIDENTS <= 5) THEN                            
    CA_M_PREMIUM = CA_M_PREMIUM * 1.20;                                         
  IF (CA_M_ACCIDENTS > 5 & CA_M_ACCIDENTS <= 8) THEN                            
    CA_M_PREMIUM = CA_M_PREMIUM * 1.50;                                         
  IF (CA_M_ACCIDENTS > 8) THEN                                                  
    CA_M_PREMIUM = CA_M_PREMIUM * 3.00;                                         
  DB2_M_PREMIUM_INT = CA_M_PREMIUM;                                             
  DB2_M_ACCIDENTS_INT = CA_M_ACCIDENTS;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_M_ACCIDENTS` | input | Drives the accident-based premium loading tier selection; its value determines which multiplier is applied to the base premium |
| `CA_M_PREMIUM` | output | Receives the adjusted motor premium after the appropriate accident-history loading factor has been applied |

#### 2.7.2 Insert Motor Policy Record into MOTOR Table

**Description:** Creates a new motor insurance policy record in the MOTOR table, persisting all vehicle details including make, model, value, registration, colour, engine size, year of manufacture, the accident-adjusted premium, and the accident count.

**Core decision logic:**
- A motor policy record must be created in the MOTOR table linked to the DB2-assigned policy number
- The accident-adjusted premium and accident count are stored as part of the permanent motor policy domain record

**Code:**
```pl1
  EM_SQLREQ = ' INSERT MOTOR ';                                                 
  EXEC SQL                                                                      
        INSERT INTO MOTOR                                                       
                  ( POLICYNUMBER,                                               
                    MAKE,                                                       
                    MODEL,                                                      
                    VALUE,                                                      
                    REGNUMBER,                                                  
                    COLOUR,                                                     
                    CC,                                                         
                    YEAROFMANUFACTURE,                                          
                    PREMIUM,                                                    
                    ACCIDENTS )                                                 
           VALUES ( :DB2_POLICYNUM_INT,                                         
                    :CA_M_MAKE,                                                 
                    :CA_M_MODEL,                                                
                    :DB2_M_VALUE_INT,                                           
                    :CA_M_REGNUMBER,                                            
                    :CA_M_COLOUR,                                               
                    :DB2_M_CC_SINT,                                             
                    :CA_M_MANUFACTURED,                                         
                    :DB2_M_PREMIUM_INT,                                         
                    :DB2_M_ACCIDENTS_INT );
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DB2_POLICYNUM_INT` | input | Supplies the DB2-generated policy number as the foreign key linking the MOTOR record to the POLICY table |

### 2.8 Procedure: INSERT_COMMERCIAL

#### 2.8.1 Determine Flood and Weather Peril Risk via Previous Peril Validation

**Description:** Invokes the VALIDATE_PREV_PERIL procedure to assess whether the postcode area has a high historical concentration of flood or weather peril claims, setting flags that drive premium surcharge decisions for the commercial policy.

**Core decision logic:**
- Before inserting a commercial policy, the system must evaluate previous peril activity in the same postcode area to determine if flood or weather risk surcharges apply

**Code:**
```pl1
  /* Increase payment for weather/flood perils */                               
  CALL VALIDATE_PREV_PERIL;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS_FLOOD_FLG` | output | Receives the flood risk flag set by VALIDATE_PREV_PERIL, indicating whether a flood surcharge must be applied to the commercial premium |
| `WS_WEATHER_FLG` | output | Receives the weather risk flag set by VALIDATE_PREV_PERIL, indicating whether a weather surcharge must be applied to the commercial premium |

**Procedures:**

* VALIDATE_PREV_PERIL
#### 2.8.2 Apply 15% Flood Premium Surcharge for High-Risk Flood Zone

**Description:** Increases the flood premium by 15% when the postcode area has been identified as a high-risk flood zone based on historical peril data from existing commercial policies in the same area.

**Core decision logic:**
- A 15% surcharge is applied to the flood premium when WS_FLOOD_FLG is 'Y', indicating the postcode area exceeds the flood peril concentration threshold

**Code:**
```pl1
  IF (WS_FLOOD_FLG = 'Y') THEN                                                  
    DB2_B_FloodPremium_INT = DB2_B_FloodPremium_INT +                           
                             (DB2_B_FloodPremium_INT * 0.15);
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS_FLOOD_FLG` | input | Controls whether the 15% flood premium surcharge is applied; a value of 'Y' triggers the loading |

#### 2.8.3 Apply 15% Weather Premium Surcharge for High-Risk Weather Zone

**Description:** Increases the weather premium by 15% when the postcode area has been identified as a high-risk weather zone based on historical peril data from existing commercial policies in the same area.

**Core decision logic:**
- A 15% surcharge is applied to the weather premium when WS_WEATHER_FLG is 'Y', indicating the postcode area exceeds the weather peril concentration threshold

**Code:**
```pl1
  IF (WS_WEATHER_FLG = 'Y') THEN                                                
    DB2_B_WeatherPremium_INT = DB2_B_WeatherPremium_INT +                       
                               (DB2_B_WeatherPremium_INT * 0.15);
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS_WEATHER_FLG` | input | Controls whether the 15% weather premium surcharge is applied; a value of 'Y' triggers the loading |

#### 2.8.4 Insert Commercial Policy Record into COMMERCIAL Table

**Description:** Creates a new commercial insurance policy record in the COMMERCIAL table, persisting all property, peril, premium (including any risk-zone surcharges), status, and geolocation details linked to the DB2-assigned policy number.

**Core decision logic:**
- A commercial policy record must be created in the COMMERCIAL table linked to the DB2-assigned policy number
- All peril and premium fields, including flood and weather values already adjusted for high-risk zone surcharges, are stored as the permanent commercial policy domain record
- Status and rejection reason are recorded as part of the commercial policy domain state

**Code:**
```pl1
  EM_SQLREQ = ' INSERT COMMER';                                                 
  EXEC SQL                                                                      
        INSERT INTO COMMERCIAL                                                  
                  (                                                             
                    PolicyNumber,                                               
                    RequestDate,                                                
                    StartDate,                                                  
                    RenewalDate,                                                
                    Address,                                                    
                    Zipcode,                                                    
                    LatitudeN,                                                  
                    LongitudeW,                                                 
                    Customer,                                                   
                    PropertyType,                                               
                    FirePeril,                                                  
                    FirePremium,                                                
                    CrimePeril,                                                 
                    CrimePremium,                                               
                    FloodPeril,                                                 
                    FloodPremium,                                               
                    WeatherPeril,                                               
                    WeatherPremium,                                             
                    Status,                                                     
                    RejectionReason                                             
                                        )                                       
           VALUES (                                                             
                    :DB2_POLICYNUM_INT,                                         
                    :CA_LASTCHANGED,                                            
                    :CA_ISSUE_DATE,                                             
                    :CA_EXPIRY_DATE,                                            
                    :CA_B_Address,                                              
                    :CA_B_Postcode,                                             
                    :CA_B_Latitude,                                             
                    :CA_B_Longitude,                                            
                    :CA_B_Customer,                                             
                    :CA_B_PropType,                                             
                    :DB2_B_FirePeril_INT,                                       
                    :DB2_B_FirePremium_INT,                                     
                    :DB2_B_CrimePeril_INT,                                      
                    :DB2_B_CrimePremium_INT,                                    
                    :DB2_B_FloodPeril_INT,                                      
                    :DB2_B_FloodPremium_INT,                                    
                    :DB2_B_WeatherPeril_INT,                                    
                    :DB2_B_WeatherPremium_INT,                                  
                    :DB2_B_Status_INT,                                          
                    :CA_B_RejectReason                                          
                                        );
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DB2_POLICYNUM_INT` | input | Supplies the DB2-generated policy number as the foreign key linking the COMMERCIAL record to the POLICY table |

### 2.9 Procedure: VALIDATE_PREV_PERIL

#### 2.9.1 Determine Flood Risk Flag Based on Historical Flood Peril Concentration

**Description:** Queries the COMMERCIAL table to sum all active flood peril values for the same postcode area. If the sum exceeds 3, the postcode is classified as a high-risk flood zone and the flood flag is set to 'Y', which will trigger a 15% premium surcharge on the new commercial policy.

**Core decision logic:**
- A postcode area with a cumulative active flood peril sum greater than 3 is classified as a high-risk flood zone
- The flood risk flag WS_FLOOD_FLG is set to 'Y' when the high-risk threshold is exceeded, triggering a premium surcharge

**Code:**
```pl1
  WS_PERILCNT   = 0;                                                            
  WS_FLOOD_FLG  = ' ';                                                          
  EXEC SQL                                                                      
        SELECT SUM(FLOODPERIL)                                                  
          INTO :WS_PERILCNT                                                     
          FROM COMMERCIAL                                                       
          WHERE (STARTDATE  < CURRENT DATE                                      
          OR    RENEWALDATE > CURRENT DATE)                                     
          AND   ZIPCODE = :CA_B_POSTCODE;                                       
                                                                                
  IF (SQLCODE = 0 & WS_PERILCNT > 3) THEN                                       
    WS_FLOOD_FLG = 'Y';
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS_FLOOD_FLG` | output | Set to 'Y' when the sum of active flood perils in the postcode area exceeds 3, flagging the zone as high-risk and triggering a 15% flood premium surcharge |
| `WS_CNT_POLICY` | output | Accumulates the sum of FLOODPERIL values for active commercial policies in the same postcode area to determine flood zone risk classification |

#### 2.9.2 Determine Weather Risk Flag Based on Historical Weather Peril Concentration

**Description:** Queries the COMMERCIAL table to sum all active weather peril values for the same postcode area. If the sum exceeds 3, the postcode is classified as a high-risk weather zone and the weather flag is set to 'Y', which will trigger a 15% premium surcharge on the new commercial policy.

**Core decision logic:**
- A postcode area with a cumulative active weather peril sum greater than 3 is classified as a high-risk weather zone
- The weather risk flag WS_WEATHER_FLG is set to 'Y' when the high-risk threshold is exceeded, triggering a premium surcharge

**Code:**
```pl1
  WS_PERILCNT   = 0;                                                            
  WS_WEATHER_FLG = ' ';                                                         
  EXEC SQL                                                                      
        SELECT SUM(WEATHERPERIL)                                                
          INTO :WS_PERILCNT                                                     
          FROM COMMERCIAL                                                       
          WHERE (STARTDATE  < CURRENT DATE                                      
          OR    RENEWALDATE > CURRENT DATE)                                     
          AND   ZIPCODE = :CA_B_POSTCODE;                                       
                                                                                
  IF (SQLCODE = 0 & WS_PERILCNT > 3) THEN                                       
    WS_WEATHER_FLG = 'Y';
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS_WEATHER_FLG` | output | Set to 'Y' when the sum of active weather perils in the postcode area exceeds 3, flagging the zone as high-risk and triggering a 15% weather premium surcharge |

### 2.10 Procedure: INSERT_CLAIM

#### 2.10.1 Reduce Broker Commission for Frequent Claims

**Description:** Invokes the UPDATE_BROKER_COMM procedure to evaluate whether the policy associated with this claim has exceeded the claim frequency threshold, and if so, reduces the broker's commission. This enforces the business policy that penalises brokers linked to high-claim policies.

**Core decision logic:**
- Broker commission must be reviewed and potentially reduced whenever a new claim is inserted against a policy

**Code:**
```pl1
  /* Reduce broker commission for frequent claims */                            
  CALL UPDATE_BROKER_COMM;
```

**Procedures:**

* UPDATE_BROKER_COMM
#### 2.10.2 Insert Claim Record into CLAIM Table

**Description:** Inserts a new claim record into the CLAIM table with all relevant claim details including claim number, policy number, claim date, paid amount, value, cause, and observations. After insertion, the assigned claim number is written back to the communication area for return to the calling program.

**Core decision logic:**
- A new claim record is created in the CLAIM table associated with the relevant policy
- The DB2-assigned claim number is returned to the caller via the communication area

**Code:**
```pl1
  EM_SQLREQ = ' INSERT CLAIM';                                                  
  EXEC SQL                                                                      
        INSERT INTO CLAIM                                                       
                  (                                                             
                    ClaimNumber,                                                
                    PolicyNumber,                                               
                    ClaimDate,                                                  
                    Paid,                                                       
                    Value,                                                      
                    Cause,                                                      
                    Observations                                                
                                        )                                       
           VALUES (                                                             
                    :DB2_C_Num_INT,                                             
                    :DB2_C_Policynum_INT,                                       
                    :CA_C_Date,                                                 
                    :DB2_C_Paid_INT,                                            
                    :DB2_C_Value_INT,                                           
                    :CA_C_Cause,                                                
                    :CA_C_Observations                                          
                                        );                                      
                                                                                
  CA_C_Num = DB2_C_Num_INT;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CA_RETURN_CODE` | output | Set to '90' if the INSERT fails, signalling a DB2 error back to the calling program |

### 2.11 Procedure: UPDATE_BROKER_COMM

#### 2.11.1 Count Current-Year Claims for Policy

**Description:** Retrieves the number of claims submitted against the current policy in the current calendar year. This count is then used to determine whether the broker commission penalty threshold has been breached.

**Core decision logic:**
- Only claims within the current calendar year are considered when evaluating broker commission eligibility for reduction

**Code:**
```pl1
  WS_CLM_CNT = 0;                                                               
  EXEC SQL                                                                      
        SELECT COUNT(CLAIMNUMBER)                                               
          INTO :WS_CLM_CNT                                                      
          FROM CLAIM                                                            
          WHERE POLICYNUMBER = :DB2_C_Policynum_INT                             
          AND  YEAR(CLAIMDATE) = YEAR(CURRENT DATE);
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS_CLM_CNT` | output | Receives the count of current-year claims for the policy, used to determine if the broker commission penalty threshold is exceeded |

#### 2.11.2 Halve Broker Commission When Claim Count Exceeds Three

**Description:** When a policy has more than three claims recorded in the current calendar year, the broker's commission for that policy is halved by updating the COMMISSION column in the POLICY table. This enforces the business rule that penalises brokers associated with high-claim policies.

**Core decision logic:**
- If more than three claims exist for a policy in the current year, the broker commission is reduced by 50%
- The commission penalty is applied directly to the POLICY table record via a DB2 UPDATE

**Code:**
```pl1
  IF (SQLCODE = 0 & WS_CLM_CNT > 3) THEN DO;                                    
    EXEC SQL                                                                    
          UPDATE POLICY                                                         
             SET COMMISSION = (COMMISSION / 2)                                  
          WHERE POLICYNUMBER = :DB2_C_Policynum_INT;                            
  END;
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS_CLM_CNT` | input | Provides the current-year claim count that is compared against the threshold of 3 to determine whether the commission penalty applies |
| `WS_COMMISSION` | output | The COMMISSION value in the POLICY table is halved when claim count exceeds 3, reflecting the updated broker commission after the penalty |

---

Generated by IBM Bob Premium Package for Z
