
# ==============================================================================
#  LLAMA-RPC-CLUSTER  |  install-worker.ps1
#  Worker PC (il vecchio PC con GPU secondaria - es. RTX 3050 4GB)
#
#  Esecuzione rapida (incolla nel terminale PowerShell come Amministratore):
#  irm https://raw.githubusercontent.com/TUO_USERNAME/llama-rpc-cluster/main/scripts/install-worker.ps1 | iex
# ==============================================================================

$ErrorActionPreference = "Stop"

function Write-Banner {
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host "   LLAMA RPC CLUSTER  |  Installazione PC WORKER" -ForegroundColor Magenta
    Write-Host "   Questa GPU aiutera' il PC Master nei calcoli!" -ForegroundColor Magenta
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host ""
}

function Write-Step([int]$n, [int]$tot, [string]$msg) {
    Write-Host "[$n/$tot] " -NoNewline -ForegroundColor Yellow
    Write-Host $msg -ForegroundColor White
}

function Write-Ok([string]$msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green  }
function Write-Warn([string]$msg) { Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function Write-Err([string]$msg)  { Write-Host "  [X]  $msg" -ForegroundColor Red; Pause; exit 1 }

# ---- Verifica privilegi di amministratore ------------------------------------
Write-Banner
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Warn "Rilancio con privilegi Amministratore..."
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    exit
}

Write-Banner
$TOTAL_STEPS = 5

# ---- STEP 1: Rilevamento GPU -------------------------------------------------
Write-Step 1 $TOTAL_STEPS "Rilevamento scheda grafica Nvidia..."

$gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" } | Select-Object -First 1
if (-not $gpu) {
    Write-Warn "Nessuna GPU Nvidia trovata. Il Worker funzionera' solo tramite CPU (piu' lento)."
    Write-Warn "Per GPU AMD (ROCm) il supporto e' sperimentale. Vedi README."
} else {
    Write-Ok "GPU rilevata: $($gpu.Name)"
}

# ---- STEP 2: IP Statico Ethernet ---------------------------------------------
Write-Step 2 $TOTAL_STEPS "Configurazione IP statico Ethernet (192.168.50.2)..."

$eth = Get-NetAdapter | Where-Object {
    $_.PhysicalMediaType -eq '802.3' -and $_.Virtual -eq $false
} | Sort-Object LinkSpeed -Descending | Select-Object -First 1

if (-not $eth) {
    Write-Warn "Cavo Ethernet non rilevato. Collega il cavo CAT6 e riesegui."
} else {
    Remove-NetIPAddress -InterfaceIndex $eth.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute     -InterfaceIndex $eth.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceIndex $eth.InterfaceIndex -AddressFamily IPv4 -IPAddress "192.168.50.2" -PrefixLength 24 | Out-Null
    Write-Ok "Adattatore '$($eth.Name)' impostato a 192.168.50.2/24"
}

# ---- STEP 3: Firewall --------------------------------------------------------
Write-Step 3 $TOTAL_STEPS "Apertura porta 50052 su Windows Firewall (ascolto RPC)..."

Remove-NetFirewallRule -DisplayName "LlamaCppRPC" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "LlamaCppRPC" -Direction Inbound -Protocol TCP -LocalPort 50052 -Action Allow | Out-Null
Write-Ok "Regola firewall TCP 50052 creata."

# ---- STEP 4: Download llama.cpp CUDA ----------------------------------------
Write-Step 4 $TOTAL_STEPS "Download ultima versione llama.cpp con supporto CUDA..."

$installDir = "C:\llama-cluster"
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

if (Test-Path "$installDir\ggml-rpc-server.exe") {
    Write-Ok "llama.cpp gia' installato in $installDir. Download saltato."
} else {
    Write-Host "  Ricerca ultima versione su GitHub..." -ForegroundColor Gray
    $releases    = Invoke-RestMethod -Uri "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=1" -UseBasicParsing
    $tag         = $releases[0].tag_name
    $binAsset    = $releases[0].assets | Where-Object { $_.name -like "llama-*-bin-win-cuda-12.4-x64.zip" } | Select-Object -First 1
    $cudartAsset = $releases[0].assets | Where-Object { $_.name -like "cudart-llama-bin-win-cuda-12.4-x64.zip" } | Select-Object -First 1

    if (-not $binAsset) { Write-Err "Impossibile trovare i binari CUDA 12.4. Controlla la connessione internet." }

    Write-Host "  Download $tag (binari)..." -ForegroundColor Gray
    curl.exe --progress-bar -L $binAsset.browser_download_url    -o "$installDir\bin.zip"
    Write-Host "  Download $tag (librerie CUDA)..." -ForegroundColor Gray
    curl.exe --progress-bar -L $cudartAsset.browser_download_url -o "$installDir\cudart.zip"

    Write-Host "  Estrazione..." -ForegroundColor Gray
    Expand-Archive -Path "$installDir\bin.zip"    -DestinationPath $installDir -Force
    Expand-Archive -Path "$installDir\cudart.zip" -DestinationPath $installDir -Force

    Remove-Item "$installDir\bin.zip", "$installDir\cudart.zip" -Force
    Write-Ok "llama.cpp $tag installato in $installDir"
}

# ---- STEP 5: Crea task di avvio automatico + script Desktop ------------------
Write-Step 5 $TOTAL_STEPS "Creazione script di avvio Worker sul Desktop..."

$desktopFolder = [Environment]::GetFolderPath("Desktop")
$workerScript  = "$desktopFolder\Avvia_Worker_RPC.bat"

$workerContent = @"
@echo off
title CLUSTER IA - WORKER RPC (RTX 3050)
cls
echo.
echo  =========================================================
echo   LLAMA RPC CLUSTER - PC WORKER
echo   Questa finestra deve restare aperta durante l'uso dell'IA!
echo  =========================================================
echo.
echo  IP di questo PC: 192.168.50.2
echo  In ascolto sulla porta 50052...
echo.
echo  Sul PC Master avvia 'Avvia_Cluster_MASTER.bat'
echo  =========================================================
echo.

C:\llama-cluster\ggml-rpc-server.exe -H 0.0.0.0 -p 50052
pause
"@

[System.IO.File]::WriteAllText($workerScript, $workerContent, [System.Text.Encoding]::ASCII)
Write-Ok "Creato sul Desktop: Avvia_Worker_RPC.bat"

# Opzione: avvio automatico con Windows
$autoStartChoice = Read-Host "  Vuoi che il Worker si avvii automaticamente all'accensione del PC? (S/N)"
if ($autoStartChoice -match "^[Ss]") {
    $taskAction  = New-ScheduledTaskAction  -Execute "C:\llama-cluster\ggml-rpc-server.exe" -Argument "-H 0.0.0.0 -p 50052"
    $taskTrigger = New-ScheduledTaskTrigger -AtLogon
    $taskSettings= New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 0)
    Register-ScheduledTask -TaskName "LlamaRPCWorker" -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -RunLevel Highest -Force | Out-Null
    Write-Ok "Task di avvio automatico 'LlamaRPCWorker' registrato."
}

# ---- FINE -------------------------------------------------------------------
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  INSTALLAZIONE WORKER COMPLETATA!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host " Come usare:" -ForegroundColor Cyan
Write-Host "  1. Clicca 'Avvia_Worker_RPC.bat' sul Desktop" -ForegroundColor White
Write-Host "  2. Lascia aperta la finestra nera che appare" -ForegroundColor White
Write-Host "  3. Sul PC Master avvia il cluster normalmente!" -ForegroundColor White
Write-Host ""
Write-Host " Questo PC risponde a: 192.168.50.2:50052" -ForegroundColor Green
Write-Host ""
Pause
