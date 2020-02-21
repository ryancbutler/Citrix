#Example script to download multiple VDA and ISO versions from Citrix.com
#Ryan Butler 2/6/2020

#Speeds up the download (Thanks James Kindon)
$ProgressPreference = "SilentlyContinue"

#Folder dialog
#https://stackoverflow.com/questions/25690038/how-do-i-properly-use-the-folderbrowserdialog-in-powershell
Function Get-Folder($initialDirectory)

{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a folder"
    $foldername.rootfolder = "MyComputer"

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }
    return ($folder + "\") 
}

#Prompt for folder path
$path = Get-Folder

#Import Download Function
. ./Helpers/Get-CTXBinary.ps1

$creds = Get-Credential -Message "Citrix Credentials"
$CitrixUserName = $creds.UserName
$CitrixPassword = $creds.GetNetworkCredential().Password

#Imports CSV with download information
$downloads = import-csv -Path ".\Helpers\Downloads.csv" -Delimiter ","

#Use CTRL to select multiple
$dls = $downloads | Out-GridView -PassThru -Title "Select VDA or ISO to download.  CTRL to select multiple"

#Processes each download
foreach ($dl in $dls) {
    write-host "Downloading $($dl.filename)..."
    Get-CTXBinary -DLNUMBER $dl.dlnumber -DLEXE $dl.filename -CitrixUserName $CitrixUserName -CitrixPassword $CitrixPassword -DLPATH $path
}
