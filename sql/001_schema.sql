-- ================================================================
-- IBM i Native MCP Server - Esquema de referencia
-- ================================================================

CREATE SCHEMA MCPDATA;

CREATE TABLE MCPDATA.MCP_TOOL (
    TOOL_NAME          VARCHAR(128) CCSID 1208 NOT NULL,
    TOOL_TITLE         VARCHAR(256) CCSID 1208 NOT NULL,
    TOOL_DESCRIPTION   VARCHAR(1024) CCSID 1208 NOT NULL,
    INPUT_SCHEMA       CLOB(64K) CCSID 1208 NOT NULL,
    HANDLER_ID         VARCHAR(32) NOT NULL,
    OPERATION_LEVEL    SMALLINT NOT NULL DEFAULT 1,
    REQUIRES_CONFIRM   CHAR(1) NOT NULL DEFAULT 'N',
    ENABLED            CHAR(1) NOT NULL DEFAULT 'Y',
    PRIMARY KEY (TOOL_NAME),
    CHECK (REQUIRES_CONFIRM IN ('Y','N')),
    CHECK (ENABLED IN ('Y','N'))
);

CREATE TABLE MCPDATA.MCP_ALLOWED_ORIGIN (
    ORIGIN VARCHAR(512) CCSID 1208 NOT NULL PRIMARY KEY,
    ENABLED CHAR(1) NOT NULL DEFAULT 'Y',
    CHECK (ENABLED IN ('Y','N'))
);

CREATE TABLE MCPDATA.MCP_AUDIT (
    AUDIT_ID        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    EVENT_TS        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CORRELATION_ID  VARCHAR(64) CCSID 1208,
    REQUEST_ID      VARCHAR(128) CCSID 1208,
    REMOTE_USER     VARCHAR(128) CCSID 1208,
    ORIGIN          VARCHAR(512) CCSID 1208,
    MCP_METHOD      VARCHAR(128) CCSID 1208,
    TOOL_NAME       VARCHAR(128) CCSID 1208,
    RESULT_CODE     VARCHAR(20) CCSID 1208,
    ELAPSED_MS      DECIMAL(15,3),
    IBM_I_JOB       VARCHAR(64) CCSID 1208,
    REQUEST_JSON    CLOB(2M) CCSID 1208,
    RESPONSE_JSON   CLOB(2M) CCSID 1208
);

CREATE TABLE MCPDATA.CUSTOMER (
    CUSTOMER_ID   VARCHAR(20) NOT NULL PRIMARY KEY,
    CUSTOMER_NAME VARCHAR(100) CCSID 1208 NOT NULL,
    STATUS        VARCHAR(10) CCSID 1208 NOT NULL,
    SEGMENT       VARCHAR(20) CCSID 1208 NOT NULL,
    RISK_LEVEL    VARCHAR(10) CCSID 1208 NOT NULL
);

INSERT INTO MCPDATA.CUSTOMER VALUES
('533714721','EMPRESA DEMO','ACTIVE','CORPORATE','MEDIUM'),
('900027382','CLIENTE PRUEBA','ACTIVE','SME','LOW');

INSERT INTO MCPDATA.MCP_ALLOWED_ORIGIN
VALUES ('https://agente.empresa.com','Y');

INSERT INTO MCPDATA.MCP_TOOL VALUES
(
 'ibmi_get_customer',
 'Consultar cliente IBM i',
 'Consulta el resumen consolidado de un cliente en Db2 for i.',
 '{"type":"object","properties":{"customerId":{"type":"string","minLength":1,"maxLength":20}},"required":["customerId"],"additionalProperties":false}',
 'GET_CUSTOMER',1,'N','Y'
),
(
 'ibmi_get_job_status',
 'Consultar estado de job IBM i',
 'Consulta información básica de un job autorizado.',
 '{"type":"object","properties":{"jobName":{"type":"string","maxLength":10}},"required":["jobName"],"additionalProperties":false}',
 'GET_JOB_STATUS',1,'N','Y'
),
(
 'ibmi_simulate_credit',
 'Simular crédito',
 'Ejecuta un cálculo demostrativo en COBOL. No crea operaciones financieras.',
 '{"type":"object","properties":{"amount":{"type":"number","minimum":1},"termMonths":{"type":"integer","minimum":1,"maximum":360},"annualRate":{"type":"number","minimum":0,"maximum":100}},"required":["amount","termMonths","annualRate"],"additionalProperties":false}',
 'SIMULATE_CREDIT',2,'N','Y'
);
