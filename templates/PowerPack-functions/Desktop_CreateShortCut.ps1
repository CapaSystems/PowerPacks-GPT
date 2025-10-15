function Desktop_CreateShortCut {
    <#
    .SYNOPSIS
        Creates a new .lnk or .url type shortcut.

    .DESCRIPTION
        Creates a new shortcut .lnk or .url file, with configurable options. This function allows you to specify various parameters such as the target path, arguments, icon location, description, working directory, window style, run as administrator, and hotkey.

    .PARAMETER LiteralPath
        Path to save the shortcut.

    .PARAMETER TargetPath
        Target path or URL that the shortcut launches.

    .PARAMETER Arguments
        Arguments to be passed to the target path.

    .PARAMETER IconLocation
        Location of the icon used for the shortcut.

    .PARAMETER IconIndex
        The index of the icon. Executables, DLLs, ICO files with multiple icons need the icon index to be specified. This parameter is an Integer. The first index is 0.

    .PARAMETER Description
        Description of the shortcut.

    .PARAMETER WorkingDirectory
        Working Directory to be used for the target path.

    .PARAMETER WindowStyle
        Windows style of the application. Options: Normal, Maximized, Minimized.

    .PARAMETER RunAsAdmin
        Set shortcut to run program as administrator. This option will prompt user to elevate when executing shortcut.

    .PARAMETER Hotkey
        Create a Hotkey to launch the shortcut, e.g. "CTRL+SHIFT+F".

    .INPUTS
        None

        You cannot pipe objects to this function.

    .OUTPUTS
        None

        This function does not return any output.

    .EXAMPLE
        Desktop_CreateShortCut -LiteralPath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\My Shortcut.lnk" -TargetPath "$env:WinDir\notepad.exe" -IconLocation "$env:WinDir\notepad.exe" -Description 'Notepad' -WorkingDirectory '%HOMEDRIVE%\%HOMEPATH%'

        Creates a new shortcut for Notepad with the specified parameters.

    .NOTES
        Url shortcuts only support TargetPath, IconLocation and IconIndex. Other parameters are ignored.
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
                if (![System.IO.Path]::GetExtension($_).ToLower().Equals('.lnk') -and ![System.IO.Path]::GetExtension($_).ToLower().Equals('.url')) {
                    $PSCmdlet.ThrowTerminatingError('The specified path does not have the correct extension.')
                }
                return ![System.String]::IsNullOrWhiteSpace($_)
            })]
        [Alias('Path', 'PSPath')]
        [System.String]$LiteralPath,

        [Parameter(Mandatory = $true)]
        [System.String]$TargetPath,

        [Parameter(Mandatory = $false)]
        [System.String]$Arguments = [System.Management.Automation.Language.NullString]::Value,

        [Parameter(Mandatory = $false)]
        [System.String]$IconLocation = [System.Management.Automation.Language.NullString]::Value,

        [Parameter(Mandatory = $false)]
        [System.Nullable[System.UInt32]]$IconIndex,

        [Parameter(Mandatory = $false)]
        [System.String]$Description = [System.Management.Automation.Language.NullString]::Value,

        [Parameter(Mandatory = $false)]
        [System.String]$WorkingDirectory = [System.Management.Automation.Language.NullString]::Value,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Normal', 'Maximized', 'Minimized')]
        [System.String]$WindowStyle = 'Normal',

        [Parameter(Mandatory = $false)]
        [System.Boolean]$RunAsAdmin,

        [Parameter(Mandatory = $false)]
        [System.String]$Hotkey
    )

    begin {
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

        Tags: psadt<br />
        Website: https://psappdeploytoolkit.com<br />
        Copyright: (C) 2025 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham, Muhammad Mashwani, Mitch Richters, Dan Gough).<br />
        License: https://opensource.org/license/lgpl-3-0

    .LINK
        https://psappdeploytoolkit.com/docs/reference/functions/New-ADTErrorRecord
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
                [System.String]$TargetName = [System.Management.Automation.Language.NullString]::Value,

                [Parameter(Mandatory = $false)]
                [ValidateNotNullOrEmpty()]
                [System.String]$TargetType = [System.Management.Automation.Language.NullString]::Value,

                [Parameter(Mandatory = $false)]
                [ValidateNotNullOrEmpty()]
                [System.String]$Activity = [System.Management.Automation.Language.NullString]::Value,

                [Parameter(Mandatory = $false)]
                [ValidateNotNullOrEmpty()]
                [System.String]$Reason = [System.Management.Automation.Language.NullString]::Value,

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

        $LogPreTag = 'Desktop_CreateShortCut:'
        $cs.Job_Writelog("$LogPreTag LiteralPath: $($LiteralPath) | TargetPath: $($TargetPath) | Arguments: $($Arguments) | IconLocation: $($IconLocation) | IconIndex: $($IconIndex) | Description: $($Description) | WorkingDirectory: $($WorkingDirectory) | WindowStyle: $($WindowStyle) | RunAsAdmin: $($RunAsAdmin) | Hotkey: $($Hotkey)")

        if ($LiteralPath.StartsWith('"')) {
            $LiteralPath = $LiteralPath.Substring(1)
        }
        if ($LiteralPath.EndsWith('"')) {
            $LiteralPath = $LiteralPath.Substring(0, $LiteralPath.Length - 1)
        }
        if ($TargetPath.StartsWith('"')) {
            $TargetPath = $TargetPath.Substring(1)
        }
        if ($TargetPath.EndsWith('"')) {
            $TargetPath = $TargetPath.Substring(0, $TargetPath.Length - 1)
        }
        if ($IconLocation.StartsWith('"')) {
            $IconLocation = $IconLocation.Substring(1)
        }
        if ($IconLocation.EndsWith('"')) {
            $IconLocation = $IconLocation.Substring(0, $IconLocation.Length - 1)
        }
        if ($Description.StartsWith('"')) {
            $Description = $Description.Substring(1)
        }
        if ($Description.EndsWith('"')) {
            $Description = $Description.Substring(0, $Description.Length - 1)
        }
        if ($WorkingDirectory.StartsWith('"')) {
            $WorkingDirectory = $WorkingDirectory.Substring(1)
        }
        if ($WorkingDirectory.EndsWith('"')) {
            $WorkingDirectory = $WorkingDirectory.Substring(0, $WorkingDirectory.Length - 1)
        }
        if ($Hotkey.StartsWith('"')) {
            $Hotkey = $Hotkey.Substring(1)
        }
        if ($Hotkey.EndsWith('"')) {
            $Hotkey = $Hotkey.Substring(0, $Hotkey.Length - 1)
        }

        $LiteralPath = $LiteralPath.Trim()
        $TargetPath = $TargetPath.Trim()
        $IconLocation = $IconLocation.Trim()
        $Description = $Description.Trim()
        $WorkingDirectory = $WorkingDirectory.Trim()
        $Hotkey = $Hotkey.Trim()
    }

    process {
        # Make sure .NET's current directory is synced with PowerShell's.
        try {
            [System.IO.Directory]::SetCurrentDirectory((Get-Location -PSProvider FileSystem).ProviderPath)
            $FullPath = [System.IO.Path]::GetFullPath($LiteralPath)
        } catch {
            $naerParams = @{
                Exception         = [System.IO.IOException]::new("Specified path [$LiteralPath] is not valid.")
                Category          = [System.Management.Automation.ErrorCategory]::InvalidArgument
                ErrorId           = 'ShortcutPathInvalid'
                TargetObject      = $LiteralPath
                RecommendedAction = 'Please confirm the provided value and try again.'
            }
            $cs.Job_Writelog("$LogPreTag Error: The specified path [$LiteralPath] is not valid.")
            throw (New-ADTErrorRecord @naerParams)
        }

        try {
            # Make sure directory is present before continuing.
            if (!($PathDirectory = [System.IO.Path]::GetDirectoryName($FullPath))) {
                # The path is root or no filename supplied.
                if (![System.IO.Path]::GetFileNameWithoutExtension($FullPath)) {
                    # No filename supplied.
                    $naerParams = @{
                        Exception         = [System.ArgumentException]::new("Specified path [$FullPath] is a directory and not a file.")
                        Category          = [System.Management.Automation.ErrorCategory]::InvalidArgument
                        ErrorId           = 'ShortcutPathInvalid'
                        TargetObject      = $FullPath
                        RecommendedAction = 'Please confirm the provided value and try again.'
                    }
                    $cs.Job_Writelog("$LogPreTag Error: The specified path [$FullPath] is a directory and not a file.")
                    throw (New-ADTErrorRecord @naerParams)
                }
            } elseif (!(Test-Path -LiteralPath $PathDirectory -PathType Container)) {
                try {
                    $cs.Job_Writelog("$LogPreTag Creating shortcut directory [$PathDirectory].")
                    $null = New-Item -Path $PathDirectory -ItemType Directory -Force
                } catch {
                    $naerParams = @{
                        Exception         = $_.Exception
                        Category          = [System.Management.Automation.ErrorCategory]::InvalidArgument
                        ErrorId           = 'ShortcutPathInvalid'
                        TargetObject      = $PathDirectory
                        RecommendedAction = 'Please confirm the provided value and try again.'
                    }
                    $cs.Job_Writelog("$LogPreTag Error: The specified path [$PathDirectory] is not valid.")
                    throw (New-ADTErrorRecord @naerParams)
                }
            }

            # Remove any pre-existing shortcut first.
            if (Test-Path -LiteralPath $FullPath -PathType Leaf) {
                $cs.Job_Writelog("$LogPreTag The shortcut [$FullPath] already exists. Deleting the file...")
                $cs.File_DelFile($FullPath)
            }

            # Build out the shortcut.
            $cs.Job_Writelog("$LogPreTag Creating shortcut [$FullPath].")
            if ([System.IO.Path]::GetExtension($LiteralPath) -eq '.url') {
                [String[]]$URLFile = '[InternetShortcut]', "URL=$TargetPath"
                if ([string]::IsNullOrWhiteSpace($IconIndex) -eq $false) {
                    $URLFile += "IconIndex=$IconIndex"
                }
                if ([string]::IsNullOrWhiteSpace($IconLocation) -eq $false) {
                    $URLFile += "IconFile=$IconLocation"
                }
                [System.IO.File]::WriteAllLines($FullPath, $URLFile, [System.Text.UTF8Encoding]::new($false))
            } else {
                $shortcut = [System.Activator]::CreateInstance([System.Type]::GetTypeFromProgID('WScript.Shell')).CreateShortcut($FullPath)
                $shortcut.TargetPath = $TargetPath
                if ([string]::IsNullOrWhiteSpace($Arguments) -eq $false) {
                    $shortcut.Arguments = $Arguments
                }
                if ([string]::IsNullOrWhiteSpace($Description) -eq $false) {
                    $shortcut.Description = $Description
                }
                if ([string]::IsNullOrWhiteSpace($WorkingDirectory) -eq $false) {
                    $shortcut.WorkingDirectory = $WorkingDirectory
                }
                if ([string]::IsNullOrWhiteSpace($Hotkey) -eq $false) {
                    $shortcut.Hotkey = $Hotkey
                }
                if ([string]::IsNullOrWhiteSpace($IconLocation) -eq $false) {
                    if ([string]::IsNullOrWhiteSpace($IconIndex) -eq $false) {
                        $shortcut.IconLocation = $IconLocation + ",$IconIndex"
                    } else {
                        $shortcut.IconLocation = $IconLocation
                    }
                }
                $shortcut.WindowStyle = switch ($WindowStyle) {
                    Normal { 1; break }
                    Maximized { 3; break }
                    Minimized { 7; break }
                }

                # Save the changes.
                $shortcut.Save()

                # Set shortcut to run program as administrator.
                if ($RunAsAdmin) {
                    $cs.Job_Writelog("$LogPreTag Setting shortcut to run program as administrator.")
                    $fileBytes = [System.IO.File]::ReadAllBytes($FullPath)
                    $fileBytes[21] = $fileBytes[21] -bor 32
                    [System.IO.File]::WriteAllBytes($FullPath, $fileBytes)
                }
            }
        } catch {
            $naerParams = @{
                Exception         = $_.Exception
                Category          = [System.Management.Automation.ErrorCategory]::NotSpecified
                ErrorId           = 'ShortcutCreationFailed'
                TargetObject      = $LiteralPath
                RecommendedAction = 'Please confirm the provided values and try again.'
            }
            $cs.Job_Writelog("$LogPreTag Error: Failed to create shortcut [$FullPath]. Exception: $($_.Exception.Message)")
            throw (New-ADTErrorRecord @naerParams)
        }
    }
}