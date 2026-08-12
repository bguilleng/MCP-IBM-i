param(
  [string]$BaseUrl = "https://ibmi.empresa.com/mcp/MCPHTTP01.PGM",
  [string]$Origin = "https://agente.empresa.com"
)

Write-Host "1) initialize"
curl.exe -k -sS -X POST $BaseUrl `
  -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" `
  -H "Origin: $Origin" `
  --data-binary "@initialize.json"

Write-Host "`n2) initialized notification"
curl.exe -k -sS -i -X POST $BaseUrl `
  -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" `
  -H "Origin: $Origin" `
  -H "MCP-Protocol-Version: 2025-11-25" `
  --data-binary '{"jsonrpc":"2.0","method":"notifications/initialized"}'

Write-Host "`n3) tools/list"
curl.exe -k -sS -X POST $BaseUrl `
  -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" `
  -H "Origin: $Origin" `
  -H "MCP-Protocol-Version: 2025-11-25" `
  --data-binary "@tools-list.json"

Write-Host "`n4) tools/call customer"
curl.exe -k -sS -X POST $BaseUrl `
  -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" `
  -H "Origin: $Origin" `
  -H "MCP-Protocol-Version: 2025-11-25" `
  --data-binary "@get-customer.json"

Write-Host "`n5) tools/call credit simulation"
curl.exe -k -sS -X POST $BaseUrl `
  -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" `
  -H "Origin: $Origin" `
  -H "MCP-Protocol-Version: 2025-11-25" `
  --data-binary "@simulate-credit.json"
