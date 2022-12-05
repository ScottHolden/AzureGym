# Multi Subnet AKS

[![Deploy To Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FScottHolden%2FAzureGym%2Fmain%2FMultiSubnetAKS%2Fgenerated-deploy.json)

## Description:

This demo deploys a VNet and an AKS Cluster with the following configuration:
- A dedicated system pool
- Multiple workload pools

Each of these node pools have a seperate node & pod subnet.

## Example deployment using default params:

- **VNet**: aksdemo-vnet-*xyz*
  - Address Space: `10.197.0.0/16`
  - Subnets:
    - aks-system-nodepool: `10.197.4.0/23`
    - aks-system-pods: `10.197.8.0/22`
    - aks-shared-nodepool: `10.197.64.0/23`
    - aks-shared-pods: `10.197.68.0/22`
    - aks-protected-nodepool: `10.197.72.0/23`
    - aks-protected-pods: `10.197.76.0/22`
- **AKS Cluster**: aksdemo-akscluster-*xyz*
  - Network mode & policy: `azure`
  - Node Pools:
    - system: 
      - Configured as `System` mode
      - `CriticalAddonsOnly=true:NoSchedule` taint
      - Nodes are connected to the *aks-system-nodepool* subnet
      - Pods are connected to the *aks-system-pods* subnet
    - shared
      - Configured as `User` mode
      - Nodes are connected to the *aks-shared-nodepool* subnet
      - Pods are connected to the *aks-shared-pods* subnet
    - protected
      - Configured as `User` mode
      - `Workload=protected:NoSchedule` taint
      - Nodes are connected to the *aks-protected-nodepool* subnet
      - Pods are connected to the *aks-protected-pods* subnet

*xyz in the examples above will be replaced with a unqiueString*

## Extra notes:
- Template build command: `az bicep build -f deploy.bicep --outfile generated-deploy.json`