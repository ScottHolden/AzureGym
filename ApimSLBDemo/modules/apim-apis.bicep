param apimName string
param appgwPrivateIp string
param slbPrivateIp string

var slbPath = 'slb'
var appgwPath = 'appgw'
var uiPath = 'ui'

var apiPolicy = loadTextContent('resources/apiPolicy.xml')
var uiPolicy = loadTextContent('resources/uiPolicy.xml')

var uiResponse = {
  statusCode: 200
  representations: [
    {
      contentType: 'text/html'
      examples: {
        default: {
          value: loadTextContent('resources/ui.html')
        }
      }
    }
  ]
}

resource apim 'Microsoft.ApiManagement/service@2021-08-01' existing = {
  name: apimName

  resource slbApi 'apis@2021-08-01' = {
    name: 'slbApi'
    properties: {
      displayName: 'SLB API'
      protocols: [
        'http'
        'https'
      ]
      path: slbPath
      serviceUrl: 'http://${slbPrivateIp}/'
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
      serviceUrl: 'http://${appgwPrivateIp}/'
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

output slbUIEndpoint string = '${apim.properties.gatewayUrl}/${slbPath}/${uiPath}'
output appgwUIEndpoint string = '${apim.properties.gatewayUrl}/${appgwPath}/${uiPath}'
