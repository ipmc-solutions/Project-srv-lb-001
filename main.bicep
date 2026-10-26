@description('Resource Region')
param location string = resourceGroup().location

@description('Administrator for the VM')
param adminUsername string = 'UserAdmin'

@description('Password for the Administrator of the VM')
@secure()
param adminPassword string

@description('Parameters of the VM')
param vmSize string = 'Standard_B2s'

// 1. Network Security Group (NSG)
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'NSG-srv-lb-001'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowRDPInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// 2. Virtual Network (VNet) & Subnet
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'VNet-srv-lb-001'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'Subnet-backend'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// 3. Public IP Address for the Load Balancer
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-srv-lb-001'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// 4. Azure Load Balancer Standard
resource loadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: 'LB-srv-lb-001'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontend'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPool'
      }
    ]
    probes: [
      {
        name: 'HTTPHealthProbe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'LBRuleHTTP'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'LB-srv-lb-001', 'LoadBalancerFrontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'LB-srv-lb-001', 'BackendPool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'LB-srv-lb-001', 'HTTPHealthProbe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}

// 5. Network Interfaces & Virtual Machines
var vmNames = [
  'srv-IIS-001'
  'srv-IIS-002'
]

resource nics 'Microsoft.Network/networkInterfaces@2023-09-01' = [for (name, i) in vmNames: {
  name: 'nic-${name}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          loadBalancerBackendAddressPools: [
            {
              id: loadBalancer.properties.backendAddressPools[0].id
            }
          ]
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2023-09-01' = [for (name, i) in vmNames: {
  name: name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
        }
      ]
    }
  }
}]

// 6. Custom Script Extension to install IIS and create the custom web page
resource customScript 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for (name, i) in vmNames: {
  name: '${name}/InstallIIS'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "Install-WindowsFeature -name Web-Server -IncludeManagementTools; $h = $env:COMPUTERNAME; $html = '<html><body><h1>Hello World from Azure Load Balancer!</h1><h2>Served by Server: <b>' + $h + '</b></h2></body></html>'; Out-File -FilePath C:\inetpub\wwwroot\iisstart.htm -InputObject $html -Encoding ascii -Force"'''
    }
  }
  dependsOn: [
    vms[i]
  ]
}]

// Final output: Public IP
output loadBalancerPublicIP string = publicIP.properties.ipAddress