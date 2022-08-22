param prefix string = 'dumpdemo'
param location string = resourceGroup().location
param adminLogin string = 'demo'
@secure()
param adminPassword string = 'D3moP@ssword1!'

var uniqueName = '${prefix}${uniqueString(resourceGroup().id, prefix)}'
var fileShareName = 'backups'
var volumeName = 'backup'
var dbName = 'sampledb'

// Create a PostreSQL Server for us to test with, and add a DB
resource dbServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-01-20-preview' = {
  name: uniqueName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '13'
    storage: {
      storageSizeGB: 32
    }
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
  }
  resource firewall 'firewallRules' = {
    name: 'AllAzure'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }
  resource db 'databases@2022-01-20-preview' = {
    name: dbName
    properties: {
    }
  }
}

// Create a Storage Account to store the backups
resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: uniqueName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// File share within the Storage Account
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  name: '${storage.name}/default/${fileShareName}'
}

// Create an Azure Container Instance that will run our backup
//  This uses the public postgres container image which contains pg_dump
//  We attach the file share as a mounted volume, and only restart the container on failure
resource aci 'Microsoft.ContainerInstance/containerGroups@2021-10-01' = {
  name: uniqueName
  location: location
  properties: {
    restartPolicy: 'OnFailure'
    containers: [
      {
        name: 'backup'
        properties: {
          image: 'postgres:13.8-alpine'
          command: [
            '/bin/bash'
            '-c'
            'pg_dump -U ${adminLogin} -h ${dbServer.properties.fullyQualifiedDomainName} -Fc -f "/backup/${dbName}-$(date +"%FT%H%M").dump" ${dbName}'
          ]
          environmentVariables: [
            {
              name: 'PGPASSWORD'
              secureValue: adminPassword
            }
          ]
          volumeMounts: [
            {
              name: volumeName
              mountPath: '/backup'
              readOnly: false
            }
          ]
          resources: {
            requests: {
              cpu: 2
              memoryInGB: 8
            }
          }
        }
      }
    ]
    osType: 'Linux'
    volumes: [
      {
        name: volumeName
        azureFile: {
          shareName: fileShareName
          storageAccountName: storage.name
          storageAccountKey: storage.listKeys('2021-09-01').keys[0].value
          readOnly: false
        }
      }
    ]
  }
  dependsOn: [
    fileShare
    dbServer::db
    dbServer::firewall
  ]
}

// Logic App for scheduled triggers
resource logicapp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: uniqueName
  location: location
  properties: {
    parameters: {
      '$connections': {
        value: {
          arm: {
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'arm')
            connectionId: armConnection.id
            connectionName: 'arm'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
          }
        }
      }
    }
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          type: 'Object'
        }
      }
      triggers: {
        Recurrence: {
          recurrence: {
              frequency: 'Minute'
              interval: 15
          }
          type: 'Recurrence'
        }
      }
      actions: {
        StartPGDumpACI: {
          inputs: {
              host: {
                  connection: {
                      name: '@parameters(\'$connections\')[\'arm\'][\'connectionId\']'
                  }
              }
              method: 'post'
              path: '/subscriptions/@{encodeURIComponent(\'${subscription().subscriptionId}\')}/resourcegroups/@{encodeURIComponent(\'${resourceGroup().name}\')}/providers/@{encodeURIComponent(\'Microsoft.ContainerInstance\')}/@{encodeURIComponent(\'containerGroups/${aci.name}\')}/@{encodeURIComponent(\'start\')}'
              queries: {
                  'x-ms-api-version': '2021-10-01'
              }
          }
          type: 'ApiConnection'
        }
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// ARM connection for logic app
#disable-next-line BCP081
resource armConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: 'arm'
  location: location
  properties: {
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'arm')
    }
    displayName: 'arm'
    parameterValueType: 'Alternative'
    alternativeParameterValues: {}
  }
}

// Create a role for starting ACI
resource startRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(uniqueName)
  properties: {
    roleName: 'Start ACI - ${uniqueName}'
    type: 'customRole'
    assignableScopes: [
      resourceGroup().id
    ]
    permissions: [
      {
        actions: [
          'Microsoft.ContainerInstance/*/read'
          'Microsoft.ContainerInstance/containerGroups/start/action'
          'Microsoft.ContainerInstance/containerGroups/stop/action'
          'Microsoft.ContainerInstance/containerGroups/restart/action'
        ]
      }
    ]
  }
}

// Setup RBAC permissions for Logic App to start the ACI Container Group
resource startRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(startRole.id, logicapp.id, aci.id)
  scope: aci
  properties: {
    principalId: logicapp.identity.principalId
    roleDefinitionId: startRole.id
    principalType: 'ServicePrincipal'
  }
}
