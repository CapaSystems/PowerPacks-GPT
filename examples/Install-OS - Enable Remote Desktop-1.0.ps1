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
  [bool]$global:DownloadPackage = $true

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

  $cs.Reg_SetInteger("HKLM","SYSTEM\CurrentControlSet\Control\Terminal Server","fDenyTSConnections",0)

  $transscriptFile=Join-Path $TempFolder 'transscript.txt'
  Start-Transcript -Path $transscriptFile -Force -UseMinimalHeader
  Set-NetFirewallRule -Group '@FirewallAPI.dll,-28752' -Enabled True -Profile Any #Remote Desktop
  Stop-Transcript
  $tempText=Get-Content -Path $transscriptFile -Raw
  if ($tempText){$cs.Job_WriteLog($tempText)}

  $domainInfo=Get-CimInstance -Namespace root\cimv2 -Class Win32_ComputerSystem
  if ($domainInfo.PartOfDomain -eq $true){
    $domain=$domainInfo.Domain
    $cs.Job_WriteLog("Client is member of a domain: $domain")
    try {Add-LocalGroupMember -SID "S-1-5-32-555" -Member "Domain Admins" -ErrorAction Stop}
    catch [Microsoft.PowerShell.Commands.MemberExistsException]{$cs.Job_WriteLog("Add-LocalGroupMember: user 'Domain Admins' already exists - continue.");$error.Clear()}
   
    try {Add-LocalGroupMember -SID "S-1-5-32-555" -Member "RDPUsers" -ErrorAction Stop}
    catch [Microsoft.PowerShell.Commands.MemberExistsException]{$cs.Job_WriteLog("Add-LocalGroupMember: user 'RDPUsers' already exists - continue.");$error.Clear()}
  }
  else{
    $cs.Job_WriteLog("Client is not member of a domain.")
  }

  $cs.Sys_Sleep(20)
  Exit-PSScript $Error

}
catch {
  $cs.Job_WriteLog("*****************","Something bad happend: " + $_.Exception.Message)
  Exit-PSScript $_.Exception.HResult
}
