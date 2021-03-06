# extract latest version and release

Invoke-WebRequest -Uri "https://biodiversityinformatics.amnh.org/open_source/dotdotgoose/index.html" -OutFile "DDG.html"
Invoke-WebRequest -Uri "https://biodiversityinformatics.amnh.org/open_source/dotdotgoose/index.html" -OutFile "release.html"
$Source = Get-Content -path DDG.html
$text = Get-Content -path release.html
$Source -match '<ul class="local-list"> <li>[0-9]{4}-[0-9]{2}-[0-9]{2} - version ([0-9]+(\.[0-9]+)+) '
$tag = $matches[1]

# $tag = "1.5.3"

$pattern = '<ul class="local-list"> <li>(.*?)</li> </ul> </li>'
$result = [regex]::match($text, $pattern).Groups[1].Value

$release = $result -replace ' <ul class="local-list"> <li>', "`n* "
$release = $release -replace '</li> <li>', "`n* "
$release = $release -replace '\(Enhancement\)', '**Enhancement** -'
$release = $release -replace '\(Bug Fix\)', '**Bug Fix** -'
$release = $release -replace '\(Bug Fixed\)', '**Bug Fixed** -'
$release = -join($release, "`n`n**Full changelog:** [https://biodiversityinformatics.amnh.org/open_source/dotdotgoose/](https://biodiversityinformatics.amnh.org/open_source/dotdotgoose/) ");

# write new version and release
$file = "./dotdotgoose/dotdotgoose.nuspec"
$xml = New-Object XML
$xml.Load($file)
$xml.package.metadata.version = $tag
$xml.package.metadata.releaseNotes = "$release"# https://biodiversityinformatics.amnh.org/open_source/dotdotgoose/ " # $release
$xml.Save($file)

# download installer and LICENSE
Invoke-WebRequest -Uri "https://biodiversityinformatics.amnh.org/open_source/dotdotgoose/ddg.php?op=download-win" -OutFile "dotdotgoose.zip"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/persts/DotDotGoose/master/LICENSE" -OutFile "./dotdotgoose/legal/LICENSE.txt"

Expand-Archive dotdotgoose.zip -DestinationPath .\dotdotgoose\tools\ -Force

Remove-Item dotdotgoose.zip

# calculation of checksum
$TABLE = Get-FileHash "./dotdotgoose/tools/DotDotGoose.exe" -Algorithm SHA256
$SHA = $TABLE.Hash

# writing of VERIFICATION.txt
$content = "VERIFICATION
Verification is intended to assist the Chocolatey moderators and community
in verifying that this package's contents are trustworthy.

The installer have been downloaded from their official website listed on <https://biodiversityinformatics.amnh.org/open_source/dotdotgoose/ddg.php?op=download-win>
and can be verified like this:

1. Download the following installer:
  Version $tag : <https://biodiversityinformatics.amnh.org/open_source/dotdotgoose/ddg.php?op=download-win>
2. You can use one of the following methods to obtain the checksum
  - Use powershell function 'Get-Filehash'
  - Use chocolatey utility 'checksum.exe'

  checksum type: SHA256
  checksum: $SHA

File 'LICENSE.txt' is obtained from <https://raw.githubusercontent.com/persts/DotDotGoose/master/LICENSE> " | out-file -filepath ./dotdotgoose/legal/VERIFICATION.txt

# packaging
choco pack ./dotdotgoose/dotdotgoose.nuspec --outputdirectory .\dotdotgoose

If ($LastExitCode -eq 0) {
	choco push ./dotdotgoose/dotdotgoose.$tag.nupkg --source https://push.chocolatey.org/
} else {
	echo "Error in introduction - Exit code: $LastExitCode "
}

If ($LastExitCode -eq 0) {

# git and create tag
git config --local user.email "a-d-r-i@outlook.fr"
git config --local user.name "A-d-r-i"
git add .
git commit -m "[Bot] Update files - dotdotgoose" --allow-empty
git tag -a dotdotgoose-v$tag -m "DotDotGoose - version $tag"
git push -f && git push --tags

# create release
Install-Module -Name New-GitHubRelease -Force
Import-Module -Name New-GitHubRelease
$newGitHubReleaseParameters = @{
GitHubUsername = "A-d-r-i"
GitHubRepositoryName = "update_choco_package"
GitHubAccessToken = "$env:ACTIONS_TOKEN"
ReleaseName = "DotDotGoose v$tag"
TagName = "dotdotgoose-v$tag"
ReleaseNotes = "$release"
AssetFilePaths = ".\dotdotgoose\dotdotgoose.$tag.nupkg"
IsPreRelease = $false
IsDraft = $false
}
$resultrelease = New-GitHubRelease @newGitHubReleaseParameters

# post tweet
$twitter = (Select-String -Path config.txt -Pattern "twitter=(.*)").Matches.Groups[1].Value
if ( $twitter -eq "y" )
{
Install-Module PSTwitterAPI -Force
Import-Module PSTwitterAPI
$OAuthSettings = @{
ApiKey = "$env:PST_KEY"
ApiSecret = "$env:PST_SECRET"
AccessToken = "$env:PST_TOKEN"
AccessTokenSecret = "$env:PST_TOKEN_SECRET"
}
Set-TwitterOAuthSettings @OAuthSettings
Send-TwitterStatuses_Update -status "DotDotGoose v$tag push now on @chocolateynuget! 
Link: https://community.chocolatey.org/packages/dotdotgoose/$tag
#dotdotgoose #release #opensource
"
}

# send telegram notification
Function Send-Telegram {
Param([Parameter(Mandatory=$true)][String]$Message)
$Telegramtoken = "$env:TELEGRAM"
$Telegramchatid = "$env:CHAT_ID"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$($Telegramtoken)/sendMessage?chat_id=$($Telegramchatid)&text=$($Message)"}

Send-Telegram -Message "[UCP] New update of DotDotGoose : $tag"

} else {
	echo "Error in choco push - Exit code: $LastExitCode "
}
