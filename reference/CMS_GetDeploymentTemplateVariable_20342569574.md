<div id="page">

<div id="main" class="aui-page-panel">

<div id="main-header">

<div id="breadcrumb-section">

1.  [CapaInstaller 6.7 Documentation Public](index.html)
2.  [CMS Functions](CMS-Functions_20342569060.html)

</div>

# <span id="title-text"> CapaInstaller 6.7 Documentation Public : CMS_GetDeploymentTemplateVariable </span>

</div>

<div id="content" class="view">

<div class="page-metadata">

Created by <span class="author"> Henrik Wendt</span> on Feb 18, 2025

</div>

<div id="main-content" class="wiki-content group">

### Description

Returns a variable from the deployment template from which the client was installed. Alternatively, the template is fetched from the business unit that the client was linked to at installation time.

### Syntax

:vb: CMS_GetDeploymentTemplateVariable(*Section, Variable*, *MustExist* ) As string

:ps: \[string\]CMS_GetDeploymentTemplateVariable -section \<string\> -variable \<string\> -mustexist \<bool\>

### Parameters

*Section (String)*

The name of the section in the template

*Variable (String)*

The name of the variable to return

*MustExist (Boolean)*

TRUE if the variable must exist

### Return value

:vb: The function returns a boolean, indicating if the call was successful. If the requested section and/or variable is not present, then false is returned, unless MustExist is set to false. The requested value will be stored in gsValue. If the variable can be read, then gbValue will be set to TRUE, otherwise, it will be set to FALSE.

:ps: Result will be returned as the result of the function. If the requested section and/or variable is not present then an error is thrown, unless MustExist is set to false.

### Example configuration

<div class="code panel pdl" style="border-width: 1px;">

<div class="codeContent panelContent pdl">

``` syntaxhighlighter-pre
{
    "operatingSystem": {
        "ImageId": 13,
        "diskConfigId": 1,
        "localAdmin": "true",
        "password": "15aarest"
    },
    "domain": {
        "joinDomain": "CAPADEMO.LOCAL",
        "domainName": "CAPADEMO.LOCAL",
        "domainUserName": "ciinst",
        "domainUserPassword": "dftgyhuj",
        "computerObjectOU": "OU=Computers,OU=Lazise,OU=Dev2,DC=CAPADEMO,DC=local"},
    "title": "Default",
    "customValues": [{
        "key": "a",
        "value": "1"
    }]
}
```

</div>

</div>

### Example

:vb: **VBScript**

<div class="table-wrap">

<table class="confluenceTable" data-table-width="960" data-layout="wide" data-local-id="a58dc257-d352-479b-bce0-dc16e0059a40">
<tbody>
<tr>
<td class="confluenceTd"><div class="code panel pdl" style="border-width: 1px;">
<div class="codeContent panelContent pdl">
<pre class="syntaxhighlighter-pre" data-syntaxhighlighter-params="brush: vb; gutter: false; theme: Confluence" data-theme="Confluence"><code>&#39;Variable exists:
If bStatus Then bStatus = CMS_GetDeploymentTemplateVariable(&quot;domain&quot;, &quot;domainUserName&quot;, True)
&#39;This will set bStatus = true, gbValue = true and gsValue = &quot;ciinst&quot;
&#10;&#39;Root variable:
If bStatus Then bStatus = CMS_GetDeploymentTemplateVariable(&quot;&quot;, &quot;title&quot;, True)
&#39;This will set bStatus = true, gbValue = true and gsValue = &quot;Default&quot;
&#10;&#39;Custom variable:
If bStatus Then bStatus = CMS_GetDeploymentTemplateVariable(&quot;CustomValues&quot;, &quot;a&quot;, True)
&#39;This will set bStatus = true, gbValue = true and gsValue = 1
&#10;&#39;bMustExist:
If bStatus Then bStatus = CMS_GetDeploymentTemplateVariable(&quot;domain&quot;, &quot;publishedAuthority&quot;, True)
&#39;This will set bStatus = false, gbValue = false and gsValue = &quot;&quot;</code></pre>
</div>
</div></td>
</tr>
</tbody>
</table>

</div>

:ps: **Powershell**

<div class="table-wrap">

<table class="confluenceTable" data-table-width="960" data-layout="wide" data-local-id="4696b35a-4240-4341-8330-140dce06dcb3">
<tbody>
<tr>
<td class="confluenceTd"><div class="code panel pdl" style="border-width: 1px;">
<div class="codeContent panelContent pdl">
<pre class="syntaxhighlighter-pre" data-syntaxhighlighter-params="brush: powershell; gutter: false; theme: Confluence" data-theme="Confluence"><code>$var = CMS_GetDeploymentTemplateVariable -section &quot;domain&quot; -variable &quot;domainUserName&#39; -mustexist $true
#This will set $var = &quot;ciinst&quot;
&#10;#Root variable:
$rootvar = CMS_GetDeploymentTemplateVariable -section &quot;&quot; -variable &quot;title&quot; -mustexist $true
#This will set $rootvar = &quot;Default&quot;
&#10;#Custom variable:
$custom = CMS_GetDeploymentTemplateVariable -section &quot;CustomValues&quot; -variable &quot;a&quot; -mustexist $true
#This will set $custom = &quot;1&quot;
&#10;#bMustExist:
$fail = CMS_GetDeploymentTemplateVariable section &quot;domain&quot; -variable &quot;publishedAuthority&quot; -mustexist $true
#This will throw an exception since &#39;publishedAuthority&#39; does not exist</code></pre>
</div>
</div></td>
</tr>
</tbody>
</table>

</div>

<a href="#" rel="nofollow">Scripting Guidelines</a>

  

</div>

</div>

</div>

<div id="footer" role="contentinfo">

<div class="section footer-body">

Document generated by Confluence on Oct 15, 2025 11:43

<div id="footer-logo">

[Atlassian](http://www.atlassian.com/)

</div>

</div>

</div>

</div>
