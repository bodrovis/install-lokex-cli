[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

if (-not $env:ACTION_PATH)     { throw "missing ACTION_PATH" }
if (-not $env:INPUT_REPO)      { throw "missing INPUT_REPO" }
if (-not $env:INPUT_BIN_NAME)  { throw "missing INPUT_BIN_NAME" }
if (-not $env:INPUT_VERSION)   { throw "missing INPUT_VERSION" }
if (-not $env:INPUT_ADD_TO_PATH) { throw "missing INPUT_ADD_TO_PATH" }
if (-not $env:GITHUB_OUTPUT)   { throw "missing GITHUB_OUTPUT" }
if (-not $env:GITHUB_PATH)     { throw "missing GITHUB_PATH" }

$INSTALLER_REPO   = "bodrovis/lokex-cli"
$INSTALLER_COMMIT = "8baa06defa404d39510d56e0a045f838b89fd944"
$INSTALLER_SHA256 = "ae1008cef4171ecb4eeab3eb8a374c9a4541b913854b58aca115d0bd3d6c81e1"

$RETRY_ATTEMPTS = if ($env:RETRY_ATTEMPTS) { [int]$env:RETRY_ATTEMPTS } else { 3 }
$RETRY_DELAY_SECONDS = if ($env:RETRY_DELAY_SECONDS) { [int]$env:RETRY_DELAY_SECONDS } else { 2 }

$installDir = if ($env:INPUT_INSTALL_DIR) {
    $env:INPUT_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA "Programs\$($env:INPUT_BIN_NAME)\bin"
}

$installerUrl = "https://raw.githubusercontent.com/$INSTALLER_REPO/$INSTALLER_COMMIT/install.ps1"

try {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.SecurityProtocolType]::Tls12 -bor `
        [Net.SecurityProtocolType]::Tls13
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)][int]$Attempts,
        [Parameter(Mandatory = $true)][int]$DelaySeconds,
        [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock,
        [Parameter(Mandatory = $true)][string]$Description
    )

    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            & $ScriptBlock
            return
        } catch {
            if ($i -ge $Attempts) {
                throw "command failed after $Attempts attempts: $Description`n$($_.Exception.Message)"
            }

            Write-Warning "attempt $i/$Attempts failed, retrying in ${DelaySeconds}s: $Description"
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Invoke-Download {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutFile
    )

    Invoke-WebRequest `
        -Uri $Url `
        -Headers @{ "User-Agent" = "lokex-cli-action-installer" } `
        -OutFile $OutFile
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$null = New-Item -ItemType Directory -Path $tmpDir -Force
$installerPath = Join-Path $tmpDir "install.ps1"

try {
    Write-Host "downloading pinned installer from ${INSTALLER_REPO}@${INSTALLER_COMMIT}"

    Invoke-WithRetry -Attempts $RETRY_ATTEMPTS -DelaySeconds $RETRY_DELAY_SECONDS `
        -Description "download installer" `
        -ScriptBlock {
            Invoke-Download -Url $installerUrl -OutFile $installerPath
        }

    $actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $installerPath).Hash.ToLowerInvariant()
    $expectedSha256 = $INSTALLER_SHA256.ToLowerInvariant()

    if ($actualSha256 -ne $expectedSha256) {
        throw @"
installer checksum mismatch
expected: $expectedSha256
actual:   $actualSha256
"@
    }

    Invoke-WithRetry -Attempts $RETRY_ATTEMPTS -DelaySeconds $RETRY_DELAY_SECONDS `
        -Description "run installer" `
        -ScriptBlock {
            & $installerPath `
                -Repo $env:INPUT_REPO `
                -BinName $env:INPUT_BIN_NAME `
                -Version $env:INPUT_VERSION `
                -InstallDir $installDir
        }

    if ($env:INPUT_ADD_TO_PATH -eq "true") {
        Add-Content -LiteralPath $env:GITHUB_PATH -Value $installDir
    }

    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "install-dir=$installDir"
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "bin-path=$(Join-Path $installDir "$($env:INPUT_BIN_NAME).exe")"
}
finally {
    if (Test-Path -LiteralPath $tmpDir) {
        Remove-Item -LiteralPath $tmpDir -Recurse -Force
    }
}