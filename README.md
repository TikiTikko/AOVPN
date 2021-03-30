# AOVPN
Always On VPN

999ik
.\Update-VPN-Profile-Office365-Exclusion-Routes.ps1 -VPNprofilefile "C:\temp\UserProfile.xml"

.\Get-VPNClientProfileXML.ps1 -ConnectionName 'Contoso VPN with Office 365 Exclusions' -xmlFilePath "C:\Temp\UserProfile.xml"

# Set Metric
$SetAOVPN = "Ethernet"
$SetMetric = "15"
# zuzr

$GetMetric = Get-NetIPInterface -InterfaceAlias $SetAOVPN -AddressFamily IPv4
$index = $GetMetric.ifIndex
Set-NetIPInterface -InterfaceIndex "$index" -InterfaceMetric $SetMetric
Get-NetIPInterface -InterfaceIndex "$index" -AddressFamily IPv4
