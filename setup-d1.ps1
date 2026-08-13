param(
	[string]$DatabaseName = "mjpanel-db"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

Write-Host "Creating D1 database: $DatabaseName"
$createOutput = npx wrangler d1 create $DatabaseName 2>&1
if ($LASTEXITCODE -ne 0) {
	throw "wrangler d1 create failed."
}

$createText = ($createOutput | Out-String)
$databaseId = [regex]::Match($createText, '(?i)database[_ ]id\s*[:=]\s*["'']?([a-f0-9-]{36})["'']?').Groups[1].Value

if (-not $databaseId) {
	throw "Could not find the D1 database id in wrangler output."
}

$tomlPath = Join-Path $repoRoot "wrangler.toml"
$toml = Get-Content $tomlPath -Raw

$bindingBlock = @"

[[d1_databases]]
binding = "DB"
database_name = "$DatabaseName"
database_id = "$databaseId"
"@

if ($toml -match '\[\[d1_databases\]\]') {
	$toml = [regex]::Replace(
		$toml,
		'(?s)\[\[d1_databases\]\].*?(?=\r?\n(?:\[\[|\w+\s*=)|\z)',
		$bindingBlock.TrimStart()
	)
} else {
	$toml = $toml.TrimEnd() + $bindingBlock + "`r`n"
}

Set-Content -Path $tomlPath -Value $toml -NoNewline

Write-Host ""
Write-Host "Updated wrangler.toml with binding DB."
Write-Host "Database name: $DatabaseName"
Write-Host "Database ID: $databaseId"
Write-Host "Now run: npx wrangler deploy"
