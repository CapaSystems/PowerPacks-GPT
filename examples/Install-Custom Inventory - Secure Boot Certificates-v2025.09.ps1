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
$Global:RegKey = 'SOFTWARE\CapaCustom\SecureBootCertificates'

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
function Get-SecureBootCertificates {
  [CmdletBinding()]
  param(
    [string[]]$Variables = @('PK', 'KEK', 'db')
  )

  # EFI_CERT_X509_GUID (X.509 cert) i ESL
  $EFI_CERT_X509_GUID_BYTES = 0xA1, 0x59, 0xC0, 0xA5, 0xE4, 0x94, 0xA7, 0x4A, 0x87, 0xB5, 0xAB, 0x15, 0x5C, 0x2B, 0xF0, 0x72

  foreach ($varName in $Variables) {
    try {
      $var = Get-SecureBootUEFI -Name $varName -ErrorAction Stop
      $bytes = $var.Bytes
      # Indeks holdes som Int32
      [int]$i = 0
      $len = $bytes.Length

      while ($i -lt $len) {
        # Header: EFI_SIGNATURE_LIST
        if ($i + 28 -gt $len) { break }  # 16 + 4 + 4 + 4

        $sigType = $bytes[$i..($i + 15)]; $i += 16
        [uint32]$listSize = [BitConverter]::ToUInt32($bytes, $i); $i += 4
        [uint32]$hdrSize = [BitConverter]::ToUInt32($bytes, $i); $i += 4
        [uint32]$sigSize = [BitConverter]::ToUInt32($bytes, $i); $i += 4

        # Minimum størrelse (header) er 28 bytes
        if ($listSize -lt 28) { break }

        # Beregn grænser for denne liste
        [int]$listStart = $i
        [int]$listEnd = $listStart + ([int]$listSize - 28)

        # Bounds-check på hele listen
        if ($listEnd -gt $len) {
          # Invalide længder -> stop for at undgå overflow
          break
        }

        # Skip evt. SignatureHeader
        if ($hdrSize -gt 0) {
          if ($i + [int]$hdrSize -gt $len) { break }
          $i += [int]$hdrSize
        }

        # Kun X.509 lister
        $isX509 = ((@($sigType) -join ',') -eq (@($EFI_CERT_X509_GUID_BYTES) -join ','))
        if (-not $isX509) {
          # hop til slutningen af denne liste og fortsæt
          $i = $listEnd
          continue
        }

        # Hver post: EFI_SIGNATURE_DATA (16 byte owner + SignatureData (cert))
        while ($i -lt $listEnd) {
          if ($i + [int]$sigSize -gt $listEnd) { break }  # post må ikke gå ud over listen

          # Spring SignatureOwner over
          $i += 16
          [int]$certLen = [int]$sigSize - 16
          if ($certLen -le 0 -or $i + $certLen -gt $len) { break }

          # Sikker kopiering (undgå range-operator overflow)
          $certBytes = New-Object byte[] $certLen
          [System.Buffer]::BlockCopy($bytes, $i, $certBytes, 0, $certLen)
          $i += $certLen

          try {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList (, $certBytes)
            $name = $cert.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
            if ([string]::IsNullOrWhiteSpace($name)) { $name = $cert.Subject }

            [PSCustomObject]@{
              Source       = $varName
              Name         = $name
              'Valid from' = $cert.NotBefore.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss\Z')
              'Valid to'   = $cert.NotAfter.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss\Z')
            }
          } catch {
            # Ignorer ikke-X.509 eller korrupt post
            continue
          }
        }

        # Sørg for at vi lander præcist på slutningen af listen
        if ($i -lt $listEnd) { $i = $listEnd }
      }
    } catch {
      # Brug din egen logger hvis tilgængelig, ellers verbose
      if ($script:cs -and $script:cs.PSObject.Properties.Name -contains 'Job_WriteLog') {
        $cs.Job_WriteLog("Could not read ${varName}: $($_.Exception.Message)")
      } else {
        Write-Verbose "Could not read ${varName}: $($_.Exception.Message)"
      }
    }
  }
}

function PreInstall {
  #MARK: PreInstall
  <#
    PreInstall runs before the package download and if $global:DownloadPackage is set to $true.
    Use this function to check for prerequisites, such as disk space, registry keys, or other requirements.
  #>
  $cs.Log_SectionHeader("PreInstall", 'o')
  if (!$cs.Sys_IsMinimumRequiredDiskspaceAvailable('c:', 1500)) { Exit-PSScript 3333 } # 1500 mb minimum disk space required
}

function Install {
  #MARK: Install
  $cs.Log_SectionHeader("Install", 'o')

  $Certificates = Get-SecureBootCertificates
  $RegistryKnownCerts = (Get-ItemProperty -Path "HKLM:\$global:RegKey").PSObject.Properties | Where-Object { $_.Name -ne "PSPath" -and $_.Name -ne "PSParentPath" -and $_.Name -ne "PSChildName" -and $_.Name -ne "PSDrive" -and $_.Name -ne "PSProvider" } | Select-Object Name, Value

  $NewKnownCerts = @()
  foreach ($Cert in $Certificates) {
    $ValidTo = $Cert.'Valid to'.Substring(0, 10)
    $ValidFrom = $Cert.'Valid from'.Substring(0, 10)

    $NewKnownCerts += [PSCustomObject]@{
      Name      = "$($Cert.Name) - Source"
      Value     = "$($Cert.Source)"
    }
    $NewKnownCerts += [PSCustomObject]@{
      Name      = "$($Cert.Name) - Valid from"
      Value     = "$ValidFrom"
    }
    $NewKnownCerts += [PSCustomObject]@{
      Name      = "$($Cert.Name) - Valid to"
      Value     = "$ValidTo"
    }

    # Does the value already exist and is it the same?
    $RegEntry = $RegistryKnownCerts | Where-Object { $_.Name -eq "$($Cert.Name) - Source" }
    if ($RegEntry) {
      if ($RegEntry.Value -ne "$($Cert.Source)") {
        $cs.Reg_SetString('HKLM', $global:RegKey, "$($Cert.Name) - Source", "$($Cert.Source)")
      }
    } else {
      $cs.Reg_SetString('HKLM', $global:RegKey, "$($Cert.Name) - Source", "$($Cert.Source)")
    }
    $RegEntry = $RegistryKnownCerts | Where-Object { $_.Name -eq "$($Cert.Name) - Valid from" }
    if ($RegEntry) {
      if ($RegEntry.Value -ne "$ValidFrom") {
        $cs.Reg_SetString('HKLM', $global:RegKey, "$($Cert.Name) - Valid from", "$ValidFrom")
      }
    } else {
      $cs.Reg_SetString('HKLM', $global:RegKey, "$($Cert.Name) - Valid from", "$ValidFrom")
    }
    $RegEntry = $RegistryKnownCerts | Where-Object { $_.Name -eq "$($Cert.Name) - Valid to" }
    if ($RegEntry) {
      if ($RegEntry.Value -ne "$ValidTo") {
        $cs.Reg_SetString('HKLM', $global:RegKey, "$($Cert.Name) - Valid to", "$ValidTo")
      }
    } else {
      $cs.Reg_SetString('HKLM', $global:RegKey, "$($Cert.Name) - Valid to", "$ValidTo")
    }

    # Add to Custom Inventory
    CMS_AddCustomInventory -category "Secure Boot Certificates" -entry "$($Cert.Name) - Source" -value "$($Cert.Source)" -valuetype "S"
    CMS_AddCustomInventory -category 'Secure Boot Certificates' -entry "$($Cert.Name) - Valid from" -value "$ValidFrom" -valuetype "S"
    CMS_AddCustomInventory -category "Secure Boot Certificates" -entry "$($Cert.Name) - Valid to" -value "$ValidTo" -valuetype "S"
  }

  # Remove old certs entries
  $ThingsToRemove = @()
  foreach ($RegEntry in $RegistryKnownCerts) {
    $Found = $NewKnownCerts | Where-Object { $_.Name -eq $RegEntry.Name }
    if (-not $Found) {
      $ThingsToRemove += $RegEntry.Name
    }
  }

  foreach ($Thing in $ThingsToRemove) {
    $cs.Reg_DeleteVariable('HKLM', $global:RegKey, $Thing)
    CMS_RemoveCustomInventory -category 'Secure Boot Certificates' -entry $Thing
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