# Seguridad — IBM i Native MCP Server

## Principios

1. HTTPS obligatorio.
2. Perfil técnico sin *ALLOBJ, *SECADM, *JOBCTL ni *SPLCTL.
3. Router cerrado de tools.
4. Nunca publicar `execute_sql`, `run_cl`, `call_program` ni lectura IFS arbitraria.
5. Validar `Origin` cuando esté presente.
6. Limitar `Content-Length`.
7. Validar tipos, longitud, rango y enumeraciones de arguments.
8. Enmascarar datos sensibles antes de construir la respuesta MCP.
9. Separar tools de consulta, simulación y actualización.
10. Requerir control humano/autenticación reforzada para operaciones críticas.

## Autoridades

El usuario CGI debería recibir solamente:

- *EXECUTE sobre MCPLIB.
- *USE sobre programas autorizados.
- *USE/*OBJOPR sobre tablas de consulta necesarias.
- *ADD/*UPD solo en tablas de auditoría/operación estrictamente requeridas.

## Auditoría

Registrar correlation ID, método MCP, tool, usuario remoto, origen, job IBM i,
resultado y duración. No registrar secretos ni Authorization headers.

## Validación

El `inputSchema` publicado ayuda al cliente, pero no sustituye la validación en
el servidor. El servidor debe volver a validar todos los argumentos.
