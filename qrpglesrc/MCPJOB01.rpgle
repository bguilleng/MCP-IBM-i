**free
ctl-opt dftactgrp(*no) actgrp(*caller) option(*srcstmt:*nodebugio);

// Ejemplo de observabilidad. En producción use QSYS2.JOB_INFO con filtros
// estrictos y autoridad mínima. No devuelve joblogs completos.

dcl-pr MCPJOB01 extpgm('MCPJOB01');
   requestJson  varchar(32767) ccsid(*utf8) const;
   responseJson varchar(32767) ccsid(*utf8);
   returnCode   char(7);
end-pr;

dcl-pi MCPJOB01;
   requestJson  varchar(32767) ccsid(*utf8) const;
   responseJson varchar(32767) ccsid(*utf8);
   returnCode   char(7);
end-pi;

dcl-s jobName varchar(10) ccsid(*utf8);

exec sql set option commit=*none, closqlcsr=*endmod;

exec sql
   values JSON_VALUE(cast(:requestJson as clob(32767) ccsid 1208),
                     '$.jobName' returning varchar(10) ccsid 1208
                     null on empty error on error)
   into :jobName;

if sqlcod < 0 or %trim(jobName) = '';
   returnCode = 'MCP0400';
   responseJson = '{"error":"jobName inválido"}';
   *inlr = *on;
   return;
endif;

// Ejemplo portable: devuelve el criterio recibido. Sustituir por una consulta
// validada a QSYS2.JOB_INFO según el release/PTF de IBM i de la instalación.
exec sql
   values JSON_OBJECT(
      'jobName' : :jobName,
      'status'  : 'QUERY_ADAPTER_READY',
      'note'    : 'Conectar aquí QSYS2.JOB_INFO con filtros autorizados'
      returning varchar(32767) ccsid 1208)
   into :responseJson;

returnCode = 'MCP0000';
*inlr = *on;
return;
