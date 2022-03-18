param location string = resourceGroup().location
param prefix string = 'demo'
param publisherEmail string = 'no-reply@microsoft.com'
param vmSku string = 'Standard_D2s_v4'
param vmUsername string = 'demovm'
param vmPassword string = 'Pw${uniqueString(newGuid())}!'
param vmCount int = 6

var uniqueName = '${prefix}${uniqueString(resourceGroup().id, prefix)}'
var addressSpace = '10.250.0.0/16'

var slbName = uniqueName

var apimSubnetName = 'apim'
var apimSubnetPrefix = '10.250.1.0/24'
var backendSubnetName = 'backend'
var backendSubnetPrefix = '10.250.2.0/24'
var backendSLB = '10.250.2.250'
var appGwSubnetName = 'appgw'
var appGwSubnetPrefix = '10.250.3.0/24'
var backendAppGw = '10.250.3.250'
var backendPoolName = 'backendPool'
var probeName = 'httpProbe'
var appGwName = uniqueName

var slbPath = 'slb'
var appgwPath = 'appgw'
var uiPath = 'ui'

var vmssScript = base64('''
#!/bin/bash
apt update -y
apt install nginx -y
curl -H Metadata:true --noproxy "*" -o /var/www/html/id.txt "http://169.254.169.254/metadata/instance/compute/name?api-version=2021-01-01&format=text"
''')

var apiPolicy = '''
<policies>
    <inbound>
        <base />
        <rewrite-uri template="id.txt" />
        <set-header name="Ocp-Apim-Subscription-Key" exists-action="delete" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
'''

var uiPolicy = '''
<policies>
    <inbound>
        <mock-response status-code="200" content-type="text/html" />
        <base />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
'''

var uiResponse = {
  statusCode: 200
  representations: [
    {
      contentType: 'text/html'
      examples: {
        default: {
          value: '''
<!DOCTYPE html><html><head><title>API Query Graph</title>
<style>#graph,#log,body,html{padding:0;margin:0}body,html{width:100%;height:100%;overflow:hidden}#graph,#log{width:100vw;height:100%}#graph{background-color:#ccc}#log{background-color:#999;overflow-y:scroll}</style>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head><body><canvas id="graph"></canvas><pre id="log"></pre>
<script>
const counts = {}; const logPre = document.getElementById("log");
const colors = Array.from({ length: 6 }, () => [[255, 99, 132], [255, 159, 64], [255, 205, 86], [75, 192, 192], [153, 102, 255]]).flat();
const graph = new Chart(document.getElementById('graph'), { type: 'bar', data: { labels: [],datasets: [{data: [],borderWidth: 1,backgroundColor: colors.map(x => "rgba(" + x + ",0.4)"),borderColor: colors.map(x => "rgb(" + x + ")"),}]},});
const timePrefix = () => " [" + new Date().toLocaleString().replace(',', '') + "]  ";
const log = x => logPre.innerText = timePrefix() + x + "\n" + logPre.innerText;
const logError = x => log("Error: " + x);
const update = x => {
    const id = counts[x] ?? (counts[x] = graph.data.labels.length)
    graph.data.datasets[0].data[id] = (graph.data.datasets[0].data[id] ?? 0) + 1;
    graph.data.labels[id] = x;
    graph.update();
}
const run = () => fetch('backend?t=' + Date.now())
    .then(x => x.ok ? x.text() : Promise.reject(x.status))
    .then(x => { log(x); update(x); })
    .catch(logError);
const interval = Math.max(50, parseInt(new URLSearchParams(window.location.search).get('s') ?? 100));
setInterval(run, interval);
</script>
</body>
</html>
'''
        }
      }
    }
  ]
}

resource vnet 'Microsoft.Network/virtualNetworks@2019-09-01' = {
  name: uniqueName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    subnets: [
      {
        name: apimSubnetName
        properties: {
          addressPrefix: apimSubnetPrefix
          networkSecurityGroup: {
            id: apimNSG.id
          }
        }
      }
      {
        name: backendSubnetName
        properties: {
          addressPrefix: backendSubnetPrefix
          networkSecurityGroup: {
            id: defaultNSG.id
          }
          natGateway: {
            id: natGateway.id
          }
        }
      }
      {
        name: appGwSubnetName
        properties: {
          addressPrefix: appGwSubnetPrefix
        }
      }
    ]
  }
}

resource natPIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${uniqueName}-nat'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2021-05-01' = {
  name: uniqueName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natPIP.id
      }
    ]
  }
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: uniqueName
  location: location
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: uniqueName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
  }
}
/*
resource networkWatcher 'Microsoft.Network/networkWatchers@2021-02-01' = {
  name: uniqueName
  location: location
  properties: {}
  resource flowLogsDefaultNSG 'flowLogs@2021-05-01' = {
    name: 'flowLogsDefaultNSG'
    properties: {
      targetResourceId: defaultNSG.id
      storageId: flowStorage.id
      enabled: true
      retentionPolicy: {
        days: 5
        enabled: true
      }
      format: {
        type: 'JSON'
        version: 2
      }
      flowAnalyticsConfiguration: {
        networkWatcherFlowAnalyticsConfiguration: {
          enabled: true
          workspaceResourceId: workspace.id
          trafficAnalyticsInterval: 10
        }
      }
    }
  }
  resource flowLogsApimNSG 'flowLogs@2021-05-01' = {
    name: 'flowLogsApimNSG'
    properties: {
      targetResourceId: apimNSG.id
      storageId: flowStorage.id
      enabled: true
      retentionPolicy: {
        days: 5
        enabled: true
      }
      format: {
        type: 'JSON'
        version: 2
      }
    }
  }
}
*/
resource storage 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: uniqueName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource defaultNSG 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: uniqueName
  location: location
  properties: {
    securityRules: []
  }
}

resource apimNSG 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: '${uniqueName}-apim'
  location: location
  properties: {
    securityRules: [
      {
        name: 'apim'
        properties: {
          priority: 320
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '80'
            '443'
            '3443'
            '6390'
          ]
        }
      }
    ]
  }
}

resource apimPIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${uniqueName}-apim'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: uniqueName
    }
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: uniqueName
  location: location
  sku: {
    capacity: 1
    name: 'Developer'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: uniqueName
    publicIpAddressId: apimPIP.id
    virtualNetworkType: 'External'
    virtualNetworkConfiguration: {
      subnetResourceId: '${vnet.id}/subnets/${apimSubnetName}'
    }
  }
  resource appins 'loggers@2021-08-01' = {
    name: 'appins'
    properties: {
      loggerType: 'applicationInsights'
      credentials: {
        instrumentationKey: applicationInsights.properties.InstrumentationKey
      }
    }
  }
  resource slbApi 'apis@2021-08-01' = {
    name: 'slbApi'
    properties: {
      displayName: 'SLB API'
      protocols: [
        'http'
        'https'
      ]
      path: slbPath
      serviceUrl: 'http://${backendSLB}/'
      subscriptionRequired: false
    }
    resource slbApiGet 'operations@2021-08-01' = {
      name: 'slbApiGet'
      properties: {
        method: 'get'
        urlTemplate: '/backend'
        displayName: 'Get Backend ID'
      }
      resource policy 'policies@2021-08-01' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: apiPolicy
        } 
      }
    }
    resource slbUiGet 'operations@2021-08-01' = {
      name: 'slbUiGet'
      properties: {
        method: 'get'
        urlTemplate: '/${uiPath}'
        displayName: 'Get UI'
        responses: [
          uiResponse
        ]
      }
      resource policy 'policies@2021-08-01' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: uiPolicy
        } 
      }
    }
  }
  resource appgwApi 'apis@2021-08-01' = {
    name: 'appgwApi'
    properties: {
      displayName: 'AppGW API'
      protocols: [
        'http'
        'https'
      ]
      path: appgwPath
      serviceUrl: 'http://${backendAppGw}/'
      subscriptionRequired: false
    }
    resource appgwApiGet 'operations@2021-08-01' = {
      name: 'appgwApiGet'
      properties: {
        method: 'get'
        urlTemplate: '/backend'
        displayName: 'Get Backend ID'
      }
      resource policy 'policies@2021-08-01' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: apiPolicy
        } 
      }
    }
    resource appgwUiGet 'operations@2021-08-01' = {
      name: 'appgwUiGet'
      properties: {
        method: 'get'
        urlTemplate: '/${uiPath}'
        displayName: 'Get UI'
        responses: [
          uiResponse
        ]
      }
      resource policy 'policies@2021-08-01' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: uiPolicy
        } 
      }
    }
  }
}

resource appgwPIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${uniqueName}-appgw'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource appGw 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: appGwName
  location: location
  properties: {
    enableHttp2: false
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${appGwSubnetName}'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: appgwPIP.id
          }
        }
      }
      {
        name: 'appGwFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: backendAppGw
          subnet: {
            id: '${vnet.id}/subnets/${appGwSubnetName}'
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'http'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
        properties: {}
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'http'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          protocol: 'Http'
          requireServerNameIndication: false
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, 'appGwFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'http')
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'httpRouting'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, backendPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'http')
          }
        }
      }
    ]
  }
}

resource slb 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: slbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'internal'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${backendSubnetName}'
          }
          privateIPAddressVersion: 'IPv4'
          privateIPAllocationMethod: 'Static'
          privateIPAddress: backendSLB
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
      }
    ]
    probes: [
      {
        name: probeName
        properties: {
          port: 80
          protocol: 'Tcp'
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'http'
        properties: {
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 4
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', slbName, probeName)
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', slbName, 'internal')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', slbName, backendPoolName)
          }
        }
      }
    ]
  }
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-03-01' = {
  name: uniqueName
  location: location
  sku: {
    name: vmSku
    capacity: vmCount
  }
  properties: {
    overprovision: false
    singlePlacementGroup: false
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          osType: 'Linux'
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
          diskSizeGB: 30
        }
        imageReference: {
          publisher: 'canonical'
          offer: '0001-com-ubuntu-server-focal'
          sku: '20_04-lts-gen2'
          version: 'latest'
        }
      }
      osProfile: {
        computerNamePrefix: 'chaosvmss'
        adminUsername: vmUsername
        adminPassword: vmPassword
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
          storageUri: storage.properties.primaryEndpoints.blob
        }
      }
      extensionProfile: {
        extensions: [
          {
            name: 'CustomScript'
            properties: {
              type: 'CustomScript'
              publisher: 'Microsoft.Azure.Extensions'
              typeHandlerVersion: '2.0'
              autoUpgradeMinorVersion: true
              settings: {
                script: vmssScript
              }
            }
          }
          {
            name: 'OMSExtension'
            properties: {
              type: 'OmsAgentForLinux'
              publisher: 'Microsoft.EnterpriseCloud.Monitoring'
              typeHandlerVersion: '1.13'
              settings: {
                workspaceId: workspace.properties.customerId
              }
              protectedSettings: {
                workspaceKey: workspace.listKeys().primarySharedKey
              }
            }
          }
        ]
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${uniqueName}-nic'
            properties: {
              primary: true
              enableAcceleratedNetworking: true
              networkSecurityGroup: {
                id: defaultNSG.id
              }
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    primary: true
                    subnet: {
                      id: '${vnet.id}/subnets/${backendSubnetName}'
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: '${slb.id}/backendAddressPools/${backendPoolName}'
                      }
                    ]
                    applicationGatewayBackendAddressPools: [
                      {
                        id: '${appGw.id}/backendAddressPools/${backendPoolName}'
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

output slbUIEndpoint string = '${apim.properties.gatewayUrl}/${slbPath}/${uiPath}'
output appgwUIEndpoint string = '${apim.properties.gatewayUrl}/${appgwPath}/${uiPath}'
