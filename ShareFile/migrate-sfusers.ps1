#Rough ShareFile functions to aide migration to new Storage Zone.
#Ryan Butler 8-29-16
#version 0.5


#Before running
#1. Grab PowerShell SDK and install https://github.com/citrix/ShareFile-PowerShell/releases
#2. Create Sf authentication file create with 'New-SfClient -Name "C:\Users\Username\Documents\MySubdomain.sfps"

Add-PSSnapin Sharefile

#######################Start Functions###################
function get-zoneid ($zonename){
    #gets id of zone
    $zone = Send-SFRequest –Client $sfClient –Method GET -Entity Zones|where{$_.name -like $zonename}
    return $zone.id
}

function get-sharedfolders {
    #gets all shared folders
    $folders = Send-SFRequest –Client $sfClient –Method GET -Entity Items -id "allshared" -Expand "Children"
    $results = @()
        foreach ($child in $folders.Children)
        {
        $folder = Send-SFRequest –Client $sfClient –Method GET -Entity Items -id $child.Id -Expand "Zone,Owner"

            if (($folder.Zone.Name -notlike $newsfname) -AND ($folder.Name -notlike "Customizations"))
            {
            $temp = new-object PSObject -Property @{
                Name = $folder.Name
                FolderID = $folder.Id
                Zone = $folder.Zone.Name
                ZoneID = $folder.Zone.ID
                Owner = $folder.Owner.FullName
                SizeMB = [MATH]::Round(($folder.FileSizeBytes)/1MB,2)
            }

            $results += $temp
            }
        }
    return $results
}

function get-migratedsharedfolders {
    #gets migrated shared folders for reporting
    $folders = Send-SFRequest –Client $sfClient –Method GET -Entity Items -id "allshared" -Expand "Children"
    $results = @()
        foreach ($child in $folders.Children)
        {
        $folder = Send-SFRequest –Client $sfClient –Method GET -Entity Items -id  $child.Id -Expand "Zone,Owner"

            if (($folder.Zone.Name -like $newsfname))
            {
            $temp = new-object PSObject -Property @{
                Name = $folder.Name
                FolderID = $folder.Id
                Zone = $folder.Zone.Name
                ZoneID = $folder.Zone.ID
                Owner = $folder.Owner.FullName
                SizeMB = [MATH]::Round(($folder.FileSizeBytes)/1MB,2)
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
            $temp = new-object PSObject -Property @{
                Name = $found.FullNameShort
                UserID = $found.Id
                Zone = $found.DefaultZone.Name
                ZoneID = $found.DefaultZone.ID
                DiskSpaceMB = [MATH]::Round(($found.HomeFolder.FileSizeBytes)/1MB,2)
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
            $temp = new-object PSObject -Property @{
                Name = $found.FullNameShort
                UserID = $found.Id
                Zone = $found.DefaultZone.Name
                ZoneID = $found.DefaultZone.ID
                DiskSpaceMB = [MATH]::Round(($found.HomeFolder.FileSizeBytes)/1MB,2)
            }

            $results += $temp
            }
        }
    return $results
}

function move-sffolder ($folderid, $newsf) {
    #moves user to different zone
    $newzone = '{"Zone": { "Id":"' +  $newsf + '" }}'
    write-host $newzone
    Send-SFRequest –Client $sfClient –Method PATCH -Entity Items -id $folderid -Bodytext $newzone
}

function move-sfuser ($userid, $newsf) {
    #moves shared folder to different zone
    $newzone = '{"DefaultZone": { "Id":"' +  $newsf + '" }}'
    write-host $newzone
    Send-SFRequest –Client $sfClient –Method PATCH -Entity Users -id $userid -Bodytext $newzone
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
#get-sfusers|Export-csv -NoClobber -NoTypeInformation ($csvpath + "SFUSERS.csv")
#get-sharedfolders|Export-csv -NoClobber -NoTypeInformation ($csvpath + "SFFOLDERS.csv")

##gets current status of migrated Sharefile folders and users
#get-migratedsfusers|Export-csv -NoClobber -NoTypeInformation ($csvpath + "SFmigUSERS.csv")
#get-migratedsharedfolders|Export-csv -NoClobber -NoTypeInformation ($csvpath + "SFmigFOLDERS.csv")

##move to zone usage
#move-sfuser -folderid "345tonsf984iowxcvbi" -newsf $newsf
#move-sffolder -folderid "sdgjk34t2423dbg3" -newsf $newsf
