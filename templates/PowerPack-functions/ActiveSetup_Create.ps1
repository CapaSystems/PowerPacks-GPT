function ActiveSetup_Create {
  <#
    .SYNOPSIS
        Creates an Active Setup entry in the registry to execute a file for each user upon login.

    .DESCRIPTION
        Active Setup allows handling of per-user changes registry/file changes upon login.

        A registry key is created in the HKLM registry hive which gets replicated to the HKCU hive when a user logs in.

        If the "Version" value of the Active Setup entry in HKLM is higher than the version value in HKCU, the file referenced in "StubPath" is executed.

        This Function:
            - Creates the registry entries in "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$AppName".
            - Creates StubPath value depending on the file extension of the $StubExePath parameter.
            - Handles Version value with yyMM,ddHH,mmss granularity to permit re-installs on the same day and still trigger Active Setup after Version increase.
            - Copies/overwrites the StubExePath to "$env:ProgramData\CapaSystems\PowerBricks\ActiveSetup\$AppName\StubPath" to ensure the file is available for all users.
              If the path is not like $Packageroot, then it will execute the file from that path.
            - Executes the StubPath file for the current user based on $ExecuteForCurrentUser (no need to logout/login to trigger Active Setup).

    .PARAMETER StubExePath
        Use this parameter to specify the destination path of the file that will be executed upon user login.

    .PARAMETER Arguments
        Arguments to pass to the file being executed.

    .PARAMETER Wow6432Node
        Specify this switch to use Active Setup entry under Wow6432Node on a 64-bit OS. Default is: $false.

    .PARAMETER ExecutionPolicy
        Specifies the ExecutionPolicy to set when StubExePath is a PowerShell script. Default is: system's ExecutionPolicy.

    .PARAMETER Version
        Optional. Specify version for Active setup entry. Active Setup is not triggered if Version value has more than 8 consecutive digits. Use commas to get around this limitation. Default: yyMM,ddHH,mmss

        Note:
            - Do not use this parameter if it is not necessary. The function will handle this parameter automatically using the time of the installation as the version number.
            - Scripts and EXEs might be blocked by AppLocker. Ensure that the path given to -StubExePath will permit end users to run Scripts and EXEs unelevated.

    .PARAMETER Locale
        Optional. Arbitrary string used to specify the installation language of the file being executed. Not replicated to HKCU.

    .PARAMETER ExecuteForCurrentUser
        Specifies whether the StubExePath should be executed for the current user. Since this user is already logged in, the user won't have the application started without logging out and logging back in.

    .PARAMETER Key
        Name of the registry key for the Active Setup entry. Defaults will be the packagename ($AppName).

    .PARAMETER Description
        Description for the Active Setup. Users will see "Setting up personalized settings for: $Description" at logon.

    .INPUTS
        None

        You cannot pipe objects to this function.

    .OUTPUTS
        System.Boolean

        Returns $true if Active Setup entry was created or updated, $false if Active Setup entry was not created or updated.

    .EXAMPLE
        ActiveSetup_Create -StubExePath 'C:\Users\Public\Company\ProgramUserConfig.vbs' -Arguments '/Silent' -Description 'Program User Config' -Key 'ProgramUserConfig' -Locale 'en'

    .EXAMPLE
        ActiveSetup_Create -StubExePath "$envWinDir\regedit.exe" -Arguments "/S `"%SystemDrive%\Program Files (x86)\PS App Deploy\PSAppDeployHKCUSettings.reg`"" -Description 'PS App Deploy Config' -Key 'PS_App_Deploy_Config'

    .EXAMPLE
        Delete "ProgramUserConfig" active setup entry from all registry hives.

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

  [CmdletBinding(DefaultParameterSetName = 'Create')]
  param
  (
    [Parameter(Mandatory = $true, ParameterSetName = 'Create')]
    [ValidateScript({
        if (('.exe', '.vbs', '.cmd', '.bat', '.ps1', '.js') -notcontains ($StubExeExt = [System.IO.Path]::GetExtension($_))) {
          $PSCmdlet.ThrowTerminatingError("Unsupported Active Setup StubPath file extension [$StubExeExt].")
        }
        return ![System.String]::IsNullOrWhiteSpace($_)
      })]
    [System.String]$StubExePath,

    [Parameter(Mandatory = $false, ParameterSetName = 'Create')]
    [System.String]$Arguments,

    [Parameter(Mandatory = $false)]
    [bool]$Wow6432Node,

    [Parameter(Mandatory = $false, ParameterSetName = 'Create')]
    [Microsoft.PowerShell.ExecutionPolicy]$ExecutionPolicy = 'Unrestricted',

    [Parameter(Mandatory = $false, ParameterSetName = 'Create')]
    [System.String]$Version,

    [Parameter(Mandatory = $false, ParameterSetName = 'Create')]
    [System.String]$Locale,

    [Parameter(Mandatory = $false, ParameterSetName = 'Create')]
    [bool]$ExecuteForCurrentUser = $true,

    [Parameter(Mandatory = $false)]
    [System.String]$Key = $AppName,

    [Parameter(Mandatory = $false, ParameterSetName = 'Create')]
    [System.String]$Description
  )

  begin {
    #region Functions
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
      if ($Root -eq 'HKEY_LOCAL_MACHINE' -or $Root -eq 'HKLM') {
        $cs.Reg_SetDWord($Root, $Key, 'IsInstalled', ([System.UInt32]!$DisableActiveSetup))
      }
    }

    function New-ADTErrorRecord {
      <#
    .SYNOPSIS
        Creates a new ErrorRecord object.

    .DESCRIPTION
        This function creates a new ErrorRecord object with the specified exception, error category, and optional parameters. It allows for detailed error information to be captured and returned to the caller, who can then throw the error.

    .PARAMETER Exception
        The exception object that caused the error.

    .PARAMETER Category
        The category of the error.

    .PARAMETER ErrorId
        The identifier for the error. Default is 'NotSpecified'.

    .PARAMETER TargetObject
        The target object that the error is related to.

    .PARAMETER TargetName
        The name of the target that the error is related to.

    .PARAMETER TargetType
        The type of the target that the error is related to.

    .PARAMETER Activity
        The activity that was being performed when the error occurred.

    .PARAMETER Reason
        The reason for the error.

    .PARAMETER RecommendedAction
        The recommended action to resolve the error.

    .INPUTS
        None

        You cannot pipe objects to this function.

    .OUTPUTS
        System.Management.Automation.ErrorRecord

        This function returns an ErrorRecord object.

    .EXAMPLE
        PS C:\>$exception = [System.Exception]::new("An error occurred.")
        PS C:\>$category = [System.Management.Automation.ErrorCategory]::NotSpecified
        PS C:\>New-ADTErrorRecord -Exception $exception -Category $category -ErrorId "CustomErrorId" -TargetObject $null -TargetName "TargetName" -TargetType "TargetType" -Activity "Activity" -Reason "Reason" -RecommendedAction "RecommendedAction"

        Creates a new ErrorRecord object with the specified parameters.

    .NOTES
        An active ADT session is NOT required to use this function.

        Tags: psadt
        Website: https://psappdeploytoolkit.com
        Copyright: (C) 2024 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham, Muhammad Mashwani, Mitch Richters, Dan Gough).
        License: https://opensource.org/license/lgpl-3-0

    .LINK
        https://psappdeploytoolkit.com
    #>

      [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'This function does not change system state.')]
      [CmdletBinding(SupportsShouldProcess = $false)]
      [OutputType([System.Management.Automation.ErrorRecord])]
      param
      (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Exception]$Exception,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.ErrorCategory]$Category,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.String]$ErrorId = 'NotSpecified',

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [System.Object]$TargetObject,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.String]$TargetName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.String]$TargetType,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Activity,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.String]$Reason,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.String]$RecommendedAction
      )

      # Instantiate new ErrorRecord object.
      $errRecord = [System.Management.Automation.ErrorRecord]::new($Exception, $ErrorId, $Category, $TargetObject)

      # Add in all optional values, if specified.
      if ($Activity) {
        $errRecord.CategoryInfo.Activity = $Activity
      }
      if ($TargetName) {
        $errRecord.CategoryInfo.TargetName = $TargetName
      }
      if ($TargetType) {
        $errRecord.CategoryInfo.TargetType = $TargetType
      }
      if ($Reason) {
        $errRecord.CategoryInfo.Reason = $Reason
      }
      if ($RecommendedAction) {
        $errRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($errRecord.Exception.Message)
        $errRecord.ErrorDetails.RecommendedAction = $RecommendedAction
      }

      # Return the ErrorRecord to the caller, who will then throw it.
      return $errRecord
    }
    #endregion

    $LogPreTag = 'ActiveSetup_Create:'
    $cs.Job_WriteLog("$LogPreTag StubExePath: $StubExePath | Arguments: $Arguments | Wow6432Node: $Wow6432Node | ExecutionPolicy: $ExecutionPolicy | Version: $Version | Locale: $Locale | ExecuteForCurrentUser: $ExecuteForCurrentUser | Key: $Key | Description: $Description")

    # Define initial variables.
    $ActiveSetupFileName = [System.IO.Path]::GetFileName($StubExePath)
    $CUStubExePath = $null
    $CUArguments = $null
    $StubExeExt = [System.IO.Path]::GetExtension($StubExePath)
    $StubPath = $null

    if ([string]::IsNullOrWhiteSpace($Version)) {
      $Version = (Get-Date -Format 'yyMM,ddHH,mmss').ToString() # Ex: 1405,1515,0522
      if ($Global:Debug) {
        $cs.Job_WriteLog("$LogPreTag Version not specified. Defaulting to current date/time version: $Version")
      }
    }

    if ([string]::IsNullOrEmpty($Global:Packageroot)) {
      $naerParams = @{
        Exception         = [System.ArgumentNullException]::new('Packageroot cannot be null or empty.')
        Category          = [System.Management.Automation.ErrorCategory]::InvalidArgument
        ErrorId           = 'PackagerootNotSet'
        TargetObject      = $Global:Packageroot
        RecommendedAction = 'Please set the Packageroot variable before running this function.'
      }
      throw (New-ADTErrorRecord @naerParams)
    }
    if ($Global:Debug) {
      $cs.Job_WriteLog("$LogPreTag Packageroot: $Global:Packageroot")
    }
    if ($StubExePath -like "$Global:Packageroot*") {
      $DestinationPath = Join-Path $global:gsProgramData 'CapaSystems' 'PowerBricks' 'ActiveSetup' $Key "$ActiveSetupFileName"
      $cs.File_CopyFile($StubExePath, $DestinationPath, $true)
      $StubExePath = $DestinationPath
      $cs.Job_WriteLog("$LogPreTag StubExePath updated to: $StubExePath")
    }
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

      # Check if the $StubExePath file exists.
      if (!(Test-Path -LiteralPath $StubExePath -PathType Leaf)) {
        $naerParams = @{
          Exception         = [System.IO.FileNotFoundException]::new("Active Setup StubPath file [$ActiveSetupFileName] is missing.")
          Category          = [System.Management.Automation.ErrorCategory]::ObjectNotFound
          ErrorId           = 'ActiveSetupFileNotFound'
          TargetObject      = $ActiveSetupFileName
          RecommendedAction = 'Please confirm the provided value and try again.'
        }
        throw (New-ADTErrorRecord @naerParams)
      }

      # Define Active Setup StubPath according to file extension of $StubExePath.
      switch ($StubExeExt) {
        '.exe' {
          $CUStubExePath = $StubExePath
          $CUArguments = $Arguments
          $StubPath = if ([System.String]::IsNullOrWhiteSpace($Arguments)) {
            "`"$CUStubExePath`""
          } else {
            "`"$CUStubExePath`" $CUArguments"
          }
          break
        }
        { $_ -in '.js', '.vbs' } {
          $CUStubExePath = "$([System.Environment]::SystemDirectory)\wscript.exe"
          $CUArguments = if ([System.String]::IsNullOrWhiteSpace($Arguments)) {
            "//nologo `"$StubExePath`""
          } else {
            "//nologo `"$StubExePath`"  $Arguments"
          }
          $StubPath = "`"$CUStubExePath`" $CUArguments"
          break
        }
        { $_ -in '.cmd', '.bat' } {
          $CUStubExePath = "$([System.Environment]::SystemDirectory)\cmd.exe"
          # Prefix any CMD.exe metacharacters ^ or & with ^ to escape them - parentheses only require escaping when there's no space in the path!
          $StubExePath = if ($StubExePath.Trim() -match '\s') {
            $StubExePath -replace '([&^])', '^$1'
          } else {
            $StubExePath -replace '([()&^])', '^$1'
          }
          $CUArguments = if ([System.String]::IsNullOrWhiteSpace($Arguments)) {
            "/C `"$StubExePath`""
          } else {
            "/C `"`"$StubExePath`" $Arguments`""
          }
          $StubPath = "`"$CUStubExePath`" $CUArguments"
          break
        }
        '.ps1' {
          if (Test-Path 'C:\Program Files\PowerShell\7\pwsh.exe') {
            $CUStubExePath = 'pwsh.exe'
          } else {
            $CUStubExePath = "$([System.Environment]::SystemDirectory)\WindowsPowerShell\v1.0\powershell.exe"
          }

          $CUArguments = if ([System.String]::IsNullOrWhiteSpace($Arguments)) {
            "-ExecutionPolicy $ExecutionPolicy -NoProfile -NoLogo -WindowStyle Hidden -File `"$StubExePath`""
          } else {
            "-ExecutionPolicy $ExecutionPolicy -NoProfile -NoLogo -WindowStyle Hidden -File `"$StubExePath`" $Arguments"
          }
          $StubPath = "`"$CUStubExePath`" $CUArguments"
          break
        }
      }

      if ($Global:Debug) {
        $cs.Job_WriteLog("$LogPreTag StubPath: $StubPath | CUStubExePath: $CUStubExePath | CUArguments: $CUArguments")
      }

      # Define common parameters split for Set-ADTActiveSetupRegistryEntry.
      $sasreParams = @{
        Version = $Version
        Locale  = $Locale
        Root    = 'HKLM'
        Key     = $HKLMRegKey
      }

      # Create the Active Setup entry in the registry.
      $cs.Job_WriteLog("Adding Active Setup Key for local machine: [$HKLMRegKey].")
      Set-ADTActiveSetupRegistryEntry @sasreParams

      # Execute the StubPath file for the current user as long as not in Session 0.
      if ($ExecuteForCurrentUser -eq $false) {
        return
      }

      if ($CUArguments) {
        Invoke-RunAsLoggedOnUser -Command $CUStubExePath -Arguments $CUArguments | Out-Null
      } else {
        Invoke-RunAsLoggedOnUser -Command $CUStubExePath | Out-Null
      }
    } catch {
      throw $_
    }
  }

  end {
    return $true
  }
}
