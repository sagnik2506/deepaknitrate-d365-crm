<#
.SYNOPSIS
  Unpacks exported solution zips into a folder of the repo, checks the count, and optionally commits and tags (steps B3 and J3). Does not touch any environment.
#>
param([Parameter(Mandatory)][string]$ZipDir, [Parameter(Mandatory)][string]$OutDir, [int]$ExpectedCount = 0, [string]$Tag = '', [string]$Message = 'Archive solutions', [switch]$Commit, [switch]$Push, [string]$Branch = 'uat-alignment', [string]$PackageType = 'Unmanaged')
. "$PSScriptRoot\Common.ps1"
$zips = @(Get-ChildItem $ZipDir -Recurse -Filter *.zip)
Write-Log "$($zips.Count) zip files to unpack into $OutDir"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$failed = @()
foreach ($z in $zips) {
    $info = Get-ZipSolutionInfo $z.FullName
    $dest = Join-Path $OutDir $info.UniqueName
    & pac solution unpack --zipfile $z.FullName --folder $dest --packagetype $PackageType --allowDelete true --allowWrite true | Out-Null
    if ($LASTEXITCODE -ne 0) { $failed += $info.UniqueName; Add-AdoWarning "unpack failed: $($info.UniqueName)" }
}
$folders = @(Get-ChildItem $OutDir -Directory).Count
Write-Log "unpacked folders: $folders (expected $ExpectedCount), failed: $($failed.Count)"
$problem = ($failed.Count -gt 0) -or ($ExpectedCount -gt 0 -and $folders -ne $ExpectedCount)
if ($problem) { Add-AdoError "Unpack check failed: $folders folders, expected $ExpectedCount, failed: $($failed -join ', ')"; exit 1 }
if ($Commit) {
    Push-Location $script:RepoRoot
    try {
        & git add -- $OutDir
        & git -c user.name='ado-pipeline' -c user.email='ado-pipeline@localhost' commit -m $Message
        if ($Tag) { & git tag -f $Tag }
        if ($Push) { & git push origin "HEAD:refs/heads/$Branch"; if ($Tag) { & git push origin $Tag --force } }
    } finally { Pop-Location }
}
