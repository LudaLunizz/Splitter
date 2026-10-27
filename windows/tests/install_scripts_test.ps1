<#
.SYNOPSIS
    Runs install.ps1 and uninstall.ps1 with stand-ins for the Windows parts,
    and checks what they do in each case.

.DESCRIPTION
    Works on any computer with PowerShell 7 (pwsh), Linux too:

      pwsh -NoProfile -File windows/tests/install_scripts_test.ps1

    Each case runs a script in a pwsh of its own, with functions in place of
    the commands that need Windows: devices (Get-CimInstance,
    Get-PnpDeviceProperty), the registry (Get-ItemProperty), certificates,
    driver packages (Get-WindowsDriver), pnputil and the setup API
    (SplitterSetup). The administrator check, the Windows build and
    Is64BitOperatingSystem are replaced in a copy of the script. The case
    passes if the output has the expected lines, lacks the forbidden ones,
    and the exit code matches.

    What this can't show: install.cmd starts Windows PowerShell 5.1, which
    differs from pwsh 7 in places (with strict mode, 5.1 can't take .Count
    of a single object, for one), and nothing here touches a real device.

    Copyright (c) the BananaSplit authors. MIT licence (see LICENSE).
#>
param(
    # Internal: run one case (the scenario is in $env:SPLITTER_CASE).
    [string] $RunScript
)

$ErrorActionPreference = 'Stop'

if ($RunScript) {
    # --- one case: stand-ins, then the script -----------------------------
    $d = @{ build = 22631; is64 = $true; arch = 'AMD64'; start = ' NOEXECUTE=OPTIN TESTSIGNING'; cer = $true;
            before = @(); after = @(); endpoints = @(); packages = @(); reboot = $false;
            noPnpModule = $false; pnputilExit = 0 }
    $j = $env:SPLITTER_CASE | ConvertFrom-Json -AsHashtable
    foreach ($k in $j.Keys) { $d[$k] = $j[$k] }
    function Dev($x) {
        $h = @{ name = 'Splitter Cables'; id = 'ROOT\MEDIA\0000'; code = 0; ver = '0.2.0.0' }
        foreach ($k in $x.Keys) { $h[$k] = $x[$k] }
        $h
    }
    $d.before = @($d.before | ForEach-Object { Dev $_ })
    $d.after = @($d.after | ForEach-Object { Dev $_ })
    $global:sc = $d

    Add-Type -TypeDefinition @'
public static class SplitterSetup {
    public static bool Done = false;
    public static bool Reboot = false;
    public static bool CreateAndInstall(string h, string i) { Done = true; System.Console.WriteLine("CALL CreateAndInstall"); return Reboot; }
    public static bool Update(string h, string i) { Done = true; System.Console.WriteLine("CALL Update"); return Reboot; }
}
'@
    [SplitterSetup]::Reboot = [bool]$d.reboot

    # Functions come before cmdlets and programs of the same name.
    function global:Add-Type { }
    function global:Start-Sleep { }
    function global:Get-ItemProperty {
        param([string] $Path, [string] $Name)
        $v = if ($Path -like '*Session Manager\Environment') { $global:sc.arch }
             elseif ($Path -like '*\Control') { $global:sc.start }
             else { throw "unexpected registry path $Path" }
        if ($null -eq $v) {
            if ($PSBoundParameters['ErrorAction'] -eq 'Stop') { throw "value $Name not found" }
            return
        }
        [pscustomobject]@{ $Name = $v }
    }
    function global:Get-CimInstance {
        param([string] $ClassName, [string] $Filter)
        if ($Filter -like '*AudioEndpoint*') {
            foreach ($n in $global:sc.endpoints) { [pscustomobject]@{ Name = $n } }
            return
        }
        # Devices as they are before the install step, and after it.
        $list = if ([SplitterSetup]::Done) { $global:sc.after } else { $global:sc.before }
        foreach ($x in $list) {
            [pscustomobject]@{ Name = $x.name; HardwareID = @('ROOT\Splitter'); PNPDeviceID = $x.id; ConfigManagerErrorCode = [int]$x.code }
        }
        [pscustomobject]@{ Name = 'USB Audio'; HardwareID = @('USB\VID_1234'); PNPDeviceID = 'USB\1'; ConfigManagerErrorCode = 0 }
    }
    function global:Get-PnpDeviceProperty {
        param([string] $InstanceId, [string] $KeyName)
        if ($global:sc.noPnpModule) { throw [System.Management.Automation.CommandNotFoundException]::new('Get-PnpDeviceProperty') }
        $x = $global:sc.before | Where-Object { $_.id -eq $InstanceId } | Select-Object -First 1
        [pscustomobject]@{ Data = $x.ver }
    }
    function global:Import-Certificate { param($FilePath, $CertStoreLocation) Write-Host "CALL trust $CertStoreLocation" }
    function global:Get-WindowsDriver {
        param([switch] $Online, [switch] $All)
        foreach ($p in $global:sc.packages) { [pscustomobject]@{ Driver = $p.oem; OriginalFileName = $p.file; ProviderName = $p.provider } }
    }
    function global:pnputil { Write-Host "CALL pnputil $($args -join ' ')"; $global:LASTEXITCODE = [int]$global:sc.pnputilExit }
    function global:Get-ChildItem { param($Path) }

    # A package folder of its own: the script, driver\splitter.inf, and the
    # test certificate if the case has one.
    $pkg = Join-Path ([IO.Path]::GetTempPath()) ("splitter-test-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path (Join-Path $pkg 'driver') | Out-Null
    New-Item -ItemType File -Path (Join-Path $pkg 'driver/splitter.inf') | Out-Null
    if ($d.cer) { Set-Content (Join-Path $pkg 'splitter-test.cer') 'x' }
    $src = Get-Content $RunScript -Raw
    $src = $src -replace '(?m)^\$principal = .*$', '$principal = [pscustomobject]@{}; $principal | Add-Member ScriptMethod IsInRole { $true }'
    $src = $src.Replace('[Environment]::OSVersion.Version.Build', '$global:sc.build').Replace('[Environment]::Is64BitOperatingSystem', '$global:sc.is64')
    $copy = Join-Path $pkg (Split-Path $RunScript -Leaf)
    Set-Content -Path $copy -Value $src
    $global:LASTEXITCODE = 0
    try { & $copy } finally { Remove-Item $pkg -Recurse -Force }
    exit $LASTEXITCODE
}

# --- the cases -------------------------------------------------------------
$install = Join-Path $PSScriptRoot '../install/install.ps1'
$uninstall = Join-Path $PSScriptRoot '../install/uninstall.ps1'

# Forward slashes: .NET on Linux doesn't take \ as a folder separator.
$ours = @{ oem = 'oem12.inf'; file = 'C:/Windows/System32/DriverStore/FileRepository/splitter.inf_amd64_1/splitter.inf'; provider = 'BananaSplit' }
$theirs = @{ oem = 'oem7.inf'; file = 'C:/Windows/System32/DriverStore/FileRepository/splitter.inf_amd64_2/Splitter.INF'; provider = 'Contoso Audio' }
$other = @{ oem = 'oem3.inf'; file = 'C:/Windows/System32/DriverStore/FileRepository/realtek.inf_amd64_3/realtek.inf'; provider = 'Realtek' }
$cables = @('Splitter 1 (Splitter Cables)', 'Splitter B1 (Splitter Cables)')

$cases = @(
    @{ name = 'ARM64 PC'; script = $install; case = @{ arch = 'ARM64' }; exit = 1
       want = @('ARM processor (ARM64)', 'Nothing was changed'); not = @('CALL') }
    @{ name = 'ARM64 PC, registry value missing, environment says ARM64'; script = $install; case = @{ arch = $null }; env = 'ARM64'; exit = 1
       want = @('ARM processor (ARM64)'); not = @('CALL') }
    @{ name = 'registry value missing, environment says AMD64'; script = $install; case = @{ arch = $null; after = @(@{}); endpoints = $cables }; env = 'AMD64'; exit = 0
       want = @('CALL CreateAndInstall', 'Splitter cables:') }
    @{ name = 'old Windows'; script = $install; case = @{ build = 18363 }; exit = 1
       want = @('build 18363'); not = @('CALL') }
    @{ name = '32-bit Windows'; script = $install; case = @{ is64 = $false }; exit = 1
       want = @('needs 64-bit Windows'); not = @('CALL') }
    @{ name = 'fresh install, test mode on'; script = $install; case = @{ after = @(@{}); endpoints = $cables }; exit = 0
       want = @('CALL trust Cert:\LocalMachine\Root', 'CALL trust Cert:\LocalMachine\TrustedPublisher', 'CALL CreateAndInstall', 'Splitter 1 (Splitter Cables)') }
    @{ name = 'test mode off'; script = $install; case = @{ start = ' NOEXECUTE=OPTIN' }; exit = 1
       want = @('This is a TEST build', 'bcdedit /set testsigning on'); not = @('CALL') }
    @{ name = 'SystemStartOptions missing'; script = $install; case = @{ start = $null }; exit = 1
       want = @('This is a TEST build'); not = @('CALL') }
    @{ name = '0.1.0 installed (driver version)'; script = $install; case = @{ before = @(@{ ver = '0.1.0.0' }) }; exit = 1
       want = @('Splitter 0.1.0 is installed', 'run uninstall.cmd'); not = @('CALL') }
    @{ name = '0.1.0 by its old name, no PnpDevice module'; script = $install; case = @{ noPnpModule = $true; before = @(@{ name = 'Splitter Virtual Cables' }) }; exit = 1
       want = @('Splitter 0.1.0 is installed'); not = @('CALL') }
    @{ name = 'only 0.1.0 cables left'; script = $install; case = @{ endpoints = @('Splitter 1 (Splitter Virtual Cables)') }; exit = 1
       want = @('Splitter 0.1.0 is installed'); not = @('CALL') }
    @{ name = 'second Splitter device with new names is not 0.1.0'; script = $install; case = @{ after = @(@{}); endpoints = @('Splitter 1 (2- Splitter Cables)') }; exit = 0
       want = @('CALL CreateAndInstall', 'Splitter 1 (2- Splitter Cables)'); not = @('0.1.0') }
    @{ name = 'two Splitter devices'; script = $install; case = @{ before = @(@{}, @{ id = 'ROOT\MEDIA\0001' }) }; exit = 1
       want = @('There are 2 Splitter devices', 'run uninstall.cmd', 'Nothing was changed'); not = @('CALL') }
    @{ name = 'update one 0.2.0 device, restart'; script = $install; case = @{ reboot = $true; before = @(@{}); after = @(@{ code = 38 }) }; exit = 0
       want = @('updating its driver', 'CALL Update', 'appear after the restart', 'asks for a restart'); not = @('CreateAndInstall') }
    @{ name = 'driver not started (code 52)'; script = $install; case = @{ after = @(@{ code = 52 }) }; exit = 1
       want = @('problem code 52', 'Code 52:') }
    @{ name = 'Microsoft-signed package, test mode off'; script = $install; case = @{ cer = $false; start = ' NOEXECUTE=OPTIN'; after = @(@{}) }; exit = 0
       want = @('CALL CreateAndInstall', 'appear in the sound settings'); not = @('CALL trust', 'TEST build') }

    @{ name = 'uninstall: ours, another company''s splitter.inf, Realtek'; script = $uninstall; case = @{ before = @(@{}); packages = @($ours, $theirs, $other) }; exit = 0
       want = @('CALL pnputil /remove-device ROOT\MEDIA\0000', 'CALL pnputil /delete-driver oem12.inf /uninstall /force', 'Splitter is removed.'); not = @('oem7.inf', 'oem3.inf') }
    @{ name = 'uninstall: only another company''s splitter.inf'; script = $uninstall; case = @{ packages = @($theirs) }; exit = 0
       want = @('Splitter was not installed.'); not = @('CALL') }
    @{ name = 'uninstall: restart needed (3010)'; script = $uninstall; case = @{ before = @(@{}); packages = @($ours); pnputilExit = 3010 }; exit = 0
       want = @('Restart Windows to finish.') }
    @{ name = 'uninstall: pnputil fails'; script = $uninstall; case = @{ before = @(@{}); packages = @($ours); pnputilExit = 5 }; exit = 1
       want = @('Some parts could not be removed') }
    @{ name = 'uninstall: package left behind, no device'; script = $uninstall; case = @{ packages = @($ours) }; exit = 0
       want = @('CALL pnputil /delete-driver oem12.inf'); not = @('remove-device') }
)

$pwsh = (Get-Process -Id $PID).Path
$failed = 0
foreach ($c in $cases) {
    $env:SPLITTER_CASE = $c.case | ConvertTo-Json -Depth 5 -Compress
    $oldArch = $env:PROCESSOR_ARCHITECTURE
    if ($c.ContainsKey('env')) { $env:PROCESSOR_ARCHITECTURE = $c.env }
    $out = & $pwsh -NoProfile -File $PSCommandPath -RunScript $c.script 2>&1 | Out-String
    $code = $LASTEXITCODE
    $env:PROCESSOR_ARCHITECTURE = $oldArch
    $why = @()
    if ($code -ne $c.exit) { $why += "exit $code, not $($c.exit)" }
    foreach ($w in $c.want) { if (-not $out.Contains($w)) { $why += "missing: $w" } }
    foreach ($n in @($c.not)) { if ($n -and $out.Contains($n)) { $why += "unexpected: $n" } }
    if ($why) {
        $failed++
        Write-Host "FAIL  $($c.name)"
        $why | ForEach-Object { Write-Host "        $_" }
        $out.TrimEnd() -split "`n" | ForEach-Object { Write-Host "      | $_" }
    } else {
        Write-Host "ok    $($c.name)"
    }
}
Write-Host ''
if ($failed) { Write-Host "$failed of $($cases.Count) cases failed"; exit 1 }
Write-Host "all $($cases.Count) cases passed"
