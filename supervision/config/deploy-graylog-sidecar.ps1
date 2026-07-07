# Graylog Sidecar Startup Deployment Script
# Execute au demarrage des postes via GPO (Computer Startup Script).
# Installe le Sidecar depuis le partage du RODC, genere sidecar.yml et
# configure le service. Idempotent : ne reinstalle pas si le service existe.

# -------------------------
# Variables
# -------------------------
$Installer  = "\\RODC01\PublicDrop\SIEM\graylog_sidecar.msi"
$InstallDir = "C:\Program Files\Graylog\sidecar"
$ConfigFile = Join-Path $InstallDir "sidecar.yml"
$LogFile    = "C:\Windows\Temp\graylog-sidecar-deploy.log"
$GraylogURL = "http://10.0.50.20:9000/api/"
$Token      = "[REDACTED]"
$NodeName   = $env:COMPUTERNAME

# -------------------------
# Logging function
# -------------------------
function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Timestamp - $Message"
}

Write-Log "========== Graylog deployment started =========="

# -------------------------
# Stop service if present
# -------------------------
try   { Stop-Service -Name graylog-sidecar ; Write-Log "Service stopped" }
catch { Write-Log "stop failed" }

# -------------------------
# Check installer availability on the share
# -------------------------
Write-Log "Checking installer availability"
if (!(Test-Path $Installer)) {
    Write-Log "Installer not reachable"
    exit 1
}

# -------------------------
# Install Sidecar (silent MSI) if not already present
# -------------------------
$Installed = Get-Service -Name graylog-sidecar -ErrorAction SilentlyContinue
if (-not $Installed) {
    Write-Log "Graylog Sidecar not installed"
    $MSI = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList @("/i", $Installer, "/qn", "/norestart") `
        -Wait -PassThru
    Write-Log "MSI exit code: $($MSI.ExitCode)"
    if ($MSI.ExitCode -ne 0) { Write-Log "Installation failed" ; exit 1 }
    Write-Log "Installation completed"
}

# -------------------------
# Wait for service registration
# -------------------------
Write-Log "Waiting for service registration"
for ($i = 0; $i -lt 30; $i++) {
    $Service = Get-Service -Name graylog-sidecar -ErrorAction SilentlyContinue
    if ($Service) { break }
    Start-Sleep 2
}
$Service = Get-Service -Name graylog-sidecar -ErrorAction SilentlyContinue
if (-not $Service)          { Write-Log "Service not found"          ; exit 1 }
if (!(Test-Path $InstallDir)) { Write-Log "Install directory missing" ; exit 1 }

# -------------------------
# Build sidecar config
# -------------------------
Write-Log "Generating sidecar.yml"
$Config = @"

server_url: "$GraylogURL"

server_api_token: "$Token"

node_name: "$NodeName"
node_id: "file:C:\\Program Files\\Graylog\\sidecar\\node-id"

update_interval: 10

send_status: true

tls_skip_verify: false

"@
$Config | Set-Content -Path $ConfigFile -Encoding UTF8
Write-Log "Configuration written"

# -------------------------
# Configure and restart service
# -------------------------
Set-Service -Name graylog-sidecar -StartupType Automatic
try {
    Restart-Service -Name graylog-sidecar -Force -ErrorAction Stop
    Write-Log "Service restarted"
}
catch {
    Write-Log "Restart failed - attempting start"
    Start-Service -Name graylog-sidecar -ErrorAction SilentlyContinue
}

Write-Log "Deployment completed"
exit 0
