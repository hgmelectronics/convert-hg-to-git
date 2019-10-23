$ErrorActionPreference = "Stop"
if ($args.Length -ne 2) {
    Write-Output "Specify input and output directory names as arguments"
    exit 1
}

$workingDir = Get-Location
$inputRepo = Resolve-Path "$($workingDir)\$($args[0])"
Set-Location $inputRepo
[string[]]$hgStatus = hg status
if ($hgStatus.Length -gt 0) {
    Write-Output "Input repo is not clean"
    exit 1
}
Set-Location $workingDir
New-Item -path $args[1] -type directory
$outputRepo = Resolve-Path "$($workingDir)\$($args[1])"
Read-Host "Converting from $($inputRepo) to $($outputRepo), press enter to continue"

# create bare output repository
Set-Location $outputRepo
git init --bare .git

# get metadata from input repo
Set-Location $inputRepo
[string[]]$heads = hg heads -T '{node} {branch}\n'
[string[]]$hashes = hg log -T '{node}\n'

# add tags for every commit so git history can be searched by hg hash
$tagRecords = $hashes
for ($i = 0; $i -lt $tagRecords.Length; $i++) {
    $hash = $hashes[$i]
    $shortHash = $hash.Substring(0, 12)
    $tagRecords[$i] = "$($hash) $($shortHash)"
}
Write-Output $tagRecords | Out-File -FilePath ".hgtags" -Encoding utf8NoBOM
hg add ".hgtags"
$originalTipHash = (hg log -T '{node}\n')[0]
$tagCommitMessage = "Added revision tags on $($originalTipHash)"
hg commit -m $tagCommitMessage
$stripHash = (hg log -T '{node}\n')[0]

# push the history over
Set-Location $inputRepo
hg push $outputRepo

# clean up the original repo
hg strip $stripHash

# create branches in the new repo and make it normal
Set-Location $outputRepo
git config --bool core.bare false
for ($i = 0; $i -lt $heads.Length; $i++) {
    $hash, $branch = $heads[$i].Split(" ");
    if ($branch -eq "default") {
        $branch = "master"
    }
    $percent = $i / ($heads.Length) * 100
    Write-Progress -Activity "Create branches in new repo" -Status "Adding $($branch)" -PercentComplete $percent
    $shortHash = $hash.Substring(0, 12)
    git branch $branch "$($shortHash)"
}
Write-Progress -Activity "Create branches in new repo" -Status "Done" -PercentComplete 100
git checkout master

Set-Location $workingDir
