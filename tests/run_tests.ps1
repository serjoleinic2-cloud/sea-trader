param(
    [Parameter(Mandatory = $true)]
    [string]$GodotBin
)

$ErrorActionPreference = 'Stop'
$engine = (Resolve-Path -LiteralPath $GodotBin).Path
$projectRoot = Split-Path -Parent $PSScriptRoot
$runId = 'SeaTraderTests-' + [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path (Join-Path $projectRoot 'work\verification-temp') $runId
$testProject = Join-Path $testRoot 'project'
New-Item -ItemType Directory -Path $testProject -Force | Out-Null

# Copy tracked and new source files, including local edits, without ignored artist models.
$sourceFiles = & git -C $projectRoot -c core.quotepath=false ls-files --cached --others --exclude-standard
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate project source files.' }
foreach ($relative in $sourceFiles) {
    if ($relative -match '^(work|\.godot)/' -or $relative -eq 'override.cfg' -or [IO.Path]::GetExtension($relative) -in @('.apk', '.idsig', '.blend', '.blend1', '.blend2')) { continue }
    $source = Join-Path $projectRoot $relative
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
    $destination = Join-Path $testProject $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
}
$override = "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$runId`"`n"
[IO.File]::WriteAllText((Join-Path $testProject 'override.cfg'), $override, [Text.UTF8Encoding]::new($false))
$userData = Join-Path ([Environment]::GetFolderPath('ApplicationData')) $runId
Write-Output "Test project and logs: $testRoot"
Write-Output "Isolated saves: $userData"
$previousTestFlag = [Environment]::GetEnvironmentVariable('SEA_TRADER_ISOLATED_TESTS', 'Process')
$env:SEA_TRADER_ISOLATED_TESTS = '1'

function Invoke-TestEngine([string]$name, [string[]]$engineArgs, [string]$completion) {
    $outLog = Join-Path $testRoot "$name.stdout.log"
    $errLog = Join-Path $testRoot "$name.stderr.log"
    $arguments = @('--headless', '--path', ('"' + $testProject + '"')) + $engineArgs
    $process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    if (-not $process.WaitForExit(180000)) {
        Stop-Process -Id $process.Id -Force
        throw "$name timed out; logs: $testRoot"
    }
    $process.Refresh()
    $log = (Get-Content -LiteralPath $outLog -Raw) + "`n" + (Get-Content -LiteralPath $errLog -Raw)
    [IO.File]::WriteAllText((Join-Path $testRoot "$name.log"), $log, [Text.UTF8Encoding]::new($false))
    if ($process.ExitCode -ne 0 -or $log -match 'SCRIPT ERROR|Parse Error|ERROR: SMOKE:|\[FAIL\]' -or ($completion -and $log -notmatch $completion)) {
        throw "$name failed; inspect $testRoot\$name.log"
    }
    $unexpectedErrors = $log -split "`n" | Where-Object {
        $_ -match '^ERROR:' -and
        -not ($name -eq 'unit' -and $_ -match '^ERROR: SaveSystem: (Both main and backup saves are corrupt\.|Migration failed\.)') -and
        -not ($name -eq 'unit' -and $_ -match '^ERROR: 1 resources still in use at exit')
    }
    if ($unexpectedErrors) {
        throw "$name reported unexpected errors; inspect $testRoot\$name.log"
    }
    $log -split "`n" | Where-Object { $_ -match '^TOTAL|^SMOKE checks=|^NAVAL SMOKE checks=' } | Write-Output
}

try {
    Invoke-TestEngine 'import' @('--editor', '--import', '--quit') ''
    Invoke-TestEngine 'unit' @('res://tests/test_runner.tscn') 'TOTAL\s+pass=\d+\s+fail=0'
    Invoke-TestEngine 'smoke' @('res://tests/runtime_smoke.tscn') 'SMOKE checks=\d+ fail=0'
    Invoke-TestEngine 'naval-smoke' @('res://tests/naval_runtime_smoke.tscn') 'NAVAL SMOKE checks=\d+ fail=0'
    Write-Output 'All checks passed. Test files and logs are retained for diagnosis.'
} finally {
    [Environment]::SetEnvironmentVariable('SEA_TRADER_ISOLATED_TESTS', $previousTestFlag, 'Process')
}
