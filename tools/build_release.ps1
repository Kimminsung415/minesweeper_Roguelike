param(
    [ValidateSet('none', 'build', 'patch', 'minor', 'major')][string]$Bump = 'none',
    [string]$ReleaseName = '',
    [string]$ReleaseDate = '',
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$metadataPath = Join-Path $projectRoot 'release.json'
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$versionMatch = [regex]::Match($metadata.version, '^(\d+)\.(\d+)\.(\d+)$')
if (-not $versionMatch.Success -or $metadata.build -lt 1) { throw 'Invalid release version or build number.' }
$major = [int]$versionMatch.Groups[1].Value
$minor = [int]$versionMatch.Groups[2].Value
$patch = [int]$versionMatch.Groups[3].Value
if ($Bump -ne 'none') {
    if ($ReleaseDate -notmatch '^\d{4}-\d{2}-\d{2}$') { throw 'Provide the user-local release date with -ReleaseDate YYYY-MM-DD when incrementing a release.' }
    switch ($Bump) {
        'patch' { $patch++ }
        'minor' { $minor++; $patch = 0 }
        'major' { $major++; $minor = 0; $patch = 0 }
    }
    $metadata.version = "$major.$minor.$patch"
    $metadata.build = [int]$metadata.build + 1
    $metadata.date = $ReleaseDate
}
if ($ReleaseName) { $metadata.name = $ReleaseName }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path (Split-Path $projectRoot -Parent) 'releases' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$baseName = 'MineLedger_v{0}_build{1:d3}' -f $metadata.version, [int]$metadata.build
$windowsPath = Join-Path $OutputDirectory ($baseName + '_Windows.zip')
$sourcePath = Join-Path $OutputDirectory ($baseName + '_Source.zip')
$checksumsPath = Join-Path $OutputDirectory ($baseName + '_SHA256.txt')
foreach ($path in @($windowsPath, $sourcePath, $checksumsPath)) {
    if (Test-Path -LiteralPath $path) { throw "Release already exists: $path. Increment the build or choose another output directory." }
}
if ($Bump -ne 'none' -or $ReleaseName) {
    [IO.File]::WriteAllText($metadataPath, ($metadata | ConvertTo-Json) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    $readmePath = Join-Path $projectRoot 'README.md'
    $readmeText = [IO.File]::ReadAllText($readmePath)
    $readmeText = [regex]::Replace($readmeText, 'MineLedger_v\d+\.\d+\.\d+_build\d+_Windows\.zip', $baseName + '_Windows.zip')
    $releaseLine = '현재 릴리스: **v{0}+build.{1} — {2}**. 버전/빌드 기준은 `VERSIONING.md`, 변경 기록은 `CHANGELOG.md`에 있습니다.' -f $metadata.version, $metadata.build, $metadata.name
    $readmeText = [regex]::Replace($readmeText, '(?m)^현재 릴리스:.*$', [Text.RegularExpressions.MatchEvaluator]{ param($match) return $releaseLine })
    [IO.File]::WriteAllText($readmePath, $readmeText, [Text.UTF8Encoding]::new($false))
}
$prefix = $projectRoot + [IO.Path]::DirectorySeparatorChar
$files = Get-ChildItem -LiteralPath $projectRoot -Recurse -File | Where-Object { $_.FullName -notlike '*\.godot\*' -and $_.FullName -notlike '*\.git\*' }
foreach ($kind in @('Windows', 'Source')) {
    $archivePath = if ($kind -eq 'Windows') { $windowsPath } else { $sourcePath }
    $archive = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($prefix.Length).Replace('\', '/')
            if ($kind -eq 'Source' -and ($relative.StartsWith('runtime/') -or $relative.EndsWith('.cmd'))) { continue }
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $relative, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally { $archive.Dispose() }
    Get-Item -LiteralPath $archivePath | Select-Object Name, Length
}
$hashLines = foreach ($path in @($windowsPath, $sourcePath)) { '{0}  {1}' -f (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash, [IO.Path]::GetFileName($path) }
[IO.File]::WriteAllLines($checksumsPath, $hashLines, [Text.UTF8Encoding]::new($false))
Write-Output "Release complete: v$($metadata.version)+build.$($metadata.build) / $($metadata.name)"
