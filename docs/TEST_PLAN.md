# Plan de pruebas

## Protocolo

- initialize válido.
- initialize con versión distinta.
- initialized notification sin id.
- ping con y sin MCP-Protocol-Version.
- tools/list.
- tools/call tool existente.
- tools/call tool inexistente.
- método desconocido (-32601).
- JSON mal formado (-32700).
- request sin jsonrpc/method (-32600).

## HTTP

- GET devuelve 405.
- PUT/DELETE devuelve 405.
- Origin permitido.
- Origin denegado.
- Content-Length 0.
- Payload > 1 MB.
- Content-Type incorrecto (añadir validación productiva).

## Negocio

- Cliente existente.
- Cliente inexistente.
- customerId vacío/largo.
- Simulación con monto/plazo/tasa válidos.
- Valores 0/negativos/fuera de rango.

## IBM i

- CCSID con acentos: José, Málaga, Crédito.
- CCSID con caracteres no EBCDIC tradicionales.
- Reutilización de jobs CGI.
- Commitment control.
- Autoridades insuficientes.
- Joblog limpio.
- Concurrencia de múltiples POST.

## Rendimiento

Medir p50/p95/p99 de:
- initialize
- tools/list
- ibmi_get_customer
- simulación

Registrar elapsed ms y CPU del job CGI.
