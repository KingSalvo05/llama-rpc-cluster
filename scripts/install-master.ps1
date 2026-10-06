
# ==============================================================================
#  LLAMA-RPC-CLUSTER  |  install-master.ps1
#  Master PC (il PC potente con GPU principale)
#
#  Esecuzione rapida (incolla nel terminale PowerShell come Amministratore):
#  irm https://raw.githubusercontent.com/KingSalvo05/llama-rpc-cluster/main/scripts/install-master.ps1 | iex
# ==============================================================================

$ErrorActionPreference = "Stop"

# Cattura globale: se qualcosa va storto mostra l'errore PRIMA di chiudersi
trap {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Red
    Write-Host "  ERRORE:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Red
    Write-Host "Premi un tasto per chiudere..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

function Write-Banner {
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "   LLAMA RPC CLUSTER  |  Installazione PC MASTER" -ForegroundColor Cyan
    Write-Host "   Unisci GPU di piu' PC per caricare modelli enormi!" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
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
    Write-Warn "Rilancio con privilegi Amministratore (necessari per configurare la rete)..."
    # Se eseguito come file .ps1 locale usa il percorso fisico;
    # se eseguito via irm|iex non esiste un file su disco, quindi ri-scarica da URL.
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath -and (Test-Path $scriptPath)) {
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    } else {
        $url = "https://raw.githubusercontent.com/KingSalvo05/llama-rpc-cluster/main/scripts/install-master.ps1"
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { irm '$url' | iex }`""
    }
    exit
}

Write-Banner
$TOTAL_STEPS = 7

# ---- STEP 1: Rilevamento GPU -------------------------------------------------
Write-Step 1 $TOTAL_STEPS "Rilevamento scheda grafica Nvidia..."

$gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" } | Select-Object -First 1
if (-not $gpu) { Write-Err "Nessuna GPU Nvidia trovata! Serve una GPU Nvidia per il PC Master." }
Write-Ok "GPU rilevata: $($gpu.Name)"

# ---- STEP 2: IP Statico Ethernet ---------------------------------------------
Write-Step 2 $TOTAL_STEPS "Configurazione IP statico Ethernet (192.168.50.1)..."

$eth = Get-NetAdapter | Where-Object {
    $_.PhysicalMediaType -eq '802.3' -and $_.Virtual -eq $false
} | Sort-Object LinkSpeed -Descending | Select-Object -First 1

if (-not $eth) {
    Write-Warn "Cavo Ethernet non rilevato. Configurazione IP saltata. Collega il cavo e riesegui."
} else {
    netsh interface ipv4 set address name="$($eth.Name)" static 192.168.50.1 255.255.255.0
    Write-Ok "Adattatore '$($eth.Name)' impostato a 192.168.50.1/24"
}

# ---- STEP 3: Firewall --------------------------------------------------------
Write-Step 3 $TOTAL_STEPS "Apertura porta 50052 su Windows Firewall (RPC in uscita)..."

Remove-NetFirewallRule -DisplayName "LlamaCppRPC" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "LlamaCppRPC" -Direction Inbound -Protocol TCP -LocalPort 50052 -Action Allow | Out-Null
Write-Ok "Regola firewall TCP 50052 creata."

# ---- STEP 4: Download llama.cpp CUDA ----------------------------------------
Write-Step 4 $TOTAL_STEPS "Download ultima versione llama.cpp con supporto CUDA..."

$installDir = "C:\llama-cluster"
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

if (Test-Path "$installDir\llama-server.exe") {
    Write-Ok "llama.cpp gia' installato in $installDir. Download saltato."
} else {
    Write-Host "  Ricerca ultima versione su GitHub..." -ForegroundColor Gray
    $releases    = Invoke-RestMethod -Uri "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=1" -UseBasicParsing
    $tag         = $releases[0].tag_name
    $binAsset    = $releases[0].assets | Where-Object { $_.name -like "llama-*-bin-win-cuda-12.4-x64.zip" } | Select-Object -First 1
    $cudartAsset = $releases[0].assets | Where-Object { $_.name -like "cudart-llama-bin-win-cuda-12.4-x64.zip" } | Select-Object -First 1

    if (-not $binAsset) { Write-Err "Impossibile trovare i binari CUDA 12.4. Controlla la connessione." }

    Write-Host "  Download release $tag (binari)..." -ForegroundColor Gray
    curl.exe --progress-bar -L $binAsset.browser_download_url    -o "$installDir\bin.zip"
    Write-Host "  Download release $tag (librerie CUDA)..." -ForegroundColor Gray
    curl.exe --progress-bar -L $cudartAsset.browser_download_url -o "$installDir\cudart.zip"

    Write-Host "  Estrazione..." -ForegroundColor Gray
    Expand-Archive -Path "$installDir\bin.zip"    -DestinationPath $installDir -Force
    Expand-Archive -Path "$installDir\cudart.zip" -DestinationPath $installDir -Force

    Remove-Item "$installDir\bin.zip", "$installDir\cudart.zip" -Force
    Write-Ok "llama.cpp $tag installato in $installDir"
}

# ---- STEP 5: Cerca modelli .gguf sul PC --------------------------------------
Write-Step 5 $TOTAL_STEPS "Ricerca modelli .gguf sul PC..."

$searchPaths = @("C:\", "D:\", "E:\")
$models = @()
foreach ($drive in $searchPaths) {
    if (Test-Path $drive) {
        $found = Get-ChildItem -Path $drive -Filter "*.gguf" -Recurse -Depth 6 -ErrorAction SilentlyContinue |
                 Where-Object { $_.Length -gt 1GB } |
                 Select-Object FullName, @{N='GB';E={[math]::Round($_.Length/1GB,1)}}
        $models += $found
    }
}

$defaultModel = $null
if ($models.Count -gt 0) {
    Write-Ok "Trovati $($models.Count) modelli .gguf:"
    for ($i = 0; $i -lt $models.Count; $i++) {
        Write-Host "    [$($i+1)] $($models[$i].GB) GB  |  $($models[$i].FullName)" -ForegroundColor Cyan
    }
    $defaultModel = $models[0].FullName
} else {
    Write-Warn "Nessun modello .gguf trovato. Potrai scaricarne uno da LM Studio o Hugging Face."
}

# ---- STEP 6: Creazione script Desktop ----------------------------------------
Write-Step 6 $TOTAL_STEPS "Creazione file di avvio sul Desktop..."

$desktopFolder = [Environment]::GetFolderPath("Desktop")
$launcherPath  = "$desktopFolder\Avvia_Cluster_MASTER.bat"

# Costruisci il menu modelli dinamicamente
$menuLines = ""
$choiceBlock = ""
if ($models.Count -gt 0) {
    for ($i = 0; $i -lt [Math]::Min($models.Count, 9); $i++) {
        $n = $i + 1
        $menuLines   += "echo   [$n] $($models[$i].GB) GB  $($models[$i].FullName)`r`n"
        $choiceBlock += "if `"!SCELTA!`"==`"$n`" set `"MODEL=$($models[$i].FullName)`"`r`n"
    }
    $menuLines += "echo   [M] Inserisci percorso manuale`r`n"
} else {
    $menuLines   = "echo   [Nessun modello trovato. Usa opzione M]`r`n"
    $choiceBlock = ""
}

$launcherContent = "@echo off`r`nsetlocal EnableDelayedExpansion`r`ntitle CLUSTER IA MASTER`r`ncls`r`necho.`r`necho  =========================================================`r`necho   LLAMA RPC CLUSTER - PC MASTER`r`necho  =========================================================`r`necho.`r`necho  Modelli disponibili:`r`necho.`r`n$menuLines`r`nset /p SCELTA=`"Scelta: `"`r`n$choiceBlock`r`nif `"!SCELTA!`"==`"M`" set /p MODEL=`"Percorso .gguf: `"`r`nif not defined MODEL ("
if ($defaultModel) {
    $launcherContent += "`r`n  set `"MODEL=$defaultModel`"`r`n)"
} else {
    $launcherContent += "`r`n  set /p MODEL=`"Nessun modello rilevato. Inserisci percorso manuale: `"`r`n)"
}
$launcherContent += @"

set /p WORKER="IP del Worker (Invio per default 192.168.50.2): "
if "!WORKER!"=="" set "WORKER=192.168.50.2"

echo.
echo  Modello: !MODEL!
echo  Worker: !WORKER!:50052
echo  Chat: http://localhost:8080
echo.

ping -n 2 !WORKER! >nul 2>&1
if %errorLevel% neq 0 (
  echo  [!!] Worker non risponde! Verifica che il cavo sia collegato
  echo       e che sul vecchio PC sia avviato il server Worker.
  pause
)

start "" powershell -Command "Start-Sleep 5; Start-Process 'http://localhost:8080'"

C:\llama-cluster\llama-server.exe -m "!MODEL!" --rpc !WORKER!:50052 -ngl 99 -c 8192 --host 0.0.0.0 --port 8080
pause
"@

[System.IO.File]::WriteAllText($launcherPath, $launcherContent, [System.Text.Encoding]::ASCII)
Write-Ok "Creato sul Desktop: Avvia_Cluster_MASTER.bat"

# ---- STEP 7: Creazione script Ripristino Internet ----------------------------
Write-Step 7 $TOTAL_STEPS "Creazione script di ripristino Internet..."
$restorePath = "$desktopFolder\RIPRISTINA_INTERNET_ETHERNET.bat"
$restoreContent = "@echo off`r`nsetlocal EnableDelayedExpansion`r`ntitle Ripristino Rete Ethernet`r`n`r`n:: Controllo privilegi amministratore`r`nnet session >nul 2>&1`r`nif %errorLevel% neq 0 (`r`n    echo Richiesta permessi di amministratore...`r`n    powershell -Command `"Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs`"`r`n    exit /b`r`n)`r`n`r`ncls`r`necho ==============================================================`r`necho    RIPRISTINO SCHEDA ETHERNET PER INTERNET NORMALE`r`necho ==============================================================`r`necho.`r`necho Sto rimettendo la porta Ethernet su `"Automatico`" (DHCP)...`r`necho.`r`n`r`nnetsh interface ipv4 set address name=`"Ethernet`" dhcp`r`nnetsh interface ipv4 set dnsservers name=`"Ethernet`" dhcp`r`n`r`necho.`r`necho [OK] Fatto! Ora puoi attaccare il cavo Ethernet al modem/router`r`necho      e navigherai su internet normalmente.`r`necho.`r`necho ==============================================================`r`npause"
[System.IO.File]::WriteAllText($restorePath, $restoreContent, [System.Text.Encoding]::ASCII)
Write-Ok "Creato sul Desktop: RIPRISTINA_INTERNET_ETHERNET.bat"

# ---- FINE -------------------------------------------------------------------
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  INSTALLAZIONE MASTER COMPLETATA!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host " Prossimi passi:" -ForegroundColor Cyan
Write-Host "  1. Sul VECCHIO PC esegui il comando Worker (vedi README su GitHub)" -ForegroundColor White
Write-Host "  2. Collega il cavo CAT6 tra i due PC" -ForegroundColor White
Write-Host "  3. Doppio click su 'Avvia_Cluster_MASTER.bat' sul Desktop!" -ForegroundColor White
Write-Host ""
Write-Host " API OpenAI-compatibile: http://127.0.0.1:8080/v1" -ForegroundColor Green
Write-Host ""
Pause




