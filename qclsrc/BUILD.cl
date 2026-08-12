/* ================================================================ */
/* IBM i Native MCP Server - Comandos orientativos de build          */
/* Ajuste SRCFILE, release y parámetros a sus estándares.            */
/* ================================================================ */

CRTLIB LIB(MCPLIB) TEXT('IBM i Native MCP objects')
CRTLIB LIB(MCPSRC) TEXT('IBM i Native MCP sources')

/* SQL: ejecutar sql/001_schema.sql con RUNSQLSTM o ACS Run SQL Scripts. */

CRTSQLRPGI OBJ(MCPLIB/MCPCLT01) +
           SRCFILE(MCPSRC/QRPGLESRC) SRCMBR(MCPCLT01) +
           OBJTYPE(*PGM) COMMIT(*NONE) DBGVIEW(*SOURCE) +
           REPLACE(*YES)

CRTSQLRPGI OBJ(MCPLIB/MCPJOB01) +
           SRCFILE(MCPSRC/QRPGLESRC) SRCMBR(MCPJOB01) +
           OBJTYPE(*PGM) COMMIT(*NONE) DBGVIEW(*SOURCE) +
           REPLACE(*YES)

CRTCBLMOD MODULE(MCPLIB/MCPCRED1) +
          SRCFILE(MCPSRC/QCBLSRC) SRCMBR(MCPCRED1) +
          DBGVIEW(*SOURCE) REPLACE(*YES)
CRTPGM PGM(MCPLIB/MCPCRED1) MODULE(MCPLIB/MCPCRED1) +
       ACTGRP(*CALLER) REPLACE(*YES)

/* MCPHTTP01 usa SQL embebido y APIs CGI. */
CRTSQLRPGI OBJ(MCPLIB/MCPHTTP01) +
           SRCFILE(MCPSRC/QRPGLESRC) SRCMBR(MCPHTTP01) +
           OBJTYPE(*MODULE) COMMIT(*NONE) DBGVIEW(*SOURCE) +
           REPLACE(*YES)

CRTPGM PGM(MCPLIB/MCPHTTP01) +
       MODULE(MCPLIB/MCPHTTP01) +
       BNDSRVPGM(QHTTPSVR/QZHBCGI) +
       ACTGRP(MCPAG) REPLACE(*YES)
