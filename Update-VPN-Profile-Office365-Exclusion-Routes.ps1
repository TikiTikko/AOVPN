# Copyright (c) Microsoft Corporation.  All rights reserved.
#  
# THIS SAMPLE CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
# WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
# IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
# CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER.

<#
.SYNOPSIS
    Applies or updates recommended Office 365 optimize IP address exclusions to an existing force tunnel Windows 10 VPN profile
.DESCRIPTION
    Connects to the Office 365 worldwide commercial service instance endpoints to obtain the latest published IP address ranges
    Compares the optimized IP addresses with those contained in the supplied VPN Profile (PowerShell or XML file)
    Adds or updates IP addresses as necessary and saves the resultant file with "-NEW" appended to the file name
.PARAMETERS
    Filename and path for a supplied Windows 10 VPN profile file in either PowerShell or XML format
.NOTES
    Requires at least Windows 10 Version 1803 with KB4493437, 1809 with KB4490481, or later
.VERSION
    1.0
#>

param (
    [string]$VPNprofilefile
)

$usage=@"

This script uses the following parameters:

VPNprofilefile - The full path and name of the VPN profile PowerShell script or XML file

EXAMPLES

To check a VPN profile PowerShell script file:

Update-VPN-Profile-Office365-Exclusion-Routes.ps1 -VPNprofilefile [FULLPATH AND NAME OF POWERSHELL SCRIPT FILE]

To check a VPN profile XML file:

Update-VPN-Profile-Office365-Exclusion-Routes.ps1 -VPNprofilefile [FULLPATH AND NAME OF XML FILE]

"@
  
# Check if filename has been provided #
if ($VPNprofilefile -eq "")
{
   Write-Host "`nWARNING: You must specify either a PowerShell script or XML filename!" -ForegroundColor Red

    $usage
    exit
}

$FileExtension = [System.IO.Path]::GetExtension($VPNprofilefile)

# Check if XML file exists and is a valid XML file #
if ( $VPNprofilefile -ne "" -and $FileExtension -eq ".xml")
{
    if ( Test-Path $VPNprofilefile )
    {
        $xml = New-Object System.Xml.XmlDocument
        try
        {
            $xml.Load((Get-ChildItem -Path $VPNprofilefile).FullName)

        }
        catch [System.Xml.XmlException]
        {
            Write-Verbose "$VPNprofilefile : $($_.toString())"
            Write-Host "`nWARNING: The VPN profile XML file is not a valid xml file or incorrectly formatted!" -ForegroundColor Red
            $usage
            exit
        }
    }else
    {
        Write-Host "`nWARNING: VPN profile XML file does not exist or cannot be found!" -ForegroundColor Red
        $usage
        exit
    }
}

# Check if VPN profile PowerShell script file exists and contains a VPNPROFILE XML section #
if ( $VPNprofilefile -ne "" -and $FileExtension -eq ".ps1")
{
    if ( (Test-Path $VPNprofilefile) )
    {
        if (-Not $(Select-String -Path $VPNprofilefile -Pattern "<VPNPROFILE>") )
        {
            Write-Host "`nWARNING: PowerShell script file does not contain a valid VPN profile XML section or is incorrectly formatted!" -ForegroundColor Red
            $usage
            exit
        }
    }else
    {
        Write-Host "`nWARNING: PowerShell script file does not exist or cannot be found!"-ForegroundColor Red
        $usage
        exit
    }
}

# Define Office 365 endpoints and service URLs #
$ws = "https://endpoints.office.com"
$baseServiceUrl = "https://endpoints.office.com"

# Path where client ID and latest version number will be stored #
$datapath = $Env:TEMP + "\endpoints_clientid_latestversion.txt"

# Fetch client ID and version if data file exists; otherwise create new file #
if (Test-Path $datapath)
{
    $content = Get-Content $datapath
    $clientRequestId = $content[0]
    $lastVersion = $content[1]

}else
{
    $clientRequestId = [GUID]::NewGuid().Guid
    $lastVersion = "0000000000"
    @($clientRequestId, $lastVersion) | Out-File $datapath
}

# Call version method to check the latest version, and pull new data if version number is different #
$version = Invoke-RestMethod -Uri ($ws + "/version?clientRequestId=" + $clientRequestId)

if ($version[0].latest -gt $lastVersion)
{

    Write-Host
    Write-Host "A new version of Office 365 worldwide commercial service instance endpoints has been detected!" -ForegroundColor Cyan

    # Write the new version number to the data file #
    @($clientRequestId, $version[0].latest) | Out-File $datapath
}

# Invoke endpoints method to get the new data #
$uri = "$baseServiceUrl" + "/endpoints/worldwide?clientRequestId=$clientRequestId"

# Invoke endpoints method to get the data for the VPN profile comparison #
$endpointSets = Invoke-RestMethod -Uri ($uri)
$Optimize = $endpointSets | Where-Object { $_.category -eq "Optimize" }
$optimizeIpsv4 = $Optimize.ips | Where-Object { ($_).contains(".") } | Sort-Object -Unique

# Temporarily include additional IP address until Teams client update is released
$optimizeIpsv4 += "13.107.60.1/32"

# Process PowerShell script file start #
if ($VPNprofilefile -ne "" -and $FileExtension -eq ".ps1")
{
    Write-host "`nStarting PowerShell script exclusion route check...`n" -ForegroundColor Cyan

    # Clear Variables to allow re-run testing #

    $ARRVPN=$null              # Array to hold VPN addresses from VPN profile PowerShell file #
    $In_Opt_Only=$null         # Variable to hold IP addresses that only appear in the optimize list #
    $In_VPN_Only=$null         # Variable to hold IP addresses that only appear in the VPN profile PowerShell file #

    # Extract the Profile XML from the ps1 file #

    $regex = '(?sm).*^*.<VPNProfile>\r?\n(.*?)\r?\n</VPNProfile>.*'

    # Create xml format variable to compare with the optimize list #

    $xmlbody=(Get-Content -Raw $VPNprofilefile) -replace $regex, '$1'
    [xml]$VPNprofilexml="<VPNProfile>"+$xmlbody+"</VPNProfile>"

        # Loop through each address found in VPNPROFILE XML section #
        foreach ($Route in $VPNprofilexml.VPNProfile.Route)
        {
        $VPNIP=$Route.Address+"/"+$Route.PrefixSize
        [array]$ARRVPN=$ARRVPN+$VPNIP
        }

    # In optimize address list only #
    $In_Opt_Only= $optimizeIpsv4 | Where {$ARRVPN -NotContains $_}

    # In VPN list only #
    $In_VPN_only =$ARRVPN | Where {$optimizeIpsv4 -NotContains $_}
    [array]$Inpfile = get-content $VPNprofilefile

    if ($In_Opt_Only.Count -gt 0 )
    {
        Write-Host "Exclusion route IP addresses are unknown, missing, or need to be updated in the VPN profile`n" -ForegroundColor Red

         [int32]$insline=0

            for ($i=0; $i -lt $Inpfile.count; $i++)
            {
                if ($Inpfile[$i] -match "</NativeProfile>")
                {
                $insline += $i # Record the position of the line after the NativeProfile section ends #
                }
            }
            $OFS = "`r`n"
                foreach ($NewIP in $In_Opt_Only)
                {
                    # Add the missing IP address(es) #
                    $IPInfo=$NewIP.Split("/")
                    $InpFile[$insline] += $OFS+"    <Route>"
                    $InpFile[$insline] += $OFS+"      <Address>"+$IPInfo[0].Trim()+"</Address>"
                    $InpFile[$insline] += $OFS+"      <PrefixSize>"+$IPInfo[1].Trim()+"</PrefixSize>"
                    $InpFile[$insline] += $OFS+"      <ExclusionRoute>true</ExclusionRoute>"
                    $InpFile[$insline] += $OFS+"    </Route>"
                }
             # Update fileName and write new PowerShell file #
             $NewFileName=(Get-Item $VPNprofilefile).Basename + "-NEW.ps1"
             $OutFile=$(Split-Path $VPNprofilefile -Parent)+"\"+$NewFileName
             $InpFile | Set-Content $OutFile
             Write-Host "Exclusion routes have been added to VPN profile and output to a separate PowerShell script file; the original file has not been modified`n" -ForegroundColor Green
    }else
    {
        Write-Host "Exclusion route IP addresses are correct and up to date in the VPN profile`n" -ForegroundColor Green
        $OutFile=$VPNprofilefile
    }

if ( $In_VPN_Only.Count -gt 0 )
{
    Write-Host "Unknown exclusion route IP addresses have been found in the VPN profile`n" -ForegroundColor Yellow

        foreach ($OldIP in $In_VPN_Only)
        {
            [array]$Inpfile = get-content $Outfile
            $IPInfo=$OldIP.Split("/")
            Write-Host "Unknown exclusion route IP address"$IPInfo[0]"has been found in the VPN profile - Do you wish to remove it? (Y/N)`n" -ForegroundColor Yellow
            $matchstr="<Address>"+$IPInfo[0].Trim()+"</Address>"
            $DelAns=Read-host
                if ($DelAns.ToUpper() -eq "Y")
                {
                    [int32]$insline=0
                        for ($i=0; $i -lt $Inpfile.count; $i++)
                        {
                            if ($Inpfile[$i] -match $matchstr)
                            {
                                $insline += $i # Record the position of the line for the string match #
                            }
                        }
                        # Remove entries from XML #
                        $InpFile[$insline-1]="REMOVETHISLINE"
                        $InpFile[$insline]="REMOVETHISLINE"
                        $InpFile[$insline+1]="REMOVETHISLINE"
                        $InpFile[$insline+2]="REMOVETHISLINE"
                        $InpFile[$insline+3]="REMOVETHISLINE"
                        $InpFile=$InpFile | Where-Object {$_ -ne "REMOVETHISLINE"}

                        # Update filename and write new PowerShell file #
                        $NewFileName=(Get-Item $VPNprofilefile).Basename + "-NEW.xml"
                        $OutFile=$(Split-Path $VPNprofilefile -Parent)+"\"+$NewFileName
                        $Inpfile | Set-content $OutFile
                        Write-Host "`nAddress"$IPInfo[0]"exclusion route has been removed from the VPN profile and output to a separate PowerShell script file; the original file has not been modified`n" -ForegroundColor Green

                }else
                {
                    Write-Host "`nExclusion route IP address has *NOT* been removed from the VPN profile`n" -ForegroundColor Green
                }
        }
 }
}

# Process XML file start #
if ($VPNprofilefile -ne "" -and $FileExtension -eq ".xml")
{
    Write-host "`nStarting XML file exclusion route check...`n" -ForegroundColor Cyan

    # Clear variables to allow re-run testing #
    $ARRVPN=$null              # Array to hold VPN addresses from the XML file #
    $In_Opt_Only=$null         # Variable to hold IP Addresses that only appear in optimize list #
    $In_VPN_Only=$null         # Variable to hold IP Addresses that only appear in the VPN profile XML file #  

    # Extract the Profile XML from the XML file #
    $regex = '(?sm).*^*.<VPNProfile>\r?\n(.*?)\r?\n</VPNProfile>.*'

    # Create xml format variable to compare with optimize list #
    $xmlbody=(Get-Content -Raw $VPNprofilefile) -replace $regex, '$1'
    [xml]$VPNRulesxml="$xmlbody"

        # Loop through each address found in VPNPROFILE file #
        foreach ($Route in $VPNRulesxml.VPNProfile.Route)
        {
            $VPNIP=$Route.Address+"/"+$Route.PrefixSize
            [array]$ARRVPN=$ARRVPN+$VPNIP
        }

    # In optimize address list only #
    $In_Opt_Only= $optimizeIpsv4 | Where {$ARRVPN -NotContains $_}

    # In VPN list only #
    $In_VPN_only =$ARRVPN | Where {$optimizeIpsv4 -NotContains $_}
    [System.Collections.ArrayList]$Inpfile = get-content $VPNprofilefile

        if ($In_Opt_Only.Count -gt 0 )
        {
            Write-Host "Exclusion route IP addresses are unknown, missing, or need to be updated in the VPN profile`n" -ForegroundColor Red

                foreach ($NewIP in $In_Opt_Only)
                {
                    # Add the missing IP address(es) #
                    $IPInfo=$NewIP.Split("/")
                    $routes += "<Route>`n"+"`t<Address>"+$IPInfo[0].Trim()+"</Address>`n"+"`t<PrefixSize>"+$IPInfo[1].Trim()+"</PrefixSize>`n"+"`t<ExclusionRoute>true</ExclusionRoute>`n"+"</Route>`n"
                }
            $inspoint = $Inpfile.IndexOf("</VPNProfile>")
            $Inpfile.Insert($inspoint,$routes)

            # Update filename and write new XML file #
            $NewFileName=(Get-Item $VPNprofilefile).Basename + "-NEW.xml"
            $OutFile=$(Split-Path $VPNprofilefile -Parent)+"\"+$NewFileName
            $InpFile | Set-Content $OutFile
            Write-Host "Exclusion routes have been added to VPN profile and output to a separate XML file; the original file has not been modified`n`n" -ForegroundColor Green

        }else
        {
            Write-Host "Exclusion route IP addresses are correct and up to date in the VPN profile`n" -ForegroundColor Green
            $OutFile=$VPNprofilefile
        }

        if ( $In_VPN_Only.Count -gt 0 )
        {
            Write-Host "Unknown exclusion route IP addresses found in the VPN profile`n" -ForegroundColor Yellow

            foreach ($OldIP in $In_VPN_Only)
            {
                [array]$Inpfile = get-content $OutFile
                $IPInfo=$OldIP.Split("/")
                Write-Host "Unknown exclusion route IP address"$IPInfo[0]"has been found in the VPN profile - Do you wish to remove it? (Y/N)`n" -ForegroundColor Yellow
                $matchstr="<Route>"+"<Address>"+$IPInfo[0].Trim()+"</Address>"+"<PrefixSize>"+$IPInfo[1].Trim()+"</PrefixSize>"+"<ExclusionRoute>true</ExclusionRoute>"+"</Route>"
                $DelAns=Read-host
                    if ($DelAns.ToUpper() -eq "Y")
                    {
                        # Remove unknown IP address(es) #
                        $inspoint = $Inpfile[0].IndexOf($matchstr)
                        $Inpfile[0] = $Inpfile[0].Replace($matchstr,"")

                        # Update filename and write new XML file #
                        $NewFileName=(Get-Item $VPNprofilefile).Basename + "-NEW.xml"
                        $OutFile=$(Split-Path $VPNprofilefile -Parent)+"\"+$NewFileName
                        $Inpfile | Set-content $OutFile
                        Write-Host "`nAddress"$IPInfo[0]"exclusion route has been removed from the VPN profile and output to a separate XML file; the original file has not been modified`n" -ForegroundColor Green

                    }else
                    {
                        Write-Host "`nExclusion route IP address has *NOT* been removed from the VPN profile`n" -ForegroundColor Green
                    }
            }
        }
}