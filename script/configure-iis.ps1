# IIS Installation
Install-WindowsFeature -name Web-Server -IncludeManagementTools

# Web page to verify the functioning
$hostname = $env:COMPUTERNAME
Set-Content -Path "C:\inetpub\wwwroot\iisstart.htm" -Value "<html><body><h1>Hello World from Azure Load Balancer!</h1><h2>Served by Server: <b>$hostname</b></h2></body></html>"