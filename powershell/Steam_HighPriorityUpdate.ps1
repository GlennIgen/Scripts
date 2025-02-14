## Set Steam games to high priority in updates

$SearchPattern = '"AutoUpdateBehavior*"'
$ReplaceString = '"AutoUpdateBehavior"		"2"'
$steamSearchPath = "C:\Program Files (x86)\Steam\steamapps\"
$AppManifestFiles = Get-ChildItem -Path $steamSearchPath -Filter "appmanifest_*.acf"

foreach ($AppManifestFile in $AppManifestFiles){
Write-Host $AppManifestFile.BaseName
$FileContent = Get-Content -Path $AppManifestFile.FullName
$FileContent = $FileContent -replace "$SearchPattern.*",$ReplaceString
$FileContent
Set-Content -Path $AppManifestFile.FullName -Value $FileContent
}
