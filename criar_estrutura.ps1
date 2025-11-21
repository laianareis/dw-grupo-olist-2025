# Caminho da raiz do repositório
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# Pastas
$dirs = @(
    "data\olist",
    "scripts",
    "visualizacoes",
    "docs"
)

# Arquivos
$files = @(
    "scripts\00_staging.sql",
    "scripts\01_oltp.sql",
    "scripts\02_dw_model.sql",
    "scripts\03_etl_load.sql",
    "scripts\04_analytics.sql",
    "scripts\05_performance.sql",
    "visualizacoes\gerar_graficos.ipynb",
    "docs\relatorio_tecnico.pdf",        # pode ser só um arquivo vazio por enquanto
    "docs\diagrama_modelo_estrela.png",  # idem
    "docs\dicionario_dados.md",
    "README.md"
)

# Criar pastas
foreach ($d in $dirs) {
    $fullPath = Join-Path $root $d
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
}

# Criar arquivos vazios se não existirem
foreach ($f in $files) {
    $fullPath = Join-Path $root $f
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType File -Path $fullPath -Force | Out-Null
    }
}

Write-Host "Estrutura criada com sucesso em $root"
