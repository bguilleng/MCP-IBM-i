param(
  [string]$BaseUrl = "https://ibmi.empresa.com/mcp/MCPHTTP01.PGM",
  [string]$Origin = "https://agente.empresa.com",
  [switch]$AllowInsecureTls,
  [switch]$RunIntegration,
  [int]$TimeoutSeconds = 20
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:passed = 0
$script:failed = 0
$script:skipped = 0
$protocol = '2025-11-25'
function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}
function Invoke-Mcp([string]$Body, [string]$Method = 'POST', [string]$ContentType = 'application/json', [string]$RequestOrigin = $Origin, [string]$Version = $protocol) {
  $headers = @{ Accept = 'application/json, text/event-stream'; Origin = $RequestOrigin }
  if ($Version) { $headers['MCP-Protocol-Version'] = $Version }
  $params = @{ Uri = $BaseUrl; Method = $Method; Headers = $headers; TimeoutSec = $TimeoutSeconds; SkipHttpErrorCheck = $true }
  if ($Method -eq 'POST') { $params.Body = [System.Text.Encoding]::UTF8.GetBytes($Body); $params.ContentType = $ContentType }
  if ($AllowInsecureTls) { $params.SkipCertificateCheck = $true }
  $response = Invoke-WebRequest @params
  return @{ Status = [int]$response.StatusCode; Body = [string]$response.Content; ContentType = [string]$response.Headers['Content-Type'] }
}
function Assert-Rpc([object]$Response, [object]$ExpectedId, [Nullable[int]]$ErrorCode = $null) {
  Assert-True ($Response.Status -ge 200 -and $Response.Status -lt 300 -or $null -ne $ErrorCode) 'Unexpected HTTP status'
  $content = $Response.Body
  if ($Response.ContentType -match 'text/event-stream') {
    $dataLines = @($content -split "`r?`n" | Where-Object { $_ -match '^data:\s*\{' })
    Assert-True ($dataLines.Count -gt 0) 'Missing SSE data'
    $content = ($dataLines[-1] -replace '^data:\s*','')
  }
  $rpc = ConvertFrom-Json -InputObject $content -ErrorAction Stop
  Assert-True ($rpc.jsonrpc -eq '2.0') 'Invalid JSON-RPC version'
  if ($null -ne $ExpectedId) { Assert-True ($rpc.id -eq $ExpectedId) 'JSON-RPC ID mismatch' }
  if ($null -ne $ErrorCode) {
    Assert-True ($null -ne $rpc.error) 'Expected JSON-RPC error'
    Assert-True ([int]$rpc.error.code -eq $ErrorCode.Value) 'Wrong JSON-RPC error code'
  } else {
    Assert-True ($null -ne $rpc.result) 'Missing JSON-RPC result'
    Assert-True ($null -eq $rpc.error) 'Unexpected JSON-RPC error'
  }
  return $rpc
}
function Invoke-Case([string]$Name, [scriptblock]$Action) {
  try { & $Action | Out-Null; $script:passed++; Write-Host "PASS $Name" }
  catch { $script:failed++; Write-Error -Message "FAIL $Name : $_" -ErrorAction Continue }
}
function Read-Fixture([string]$Name) {
  $path = Join-Path $PSScriptRoot $Name
  Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Missing fixture $Name"
  $body = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  $null = ConvertFrom-Json -InputObject $body -ErrorAction Stop
  return $body
}
foreach ($file in @('initialize.json','tools-list.json','get-customer.json','simulate-credit.json')) {
  Invoke-Case "fixture/$file" { $null = Read-Fixture $file }
}
Invoke-Case 'fixture/id-and-method' {
  $expected = @(@('initialize.json',1,'initialize'),@('tools-list.json',2,'tools/list'),@('get-customer.json',3,'tools/call'),@('simulate-credit.json',4,'tools/call'))
  foreach ($row in $expected) {
    $obj = Read-Fixture $row[0] | ConvertFrom-Json
    Assert-True ($obj.jsonrpc -eq '2.0' -and $obj.id -eq $row[1] -and $obj.method -eq $row[2]) "Bad fixture $($row[0])"
  }
}
if (-not $RunIntegration) {
  Write-Host 'Integration tests skipped (use -RunIntegration with an authorized endpoint).'
  Write-Host "Summary: passed=$script:passed failed=$script:failed skipped=integration"
  if ($script:failed -gt 0) { exit 1 }; exit 0
}
if ($AllowInsecureTls) { Write-Warning 'TLS certificate validation disabled explicitly for authorized test environment only.' }
Invoke-Case 'initialize' {
  $r = Invoke-Mcp (Read-Fixture 'initialize.json')
  $rpc = Assert-Rpc $r 1
  Assert-True ($null -ne $rpc.result.protocolVersion) 'Missing negotiated protocolVersion'
}
Invoke-Case 'initialized notification' {
  $r = Invoke-Mcp '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  Assert-True ($r.Status -eq 202 -or $r.Status -eq 204 -or $r.Status -eq 200) 'Unexpected notification HTTP status'
  Assert-True ([string]::IsNullOrWhiteSpace($r.Body)) 'Notification should not return JSON-RPC result'
}
Invoke-Case 'tools/list' {
  $rpc = Assert-Rpc (Invoke-Mcp (Read-Fixture 'tools-list.json')) 2
  Assert-True ($null -ne $rpc.result.tools) 'Missing tools array'
  $names = @($rpc.result.tools | ForEach-Object { $_.name })
  Assert-True ($names -contains 'ibmi_get_customer') 'Customer tool absent'
  Assert-True ($names -contains 'ibmi_simulate_credit') 'Credit tool absent'
}
Invoke-Case 'customer' {
  $rpc = Assert-Rpc (Invoke-Mcp (Read-Fixture 'get-customer.json')) 3
  Assert-True ($null -ne $rpc.result.content) 'Missing customer content'
  Assert-True (-not $rpc.result.isError) 'Customer tool returned isError'
}
Invoke-Case 'credit' {
  $rpc = Assert-Rpc (Invoke-Mcp (Read-Fixture 'simulate-credit.json')) 4
  Assert-True ($null -ne $rpc.result.content) 'Missing credit content'
  Assert-True (-not $rpc.result.isError) 'Credit tool returned isError'
}
Invoke-Case 'unknown method' {
  $rpc = Assert-Rpc (Invoke-Mcp '{"jsonrpc":"2.0","id":90,"method":"does/not/exist"}') 90 (-32601)
}
Invoke-Case 'malformed JSON' {
  $rpc = Assert-Rpc (Invoke-Mcp '{"jsonrpc":') $null (-32700)
}
Invoke-Case 'invalid request' {
  $rpc = Assert-Rpc (Invoke-Mcp '{"jsonrpc":"2.0","id":92}') 92 (-32600)
}
foreach ($verb in @('GET','PUT','DELETE')) {
  Invoke-Case "HTTP/$verb" {
    $r = Invoke-Mcp '' $verb
    Assert-True ($r.Status -eq 405) "Expected HTTP 405; got $($r.Status)"
  }
}
Write-Host "Summary: passed=$script:passed failed=$script:failed"
if ($script:failed -gt 0) { exit 1 }
exit 0
