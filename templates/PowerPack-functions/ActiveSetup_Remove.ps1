function ActiveSetup_Remove {
  <#
    .SYNOPSIS
        Remove an Active Setup entry in the registry.

    .DESCRIPTION
        Active Setup allows handling of per-user changes registry/file changes upon login.

        A registry key is removed in the HKLM registry hive which gets replicated to the HKCU hive when a user logs in.

    .PARAMETER Key
        Name of the registry key for the Active Setup entry. Defaults will be the packagename ($AppName).

    .PARAMETER DisableActiveSetup
        Disables the Active Setup entry so that the StubPath file will not be executed. If not true, the entry and file will be removed.

    .PARAMETER Wow6432Node
        Indicates whether to use the Wow6432Node registry key for 32-bit applications on 64-bit systems.

    .INPUTS
        None

        You cannot pipe objects to this function.

    .OUTPUTS
        System.Boolean

        Returns $true if Active Setup entry was created or updated, $false if Active Setup entry was not created or updated.

    .EXAMPLE
        ActiveSetup_Remove

    .EXAMPLE
        ActiveSetup_Remove -Key 'MyActiveSetupEntry'

    .NOTES
        Original code borrowed from: Denis St-Pierre (Ottawa, Canada), Todd MacNaught (Ottawa, Canada)
        And changed to fit the PowerPack runspace.

        Tags: psadt
        Website: https://psappdeploytoolkit.com
        Copyright: (C) 2024 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham, Muhammad Mashwani, Mitch Richters, Dan Gough).
        License: https://opensource.org/license/lgpl-3-0

    .LINK
        https://psappdeploytoolkit.com
    #>

  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $false)]
    [System.String]$Key = $AppName,

    [Parameter(Mandatory = $false)]
    [bool]$DisableActiveSetup = $false,

    [Parameter(Mandatory = $false)]
    [bool]$Wow6432Node
  )

  begin {
    #region Functions
    function Registry-Delete-Key {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('HKEY_LOCAL_MACHINE', 'HKEY_USERS', 'HKEY_CURRENT_USER')]
        [string]$Registry_Root,
        [Parameter(Mandatory = $true)]
        [string]$Registry_Key
      )
      $LogPreTag = 'Registry-Delete-Key:'

      try {
        $cs.Job_WriteLog("$LogPreTag Calling function with: Registry_Root: $Registry_Root | Registry_Key: $Registry_Key")

        switch ($Registry_Root) {
          'HKEY_CURRENT_USER' {
            $cs.Job_WriteLog("$LogPreTag Building Array With All Users That Have Logged On To This Unit....")
            $RegKeys = $cs.Reg_EnumKey('HKLM', 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList', $true)

            # Convert from array to list and add DEFAULT user
            $UsersRegKey = @()
            $UsersRegKey += $RegKeys
            $UsersRegKey += 'DEFAULT'

            try {
              foreach ($User in $UsersRegKey) {
                $cs.Job_WriteLog("$LogPreTag Running for $User")

                # Skip if the user is not a user or the default user
                $split = $User -split '-'
                if ($split[3] -ne '21' -and $User -ne 'DEFAULT' -and $split[3] -ne '1') {
                  $cs.Job_WriteLog("$LogPreTag Skipping $User")
                  continue
                }

                if ($Global:Debug -ne $true) {
                  $cs.Job_DisableLog()
                }

                # Sets user specific variables
                switch ($User) {
                  'DEFAULT' {
                    $ProfileImagePath = 'C:\Users\DEFAULT'
                    $Temp_Registry_Root = 'HKLM'
                    $RegistryCoreKey = 'TempHive\'
                    $HKUExists = $false
                  }
                  default {
                    $ProfileImagePath = $cs.Reg_GetExpandString('HKLM', "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$User", 'ProfileImagePath')
                    if ($ProfileImagePath) {
                      if ($cs.Reg_ExistKey('HKU', $User)) {
                        $Temp_Registry_Root = 'HKU'
                        $RegistryCoreKey = "$User\"
                        $HKUExists = $true
                      } else {
                        $Temp_Registry_Root = 'HKLM'
                        $RegistryCoreKey = 'TempHive\'
                        $HKUExists = $false
                      }
                    } else {
                      $cs.Job_WriteLog("$LogPreTag ProfileImagePath is empty for $User. Skipping...")
                      continue
                    }
                  }
                }

                # Load the NTUSER.DAT file if it exists
                $NTUserDatFile = Join-Path $ProfileImagePath 'NTUSER.DAT'
                if ($RegistryCoreKey -eq 'TempHive\' -and ($cs.File_ExistFile($NTUserDatFile))) {
                  $RetValue = $cs.Shell_Execute('cmd.exe', "/c reg load HKLM\TempHive `"$ProfileImagePath\NTUSER.DAT`"")
                  if ($RetValue -ne 0) {
                    $cs.Job_EnableLog()
                    $cs.Job_WriteLog("$LogPreTag Error: The registry hive for $User could not be mounted. Skipping...")
                    continue
                  }
                } elseif ($HKUExists) {
                  # Do nothing
                }	else {
                  $cs.Job_WriteLog("$LogPreTag NTUSER.DAT does not exist for $User. Skipping...")
                  continue
                }

                # Set the registry value
                $RegKeyPathTemp = "$RegistryCoreKey$Registry_Key"
                $cs.Reg_DeleteTree($Temp_Registry_Root, $RegKeyPathTemp)

                # Unload the NTUSER.DAT file if it was loaded
                if ($RegistryCoreKey -eq 'TempHive\') {
                  [gc]::collect()
                  [gc]::WaitForPendingFinalizers()
                  Start-Sleep -Seconds 2
                  $RetValue = $cs.Shell_Execute('cmd.exe', '/c reg unload HKLM\TempHive')
                  if ($RetValue -ne 0) {
                    $cs.Job_EnableLog()
                    $cs.Job_WriteLog("$LogPreTag Error: The registry hive for $User could not be unmounted")
                  }
                }
              }
            } finally {
              if ($cs.Reg_ExistKey('HKLM', 'TempHive')) {
                [gc]::collect()
                [gc]::WaitForPendingFinalizers()
                Start-Sleep -Seconds 2
                $RetValue = $cs.Shell_Execute('cmd.exe', '/c reg unload HKLM\TempHive')
                if ($RetValue -ne 0) {
                  $cs.Job_EnableLog()
                  $cs.Job_WriteLog("$LogPreTag Error: The registry hive could not be unmounted")
                }
              }
            }
          }
          default {
            $cs.Reg_DeleteTree($Registry_Root, $Registry_Key)
          }
        }
      } finally {
        $cs.Job_EnableLog()
      }
    }

    function Set-ADTActiveSetupRegistryEntry {
      [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'This is an internal worker function that requires no end user confirmation.')]
      [CmdletBinding()]
      param
      (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Root,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Key,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Version,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [System.String]$Locale,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$DisableActiveSetup
      )

      $cs.Reg_SetString($Root, $Key, '(Default)', $Description)
      $cs.Reg_SetString($Root, $Key, 'Version', $Version)
      $cs.Reg_SetString($Root, $Key, 'StubPath', $StubPath)
      if (![System.String]::IsNullOrWhiteSpace($Locale)) {
        $cs.Reg_SetString($Root, $Key, 'Locale', $Locale)
      }

      # Only Add IsInstalled to HKLM.
      if ($RegPath.Contains('HKEY_LOCAL_MACHINE') -or $RegPath.Contains('HKLM')) {
        $cs.Reg_SetDWord($Root, $Key, 'IsInstalled', ([System.UInt32]!$DisableActiveSetup))
      }
    }
    #endregion

    $LogPreTag = 'ActiveSetup_Remove:'
    $cs.Job_WriteLog("$LogPreTag Key: $Key")

    # Define initial variables.
  }
  process {
    try {
      # Set up the relevant keys, factoring in bitness and architecture.
      if ($Wow6432Node -and [System.Environment]::Is64BitOperatingSystem) {
        $HKLMRegKeyCore = 'SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components'
        $HKLMRegKey = "$HKLMRegKeyCore\$Key"
        $HKCURegKeyCore = 'Software\Wow6432Node\Microsoft\Active Setup\Installed Components'
        $HKCURegKey = "$HKCURegKeyCore\$Key"
      } else {
        $HKLMRegKeyCore = 'SOFTWARE\Microsoft\Active Setup\Installed Components'
        $HKLMRegKey = "$HKLMRegKeyCore\$Key"
        $HKCURegKeyCore = 'Software\Microsoft\Active Setup\Installed Components'
        $HKCURegKey = "$HKCURegKeyCore\$Key"
      }

      if ($DisableActiveSetup) {
        $sasreParams = @{
          Version            = ((Get-Date -Format 'yyMM,ddHH,mmss').ToString())
          DisableActiveSetup = $DisableActiveSetup
        }

        $cs.Job_WriteLog("$LogPreTag Disabling Active Setup entry")
        Set-ADTActiveSetupRegistryEntry @sasreParams -RegPath $HKLMRegKey

        return
      }

      # Delete Active Setup registry entry from the HKLM hive and for all logon user registry hives on the system.

      # Delete file or folder
      $StubPath = $cs.Reg_GetString('HKLM', $HKLMRegKey, 'StubPath')

      if ([string]::IsNullOrEmpty($global:gsProgramData) -and ![string]::IsNullOrEmpty($cs.gsProgramData)) {
        $global:gsProgramData = $cs.gsProgramData
      } elseif ([string]::IsNullOrEmpty($global:gsProgramData)) {
        $cs.Initialize_ScriptingVariables()
        $global:gsProgramData = $cs.gsProgramData
      }
      if ([string]::IsNullOrEmpty($global:gsProgramData)) {
        $naerParams = @{
          Exception         = [System.ArgumentNullException]::new('gsProgramData cannot be null or empty.')
          Category          = [System.Management.Automation.ErrorCategory]::InvalidArgument
          ErrorId           = 'gsProgramDataNotSet'
          TargetObject      = $global:gsProgramData
          RecommendedAction = 'Please set the gsProgramData variable before running this function.'
        }
        throw (New-ADTErrorRecord @naerParams)
      }
      if ($Global:Debug) {
        $cs.Job_WriteLog("$LogPreTag gsProgramData: $global:gsProgramData")
      }

      $DefaultDestination = Join-Path $global:gsProgramData 'CapaSystems' 'PowerBricks' 'ActiveSetup' $Key
      if ($StubPath -like "*$DefaultDestination*") {
        $cs.File_DelTree($DefaultDestination)
      }

      # HLKM first.
      $cs.Job_WriteLog("$LogPreTag Removing Active Setup entry [$HKLMRegKey].")
      $cs.Reg_DelTree('HKLM', $HKLMRegKeyCore, $Key)

      # All remaining users thereafter.
      $cs.Job_WriteLog("$LogPreTag Removing Active Setup entry [$HKCURegKey] for all logged on user registry hives on the system.")
      Registry-Delete-Key -Registry_Root 'HKEY_CURRENT_USER' -Registry_Key $HKCURegKey
      return
    } catch {
      throw $_
    }
  }

  end {
    return $true
  }
}
