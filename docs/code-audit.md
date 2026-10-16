# Auditoría y ejecución de pruebas — 2026-10-16

## Alcance de PR #1
Se conserva la corrección original basada en `$PSScriptRoot`. `tests/test.ps1` ahora incorpora aserciones, contador de fallos y código de salida distinto de cero, lectura validada de fixtures, validación JSON-RPC 2.0 (id, result, error.code), verificación de métodos y resultados básicos, y pruebas negativas de protocolo y verbos HTTP.

## Seguridad TLS
Se eliminó `curl.exe -k`. La implementación usa `Invoke-WebRequest` de PowerShell 7+ con verificación TLS predeterminada. `-AllowInsecureTls` habilita `SkipCertificateCheck` **únicamente** cuando el operador lo indica expresamente, con aviso visible. No utilizar contra datos productivos.

## Ejecución
Requisito: PowerShell 7.2+.

Portable, sin red:
```powershell
pwsh -NoProfile -File ./tests/test.ps1
```
Integración autorizada (certificado válido):
```powershell
pwsh -NoProfile -File ./tests/test.ps1 -RunIntegration -BaseUrl 'https://HOST/mcp/MCPHTTP01.PGM' -Origin 'https://ORIGEN'
```
Para un laboratorio aislado con certificado autofirmado, añadir `-AllowInsecureTls` explícitamente.

## Limitaciones y pendientes de aceptación
- **No se ejecutaron** pruebas portables PowerShell en esta sesión: `pwsh` no está instalado en el entorno de ejecución. Los cambios no equivalen a pruebas superadas.
- No se probó ningún endpoint IBM i ni se compiló SQLRPGLE/COBOL.
- Se requiere un mock HTTP local reproducible y pruebas automáticas de fallos deliberados para demostrar que la suite detecta respuestas incorrectas.
- La suite actual cubre initialize, notification, tools/list, dos tools/call, método desconocido, JSON mal formado, request inválido y GET/PUT/DELETE. Quedan pendientes origen denegado, tamaños, Content-Type, versión incompatible, límites de argumentos, autorizaciones, CCSID, concurrencia y rendimiento.
- Las pruebas de negocio validan el contrato superficial de content/isError; aún no verifican importes, cálculo financiero ni datos maestros. Deben definirse fixtures de salida estables en el laboratorio antes de hacer esas aserciones.
- La semántica HTTP/JSON-RPC exacta debe contrastarse con el servidor IBM i y el protocolo MCP implementado. Las expectativas de esta suite son controles propuestos, no evidencia de conformidad.
- No fusionar hasta ejecutar verificaciones portables, mock local, revisión de seguridad y pruebas de integración autorizadas IBM i 7.5.

## Estado
PR permanece draft. Validación portable: pendiente de ejecutar en entorno con PowerShell 7. IBM i: pendiente. Certificación: no concedida.
