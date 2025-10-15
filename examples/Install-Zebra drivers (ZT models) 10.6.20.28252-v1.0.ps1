[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$Packageroot,
  [Parameter(Mandatory=$true)]
  [string]$AppName,
  [Parameter(Mandatory=$true)]
  [string]$AppRelease,
  [Parameter(Mandatory=$true)]
  [string]$LogFile,
  [Parameter(Mandatory=$true)]
  [string]$TempFolder,
  [Parameter(Mandatory=$true)]
  [string]$DllPath,
  [Parameter(Mandatory=$false)]
  [Object]$InputObject=$null
)
###################
#### VARIABLES ####
###################
$global:DownloadPackage = $true # Set to $true if you want to download the kit folder from the server

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
  $cs.Log_SectionHeader("PreInstall",'o')
  if(!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:',1500)){Exit-PSScript 3333} # 1500 mb minimum disk space required


}

function Install {
  #MARK: Install
  $cs.Log_SectionHeader("Install",'o')

  $FilePath = Join-Path $global:Packageroot "kit" "zddriver-v1062028252-certified.exe"
  $arguments = "/s /v`"/qn /norestart`""
  $cs.Shell_Execute($FilePath, $arguments)
}

function PostInstall {
  #MARK: PostInstall
  $cs.Log_SectionHeader("PostInstall",'o')

}

##############
#### MAIN ####
##############
try {
  if ($global:InputObject){$pgkit=""}else{$pgkit="kit"}
  Import-Module (Join-Path $global:Packageroot $pgkit "PSlib.psm1") -ErrorAction stop
  $cs=Add-PSDll
  $cs.Job_Start("WS",$global:AppName,$global:AppRelease,$global:LogFile,"INSTALL")

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
  if ($global:DownloadPackage -and $global:InputObject){Start-PSDownloadPackage}
  Install
  PostInstall
  Exit-PSScript 0
}
catch {
    $line = $_.InvocationInfo.ScriptLineNumber
    $cs.Job_WriteLog("*****************","Something bad happend at line $($line): $($_.Exception.Message)")
    Exit-PSScript $_.Exception.HResult
}