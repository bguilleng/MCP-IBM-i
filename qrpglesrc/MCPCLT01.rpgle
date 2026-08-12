**free
ctl-opt dftactgrp(*no) actgrp(*caller) option(*srcstmt:*nodebugio);

// Tool de negocio: consulta de cliente.
// Entrada/salida JSON UTF-8. El CGI nunca permite SQL arbitrario.

dcl-pr MCPCLT01 extpgm('MCPCLT01');
   requestJson  varchar(32767) ccsid(*utf8) const;
   responseJson varchar(32767) ccsid(*utf8);
   returnCode   char(7);
end-pr;

dcl-pi MCPCLT01;
   requestJson  varchar(32767) ccsid(*utf8) const;
   responseJson varchar(32767) ccsid(*utf8);
   returnCode   char(7);
end-pi;

dcl-s customerId varchar(20) ccsid(*utf8);

clear responseJson;
returnCode = 'MCP0000';

exec sql
   set option commit=*none, closqlcsr=*endmod;

exec sql
   values JSON_VALUE(
      cast(:requestJson as clob(32767) ccsid 1208),
      '$.customerId' returning varchar(20) ccsid 1208
      null on empty error on error)
   into :customerId;

if sqlcod < 0 or %trim(customerId) = '';
   returnCode = 'MCP0400';
   responseJson = '{"error":"customerId inválido"}';
   *inlr = *on;
   return;
endif;

exec sql
   select JSON_OBJECT(
      'customerId' : CUSTOMER_ID,
      'name'       : CUSTOMER_NAME,
      'status'     : STATUS,
      'segment'    : SEGMENT,
      'riskLevel'  : RISK_LEVEL
      returning varchar(32767) ccsid 1208)
   into :responseJson
   from MCPDATA.CUSTOMER
   where CUSTOMER_ID = :customerId;

if sqlcod = 100;
   returnCode = 'MCP0404';
   responseJson = '{"error":"Cliente no encontrado"}';
elseif sqlcod < 0;
   returnCode = 'MCP0500';
   responseJson = '{"error":"Error Db2 consultando cliente"}';
endif;

*inlr = *on;
return;
