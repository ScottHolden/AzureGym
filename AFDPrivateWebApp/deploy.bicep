@description('Name to be used for the AFD profile')
param profileName string = 'AFDTest'

@description('The full resource ID of the AppService/WebApp')
param appServiceID string = '/subscriptions/<subid>/resourceGroups/<rgname>/providers/Microsoft.Web/sites/<webappname>'

@description('The origin URL of the AppService/WebApp')
param appServiceUrl string = '<webappname>.azurewebsites.net'

@description('AppService/WebApp region')
param appServiceRegion string = 'AustraliaEast'


resource profile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: profileName
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }

  resource endpoint 'afdEndpoints@2021-06-01' = {
    name: 'DemoEndpoint'
    location: 'global'
    properties: {
      enabledState: 'Enabled'
    }

    resource route 'routes@2021-06-01' = {
      name: 'Default'
      properties: {
        originGroup: {
          id: originGroup.id
        }
        supportedProtocols: [
          'Http'
          'Https'
        ]
        patternsToMatch: [
          '/*'
        ]
        cacheConfiguration: {
          queryStringCachingBehavior: 'IgnoreQueryString'
        }
        forwardingProtocol: 'HttpsOnly'
        linkToDefaultDomain: 'Enabled'
        httpsRedirect: 'Enabled'
      }
      dependsOn: [
        originGroup::origin
      ]
    }
  }

  resource originGroup 'originGroups@2021-06-01' = {
    name: 'WebAppOrigin'
    properties: {
      loadBalancingSettings: {
        sampleSize: 4
        successfulSamplesRequired: 3
      }
      healthProbeSettings: {
        probePath: '/'
        probeRequestType: 'HEAD'
        probeProtocol: 'Http'
        probeIntervalInSeconds: 100
      }
    }

    resource origin 'origins@2021-06-01' = {
      name: 'WebApp'
      properties: {
        hostName: appServiceUrl
        httpPort: 80
        httpsPort: 443
        originHostHeader: appServiceUrl
        priority: 1
        weight: 1000
        sharedPrivateLinkResource: {
          privateLink: {
            id: appServiceID
          }
          groupId: 'sites'
          privateLinkLocation: appServiceRegion
          requestMessage: 'AFD Test'
        }
      }
    }
  }
}
