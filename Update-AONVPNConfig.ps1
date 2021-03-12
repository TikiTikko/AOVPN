# Copyright (c) Microsoft Corporation.  All rights reserved.
#
# THIS SAMPLE CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
# WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
# IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
# CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER.

<#
.SYNOPSIS
    Configures an AlwaysOn IKEv2 VPN Connection using a basic script
.DESCRIPTION
    Configures an AlwaysOn IKEv2 VPN Connection with proxy PAC information and force tunneling
.PARAMETERS
    Parameters are defined in a ProfileXML object within the script itself
.NOTES
    Requires at least Windows 10 Version 1803 with KB4493437, 1809 with KB4490481, or later
.VERSION
    1.0
#>

<#-- Define Key VPN Profile Parameters --#>
$ProfileName = 'Contoso VPN with Office 365 Exclusions'
$ProfileNameEscaped = $ProfileName -replace ' ', '%20'

<#-- Define VPN ProfileXML --#>
$ProfileXML = '<VPNProfile>
   <RememberCredentials>true</RememberCredentials>
   <AlwaysOn>true</AlwaysOn>
   <DnsSuffix>corp.contoso.com</DnsSuffix>
   <TrustedNetworkDetection>corp.contoso.com</TrustedNetworkDetection>
   <Proxy>
      <AutoConfigUrl>http://webproxy.corp.contoso.com/proxy.pac</AutoConfigUrl>
   </Proxy>
   <NativeProfile>
      <Servers>edge1.contoso.com;edge1.contoso.com</Servers>
      <RoutingPolicyType>ForceTunnel</RoutingPolicyType>
      <NativeProtocolType>Ikev2</NativeProtocolType>
      <Authentication>
         <MachineMethod>Certificate</MachineMethod>
      </Authentication>
   </NativeProfile>
   <Route>
      <Address>91.120.0.0</Address>
      <PrefixSize>14</PrefixSize>
      <ExclusionRoute>true</ExclusionRoute>      
   </Route>
<Route>
	<Address>104.146.128.0</Address>
	<PrefixSize>17</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>13.107.128.0</Address>
	<PrefixSize>22</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>13.107.136.0</Address>
	<PrefixSize>22</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>13.107.18.10</Address>
	<PrefixSize>31</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>13.107.6.152</Address>
	<PrefixSize>31</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>13.107.64.0</Address>
	<PrefixSize>18</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>131.253.33.215</Address>
	<PrefixSize>32</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>132.245.0.0</Address>
	<PrefixSize>16</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>150.171.32.0</Address>
	<PrefixSize>22</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>150.171.40.0</Address>
	<PrefixSize>22</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>204.79.197.215</Address>
	<PrefixSize>32</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>23.103.160.0</Address>
	<PrefixSize>20</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>40.104.0.0</Address>
	<PrefixSize>15</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>40.108.128.0</Address>
	<PrefixSize>17</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>40.96.0.0</Address>
	<PrefixSize>13</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>52.104.0.0</Address>
	<PrefixSize>14</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>52.112.0.0</Address>
	<PrefixSize>14</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>52.120.0.0</Address>
	<PrefixSize>14</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>52.96.0.0</Address>
	<PrefixSize>14</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
<Route>
	<Address>13.107.60.1</Address>
	<PrefixSize>32</PrefixSize>
	<ExclusionRoute>true</ExclusionRoute>
</Route>
</VPNProfile>'

<#-- Convert ProfileXML to Escaped Format --#>
$ProfileXML = $ProfileXML -replace '<', '&lt;'
$ProfileXML = $ProfileXML -replace '>', '&gt;'
$ProfileXML = $ProfileXML -replace '"', '&quot;'

<#-- Define WMI-to-CSP Bridge Properties --#>
$nodeCSPURI = './Vendor/MSFT/VPNv2'
$namespaceName = "root\cimv2\mdm\dmmap"
$className = "MDM_VPNv2_01"

<#-- Define WMI Session --#>
$session = New-CimSession

<#-- Detect and Delete Previous VPN Profile --#>
try
{
    $deleteInstances = $session.EnumerateInstances($namespaceName, $className, $options)
    foreach ($deleteInstance in $deleteInstances)
    {
        $InstanceId = $deleteInstance.InstanceID
        if ("$InstanceId" -eq "$ProfileNameEscaped")
        {
            $session.DeleteInstance($namespaceName, $deleteInstance, $options)
            $Message = "Removed $ProfileName profile $InstanceId"
            Write-Host "$Message"
        } else {
            $Message = "Ignoring existing VPN profile $InstanceId"
            Write-Host "$Message"
        }
    }
}
catch [Exception]
{
    $Message = "Unable to remove existing outdated instance(s) of $ProfileName profile: $_"
    Write-Host "$Message"
    exit
}

<#-- Create VPN Profile --#>
try
{
    $newInstance = New-Object Microsoft.Management.Infrastructure.CimInstance $className, $namespaceName
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ParentID", "$nodeCSPURI", 'String', 'Key')
    $newInstance.CimInstanceProperties.Add($property)
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("InstanceID", "$ProfileNameEscaped", 'String', 'Key')
    $newInstance.CimInstanceProperties.Add($property)
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ProfileXML", "$ProfileXML", 'String', 'Property')
    $newInstance.CimInstanceProperties.Add($property)

    $session.CreateInstance($namespaceName, $newInstance, $options)
    $Message = "Created $ProfileName profile."
    Write-Host "$Message"
    Write-Host "$ProfileName profile summary:"  
    $session.EnumerateInstances($namespaceName, $className, $options)
}
catch [Exception]
{
    $Message = "Unable to create $ProfileName profile: $_"
    Write-Host "$Message"
    exit
}

$Message = "Script Complete"
Write-Host "$Message"