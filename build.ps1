$sourceBicep = "deploy.bicep"
$targetFile = "_generated/deploy.json"
$readmeFile = "readme.md"
$githubRepo = "ScottHolden/AzureGym"

if ((Split-Path -Path $PWD) -ne $PSScriptRoot) {
    Write-Error "You must run this from a project sub-directory. Eg: ../build.ps1"
    return;
}
if (-not (Test-Path $sourceBicep)) {
    Write-Error "Can't find $sourceBicep"
    return;
}

Write-Host "Checking for Bicep updates..."
& az bicep upgrade
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error whilst upgrading Bicep, is the Azure CLI & Bicep installed?" -ErrorAction Stop
}

New-Item -ItemType Directory -Force -Path (Split-Path -Path $targetFile) | Out-Null

Write-Host "Building $sourceBicep in $(Split-Path -Path $PWD -Leaf)"
& az bicep build -f "$sourceBicep" --outfile "$targetFile"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Unable to build $sourceBicep!" -ErrorAction Stop
}

if (-not (Test-Path $readmeFile)) {
    Write-Host "Dropping new $readmeFile"

    $folderName = $(Split-Path -Path $PWD -Leaf)
    $githubUrl = "https://raw.githubusercontent.com/$($githubRepo)/main/$($folderName)/$($targetFile)"
    $deployUrl = "https://portal.azure.com/#create/Microsoft.Template/uri/$([Uri]::EscapeDataString($githubUrl))"

    Set-Content -Path $readmeFile -Value @"
# $folderName

[![Deploy To Azure](https://aka.ms/deploytoazurebutton)]($deployUrl)

## Description:
Todo: Add this
"@
}