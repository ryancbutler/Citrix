#Clears all UPM default exclusion path contents
#Maybe you forgot to remove the = from the UPM GPO path exclusions?
#Ryan Butler 3-22-16

Clear-Host
#Default excludes https://docs.citrix.com/en-us/profile-management/5/upm-tuning-den/upm-include-exclude-defaults-den.html along with some google
$excludes = "AppData\LocalLow\",`
 	"AppData\Local\Microsoft\Windows\Temporary Internet Files\",`
 	"AppData\Local\Microsoft\Windows\INetCache\",`
 	"AppData\Local\Microsoft\Windows\Burn\",`
 	"AppData\Local\Microsoft\Windows\CD Burning\",`
 	"AppData\Local\Microsoft\Windows Live\",`
 	"AppData\Local\Microsoft\Windows Live Contacts\",`
 	"AppData\Local\Microsoft\Terminal Server Client\",`
 	"AppData\Local\Microsoft\Messenger\",`
 	"AppData\Local\Microsoft\OneNote\",`
 	"AppData\Local\Microsoft\Outlook\",`
 	"AppData\Local\Windows Live\",`
 	"AppData\Local\Sun\",`
 	"AppData\Local\Temp\",`
 	"AppData\Local\Google\Chrome\User Data\Default\Media Cache\",`
 	"AppData\Local\Google\Chrome\User Data\Default\JumpListIcons\",`
 	"AppData\Local\Google\Chrome\User Data\Default\JumpListIconsOld\",`
 	"AppData\Roaming\Sun\Java\Deployment\cache\",`
 	"AppData\Roaming\Sun\Java\Deployment\log\",`
 	"AppData\Roaming\Sun\Java\Deployment\tmp\",`
 	"AppData\Local\Google\Chrome\User Data\Default\Cache\",`
 	"AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images\"


#profile store.  Please note trailing \
$profpath = "D:\User Data\ctxprofiles\"


##################Script

#Gets all profile folders
$profiles = Get-ChildItem -Path $profpath | Where-Object { $_.PSIsContainer -eq $true }

foreach ($profile in $profiles)
{

	#checks each folder and removes contents if found
	foreach ($exclude in $excludes)
	{

		$checkpath = $profile.FullName + "\UPM_Profile\" + $exclude

		Write-Host $checkpath

		if (Test-Path $checkpath)
		{
			Write-Host "Found path and removing contents" -ForegroundColor Green
			Remove-Item -Path ($checkpath + "*") -Recurse -Force
		}
		else
		{
			Write-Host "Path not found" -ForegroundColor Yellow
		}
	}
}
