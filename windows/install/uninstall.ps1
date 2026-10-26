<#
.SYNOPSIS
    Removes the Splitter virtual cables.

.DESCRIPTION
    Run uninstall.cmd, which asks for administrator rights and runs this.

    Removes every device with hardware id ROOT\Splitter, then every Splitter
    driver package from the driver store. With -RemoveCertificate it also
    removes the Splitter test certificate from this PC's trusted stores.
    Test-signing mode is left as it is (bcdedit /set testsigning off turns
    it off, after a restart).
#>
[CmdletBinding()]
param(
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

# Driver packages: every oemNN.inf whose original name is splitter.inf.
$drivers = @(Get-WindowsDriver -Online -All | Where-Object {
    $_.OriginalFileName -and ([IO.Path]::GetFileName($_.OriginalFileName) -ieq 'splitter.inf')
})
foreach ($p in $drivers) {
    Write-Host "Removing driver package $($p.Driver)..."
    & pnputil /delete-driver $p.Driver /uninstall /force | Out-Host
    Read-PnputilResult
}

if ($RemoveCertificate) {
    foreach ($store in 'Root', 'TrustedPublisher') {
        Get-ChildItem "Cert:\LocalMachine\$store" |
            Where-Object { $_.Subject -eq 'CN=Splitter test signing (BananaSplit)' } |
            ForEach-Object {
                Write-Host "Removing test certificate $($_.Thumbprint) from $store..."
                Remove-Item $_.PSPath
            }
    }
}

if ($devices.Count -eq 0 -and $drivers.Count -eq 0) {
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
