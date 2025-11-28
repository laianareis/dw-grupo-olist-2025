# run_all.ps1 - Executa o pipeline 00→05 no Windows (PowerShell)
# Uso: .\run_all.ps1

$ErrorActionPreference = 'Stop'

# Ir para a pasta do script
Set-Location -Path $PSScriptRoot

# Selecionar executável do DuckDB: PATH ou local
$duckdbCmd = (Get-Command duckdb -ErrorAction SilentlyContinue)
if (-not $duckdbCmd) {
  $localDuck = Join-Path $PSScriptRoot 'duckdb.exe'
  if (Test-Path $localDuck) {
    $duckdbCmd = $localDuck
  } else {
    Write-Error "duckdb não encontrado no PATH nem na pasta do projeto. Coloque duckdb.exe aqui ou adicione ao PATH."
  }
}

# Arquivo de banco (persistente)
$dbFile = Join-Path $PSScriptRoot 'olist_dw.duckdb'

function Run-Step($scriptRelPath) {
  Write-Host "Executando: $scriptRelPath" -ForegroundColor Cyan
  & $duckdbCmd $dbFile -c ".read $scriptRelPath"
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao executar $scriptRelPath (exit $LASTEXITCODE)"
  }
}

Run-Step 'scripts/00_staging.sql'
Run-Step 'scripts/01_oltp.sql'
Run-Step 'scripts/02_dw_model.sql'
Run-Step 'scripts/03_etl_load.sql'
Run-Step 'scripts/04_validate.sql'
Run-Step 'scripts/05_analytics.sql'
Run-Step 'scripts/06_performance.sql'

Write-Host "Pipeline concluído com sucesso." -ForegroundColor Green
