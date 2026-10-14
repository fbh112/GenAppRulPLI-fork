 /*********************************************************************/
 /* DCLGEN TABLE(GENASA1.POLICY)                                      */
 /*        LIBRARY(IBMUSER.COBOL.COPYLIB(POLICY))                     */
 /*        ACTION(REPLACE)                                            */
 /*        LANGUAGE(PLI)                                              */
 /*        APOST                                                      */
 /* ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS      */
 /*********************************************************************/
 EXEC SQL DECLARE POLICY TABLE
           ( POLICYNUMBER                   INTEGER NOT NULL,
             CUSTOMERNUMBER                 INTEGER NOT NULL,
             ISSUEDATE                      DATE,
             EXPIRYDATE                     DATE,
             POLICYTYPE                     CHAR(1),
             LASTCHANGED                    TIMESTAMP NOT NULL,
             BROKERID                       INTEGER,
             BROKERSREFERENCE               CHAR(10),
             PAYMENT                        INTEGER,
             COMMISSION                     SMALLINT
           ) ;
 /*********************************************************************/
 /* PLI DECLARATION FOR TABLE GENASA1.POLICY                          */
 /*********************************************************************/
 DCL 1 DCLPOLICY,
      5 POLICYNUMBER  BIN FIXED(31),
      5 CUSTOMERNUMBER  BIN FIXED(31),
      5 ISSUEDATE  CHAR(10),
      5 EXPIRYDATE  CHAR(10),
      5 POLICYTYPE  CHAR(1),
      5 LASTCHANGED  CHAR(26),
      5 BROKERID BIN FIXED(31),
      5 BROKERSREFERENCE  CHAR(10),
      5 PAYMENT  BIN FIXED(31),
      5 COMMISSION  BIN FIXED(15);
 /*********************************************************************/
 /* THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 10         */
 /*********************************************************************/