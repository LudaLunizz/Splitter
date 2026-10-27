<#
.SYNOPSIS
    Removes the Splitter virtual cables.

.DESCRIPTION
    Run uninstall.cmd, which asks for administrator rights and runs this.

    Removes every device with hardware id ROOT\Splitter, then every Splitter
    driver package (splitter.inf from provider BananaSplit) from the driver
    store, and the Splitter test certificates that install.ps1 added to
    this PC's trusted stores.
    Test-signing mode is left as it is (bcdedit /set testsigning off turns
    it off, after a restart).
#>
[CmdletBinding()]
param(
    # Accepted for older instructions; the certificates are always removed.
    [switch] $RemoveCertificate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$hwid = 'ROOT\Splitter'

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Run uninstall.cmd (it asks for administrator rights).' -ForegroundColor Red
    exit 1
}

$failed = $false
$restart = $false

# pnputil's exit code: 0 is done, 3010 (ERROR_SUCCESS_REBOOT_REQUIRED) is
# done but finished by a restart, anything else failed.
function Read-PnputilResult {
    if ($LASTEXITCODE -eq 3010) { $script:restart = $true } elseif ($LASTEXITCODE -ne 0) { $script:failed = $true }
}

# Devices (pnputil /remove-device exists since Windows 10 version 2004).
$devices = @(Get-CimInstance Win32_PnPEntity | Where-Object { $_.HardwareID -contains $hwid })
foreach ($d in $devices) {
    Write-Host "Removing device $($d.PNPDeviceID)..."
    & pnputil /remove-device $d.PNPDeviceID | Out-Host
    Read-PnputilResult
}

# Driver packages: every oemNN.inf whose original name is splitter.inf and
# whose provider is BananaSplit (Splitter.inx). splitter.inf alone is a
# common enough name that another company's driver could have it, and
# /force would remove that one even while a device uses it.
$drivers = @(Get-WindowsDriver -Online -All | Where-Object {
    $_.OriginalFileName -and ([IO.Path]::GetFileName($_.OriginalFileName) -ieq 'splitter.inf') -and
    $_.ProviderName -eq 'BananaSplit'
})
foreach ($p in $drivers) {
    Write-Host "Removing driver package $($p.Driver)..."
    & pnputil /delete-driver $p.Driver /uninstall /force | Out-Host
    Read-PnputilResult
}

# The test certificates. install.ps1 makes this PC trust the one of each
# test build it installs, as a root and as a publisher; left behind, they
# would keep the PC trusting whatever their keys sign, long after Splitter
# is gone. (Before this, only -RemoveCertificate removed them.)
$certs = 0
foreach ($store in 'Root', 'TrustedPublisher') {
    foreach ($c in @(Get-ChildItem "Cert:\LocalMachine\$store" |
            Where-Object { $_.Subject -eq 'CN=Splitter test signing (BananaSplit)' })) {
        Write-Host "Removing test certificate $($c.Thumbprint) from $store..."
        try {
            Remove-Item $c.PSPath
            $certs++
        } catch {
            Write-Host "  failed: $($_.Exception.Message)" -ForegroundColor Red
            $failed = $true
        }
    }
}

if ($devices.Count -eq 0 -and $drivers.Count -eq 0 -and $certs -eq 0 -and -not $failed) {
    Write-Host 'Splitter was not installed.'
} elseif ($failed) {
    Write-Host 'Some parts could not be removed; see the messages above. A restart and a second run usually finish it.' -ForegroundColor Yellow
    exit 1
} elseif ($restart) {
    Write-Host 'Splitter is removed. Restart Windows to finish.' -ForegroundColor Yellow
} else {
    Write-Host 'Splitter is removed.'
}
exit 0
