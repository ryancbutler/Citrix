#Grabs CSVs and places into Excel workbook
#Ryan Butler 9-21-16
#Version 1.0

#Path for CSVs
$csvpath = "C:\Users\JoeUser\Documents\CSV\"
#Grabs the current date
$date = Get-Date -Format MM-dd

#Excel file name
$finalxls = "ShareFileState-" + $date + ".xlsx"

#Grabs all CSVs from above path
$csvs = Get-ChildItem -Path $csvpath -Filter *.csv
$y = $csvs.Count
Write-Host “Detected the following CSV files: ($y)”

foreach ($csv in $csvs)
{
	Write-Host ” “ $csv.Name
}
$outputfilename = $csvpath + $finalxls

#opens Excel
$excelapp = New-Object -ComObject Excel.Application
$excelapp.DisplayAlerts = $false #no alerts
$excelapp.visible = $false #hides app running
#Creates new workbook
$xlsx = $excelapp.Workbooks.Add()


$sheet = 1

foreach ($csv in $csvs)
{
	Write-Host $csv.Name

	#Adds worksheet
	$worksheet = $xlsx.Worksheets.Item($sheet)
	$worksheet.Name = $csv.BaseName

	#Opens CSV and copies to new worksheet
	$tempcsv = $excelapp.Workbooks.Open($csv.FullName)
	$tempsheet = $tempcsv.Worksheets.Item(1)
	$tempSheet.UsedRange.Copy() | Out-Null
	$worksheet.Paste()
	$tempcsv.close()

	#Select all used cells
	$range = $worksheet.UsedRange
	#Converts to table to make pretty
	$table = "table" + $sheet
	$worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange,$excelapp.ActiveCell.CurrentRegion,$null,[Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes).Name = $table
	$worksheet.ListObjects.Item($table).TableStyle = "TableStyleMedium2"

	#Autofit the columns
	$range.EntireColumn.Autofit() | Out-Null

	#counter
	$sheet++
}

#close Excel
$xlsx.SaveAs($outputfilename)
$xlsx.close()
$excelapp.quit()
