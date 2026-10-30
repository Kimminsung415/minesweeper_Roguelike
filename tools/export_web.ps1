param([Parameter(Mandatory = $true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$docsRoot = Join-Path $projectRoot 'docs'
[IO.Directory]::CreateDirectory($docsRoot) | Out-Null
[IO.File]::WriteAllText((Join-Path $docsRoot '.gdignore'), '')
[IO.File]::WriteAllText((Join-Path $docsRoot '.nojekyll'), '')
function Invoke-GodotExportStep([string[]]$EngineArguments) {
    $start = [Diagnostics.ProcessStartInfo]::new($GodotPath)
    $start.UseShellExecute = $false
    foreach ($argument in $EngineArguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "Godot export step failed: $($process.ExitCode)" }
}
Invoke-GodotExportStep @('--headless', '--path', $projectRoot, '--editor', '--import', '--quit')
Invoke-GodotExportStep @('--headless', '--path', $projectRoot, '--export-release', 'Web', (Join-Path $docsRoot 'index.html'))
Copy-Item -LiteralPath (Join-Path $projectRoot 'release.json') -Destination (Join-Path $docsRoot 'build.json')
$licensesRoot = Join-Path $docsRoot 'licenses'
[IO.Directory]::CreateDirectory($licensesRoot) | Out-Null
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'LICENSES') -File) {
    Copy-Item -LiteralPath $file.FullName -Destination $licensesRoot
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/fonts/OFL.txt') -Destination (Join-Path $licensesRoot 'NOTO_SANS_KR_OFL.txt')
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/IMAGE_SOURCES.md') -Destination $licensesRoot
Write-Output "Web export ready: $docsRoot"
