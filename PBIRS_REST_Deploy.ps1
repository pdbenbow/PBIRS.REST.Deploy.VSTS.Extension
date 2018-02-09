<#param(
	[Parameter(Mandatory=$True, Position=1)][string]$ReportFiles,
	[Parameter(Mandatory=$True)][string]$ReportUploadRootPath,
	[string]$IncludeDataSource,
	[string]$DataSourceLocalPath,
	[string]$DataSourceRootPath,
	[string]$ConnectionString,
	[string]$UpdateDataSource,

	[string]$IncludeDataSet,
	[string]$DataSetLocalPath,
	[string]$DataSetRootPath,

	[string]$IncludeResources,
	[string]$ResourceRootLocalPath,
	[string]$ResourcePatterns,
	[string]$ResourceRootPath,

	[Parameter(Mandatory=$True)][string]$WebserviceUrl,
	[string]$WsUsername,
	[string]$WsPassword,
	[string]$UseVerbose,
	[string]$OverrideExisting,
	[string]$AddResourceExtension
)#>

$ReportFiles = 'C:\reports\'
$ReportUploadRootPath = '/'
$UseVerbose = $true;
$WebserviceUrl = "http://w18031/PBIReports"
#$WebserviceUrl = "https://bi3.davidson.edu/PBIReports"

function Verbose-WriteLine {
	[cmdletbinding()]
	param(
		[Parameter(Position=1)]$text
	)
	if($UseVerbose -and $UseVerbose -eq $true) {
		Write-Host "[VERBOSE] >> $text" -;
	}
}

# Check to see if RSTools are already installed; if not, download them
if (Get-Module -ListAvailable -Name ReportingServicesTools) {
	Write-Host "Reporting Services Tools already installed`n"
} else {
	Invoke-Expression (Invoke-WebRequest https://raw.githubusercontent.com/Microsoft/ReportingServicesTools/master/Install.ps1)
}

# Check if the Webservice has a password and replace it with stars
$hasWsPassword = "N/A";
if([System.String]::IsNullOrWhiteSpace($WsPassword) -eq $false) { 
	$hasWsPassword = "********";
}

# Correcting remote server path
if([string]::IsNullOrWhiteSpace($ReportUploadRootPath) -eq $false -and $ReportUploadRootPath.Length-1 -le -1 -and $ReportUploadRootPath.LastIndexOf("/") -eq $ReportUploadRootPath.Length-1) {
	$ReportUploadRootPath = $ReportUploadRootPath.Substring(0,$ReportUploadRootPath.Length-1);
}
if([string]::IsNullOrWhiteSpace($DataSetRootPath) -eq $false -and $DataSetRootPath.Length-1 -le -1 -and $DataSetRootPath.LastIndexOf("/") -eq $DataSetRootPath.Length-1) {
	Verbose-WriteLine "Correcting DataSetRootPath";
	$DataSetRootPath = $DataSetRootPath.Substring(0,$DataSetRootPath.Length-1);
}
if([string]::IsNullOrWhiteSpace($ResourceRootPath) -eq $false -and $ResourceRootPath.Length-1 -le -1 -and $ResourceRootPath.LastIndexOf("/") -eq $ResourceRootPath.Length-1) {
	Verbose-WriteLine "Correcting ResourceRootPath";
	$ResourceRootPath = $ResourceRootPath.Substring(0,$ResourceRootPath.Length-1);
}

##########################################################
#		             Uploading reports                   #
##########################################################

$files = @(Get-ChildItem $ReportFiles);
$fileCount = $files.Length;

Write-Host "Found $fileCount item in $ReportFiles`nUploading items...`n"

$files | ForEach-Object{ 
	$reportName = [System.IO.Path]::GetFileName($_.Name); # Get the name of the report
	$reportPath = [System.IO.Path]::GetFullPath($_.FullName); # Get the full path
	$bytes = [System.IO.File]::ReadAllBytes($_.FullName); #Get The path to upload
	$byteLength = $bytes.Length; #for verbose logging 
	Write-Host "Uploading $reportName to $WebserviceUrl...";
	try{
		Write-RsRestCatalogItem -Path $reportPath -ReportPortalUri $WebserviceUrl -RsFolder $ReportUploadRootPath -Overwrite
		Write-Host "$reportName successfully uploaded"
		Verbose-WriteLine "Uploading $reportName with filesize $byteLength bytes"; 

		if($warnings -ne $null) {
			Write-Warning "One or more warnings occured during upload:";
			$warningSb = New-Object System.Text.StringBuilder;
			$warnings | ForEach-Object{
				$txtWarning = $_.Message;
				$warningSb.AppendLine("`t- {$txtWarning}");
			}
			Write-Warning $warningSb.ToString();
		}

		} catch [System.Exception] {
		Write-Error $_.Exception.Message;
		exit -1; # Terminate script
	}
}

Write-Host "`nSuccessfully uploaded $fileCount items`n"