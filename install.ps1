# ============================================================
# ByteHide Server Agent — Windows Installer (PowerShell)
# ============================================================
#
# Install with (PowerShell as Administrator):
#   irm https://raw.githubusercontent.com/bytehide/monitor-dotnet-agent/main/install.ps1 | iex
#
# Or with token inline:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/bytehide/monitor-dotnet-agent/main/install.ps1))) -Token "bh_xxx"
#
# Or download and run:
#   .\install.ps1 -Token "bh_xxx"
#
# ============================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$Token,

    [string]$Version = "1.0.5",

    [string]$InstallDir = "$env:ProgramFiles\ByteHide\CLI",

    [switch]$NoInstall
)

$ErrorActionPreference = "Stop"

# ── Config ────────────────────────────────────────────────
$GitHubRepo = "bytehide/monitor-dotnet-agent"

# ── Colors ────────────────────────────────────────────────
function Write-Info    { param($Msg) Write-Host "[ByteHide] $Msg" -ForegroundColor Cyan }
function Write-Ok      { param($Msg) Write-Host "[ByteHide] $Msg" -ForegroundColor Green }
function Write-Warn    { param($Msg) Write-Host "[ByteHide] $Msg" -ForegroundColor Yellow }
function Write-Err     { param($Msg) Write-Host "[ByteHide] $Msg" -ForegroundColor Red }

# ── Validate ──────────────────────────────────────────────
if (-not $Token -and -not $NoInstall) {
    # Prompt for token if not provided
    $Token = Read-Host "Enter your ByteHide API token"
    if (-not $Token) {
        Write-Err "Token is required."
        Write-Host ""
        Write-Host "Usage:"
        Write-Host '  .\install.ps1 -Token "bh_xxxxxxxxxxxx"'
        Write-Host ""
        Write-Host "Get your token from: https://app.bytehide.com -> Settings -> API Tokens"
        exit 1
    }
}

# ── Check Admin ───────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Not running as Administrator. Agent install may fail (needs to set machine-level env vars)."
    Write-Warn "Re-run as Administrator for best results."
    Write-Host ""
}

# ── Banner ────────────────────────────────────────────────
Write-Host ""
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host "   ByteHide Server Agent Installer" -ForegroundColor Cyan
Write-Host "   Windows x64" -ForegroundColor Cyan
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host ""

# ── Detect architecture ──────────────────────────────────
$arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
$rid = "win-$arch"

Write-Info "Platform: $rid"
Write-Info "Version:  $Version"

# ── Build download URL ───────────────────────────────────
$downloadUrl = if ($env:BYTEHIDE_AGENT_URL) {
    Write-Info "Using custom URL: $env:BYTEHIDE_AGENT_URL"
    $env:BYTEHIDE_AGENT_URL
} else {
    "https://github.com/$GitHubRepo/releases/download/v$Version/bytehide-agent-$Version-$rid.zip"
}

# ── Download ─────────────────────────────────────────────
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "bytehide-agent-install-$(Get-Random)"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

try {
    $archivePath = Join-Path $tmpDir "bytehide-agent.zip"

    Write-Info "Downloading bytehide-agent..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing
    }
    catch {
        Write-Err "Download failed from: $downloadUrl"
        Write-Host ""
        Write-Err "Possible causes:"
        Write-Err "  1. Version $Version not available for $rid"
        Write-Err "  2. Release not published on GitHub"
        Write-Err "  3. Network connectivity issue"
        Write-Host ""
        Write-Err "Manual install: download the binary and run:"
        Write-Err "  .\bytehide-agent.exe install --token <token>"
        exit 1
    }

    # ── Extract ──────────────────────────────────────────
    Write-Info "Extracting..."
    $extractDir = Join-Path $tmpDir "extracted"
    Expand-Archive -Path $archivePath -DestinationPath $extractDir -Force

    $binary = Join-Path $extractDir "bytehide-agent.exe"
    if (-not (Test-Path $binary)) {
        Write-Err "Archive does not contain 'bytehide-agent.exe'."
        exit 1
    }

    # Verify payload
    $payloadDir = Join-Path $extractDir "payload"
    if (-not (Test-Path $payloadDir)) {
        Write-Err "Archive does not contain 'payload\' directory with agent DLLs."
        exit 1
    }
    $payloadCount = (Get-ChildItem -Path $payloadDir -Filter "*.dll").Count
    Write-Info "Payload: $payloadCount DLLs"

    # ── Run agent install from extracted dir ─────────────
    if ($NoInstall) {
        Write-Ok "Binary downloaded. Skipping agent install (-NoInstall)."
    }
    else {
        Write-Info "Running agent install..."
        Write-Host ""
        & $binary install --token $Token
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Agent install failed with exit code $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }

    # ── Copy binary to install dir for future use ────────
    Write-Info "Installing CLI to $InstallDir..."
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Copy-Item -Path $binary -Destination (Join-Path $InstallDir "bytehide-agent.exe") -Force
    Write-Ok "CLI installed: $InstallDir\bytehide-agent.exe"

    # ── Add to PATH if not already there ─────────────────
    $machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($machinePath -notlike "*$InstallDir*") {
        if ($isAdmin) {
            [Environment]::SetEnvironmentVariable("PATH", "$machinePath;$InstallDir", "Machine")
            Write-Ok "Added $InstallDir to system PATH"
        }
        else {
            # Add to user PATH as fallback
            $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            if ($userPath -notlike "*$InstallDir*") {
                [Environment]::SetEnvironmentVariable("PATH", "$userPath;$InstallDir", "User")
                Write-Ok "Added $InstallDir to user PATH (run as Admin for system PATH)"
            }
        }
    }

    # ── Load env vars into current session ───────────────
    # Registry vars only apply to NEW processes. Load them into the current
    # PowerShell session so the user can launch apps immediately.
    $agentVars = @(
        "DOTNET_STARTUP_HOOKS",
        "ASPNETCORE_HOSTINGSTARTUPASSEMBLIES",
        "BYTEHIDE_MONITOR_TOKEN",
        "BYTEHIDE_MONITOR_CONFIG"
    )
    foreach ($varName in $agentVars) {
        $val = [Environment]::GetEnvironmentVariable($varName, "Machine")
        if ($val) {
            [Environment]::SetEnvironmentVariable($varName, $val, "Process")
        }
    }
    # Add CLI dir to current PATH (don't replace — preserve existing entries like dotnet)
    if ($env:Path -notlike "*$InstallDir*") {
        $env:Path = "$InstallDir;$env:Path"
    }
    Write-Ok "Environment variables loaded into current session"

    Write-Host ""
    Write-Ok "Done! ByteHide Server Agent is ready."
    Write-Host ""
    Write-Host "  Commands:" -ForegroundColor Gray
    Write-Host "    bytehide-agent status       # Check agent status"
    Write-Host "    bytehide-agent config show   # Show configuration"
    Write-Host "    bytehide-agent logs          # View logs"
    Write-Host "    bytehide-agent uninstall     # Remove agent"
    Write-Host ""
    if (-not $NoInstall) {
        Write-Host "  All .NET applications started from this session are now protected." -ForegroundColor Green
        Write-Warn "Running applications need to be restarted to pick up protection."
    }
}
finally {
    # Cleanup temp directory
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
