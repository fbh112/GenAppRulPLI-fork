 /*********************************************************************/
 /* DCLGEN TABLE(GENASA1.ENDOWMENT)                                   */
 /*        LIBRARY(IBMUSER.COBOL.COPYLIB(DCLENDOW))                   */
 /*        ACTION(REPLACE)                                            */
 /*        LANGUAGE(PLI)                                              */
 /*        APOST                                                      */
 /* ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS      */
 /*********************************************************************/
 EXEC SQL DECLARE ENDOWMENT TABLE
           ( POLICYNUMBER                   INTEGER NOT NULL,
             EQUITIES                       CHAR(1),
             WITHPROFITS                    CHAR(1),
             MANAGEDFUND                    CHAR(1),
             FUNDNAME                       CHAR(10),
             TERM                           SMALLINT,
             SUMASSURED                     INTEGER,
             LIFEASSURED                    CHAR(31),
             PADDINGDATA                    VARCHAR(32606)
           ) ;
 /*********************************************************************/
 /* PLI DECLARATION FOR TABLE GENASA1.ENDOWMENT                       */
 /*********************************************************************/
 DCL 1 DCLENDOWMENT,
      5 POLICYNUMBER  BIN FIXED(31),
      5 EQUITIES CHAR(1),
      5 WITHPROFITS  CHAR(1),
      5 MANAGEDFUND  CHAR(1),
      5 FUNDNAME CHAR(10),
      5 TERM     BIN FIXED(15),
      5 SUMASSURED  BIN FIXED(31),
      5 LIFEASSURED  CHAR(31),
      5 PADDINGDATA  CHAR(32606) VAR;
 /*********************************************************************/
 /* THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 9          */
 /*********************************************************************/