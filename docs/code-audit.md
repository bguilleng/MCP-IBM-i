# Auditoría de código — 2026-10-12

Estado: parcial; no equivale a certificación del servidor.
SHA revisado: 387fad8b0b751f2f0e9e9f1e5b213962a4d5cbed.

## Corrección validada
tests/test.ps1 resolvía los cuatro archivos JSON con relación al directorio de trabajo. Ejecutarlo desde la raíz del repositorio fallaba al leerlos. Ahora se resuelven mediante PSScriptRoot.
Se verificó la sintaxis con el parser de PowerShell y se ejecutó el script desde fuera de tests con curl.exe simulado: las cuatro rutas se resolvieron y sus JSON se analizaron correctamente. No se enviaron solicitudes al servidor. git diff --check pasó.

## Pendientes
- No se ejecutaron compilación SQLRPGLE/COBOL, análisis especializado IBM i ni pruebas de integración: se necesita un entorno IBM i de pruebas configurado.
- El script utiliza curl -k y por tanto no verifica certificados TLS; no usar esta prueba como evidencia de seguridad TLS.
- El script muestra respuestas sin comprobar códigos HTTP ni contenido esperado; no representa una suite de aserciones.
- La configuración Apache de ejemplo permite acceso al endpoint; validar autenticación y autorización antes de exponer datos reales.
- Completar los escenarios de docs/TEST_PLAN.md, incluidos validación de argumentos, errores SQL y CCSID.

No se ha marcado el SHA como completamente auditado. No integrar automáticamente hasta resolver la validación pendiente.
