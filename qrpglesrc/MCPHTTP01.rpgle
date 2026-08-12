**free
ctl-opt dftactgrp(*no) actgrp('MCPAG') option(*srcstmt:*nodebugio);

// ============================================================================
// MCPHTTP01 - MCP Server CGI de referencia para IBM i
// Apache -> CGI -> JSON-RPC 2.0 -> RPG/COBOL
// MCP target: 2025-11-25, Streamable HTTP síncrono, sin SSE/sesión.
// ============================================================================

/include qsysinc/qrpglesrc,qusec

dcl-pr QtmhGetEnv extproc('QtmhGetEnv');
   receiver         char(32767) options(*varsize);
   receiverLength   int(10) const;
   responseLength   int(10);
   variableName     char(256) const options(*varsize);
   variableNameLen  int(10) const;
   errorCode        likeds(QUSEC);
end-pr;

dcl-pr QtmhRdStin extproc('QtmhRdStin');
   receiver         char(1048576) options(*varsize);
   receiverLength   int(10) const;
   responseLength   int(10);
   errorCode        likeds(QUSEC);
end-pr;

dcl-pr QtmhWrStout extproc('QtmhWrStout');
   data             char(1048576) const options(*varsize);
   dataLength       int(10) const;
   errorCode        likeds(QUSEC);
end-pr;

dcl-pr MCPCLT01 extpgm('MCPCLT01');
   requestJson  varchar(32767) ccsid(*utf8) const;
   responseJson varchar(32767) ccsid(*utf8);
   returnCode   char(7);
end-pr;

dcl-pr MCPJOB01 extpgm('MCPJOB01');
   requestJson  varchar(32767) ccsid(*utf8) const;
   responseJson varchar(32767) ccsid(*utf8);
   returnCode   char(7);
end-pr;

// COBOL: se recomienda wrapper RPG cuando el contrato COBOL use estructuras
// packed/zonadas. Aquí la llamada queda documentada en CallSimulateCredit().

dcl-c SUPPORTED_PROTOCOL '2025-11-25';
dcl-c MAX_BODY 1048576;

dcl-s requestMethod varchar(16);
dcl-s contentLength varchar(32);
dcl-s contentType varchar(256);
dcl-s acceptHeader varchar(1024);
dcl-s originHeader varchar(1024) ccsid(*utf8);
dcl-s protocolHeader varchar(64) ccsid(*utf8);
dcl-s remoteUser varchar(128) ccsid(*utf8);

dcl-s rawBuffer char(MAX_BODY);
dcl-s bytesRead int(10);
dcl-s bodyLen int(10);
dcl-s requestJson varchar(MAX_BODY) ccsid(*utf8);
dcl-s responseJson varchar(MAX_BODY) ccsid(*utf8);

dcl-s jsonrpc varchar(10) ccsid(*utf8);
dcl-s method varchar(128) ccsid(*utf8);
dcl-s idJson varchar(256) ccsid(*utf8);
dcl-s paramsJson varchar(32767) ccsid(*utf8);
dcl-s toolName varchar(128) ccsid(*utf8);
dcl-s argumentsJson varchar(32767) ccsid(*utf8);
dcl-s businessJson varchar(32767) ccsid(*utf8);
dcl-s returnCode char(7);
dcl-s originCount int(10);

exec sql set option commit=*none, closqlcsr=*endmod;

requestMethod  = GetEnv('REQUEST_METHOD');
contentLength  = GetEnv('CONTENT_LENGTH');
contentType    = GetEnv('CONTENT_TYPE');
acceptHeader   = GetEnv('HTTP_ACCEPT');
originHeader   = GetEnv('HTTP_ORIGIN');
protocolHeader = GetEnv('HTTP_MCP_PROTOCOL_VERSION');
remoteUser     = GetEnv('REMOTE_USER');

if requestMethod = 'GET';
   SendHttp(405:'{"jsonrpc":"2.0","id":null,"error":{"code":-32000,"message":"SSE no habilitado"}}');
   *inlr = *on;
   return;
endif;

if requestMethod <> 'POST';
   SendHttp(405:'{"jsonrpc":"2.0","id":null,"error":{"code":-32600,"message":"Método HTTP no permitido"}}');
   *inlr = *on;
   return;
endif;

// Validación de Origin si viene presente.
if %trim(originHeader) <> '';
   exec sql
      select count(*) into :originCount
        from MCPDATA.MCP_ALLOWED_ORIGIN
       where ORIGIN = :originHeader
         and ENABLED = 'Y';
   if originCount = 0;
      SendHttp(403:'{"jsonrpc":"2.0","id":null,"error":{"code":-32003,"message":"Origin no autorizado"}}');
      *inlr = *on;
      return;
   endif;
endif;

monitor;
   bodyLen = %int(%trim(contentLength));
on-error;
   bodyLen = 0;
endmon;

if bodyLen <= 0 or bodyLen > MAX_BODY;
   SendHttp(413:'{"jsonrpc":"2.0","id":null,"error":{"code":-32600,"message":"Tamaño de solicitud inválido"}}');
   *inlr = *on;
   return;
endif;

clear QUSEC;
QUSEC.QUSBPRV = %size(QUSEC);
QtmhRdStin(rawBuffer:bodyLen:bytesRead:QUSEC);
if QUSEC.QUSBAVL > 0 or bytesRead <= 0;
   SendHttp(400:'{"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"No fue posible leer stdin"}}');
   *inlr = *on;
   return;
endif;

// En una instalación real, valide la conversión exacta con QIBM_CGI_CCSID y
// el CCSID del job. Se busca conservar JSON en UTF-8/1208 de extremo a extremo.
requestJson = %subst(rawBuffer:1:bytesRead);

// Valida JSON y extrae envelope. JSON_QUERY preserva id como JSON (número/string/null).
exec sql
   select JSON_VALUE(cast(:requestJson as clob(1M) ccsid 1208),
                     '$.jsonrpc' returning varchar(10) ccsid 1208
                     null on empty error on error),
          JSON_VALUE(cast(:requestJson as clob(1M) ccsid 1208),
                     '$.method' returning varchar(128) ccsid 1208
                     null on empty error on error),
          coalesce(JSON_QUERY(cast(:requestJson as clob(1M) ccsid 1208),
                              '$.id' returning varchar(256) ccsid 1208
                              null on empty error on error),'null'),
          coalesce(JSON_QUERY(cast(:requestJson as clob(1M) ccsid 1208),
                              '$.params' returning varchar(32767) ccsid 1208
                              null on empty error on error),'{}')
     into :jsonrpc,:method,:idJson,:paramsJson
     from sysibm.sysdummy1;

if sqlcod < 0;
   SendHttp(400:'{"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"JSON inválido"}}');
   *inlr = *on;
   return;
endif;

if jsonrpc <> '2.0' or %trim(method) = '';
   SendHttp(400:BuildError(idJson:-32600:'Solicitud JSON-RPC inválida'));
   *inlr = *on;
   return;
endif;

// Inicialización: protocolVersion está en params; header todavía no es obligatorio.
select;
when method = 'initialize';
   responseJson = HandleInitialize(idJson:paramsJson);
   SendHttp(200:responseJson);

when method = 'notifications/initialized';
   SendEmpty(202);

when method = 'ping';
   if not ValidProtocolHeader(protocolHeader);
      SendHttp(400:BuildError(idJson:-32600:'MCP-Protocol-Version no soportado'));
   else;
      responseJson = BuildResult(idJson:'{}');
      SendHttp(200:responseJson);
   endif;

when method = 'tools/list';
   if not ValidProtocolHeader(protocolHeader);
      SendHttp(400:BuildError(idJson:-32600:'MCP-Protocol-Version no soportado'));
   else;
      responseJson = HandleToolsList(idJson);
      SendHttp(200:responseJson);
   endif;

when method = 'tools/call';
   if not ValidProtocolHeader(protocolHeader);
      SendHttp(400:BuildError(idJson:-32600:'MCP-Protocol-Version no soportado'));
   else;
      responseJson = HandleToolsCall(idJson:paramsJson);
      SendHttp(200:responseJson);
   endif;

other;
   SendHttp(200:BuildError(idJson:-32601:'Método MCP no encontrado'));
endsl;

*inlr = *on;
return;

// ----------------------------------------------------------------------------
dcl-proc GetEnv;
   dcl-pi *n varchar(32767);
      name varchar(256) const;
   end-pi;
   dcl-s receiver char(32767);
   dcl-s responseLen int(10);
   dcl-s value varchar(32767);
   clear QUSEC;
   QUSEC.QUSBPRV = %size(QUSEC);
   QtmhGetEnv(receiver:%size(receiver):responseLen:name:%len(%trimr(name)):QUSEC);
   if QUSEC.QUSBAVL = 0 and responseLen > 0;
      value = %subst(receiver:1:%min(responseLen:%size(receiver)));
   endif;
   return value;
end-proc;

// ----------------------------------------------------------------------------
dcl-proc ValidProtocolHeader;
   dcl-pi *n ind;
      h varchar(64) const;
   end-pi;
   return %trim(h) = SUPPORTED_PROTOCOL;
end-proc;

// ----------------------------------------------------------------------------
dcl-proc HandleInitialize;
   dcl-pi *n varchar(MAX_BODY) ccsid(*utf8);
      id varchar(256) ccsid(*utf8) const;
      params varchar(32767) ccsid(*utf8) const;
   end-pi;
   dcl-s clientVersion varchar(64) ccsid(*utf8);
   dcl-s result varchar(32767) ccsid(*utf8);
   dcl-s response varchar(MAX_BODY) ccsid(*utf8);

   exec sql
      values JSON_VALUE(cast(:params as clob(32767) ccsid 1208),
                        '$.protocolVersion' returning varchar(64) ccsid 1208
                        null on empty error on error)
      into :clientVersion;

   if sqlcod < 0;
      return BuildError(id:-32602:'protocolVersion obligatorio');
   endif;

   // MCP permite negociar otra versión soportada. Este ejemplo solo soporta una.
   exec sql
      values JSON_OBJECT(
        'protocolVersion' : :SUPPORTED_PROTOCOL,
        'capabilities' : JSON_OBJECT(
            'tools' : JSON_OBJECT('listChanged' : false)
        ),
        'serverInfo' : JSON_OBJECT(
            'name' : 'ibmi-native-mcp',
            'title' : 'IBM i Native MCP Server',
            'version' : '1.0.0',
            'description' : 'Apache CGI + SQLRPGLE + COBOL'
        ),
        'instructions' : 'Servidor de herramientas IBM i de acceso controlado.'
        returning varchar(32767) ccsid 1208)
      into :result;

   response = BuildResult(id:result);
   return response;
end-proc;

// ----------------------------------------------------------------------------
dcl-proc HandleToolsList;
   dcl-pi *n varchar(MAX_BODY) ccsid(*utf8);
      id varchar(256) ccsid(*utf8) const;
   end-pi;
   dcl-s result varchar(MAX_BODY) ccsid(*utf8);
   dcl-s toolsArray varchar(MAX_BODY) ccsid(*utf8);

   exec sql
      select coalesce(
        JSON_ARRAYAGG(
          JSON_OBJECT(
            'name' : TOOL_NAME,
            'title' : TOOL_TITLE,
            'description' : TOOL_DESCRIPTION,
            'inputSchema' : INPUT_SCHEMA format json
          ) order by TOOL_NAME
          returning varchar(1040000) ccsid 1208
        ),
        '[]')
      into :toolsArray
      from MCPDATA.MCP_TOOL
      where ENABLED = 'Y';

   if sqlcod < 0;
      return BuildError(id:-32603:'Error generando tools/list');
   endif;

   exec sql
      values JSON_OBJECT('tools' : :toolsArray format json
                         returning varchar(1040000) ccsid 1208)
      into :result;

   return BuildResult(id:result);
end-proc;

// ----------------------------------------------------------------------------
dcl-proc HandleToolsCall;
   dcl-pi *n varchar(MAX_BODY) ccsid(*utf8);
      id varchar(256) ccsid(*utf8) const;
      params varchar(32767) ccsid(*utf8) const;
   end-pi;

   dcl-s handlerId varchar(32);
   dcl-s enabled char(1);
   dcl-s result varchar(MAX_BODY) ccsid(*utf8);
   dcl-s toolResult varchar(32767) ccsid(*utf8);

   exec sql
      select JSON_VALUE(cast(:params as clob(32767) ccsid 1208),
                        '$.name' returning varchar(128) ccsid 1208
                        null on empty error on error),
             coalesce(JSON_QUERY(cast(:params as clob(32767) ccsid 1208),
                                 '$.arguments' returning varchar(32767) ccsid 1208
                                 null on empty error on error),'{}')
        into :toolName,:argumentsJson
        from sysibm.sysdummy1;

   if sqlcod < 0 or %trim(toolName) = '';
      return BuildError(id:-32602:'tools/call requiere name y arguments válidos');
   endif;

   exec sql
      select HANDLER_ID, ENABLED
        into :handlerId,:enabled
        from MCPDATA.MCP_TOOL
       where TOOL_NAME = :toolName;

   if sqlcod = 100 or enabled <> 'Y';
      return BuildToolError(id:'Tool no registrado o deshabilitado':'MCP0404');
   elseif sqlcod < 0;
      return BuildError(id:-32603:'Error consultando catálogo MCP');
   endif;

   // Router cerrado: HANDLER_ID proviene de catálogo administrado, pero nunca se
   // convierte en CALL dinámico. La lista es deliberadamente explícita.
   select;
   when handlerId = 'GET_CUSTOMER';
      MCPCLT01(argumentsJson:businessJson:returnCode);
   when handlerId = 'GET_JOB_STATUS';
      MCPJOB01(argumentsJson:businessJson:returnCode);
   when handlerId = 'SIMULATE_CREDIT';
      CallSimulateCredit(argumentsJson:businessJson:returnCode);
   other;
      return BuildToolError(id:'Handler no autorizado':'MCP0403');
   endsl;

   if returnCode <> 'MCP0000';
      return BuildToolError(id:businessJson:returnCode);
   endif;

   // Tool result con content + structuredContent.
   exec sql
      values JSON_OBJECT(
         'content' : JSON_ARRAY(
             JSON_OBJECT('type' : 'text',
                         'text' : cast(:businessJson as varchar(32767) ccsid 1208))
         ),
         'structuredContent' : :businessJson format json,
         'isError' : false
         returning varchar(1040000) ccsid 1208)
      into :result;

   return BuildResult(id:result);
end-proc;

// ----------------------------------------------------------------------------
dcl-proc CallSimulateCredit;
   dcl-pi *n;
      args varchar(32767) ccsid(*utf8) const;
      outJson varchar(32767) ccsid(*utf8);
      rc char(7);
   end-pi;

   dcl-s amount packed(13:2);
   dcl-s termMonths packed(3:0);
   dcl-s annualRate packed(9:6);
   dcl-s total packed(15:2);
   dcl-s monthly packed(13:2);

   // Para que el ejemplo compile sin copybook COBOL/RPG compartido, se deja
   // el cálculo de demostración en este wrapper. En producción sustituir por
   // CALLP a MCPCRED1 usando un copybook/layout común.
   exec sql
      select JSON_VALUE(cast(:args as clob(32767) ccsid 1208),'$.amount'
                        returning decimal(13,2) error on error),
             JSON_VALUE(cast(:args as clob(32767) ccsid 1208),'$.termMonths'
                        returning decimal(3,0) error on error),
             JSON_VALUE(cast(:args as clob(32767) ccsid 1208),'$.annualRate'
                        returning decimal(9,6) error on error)
        into :amount,:termMonths,:annualRate
        from sysibm.sysdummy1;

   if sqlcod < 0 or amount <= 0 or termMonths <= 0;
      rc = 'MCP0400';
      outJson = '{"error":"Parámetros de simulación inválidos"}';
      return;
   endif;

   total = amount + (amount * (annualRate / 100) * (termMonths / 12));
   monthly = total / termMonths;

   exec sql
      values JSON_OBJECT(
        'amount' : :amount,
        'termMonths' : :termMonths,
        'annualRate' : :annualRate,
        'monthlyPayment' : :monthly,
        'totalPayment' : :total,
        'calculationType' : 'DEMO_SIMPLE_INTEREST'
        returning varchar(32767) ccsid 1208)
      into :outJson;
   rc = 'MCP0000';
end-proc;

// ----------------------------------------------------------------------------
dcl-proc BuildResult;
   dcl-pi *n varchar(MAX_BODY) ccsid(*utf8);
      id varchar(256) ccsid(*utf8) const;
      result varchar(MAX_BODY) ccsid(*utf8) const;
   end-pi;
   dcl-s out varchar(MAX_BODY) ccsid(*utf8);
   exec sql
      values JSON_OBJECT(
        'jsonrpc' : '2.0',
        'id' : :id format json,
        'result' : :result format json
        returning varchar(1040000) ccsid 1208)
      into :out;
   return out;
end-proc;

// ----------------------------------------------------------------------------
dcl-proc BuildError;
   dcl-pi *n varchar(MAX_BODY) ccsid(*utf8);
      id varchar(256) ccsid(*utf8) const;
      code int(10) value;
      message varchar(512) ccsid(*utf8) const;
   end-pi;
   dcl-s out varchar(MAX_BODY) ccsid(*utf8);
   exec sql
      values JSON_OBJECT(
        'jsonrpc' : '2.0',
        'id' : :id format json,
        'error' : JSON_OBJECT('code' : :code,'message' : :message)
        returning varchar(1040000) ccsid 1208)
      into :out;
   return out;
end-proc;

// ----------------------------------------------------------------------------
dcl-proc BuildToolError;
   dcl-pi *n varchar(MAX_BODY) ccsid(*utf8);
      id varchar(256) ccsid(*utf8) const;
      message varchar(32767) ccsid(*utf8) const;
      rc varchar(20) const;
   end-pi;
   dcl-s toolResult varchar(MAX_BODY) ccsid(*utf8);
   exec sql
      values JSON_OBJECT(
        'content' : JSON_ARRAY(JSON_OBJECT('type':'text','text': :message)),
        'structuredContent' : JSON_OBJECT('returnCode': :rc,'message': :message),
        'isError' : true
        returning varchar(1040000) ccsid 1208)
      into :toolResult;
   return BuildResult(id:toolResult);
end-proc;

// ----------------------------------------------------------------------------
dcl-proc SendHttp;
   dcl-pi *n;
      status int(10) value;
      body varchar(MAX_BODY) ccsid(*utf8) const;
   end-pi;
   dcl-s header varchar(4096) ccsid(*utf8);
   dcl-s output varchar(MAX_BODY) ccsid(*utf8);

   select;
   when status = 200; header = 'Status: 200 OK';
   when status = 400; header = 'Status: 400 Bad Request';
   when status = 403; header = 'Status: 403 Forbidden';
   when status = 405; header = 'Status: 405 Method Not Allowed';
   when status = 413; header = 'Status: 413 Payload Too Large';
   other; header = 'Status: 500 Internal Server Error';
   endsl;

   // x'0D25' es CRLF en EBCDIC habitual; validar en el entorno y CCSID del job.
   header += x'0D25' +
             'Content-Type: application/json; charset=utf-8' + x'0D25' +
             'Cache-Control: no-store' + x'0D25' +
             'X-Content-Type-Options: nosniff' + x'0D25' + x'0D25';
   output = header + body;

   clear QUSEC;
   QUSEC.QUSBPRV = %size(QUSEC);
   QtmhWrStout(output:%len(%trimr(output)):QUSEC);
end-proc;

// ----------------------------------------------------------------------------
dcl-proc SendEmpty;
   dcl-pi *n;
      status int(10) value;
   end-pi;
   dcl-s output varchar(512);
   if status = 202;
      output = 'Status: 202 Accepted' + x'0D25' +
               'Content-Length: 0' + x'0D25' + x'0D25';
   else;
      output = 'Status: 204 No Content' + x'0D25' +
               'Content-Length: 0' + x'0D25' + x'0D25';
   endif;
   clear QUSEC;
   QUSEC.QUSBPRV = %size(QUSEC);
   QtmhWrStout(output:%len(%trimr(output)):QUSEC);
end-proc;
