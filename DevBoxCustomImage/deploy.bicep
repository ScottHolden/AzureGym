@description('The location all resources will be deployed to')
param location string = resourceGroup().location

@description('An array of additional regions to replicate images to')
param additionalLocations array = []

@description('A prefix to add to the start of all resource names. Note: A "unique" suffix will also be added')
param prefix string = 'devboxcustom'

@description('The name of the image to be created')
param imageName string = 'devboxCustImageDef'

@description('The name of the image publisher')
param imagePublisher string = 'myCompany'

@description('Tags to be applied to all deployed resources')
param tags object = {
  'Demo-Name': 'DevBoxCustomImage'
  'Demo-Repo': 'https://github.com/ScottHolden/AzureGym/DevBoxCustomImage'
}

var uniqueName = '${toLower(prefix)}${uniqueString(prefix, resourceGroup().id)}'

// Todo: make params
var imageOffer = 'devboxcustom'
var imageSku = '1-0-0'
var imageBuilderSku = 'Standard_DS2_v2'
var imageBuilderDiskSize = 127
var runOutputName = 'aibCustWinManImg01'

resource aibIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: uniqueName
  location: location
  tags: tags
}

// Todo: Make custom role not full contributor
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: resourceGroup()
  name: guid(aibIdentity.id, contributorRoleDefinition.id)
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: aibIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource computeGallery 'Microsoft.Compute/galleries@2022-03-03' = {
  name: uniqueName
  location: location
  properties: {}
  tags: tags

  resource image 'images@2022-03-03' = {
    name: imageName
    location: location
    properties: {
      features: [
        {
          name: 'SecurityType'
          value: 'TrustedLaunch'
        }
      ]
      identifier: {
        offer: imageOffer
        publisher: imagePublisher
        sku: imageSku
      }
      osState: 'Generalized'
      osType: 'Windows'
      hyperVGeneration: 'V2'
    }
    tags: tags
  }
}

resource imageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2022-02-14' = {
  name: uniqueName
  location: location
  properties: {
    buildTimeoutInMinutes: 100
    vmProfile: {
      vmSize: imageBuilderSku
      osDiskSizeGB: imageBuilderDiskSize
    }
    source: {
      type: 'PlatformImage'
      // Todo: Make this var/param
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'Windows-11'
      sku: 'win11-21h2-avd'
      version: 'latest'
    }
    // This is where we customise the image
    customize: [
      {
        type: 'PowerShell'
        name: 'Install Choco and Vscode'
        inline: [
          'Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString(\'https://community.chocolatey.org/install.ps1\'))"'
          'choco install -y vscode'
        ]
      }
    ]
    distribute: [
      {
        galleryImageId: computeGallery::image.id
        replicationRegions: concat([location], additionalLocations)
        runOutputName: runOutputName
        artifactTags: {
          source: 'azureVmImageBuilder'
          baseosimg: 'win11multi'
        }
        type: 'SharedImage'
      }
    ]
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aibIdentity.id}': {}
    }
  }
  tags: tags
}
