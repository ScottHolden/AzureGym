param location string = resourceGroup().location
param prefix string = 'AzVAmPI'

param vampiGitUrl string = 'https://github.com/erev0s/VAmPI.git'
param vampiOpenApiSpecUrl string = 'https://raw.githubusercontent.com/erev0s/VAmPI/master/openapi_specs/openapi3.yml'
param vampiImageName string = 'vampi'
param vampiImageTag string = 'v1-${uniqueString(utcNow())}'

param apimEmail string = 'noreply@microsoft.com'

var uniqueNameFormat = '${prefix}-{0}-${uniqueString(resourceGroup().id, prefix)}'
var uniqueShortNameFormat = toLower('${prefix}{0}${uniqueString(resourceGroup().id, prefix)}')
var vampiImageNameWithTag = '${vampiImageName}:${vampiImageTag}'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: format(uniqueShortNameFormat, 'acr')
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource buildTask 'Microsoft.ContainerRegistry/registries/taskRuns@2019-06-01-preview' = {
  name: uniqueString(vampiImageName)
  parent: containerRegistry
  properties: {
    forceUpdateTag: vampiImageTag
    runRequest: {
      type: 'DockerBuildRequest'
      dockerFilePath: 'Dockerfile'
      imageNames: [
        vampiImageNameWithTag
      ]
      isPushEnabled: true
      sourceLocation: vampiGitUrl
      platform: {
        os: 'Linux'
        architecture: 'amd64'
      }
      agentConfiguration: {
        cpu: 2
      }
    }
  }
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: format(uniqueNameFormat, 'Logs')
  location: location
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: format(uniqueNameFormat, 'AppIns')
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
  }
}

resource containerPullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: format(uniqueNameFormat, 'ACRPull')
  location: location
}

resource containerPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // ACR Pull
}

resource containerPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, containerPullIdentity.id, containerPullRoleDefinition.id)
  properties: {
    principalId: containerPullIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: containerPullRoleDefinition.id
  }
}

resource containerAppsEnv 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: format(uniqueNameFormat, 'ACAEnv')
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.properties.customerId
        sharedKey: workspace.listKeys().primarySharedKey
      }
    }
  }
}

resource vampiApp 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'vampi'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 5000
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: containerPullIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          image: '${containerRegistry.properties.loginServer}/${vampiImageNameWithTag}'
          name: 'vampi'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  identity: {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: {
      '${containerPullIdentity.id}': {}
    }
  }
  dependsOn: [
    buildTask
    containerPullRoleAssignment
  ]
}

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: format(uniqueNameFormat, 'APIM')
  location: location
  sku: {
    capacity: 1
    name: 'Developer'
  }
  properties: {
    publisherEmail: apimEmail
    publisherName: prefix
  }
  resource appInsightsLogger 'loggers@2022-04-01-preview' = {
    name: appInsights.name
    properties: {
      loggerType: 'applicationInsights'
      resourceId: appInsights.id
      credentials: {
        instrumentationKey: appInsights.properties.InstrumentationKey
      }
    }
  }
  resource diagnostics 'diagnostics@2022-04-01-preview' = {
    name: 'applicationinsights'
    properties: {
      alwaysLog: 'allErrors'
      loggerId: appInsightsLogger.id
      sampling: {
        percentage: 100
        samplingType: 'fixed'
      }
    }
  }
  resource vampiApi 'apis@2022-08-01' = {
    name: 'vampi'
    properties: {
      displayName: 'VAmPI'
      path: 'vampi'
      protocols: [
        'https'
      ]
      format: 'openapi-link'
      value: vampiOpenApiSpecUrl
      serviceUrl: 'https://${vampiApp.properties.configuration.ingress.fqdn}/'
    }
  }
}
