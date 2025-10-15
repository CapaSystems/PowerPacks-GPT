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
  [string]$global:username='FIRMAx\capaosd'
  [string]$global:domain='FirmaX.Local'
  $global:key=@(36,28,23,200,38,85,248,24,77,10,105,80,236,168,17,0,86,209,5,97,168,52,40,149,39,57,107,168,9,229,95,121)
  [string]$global:encpass='76492d1116743f0423413b16050a5345MgB8ADEAegBOAGEANgA2AHoAUgBXADcqAFgAYgBnAHEAeABBAEYALwBxAEEAPQA9AHwAZQA0AGIAYQA3AGEAYQAxADkAOQBiAGUANwBmAGEAYwBkAGEAMgBhAGUAMQBjAGUANgBmADMAZQBhADkAYQA1ADEANwAyADYAMQA2ADgAZAA4AGUANQBhAGMAOQAxADUAYQBkADUAZgAwAGUAOQBjADEANwAwAGYAYgA0ADIAMwA='
  [string]$global:ou=''

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

  $domainInfo=Get-CimInstance -Namespace root\cimv2 -Class Win32_ComputerSystem
  if ($domainInfo.PartOfDomain -eq $false){

    #$transscriptFile=Join-Path $TempFolder 'transscript.txt'
    #Start-Transcript -Path $transscriptFile -Force -UseMinimalHeader

    Import-Module Microsoft.PowerShell.Management -UseWindowsPowerShell -NoClobber -WarningAction:SilentlyContinue
    $cred=New-Object System.Management.Automation.PsCredential $global:username,($global:encpass | ConvertTo-SecureString -key $key)
    if ($global:ou) {
      add-computer -domainname $global:domain -credential $cred -oupath $global:ou -PassThru}
    else {
      add-computer -domainname $global:domain -credential $cred -PassThru}


    #Stop-Transcript
    #$tempText=Get-Content -Path $transscriptFile -Raw
    #if ($tempText){$cs.Job_WriteLog($tempText)}

    $cs.Job_RebootWS("Rebooting")
    shutdown -r -t 10

  }
  else{
    $cs.Job_WriteLog("Computer is already joined to domain: $($domainInfo.Domain)")
  }
  Exit-PSScript $Error

}
catch {
  $line = $_.InvocationInfo.ScriptLineNumber
  $cs.Job_WriteLog("*****************","Something bad happend at line $($line): $($_.Exception.Message)")
  Exit-PSScript $_.Exception.HResult
}
