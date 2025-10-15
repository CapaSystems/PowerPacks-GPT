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

try {
  ### Download package kit
  [bool]$global:DownloadPackage = $false

  ##############################################
  #load core PS lib - don't mess with this!
  if ($InputObject){$pgkit=""}else{$pgkit="kit"}
  Import-Module (Join-Path $Packageroot $pgkit "PSlib.psm1") -ErrorAction stop
  #load Library dll
  $cs=Add-PSDll
  ##############################################

  #Begin
  $cs.Job_Start("WS",$AppName,$AppRelease,$LogFile,"INSTALL")
  $cs.Job_WriteLog("[Init]: Starting package: '" + $AppName + "' Release: '" + $AppRelease + "'")
  if(!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:',100)){Exit-PSScript 3333}
  if ($global:DownloadPackage -and $InputObject){Start-PSDownloadPackage}
  
  $cs.Job_WriteLog("[Init]: `$PackageRoot:` '" + $Packageroot + "'")
  $cs.Job_WriteLog("[Init]: `$AppName:` '" + $AppName + "'")
  $cs.Job_WriteLog("[Init]: `$AppRelease:` '" + $AppRelease + "'")
  $cs.Job_WriteLog("[Init]: `$LogFile:` '" + $LogFile + "'")
  $cs.Job_WriteLog("[Init]: `$TempFolder:` '" + $TempFolder + "'")
  $cs.Job_WriteLog("[Init]: `$DllPath:` '" + $DllPath + "'")
  $cs.Job_WriteLog("[Init]: `$global:DownloadPackage`: '" + $global:DownloadPackage + "'")
  $cs.Job_WriteLog("[Init]: `$global:PSLibVersion`: '" + $global:PSLibVersion + "'")

  <# $transscriptFile=Join-Path $TempFolder 'transscript.txt'
  Start-Transcript -Path $transscriptFile -Force -UseMinimalHeader

  $cs.Job_WriteLog("PSLib: $pslibversion")
  $cs.Job_RebootWS("Rebooting")

  Stop-Transcript
  $tempText=Get-Content -Path $transscriptFile -Raw
  if ($tempText){$cs.Job_WriteLog($tempText)}
 #>
  
  #$sb={start-sleep 5; Restart-Computer -force}
  #Start-ThreadJob -ScriptBlock $sb
  
  #Restart-Computer -Timeout 10 -Wait -Force

  shutdown -r -t 10

  Exit-PSScript $Error

}
catch {
  $line = $_.InvocationInfo.ScriptLineNumber
  $cs.Job_WriteLog("*****************","Something bad happend at line $($line): $($_.Exception.Message)")
  Exit-PSScript $_.Exception.HResult
}
