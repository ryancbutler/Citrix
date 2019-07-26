#Rough ShareFile functions to aide migration to new Storage Zone.
#Ryan Butler 8-29-16
#version 0.5


#Before running
#1. Grab PowerShell SDK and install https://github.com/citrix/ShareFile-PowerShell/releases
#2. Create Sf authentication file create with 'New-SfClient -Name "C:\Users\Username\Documents\MySubdomain.sfps"

Add-PSSnapin Sharefile

#######################Start Functions###################
function get-zoneid ($zonename) {
	#gets id of zone
	$zone = Send-SFRequest –Client $sfClient –Method GET -Entity Zones | Where-Object { $_.Name -like $zonename }
	return $zone.id
}

function get-sharedfolders {
	#gets all shared folders
	$folders = Send-SFRequest –Client $sfClient –Method GET -Entity Items -Id "allshared" -Expand "Children"
	$results = @()
	foreach ($child in $folders.Children)
	{
		$folder = Send-SFRequest –Client $sfClient –Method GET -Entity Items -Id $child.id -Expand "Zone,Owner"

		if (($folder.Zone.Name -notlike $newsfname) -and ($folder.Name -notlike "Customizations"))
		{
			$temp = New-Object PSObject -Property @{
				Name = $folder.Name
				FolderID = $folder.id
				Zone = $folder.Zone.Name
				ZoneID = $folder.Zone.id
				Owner = $folder.Owner.FullName
				SizeMB = [math]::Round(($folder.FileSizeBytes) / 1MB,2)
			}

			$results += $temp
		}
	}
	return $results
}

function get-migratedsharedfolders {
	#gets migrated shared folders for reporting
	$folders = Send-SFRequest –Client $sfClient –Method GET -Entity Items -Id "allshared" -Expand "Children"
	$results = @()
	foreach ($child in $folders.Children)
	{
		$folder = Send-SFRequest –Client $sfClient –Method GET -Entity Items -Id $child.id -Expand "Zone,Owner"

		if (($folder.Zone.Name -like $newsfname))
		{
			$temp = New-Object PSObject -Property @{
				Name = $folder.Name
				FolderID = $folder.id
				Zone = $folder.Zone.Name
				ZoneID = $folder.Zone.id
				Owner = $folder.Owner.FullName
				SizeMB = [math]::Round(($folder.FileSizeBytes) / 1MB,2)
			}

			$results += $temp
		}
	}
	return $results
}

function get-migratedsfusers {
	#gets users migrated
	$users = Send-SFRequest –Client $sfClient –Method GET -Entity Accounts/Employees -select "Id,Email"
	$results = @()
	foreach ($user in $users)
	{
		$found = Send-SFRequest –Client $sfClient –Method GET -Entity Users -Id $user.id -Expand "DefaultZone,DiskSpace,HomeFolder"
		if ($found.DefaultZone.Name -like $newsfname)
		{
			$temp = New-Object PSObject -Property @{
				Name = $found.FullNameShort
				UserID = $found.id
				Zone = $found.DefaultZone.Name
				ZoneID = $found.DefaultZone.id
				DiskSpaceMB = [math]::Round(($found.HomeFolder.FileSizeBytes) / 1MB,2)
			}

			$results += $temp
		}
	}
	return $results
}


function get-sfusers {
	#gets users and zone information
	$users = Send-SFRequest –Client $sfClient –Method GET -Entity Accounts/Employees -select "Id,Email"
	$results = @()
	foreach ($user in $users)
	{
		$found = Send-SFRequest –Client $sfClient –Method GET -Entity Users -Id $user.id -Expand "DefaultZone,DiskSpace,HomeFolder"
		if ($found.DefaultZone.Name -notlike $newsfname)
		{
			$temp = New-Object PSObject -Property @{
				Name = $found.FullNameShort
				UserID = $found.id
				Zone = $found.DefaultZone.Name
				ZoneID = $found.DefaultZone.id
				DiskSpaceMB = [math]::Round(($found.HomeFolder.FileSizeBytes) / 1MB,2)
			}

			$results += $temp
		}
	}
	return $results
}

function move-sffolder ($folderid,$newsf) {
	#moves user to different zone
	$newzone = '{"Zone": { "Id":"' + $newsf + '" }}'
	Write-Host $newzone
	Send-SFRequest –Client $sfClient –Method PATCH -Entity Items -Id $folderid -Bodytext $newzone
}

function move-sfuser ($userid,$newsf) {
	#moves shared folder to different zone
	$newzone = '{"DefaultZone": { "Id":"' + $newsf + '" }}'
	Write-Host $newzone
	Send-SFRequest –Client $sfClient –Method PATCH -Entity Users -Id $userid -Bodytext $newzone
}
#######################End Functions###################

###Variables

#see Github for additonal usage https://github.com/citrix/ShareFile-PowerShell/wiki/Getting-Started
$sfClient = Get-SfClient –Name "C:\Users\JoeUser\Documents\Sharefile.sfps" #create with New-SfClient -Name "C:\Users\Username\Documents\MySubdomain.sfps"

#zone id
$newsf = "changethistoid" #Zone ID of new zone. (get-zoneid -zonename $oldsfname)

#path for reporting
$csvpath = "C:\Users\JoeUser\Documents\CSV\"

#Zone names
$newsfname = "NEWzonename" #zone to migrate TO
$oldsfname = "OLDzonename" #zone to migrate FROM


###Function usage

##Zone ID of new zone.
#get-zoneid -zonename $oldsfname

##gets current status of non-migrated Sharefile folders and users
#get-sfusers|Export-csv -NoClobber -NoTypeInformation ($csvpath + "NonMigratedUsers.csv")
#get-sharedfolders|Export-csv -NoClobber -NoTypeInformation ($csvpath + "NonMigratedFolders.csv")

##gets current status of migrated Sharefile folders and users
#get-migratedsfusers|Export-csv -NoClobber -NoTypeInformation ($csvpath + "MigratedUsers.csv")
#get-migratedsharedfolders|Export-csv -NoClobber -NoTypeInformation ($csvpath + "MigratedFolders.csv")

##move to zone usage
#move-sfuser -folderid "345tonsf984iowxcvbi" -newsf $newsf
#move-sffolder -folderid "sdgjk34t2423dbg3" -newsf $newsf
