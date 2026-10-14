//GENABIND JOB 241901,'BIND PROGRAMS',NOTIFY=&SYSUID,CLASS=A,MSGCLASS=H
//*
//* LICENSED MATERIALS - PROPERTY OF IBM
//*
//* "RESTRICTED MATERIALS OF IBM"
//*
//* CB12
//*
//* (C) COPYRIGHT IBM CORP. 2011, 2013 ALL RIGHTS RESERVED
//*
//*  US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION,
//*  OR DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE
//*  CONTRACT WITH IBM CORPORATION
//*
//BIND    EXEC PGM=IKJEFT01,DYNAMNBR=20
//STEPLIB  DD  DSN=DB2V13.SDSNLOAD,DISP=SHR
//DBRMLIB  DD  DSN=DEV.ZAPPBUIL.DBRM,DISP=SHR
//SYSPRINT DD  SYSOUT=*
//SYSTSPRT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//SYSIN  DD *
/*
//SYSTSIN DD *
DSN SYSTEM(DBD1)
BIND PACKAGE (GENASA1)                                    -
     ISO(CS)                                              -
     CURRENTDATA(NO)                                      -
     MEMBER(LGICDB01)                                     -
     DEGREE(1)                                            -
     DYNAMICRULES(BIND)                                   -
     ACTION (REPLACE)                                     -
     EXPLAIN(NO)                                          -
     OWNER(IBMUSER)                                       -
     QUALIFIER(GENASA1)                                   -
     ENABLE(BATCH,CICS)                                   -
     REL(DEALLOCATE)                                      -
     VALIDATE(BIND)

BIND PACKAGE (GENASA1)                                    -
     ISO(CS)                                              -
     CURRENTDATA(NO)                                      -
     MEMBER(LGIPDB01)                                     -
     DEGREE(1)                                            -
     DYNAMICRULES(BIND)                                   -
     ACTION (REPLACE)                                     -
     EXPLAIN(NO)                                          -
     OWNER(IBMUSER)                                       -
     QUALIFIER(GENASA1)                                   -
     ENABLE(BATCH,CICS)                                   -
     REL(DEALLOCATE)                                      -
     VALIDATE(BIND)

BIND PACKAGE (GENASA1)                                    -
     ISO(CS)                                              -
     CURRENTDATA(NO)                                      -
     MEMBER(LGDPDB01)                                     -
     DEGREE(1)                                            -
     DYNAMICRULES(BIND)                                   -
     ACTION (REPLACE)                                     -
     EXPLAIN(NO)                                          -
     OWNER(IBMUSER)                                       -
     QUALIFIER(GENASA1)                                   -
     ENABLE(BATCH,CICS)                                   -
     REL(DEALLOCATE)                                      -
     VALIDATE(BIND)

BIND PACKAGE (GENASA1)                                    -
     ISO(CS)                                              -
     CURRENTDATA(NO)                                      -
     MEMBER(LGAPDB01)                                     -
     DEGREE(1)                                            -
     DYNAMICRULES(BIND)                                   -
     ACTION (REPLACE)                                     -
     EXPLAIN(NO)                                          -
     OWNER(IBMUSER)                                       -
     QUALIFIER(GENASA1)                                   -
     ENABLE(BATCH,CICS)                                   -
     REL(DEALLOCATE)                                      -
     VALIDATE(BIND)

BIND PACKAGE (GENASA1)                                    -
     ISO(CS)                                              -
     CURRENTDATA(NO)                                      -
     MEMBER(LGACDB01)                                     -
     DEGREE(1)                                            -
     DYNAMICRULES(BIND)                                   -
     ACTION (REPLACE)                                     -
     EXPLAIN(NO)                                          -
     OWNER(IBMUSER)                                       -
     QUALIFIER(GENASA1)                                   -
     ENABLE(BATCH,CICS)                                   -
     REL(DEALLOCATE)                                      -
     VALIDATE(BIND)

BIND PACKAGE (GENASA1)                                    -
     ISO(CS)                                              -
     CURRENTDATA(NO)                                      -
     MEMBER(LGACDB02)                                     -
     DEGREE(1)                                            -
     DYNAMICRULES(BIND)                                   -
     ACTION (REPLACE)                                     -
     EXPLAIN(NO)                                          -
     OWNER(IBMUSER)                                       -
     QUALIFIER(GENASA1)                                   -
     ENABLE(BATCH,CICS)                                   -
     REL(DEALLOCATE)                                      -
     VALIDATE(BIND)

BIND PACKAGE (GENASA1)                                    -
     ISO(CS)                                              -
     CURRENTDATA(NO)                                      -
     MEMBER(LGUCDB01)                                     -
     DEGREE(1)                                            -
     DYNAMICRULES(BIND)                                   -
     ACTION (REPLACE)                                     -
     EXPLAIN(NO)                                          -
     OWNER(IBMUSER)                                       -
     QUALIFIER(GENASA1)                                   -
     ENABLE(BATCH,CICS)                                   -
     REL(DEALLOCATE)                                      -
     VALIDATE(BIND)

BIND PACKAGE (GENASA1)                                    -
     ISO(CS)                                              -
     CURRENTDATA(NO)                                      -
     MEMBER(LGUPDB01)                                     -
     DEGREE(1)                                            -
     DYNAMICRULES(BIND)                                   -
     ACTION (REPLACE)                                     -
     EXPLAIN(NO)                                          -
     OWNER(IBMUSER)                                       -
     QUALIFIER(GENASA1)                                   -
     ENABLE(BATCH,CICS)                                   -
     REL(DEALLOCATE)                                      -
     VALIDATE(BIND)

BIND PACKAGE (GENASA1)                                    -
     ISO(CS)                                              -
     CURRENTDATA(NO)                                      -
     MEMBER(EPSCMORT)                                     -
     DEGREE(1)                                            -
     DYNAMICRULES(BIND)                                   -
     ACTION (REPLACE)                                     -
     EXPLAIN(NO)                                          -
     OWNER(IBMUSER)                                       -
     QUALIFIER(GENASA1)                                   -
     ENABLE(BATCH,CICS)                                   -
     REL(DEALLOCATE)                                      -
     VALIDATE(BIND)

BIND PLAN (GENAONE)                                       -
     PKLIST(NULLID.*, *.GENASA1.*)                        -
     CURRENTDATA(NO)                                      -
     ISO(CS)                                              -
     ACTION (REP)                                         -
     OWNER(IBMUSER)                                       -
     QUALIFIER(GENASA1)                                   -
     REL(DEALLOCATE)                                      -
     ACQUIRE(USE)                                         -
     RETAIN                                               -
     NOREOPT(VARS)                                        -
     VALIDATE(BIND)

     BIND PACKAGE(JKE) -
     MEMBER(EPSCMORT) -
                  ACTION(REPLACE) VALIDATE(BIND)

 BIND PLAN(JKEPLAN) -
   PKLIST(JKE.*,NULLID.*, *.GENASA1.*) -
   ACTION(REPLACE) -
   OWNER(IBMUSER) -
   QUALIFIER(GENASA1) -
   ISOLATION(CS) -
   CACHESIZE(0) -
   ENABLE(CICS)
 END



/*