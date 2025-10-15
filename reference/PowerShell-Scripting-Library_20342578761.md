<div id="page">

<div id="main" class="aui-page-panel">

<div id="main-header">

<div id="breadcrumb-section">

1.  [CapaInstaller 6.7 Documentation Public](index.html)

</div>

# <span id="title-text"> CapaInstaller 6.7 Documentation Public : PowerShell Scripting Library </span>

</div>

<div id="content" class="view">

<div class="page-metadata">

Created by <span class="author"> Henrik Wendt</span>, last modified by <span class="editor"> Mark Bønnelykke Rasmussen</span> on Jul 04, 2025

</div>

<div id="main-content" class="wiki-content group">

## Powershell Scripting Library Reference

<div class="confluence-information-macro confluence-information-macro-information">

<span class="aui-icon aui-icon-small aui-iconfont-info confluence-information-macro-icon"></span>

<div class="confluence-information-macro-body">

**PowerPacks** are built on PowerShell and require a PowerShell *Runspace* to function, due to application management constraints. Since this *Runspace* is only available in .NET Core, the Microsoft .NET Core Runtime (version 8.x) is **required** for running PowerPacks on client systems.

The .NET Core Runtime 8.x is provided as part of the **CapaPacks**.

</div>

</div>

- <a href="PowerPack-Global-Variables_20342578788.html" data-linked-resource-id="20342578788" data-linked-resource-version="2" data-linked-resource-type="page">PowerPack Global Variables</a>
- <a href="PowerShell-CMS-Functions_20342578812.html" data-linked-resource-id="20342578812" data-linked-resource-version="2" data-linked-resource-type="page">PowerShell CMS Functions</a>
- <a href="%24cs.File_AppendToFile_20342578841.html" data-linked-resource-id="20342578841" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_AppendToFile</a>
- <a href="%24cs.File_CopyFile_20342578865.html" data-linked-resource-id="20342578865" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_CopyFile</a>
- <a href="%24cs.File_CopyTree_20342578889.html" data-linked-resource-id="20342578889" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_CopyTree</a>
- <a href="%24cs.File_CreateDir_20342578913.html" data-linked-resource-id="20342578913" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_CreateDir</a>
- <a href="%24cs.File_DelEmptyFolder_20342578937.html" data-linked-resource-id="20342578937" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_DelEmptyFolder</a>
- <a href="%24cs.File_DeleteLineInFile_20342578961.html" data-linked-resource-id="20342578961" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_DeleteLineInFile</a>
- <a href="%24cs.File_DelFile_20342578985.html" data-linked-resource-id="20342578985" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_DelFile</a>
- <a href="%24cs.File_DelTree_20342579009.html" data-linked-resource-id="20342579009" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_DelTree</a>
- <a href="%24cs.File_ExistDir_20342579033.html" data-linked-resource-id="20342579033" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_ExistDir</a>
- <a href="%24cs.File_ExistFile_20342579057.html" data-linked-resource-id="20342579057" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_ExistFile</a>
- <a href="%24cs.File_FindFile_20342579081.html" data-linked-resource-id="20342579081" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_FindFile</a>
- <a href="%24cs.File_GetFileVersion_20342579105.html" data-linked-resource-id="20342579105" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_GetFileVersion</a>
- <a href="%24cs.File_GetFolderSize_20342579129.html" data-linked-resource-id="20342579129" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_GetFolderSize</a>
- <a href="%24cs.File_GetProductVersion_20342579153.html" data-linked-resource-id="20342579153" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_GetProductVersion</a>
- <a href="%24cs.File_RenameDir_20342579177.html" data-linked-resource-id="20342579177" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_RenameDir</a>
- <a href="%24cs.File_RenameFile_20342579201.html" data-linked-resource-id="20342579201" data-linked-resource-version="1" data-linked-resource-type="page">$cs.File_RenameFile</a>
- <a href="%24cs.Ini_ReadEntry_20342579225.html" data-linked-resource-id="20342579225" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Ini_ReadEntry</a>
- <a href="%24cs.Ini_WriteEntry_20342579249.html" data-linked-resource-id="20342579249" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Ini_WriteEntry</a>
- <a href="%24cs.Job_DisableLog_20342579273.html" data-linked-resource-id="20342579273" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Job_DisableLog</a>
- <a href="%24cs.Job_EnableLog_20342579297.html" data-linked-resource-id="20342579297" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Job_EnableLog</a>
- <a href="%24cs.Job_RebootWS_20342579321.html" data-linked-resource-id="20342579321" data-linked-resource-version="2" data-linked-resource-type="page">$cs.Job_RebootWS</a>
- <a href="%24cs.Job_Start_20342579345.html" data-linked-resource-id="20342579345" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Job_Start</a>
- <a href="%24cs.Job_WriteLog_20342579372.html" data-linked-resource-id="20342579372" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Job_WriteLog</a>
- <a href="%24cs.Log_SectionHeader_20342579396.html" data-linked-resource-id="20342579396" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Log_SectionHeader</a>
- <a href="%24cs.MSI_GetProductCodeFromMSI_20342579420.html" data-linked-resource-id="20342579420" data-linked-resource-version="1" data-linked-resource-type="page">$cs.MSI_GetProductCodeFromMSI</a>
- <a href="%24cs.MSI_GetPropertiesFromMSI_20342579444.html" data-linked-resource-id="20342579444" data-linked-resource-version="1" data-linked-resource-type="page">$cs.MSI_GetPropertiesFromMSI</a>
- <a href="%24cs.MSI_GetPropertyFromMSI_20342579468.html" data-linked-resource-id="20342579468" data-linked-resource-version="1" data-linked-resource-type="page">$cs.MSI_GetPropertyFromMSI</a>
- <a href="%24cs.MSI_IsMSIFileInstalled_20342579492.html" data-linked-resource-id="20342579492" data-linked-resource-version="1" data-linked-resource-type="page">$cs.MSI_IsMSIFileInstalled</a>
- <a href="%24cs.MSI_IsMSIGuidInstalled_20342579516.html" data-linked-resource-id="20342579516" data-linked-resource-version="1" data-linked-resource-type="page">$cs.MSI_IsMSIGuidInstalled</a>
- <a href="%24cs.Reg_CreateKey_20342579540.html" data-linked-resource-id="20342579540" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_CreateKey</a>
- <a href="%24cs.Reg_DeleteVariable_20342579564.html" data-linked-resource-id="20342579564" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_DeleteVariable</a>
- <a href="%24cs.Reg_DelTree_20342579588.html" data-linked-resource-id="20342579588" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_DelTree</a>
- <a href="%24cs.Reg_EnumKey_20342579612.html" data-linked-resource-id="20342579612" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_EnumKey</a>
- <a href="%24cs.Reg_ExistKey_20342579636.html" data-linked-resource-id="20342579636" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_ExistKey</a>
- <a href="%24cs.Reg_ExistVariable_20342579660.html" data-linked-resource-id="20342579660" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_ExistVariable</a>
- <a href="%24cs.Reg_GetExpandString_20342579684.html" data-linked-resource-id="20342579684" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_GetExpandString</a>
- <a href="%24cs.Reg_GetInteger_20342579708.html" data-linked-resource-id="20342579708" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_GetInteger</a>
- <a href="%24cs.Reg_GetMultiString_20342579732.html" data-linked-resource-id="20342579732" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_GetMultiString</a>
- <a href="%24cs.Reg_GetString_20342579756.html" data-linked-resource-id="20342579756" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_GetString</a>
- <a href="%24cs.Reg_SetDword_20342579780.html" data-linked-resource-id="20342579780" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_SetDword</a>
- <a href="%24cs.Reg_SetExpandString_20342579804.html" data-linked-resource-id="20342579804" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_SetExpandString</a>
- <a href="%24cs.Reg_SetInteger_20342579828.html" data-linked-resource-id="20342579828" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_SetInteger</a>
- <a href="%24cs.Reg_SetQword_20342579852.html" data-linked-resource-id="20342579852" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_SetQword</a>
- <a href="%24cs.Reg_SetString_20342579876.html" data-linked-resource-id="20342579876" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Reg_SetString</a>
- <a href="%24cs.Service_Exist_20342579900.html" data-linked-resource-id="20342579900" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Service_Exist</a>
- <a href="%24cs.Service_Start_20342579924.html" data-linked-resource-id="20342579924" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Service_Start</a>
- <a href="%24cs.Service_Stop_20342579948.html" data-linked-resource-id="20342579948" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Service_Stop</a>
- <a href="%24cs.Shell_Execute_20342579972.html" data-linked-resource-id="20342579972" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Shell_Execute</a>
- <a href="%24cs.Shell_ExecuteWithTimeout_20342579996.html" data-linked-resource-id="20342579996" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Shell_ExecuteWithTimeout</a>
- <a href="%24cs.Sys_ExistProcess_20342580020.html" data-linked-resource-id="20342580020" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Sys_ExistProcess</a>
- <a href="%24cs.Sys_GetFreeDiskSpace_20342580044.html" data-linked-resource-id="20342580044" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Sys_GetFreeDiskSpace</a>
- <a href="%24cs.Sys_IsMinimumRequiredDiskspaceAvailable_20342580068.html" data-linked-resource-id="20342580068" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Sys_IsMinimumRequiredDiskspaceAvailable</a>
- <a href="%24cs.Sys_isUserLoggedOn_20342580092.html" data-linked-resource-id="20342580092" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Sys_isUserLoggedOn</a>
- <a href="%24cs.Sys_KillProcess_20342580116.html" data-linked-resource-id="20342580116" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Sys_KillProcess</a>
- <a href="%24cs.Sys_Sleep_20342580140.html" data-linked-resource-id="20342580140" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Sys_Sleep</a>
- <a href="%24cs.Sys_WaitForProcess_20342580164.html" data-linked-resource-id="20342580164" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Sys_WaitForProcess</a>
- <a href="%24cs.Sys_WaitForProcessToExist_20342580188.html" data-linked-resource-id="20342580188" data-linked-resource-version="1" data-linked-resource-type="page">$cs.Sys_WaitForProcessToExist</a>
- <a href="%24cs.UsrMgr_AddUserToLocalGroup_20342580212.html" data-linked-resource-id="20342580212" data-linked-resource-version="1" data-linked-resource-type="page">$cs.UsrMgr_AddUserToLocalGroup</a>
- <a href="%24cs.UsrMgr_ChangePassword_20342580236.html" data-linked-resource-id="20342580236" data-linked-resource-version="1" data-linked-resource-type="page">$cs.UsrMgr_ChangePassword</a>
- <a href="%24cs.UsrMgr_CreateLocalUser_20342580260.html" data-linked-resource-id="20342580260" data-linked-resource-version="1" data-linked-resource-type="page">$cs.UsrMgr_CreateLocalUser</a>
- <a href="%24cs.UsrMgr_DeleteLocalUserAccount_20342580284.html" data-linked-resource-id="20342580284" data-linked-resource-version="1" data-linked-resource-type="page">$cs.UsrMgr_DeleteLocalUserAccount</a>
- <a href="%24cs.UsrMgr_EnumMembersOfLocalGroup_20342580308.html" data-linked-resource-id="20342580308" data-linked-resource-version="1" data-linked-resource-type="page">$cs.UsrMgr_EnumMembersOfLocalGroup</a>
- <a href="%24cs.UsrMgr_ExistLocalUserAccount_20342580332.html" data-linked-resource-id="20342580332" data-linked-resource-version="1" data-linked-resource-type="page">$cs.UsrMgr_ExistLocalUserAccount</a>
- <a href="%24cs.UsrMgr_GetNameBySid_20342580356.html" data-linked-resource-id="20342580356" data-linked-resource-version="1" data-linked-resource-type="page">$cs.UsrMgr_GetNameBySid</a>
- <a href="%24cs.UsrMgr_RemoveUserFromLocalGroup_20342580380.html" data-linked-resource-id="20342580380" data-linked-resource-version="1" data-linked-resource-type="page">$cs.UsrMgr_RemoveUserFromLocalGroup</a>
- <a href="%24InputObject.ShowMessageBox_20342580404.html" data-linked-resource-id="20342580404" data-linked-resource-version="1" data-linked-resource-type="page">$InputObject.ShowMessageBox</a>
- <a href="Exit-PSScript_20342580435.html" data-linked-resource-id="20342580435" data-linked-resource-version="1" data-linked-resource-type="page">Exit-PSScript</a>
- <a href="Invoke-RunAsLoggedOnUser_20342580461.html" data-linked-resource-id="20342580461" data-linked-resource-version="3" data-linked-resource-type="page">Invoke-RunAsLoggedOnUser</a>

</div>

</div>

</div>

<div id="footer" role="contentinfo">

<div class="section footer-body">

Document generated by Confluence on Oct 15, 2025 09:10

<div id="footer-logo">

[Atlassian](http://www.atlassian.com/)

</div>

</div>

</div>

</div>
