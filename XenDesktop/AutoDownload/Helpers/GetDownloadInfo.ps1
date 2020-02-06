$pages = @(
    "https://www.citrix.com/downloads/citrix-virtual-apps-and-desktops/product-software/citrix-virtual-apps-and-desktops-1912.html",
    'https://www.citrix.com/downloads/citrix-virtual-apps-and-desktops/product-software/citrix-virtual-apps-and-desktops-1909.html',
    'https://www.citrix.com/downloads/citrix-virtual-apps-and-desktops/product-software/citrix-virtual-apps-and-desktops-1906.html',
    'https://www.citrix.com/downloads/citrix-virtual-apps-and-desktops/product-software/citrix-virtual-apps-and-desktops-1903.html'
)
$ie = new-object -com internetexplorer.application
$ie.visible=$true
$final = @()
foreach ($page in $pages)
{
    $ie.navigate($page)
    while ($ie.Busy)
    {
      [System.Threading.Thread]::Sleep(10)
    }

    $dls = $ie.Document.documentElement.getElementsByClassName("ctx-dl-link ctx-photo")

    $links = $dls|Where-Object {($_.rel -like "*.iso") -or ($_.rel -like "*.exe") -and ($_.rel -notlike "*CitrixStoreFront*") }|select rel

    
    foreach($link in $links)
    {
        $link.rel -match '(?<=DLID=)(.*)(?=&)'
        $Matches[1]

        $final += [pscustomobject]@{
        "dlnumber" = $Matches[1]
        "filename" = $link.rel -split "/" | select -Last 1
        }
    }
}

$final