[CmdletBinding()]
Param(
  [Parameter(Mandatory = $true)]
  [string]$Packageroot,
  [Parameter(Mandatory = $true)]
  [string]$AppName,
  [Parameter(Mandatory = $true)]
  [string]$AppRelease,
  [Parameter(Mandatory = $true)]
  [string]$LogFile,
  [Parameter(Mandatory = $true)]
  [string]$TempFolder,
  [Parameter(Mandatory = $true)]
  [string]$DllPath,
  [Parameter(Mandatory = $false)]
  [Object]$InputObject = $null
)
###################
#### VARIABLES ####
###################
$global:DownloadPackage = $false # Set to $true if you want to download the kit folder from the server

# DO NOT CHANGE THESE VARIABLES
$global:Packageroot = $Packageroot
$global:AppName = $AppName
$global:AppRelease = $AppRelease
$global:LogFile = $LogFile
$global:TempFolder = $TempFolder
$global:DllPath = $DllPath
$global:InputObject = $InputObject

###################
#### FUNCTIONS ####
###################
function PreInstall {
  #MARK: PreInstall
  <#
    PreInstall runs before the package download and if $global:DownloadPackage is set to $true.
    Use this function to check for prerequisites, such as disk space, registry keys, or other requirements.
  #>
  $cs.Log_SectionHeader("PreInstall", 'o')

}

function Install {
  #MARK: Install
  $cs.Log_SectionHeader("Install", 'o')

  $Program = "C:\Program Files\TeamViewer\TeamViewer.exe"
  $Arguments = "assignment --id 0001CoABChDoK-sgjuYR8IjLCkAigFqBEigIACAAAgAJALZ4Pp4SX_z1EW_h7eyAF6gNY_k2H7SLEm3T_bYomJdAmPd2C6ldsUMfopU7nNFoYCsNhJFh-Evo1uLzR9kvbUsa2l2SGOnjSwdUNMEYIAEQo6j-xAo= --offline --retries=3 --timeout=120"

  if ($cs.File_ExistFile($Program)) {
    $cs.Service_Start('TeamViewer')
    Start-Sleep -Seconds 5 # Give the service some time to start
    $RetVal = $cs.Shell_Execute($Program, $Arguments)
    if ($RetVal -ne 0) {
      Exit-PSScript -exitcode $RetVal -exitmessage "Failed to assign TeamViewer to the account, error code: $RetVal"
    }

  } else {
    Exit-PSScript -exitcode 3326 -exitmessage "TeamViewer is not installed on this machine, retrying later."
  }

}

function PostInstall {
  #MARK: PostInstall
  $cs.Log_SectionHeader("PostInstall", 'o')

}

##############
#### MAIN ####
##############
try {
  if ($global:InputObject) { $pgkit = "" }else { $pgkit = "kit" }
  Import-Module (Join-Path $global:Packageroot $pgkit "PSlib.psm1") -ErrorAction stop
  $cs = Add-PSDll
  $cs.Job_Start("WS", $global:AppName, $global:AppRelease, $global:LogFile, "INSTALL")

  $cs.Job_WriteLog("[Init]: Starting package: '" + $global:AppName + "' Release: '" + $global:AppRelease + "'")
  $cs.Job_WriteLog("[Init]: `$PackageRoot:` '" + $global:Packageroot + "'")
  $cs.Job_WriteLog("[Init]: `$AppName:` '" + $global:AppName + "'")
  $cs.Job_WriteLog("[Init]: `$AppRelease:` '" + $global:AppRelease + "'")
  $cs.Job_WriteLog("[Init]: `$LogFile:` '" + $global:LogFile + "'")
  $cs.Job_WriteLog("[Init]: `$global:AppLogFolder:` '" + $global:AppLogFolder + "'")
  $cs.Job_WriteLog("[Init]: `$TempFolder:` '" + $global:TempFolder + "'")
  $cs.Job_WriteLog("[Init]: `$DllPath:` '" + $global:DllPath + "'")
  $cs.Job_WriteLog("[Init]: `$global:DownloadPackage`: '" + $global:DownloadPackage + "'")
  $cs.Job_WriteLog("[Init]: `$global:PSLibVersion`: '" + $global:PSLibVersion + "'")
  Initialize-Variables

  PreInstall
  if ($global:DownloadPackage -and $global:InputObject) { Start-PSDownloadPackage }
  Install
  PostInstall
  Exit-PSScript 0
}
catch {
  $line = $_.InvocationInfo.ScriptLineNumber
  $cs.Job_WriteLog("*****************", "Something bad happend at line $($line): $($_.Exception.Message)")
  Exit-PSScript $_.Exception.HResult
}