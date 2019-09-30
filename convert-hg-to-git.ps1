$ErrorActionPreference = "Stop"
if ($args.Length -ne 2) {
    Write-Output "Specify input and output directory names as arguments"
    exit 1
}

$inputRepo = Resolve-Path "$(Get-Location)\$($args[0])"
New-Item -path $args[1] -type directory
$outputRepo = Resolve-Path "$(Get-Location)\$($args[1])"
Read-Host "Converting from $($inputRepo) to $($outputRepo), press enter to continue"

# create bare output repository
Set-Location $outputRepo
git init --bare .git

# get metadata from input repo
Set-Location $inputRepo
[string[]]$heads = hg heads -T '{node} {branch}\n'
[string[]]$hashes = hg log -T '{node}\n'

# add tags for every commit so git history can be searched by hg hash
for ($i = 0; $i -lt $hashes.Length; $i++) {
    $hash = $hashes[$i]
    $percent = $i / ($hashes.Length) * 100
    Write-Progress -Activity "Adding tags for each revision..." -Status $hash -PercentComplete $percent
    hg tag -r $hash "hg-$($hash)"
    if (!$stripHash) {
        $stripHash = (hg log -T '{node}\n')[0]
    }
}

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
    git branch $branch "hg-$($hash)"
}
Write-Progress -Activity "Create branches in new repo" -Status "Done" -PercentComplete 100
git checkout master
