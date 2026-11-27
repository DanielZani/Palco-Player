#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$Release,
    [Parameter(Mandatory)][string]$ExpectedComputer,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9 _.-]+$')][string]$PuttySession,
    [Parameter(Mandatory)][ValidatePattern('^SHA256:[A-Za-z0-9+/]{43}=?$')][string]$HostKey,
    [Parameter(Mandatory)][ipaddress]$IPv4,
    [ipaddress]$IPv6,
    [switch]$DnsRecordVerified,
    [ValidatePattern('^refs/heads/[A-Za-z0-9_./-]+$')][string]$SourceRef = 'refs/heads/main',
    [ValidateSet('Publish','Verify','Rollback')][string]$Mode = 'Publish'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$domain = 'player.zani.ia.br'
$pages = @('index.html', 'docs/manual.html', 'docs/arquitetura.html')
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Release = $Release.ToLowerInvariant()

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed (exit $LASTEXITCODE)."
    }
}

function Get-DnsState {
    # Both resolvers must agree before promotion. Provider UI is authoritative for edits.
    $ready = $true
    foreach ($resolver in @('https://dns.google/resolve', 'https://cloudflare-dns.com/dns-query')) {
        foreach ($rr in @(@('A',1,$IPv4), @('AAAA',28,$IPv6), @('CNAME',5,$null))) {
            $answer = Invoke-RestMethod -Uri ("${resolver}?name=$domain&type=" + $rr[0]) -Headers @{Accept='application/dns-json'} -TimeoutSec 15
            if ($answer.Status -notin @(0,3) -or $answer.TC) { throw "DNS inconclusive at $resolver." }
            $records = @()
            if ($answer.PSObject.Properties['Answer']) { $records = @($answer.Answer) }
            if (@($records | Where-Object { $_.type -eq 5 }).Count) { throw "DNS conflict: existing CNAME. Preserve provider state." }
            $values = @($records | Where-Object { $_.type -eq $rr[1] -and $_.name.TrimEnd('.') -ieq $domain })
            if ($values.Count -gt 0) {
                foreach ($value in $values) {
                    if ($null -eq $rr[2] -or -not ([ipaddress]::Parse($value.data)).Equals($rr[2])) {
                        throw "DNS conflict: unexpected $($rr[0]) for $domain. Preserve provider state."
                    }
                }
            } elseif ($null -ne $rr[2]) { $ready = $false }
        }
    }
    return $ready
}

function Invoke-Vps([string]$Command) {
    Invoke-Checked 'plink.exe' ($sshOptions + @('-T', $PuttySession, $Command))
}

function Invoke-Release([string]$Operation) {
    $lines = @(Invoke-Vps "bash $remoteDir/vps-release.sh $Operation $remoteDir $Release $domain")
    if ($lines.Count -eq 0) { throw "Missing VPS receipt for $Operation. Reconcile before retry." }
    $receipt = $lines[-1] | ConvertFrom-Json
    if ($receipt.release -cne $Release -or $receipt.action -cne $Operation -or
        $receipt.active -isnot [bool] -or $receipt.staged -isnot [bool]) {
        throw "Unexpected VPS receipt for $Operation. Reconcile before retry."
    }
    return $receipt
}

function Test-PublicSite {
    $observedConflict = $false
    # Normal Windows certificate and hostname validation; redirects are not followed.
    foreach ($resource in (@('') + $pages)) {
        $destination = Join-Path $work 'received.html'
        $status = & curl.exe --silent --proto '=https' --connect-timeout 8 --max-time 20 --output $destination --write-out '%{http_code}' "https://$domain/$resource"
        if ($LASTEXITCODE -ne 0) { return 'Unknown' }
        $expected = if ($resource) { $hashes[$resource] } else { $hashes['index.html'] }
        if ($status -ne '200' -or (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash -ine $expected) {
            $observedConflict = $true
        }
    }
    if ($observedConflict) { return 'Mismatch' }
    return 'Verified'
}

if ($env:OS -ne 'Windows_NT' -or $env:COMPUTERNAME -ine $ExpectedComputer) {
    throw 'Requires the authorized Windows Desktop computer. Verify its identity in Nexo.'
}
if ($IPv4.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or
    ($IPv6 -and $IPv6.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetworkV6)) {
    throw 'Provide the verified VPS IPv4 and, only if routed to the same VPS, its IPv6.'
}
$origin = (Invoke-Checked git @('-C',$repo,'remote','get-url','origin')).Trim()
if ($origin -notmatch '^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)DanielZani/Palco-Player(\.git)?$') {
    throw 'Unexpected Git origin.'
}
$head = (Invoke-Checked git @('-C',$repo,'rev-parse','HEAD')).Trim()
$changes = @(Invoke-Checked git @('-C',$repo,'status','--porcelain','--untracked-files=all'))
if ($head -cne $Release -or $changes.Count) { throw 'A clean checkout at the exact release commit is required.' }
if ($Mode -eq 'Publish') {
    $source = @(Invoke-Checked git @('-C',$repo,'ls-remote','--exit-code','origin',$SourceRef))
    if ($source.Count -ne 1 -or ($source[0] -split '\s+')[0] -cne $Release) { throw 'Remote source ref differs from the approved release.' }
}

$sshOptions = @('-batch','-agent','-hostkey',$HostKey)
$mutex = [Threading.Mutex]::new($false, 'Local\PalcoPlayerPublish')
$ownsLock = $false
$work = $null
$remoteDir = $null
$uploadConfirmed = $false
try {
    try { $ownsLock = $mutex.WaitOne(0) }
    catch [System.Threading.AbandonedMutexException] { $ownsLock = $true }
    if (-not $ownsLock) { throw 'Another Desktop publication is running.' }
    $work = Join-Path ([IO.Path]::GetTempPath()) ('palco-' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($work)
    $archive = Join-Path $work 'source.zip'
    $sourceDir = Join-Path $work 'source'
    Invoke-Checked git @('-c','core.autocrlf=false','-c','core.eol=lf','-C',$repo,'archive','--format=zip','-o',$archive,$Release)
    Expand-Archive -LiteralPath $archive -DestinationPath $sourceDir
    if ((Get-Content -LiteralPath (Join-Path $sourceDir 'VERSION') -Raw).Trim() -cne '1.2.0') { throw 'Unexpected player version.' }

    if ($Mode -ne 'Rollback') {
        $dnsReady = Get-DnsState
        if ($Mode -eq 'Verify' -and -not $dnsReady) { throw 'DNS still pending.' }
        $venv = Join-Path $work 'venv'
        Invoke-Checked 'py.exe' @('-3','-m','venv',$venv)
        $python = Join-Path $venv 'Scripts/python.exe'
        Invoke-Checked $python @('-m','pip','--disable-pip-version-check','install','-r',(Join-Path $sourceDir 'scripts/requirements-guias.txt'))
        $utf8Before = [Environment]::GetEnvironmentVariable('PYTHONUTF8')
        try {
            $env:PYTHONUTF8 = '1'
            Invoke-Checked $python @((Join-Path $sourceDir 'scripts/gerar_site.py'))
        } finally { [Environment]::SetEnvironmentVariable('PYTHONUTF8', $utf8Before) }
        $dist = Join-Path $sourceDir 'dist'
        $hashes = @{}
        $manifest = foreach ($page in $pages) {
            $hashes[$page] = (Get-FileHash -LiteralPath (Join-Path $dist $page) -Algorithm SHA256).Hash.ToLowerInvariant()
            "$($hashes[$page])  $page"
        }
        # The Linux manifest needs LF even on Windows.
        $manifestPath = Join-Path $work 'SHA256SUMS'
        [IO.File]::WriteAllText($manifestPath, (($manifest -join "`n") + "`n"), [Text.Encoding]::ASCII)
        $package = Join-Path $work 'site.tar.gz'
        Invoke-Checked 'tar.exe' (@('-czf',$package,'-C',$dist) + $pages)
        if ($Mode -eq 'Verify') {
            if ((Test-PublicSite) -ne 'Verified') { throw 'Public HTTP/TLS or file hash verification failed.' }
            Write-Output "VERIFIED https://$domain/ $Release"
            return
        }
    }

    # Remote mktemp creates a private directory owned by the authenticated SSH account.
    $remoteDir = (Invoke-Vps 'umask 077 && mktemp -d /tmp/palco-release.XXXXXXXXXX' | Select-Object -Last 1)
    if ($remoteDir -cnotmatch '^/tmp/palco-release\.[A-Za-z0-9]{10}$') { throw 'Unrecognized SSH staging directory.' }
    $files = @((Join-Path $sourceDir 'deploy/vps-release.sh'))
    if ($Mode -ne 'Rollback') { $files += @($package, $manifestPath, (Join-Path $sourceDir 'deploy/default.conf')) }
    Invoke-Checked 'pscp.exe' (@('-load',$PuttySession) + $sshOptions + @('-sftp') + $files + @("${PuttySession}:${remoteDir}/"))
    $uploadConfirmed = $true
    if ($Mode -eq 'Rollback') {
        $result = Invoke-Release 'rollback'
        if ($result.active) { throw 'Rollback did not retire this release.' }
        $result | ConvertTo-Json -Compress
        return
    }
    $before = Invoke-Release 'status'
    if (-not $before.active) {
        $staged = Invoke-Release 'stage'
        if (-not $staged.staged) { throw 'Canary staging did not complete.' }
    }
    if (-not $DnsRecordVerified -or -not $dnsReady -or -not (Get-DnsState)) {
        Write-Output "DNS_PENDING $domain SHA=$Release. Nexo/Computer Use: inspect the exact owner name, A/AAAA/CNAME and wildcard on the authoritative provider; create only missing approved A/AAAA; reread the exact records and resume with -DnsRecordVerified. Exit 20."
        exit 20
    }
    $promoted = $false
    if (-not $before.active) {
        $published = Invoke-Release 'activate'
        if (-not $published.active) { throw 'VPS did not confirm activation. Reconcile status.' }
        $promoted = $true
    }
    $until = [DateTime]::UtcNow.AddMinutes(5)
    $result = 'Unknown'
    do {
        $result = Test-PublicSite
        if ($result -eq 'Verified') {
            Write-Output "VERIFIED https://$domain/ $Release $($hashes | ConvertTo-Json -Compress)"
            return
        }
        Start-Sleep -Seconds 10
    } while ([DateTime]::UtcNow -lt $until)

    if ($promoted -and $result -eq 'Mismatch' -and (Get-DnsState)) {
        $current = Invoke-Release 'status'
        if ($current.active) {
            $reverted = Invoke-Release 'rollback'
            if ($reverted.active) { throw 'Rollback unconfirmed; reconcile on VPS.' }
            throw 'Public content mismatch. VPS confirmed conditional rollback. Reconcile any DNS created by this change.'
        }
    }
    throw 'Public verification inconclusive or baseline already active. Check connectivity, DNS, TLS and VPS status before any retry.'
} finally {
    if ($remoteDir -cmatch '^/tmp/palco-release\.[A-Za-z0-9]{10}$' -and $uploadConfirmed) {
        try { Invoke-Vps "rm -f -- $remoteDir/site.tar.gz $remoteDir/SHA256SUMS $remoteDir/vps-release.sh $remoteDir/default.conf && rmdir -- $remoteDir" | Out-Null }
        catch { Write-Warning "Could not confirm cleanup of temporary upload $remoteDir." }
    }
    if ($work -and (Test-Path -LiteralPath $work)) { Remove-Item -LiteralPath $work -Recurse -Force }
    if ($ownsLock) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
