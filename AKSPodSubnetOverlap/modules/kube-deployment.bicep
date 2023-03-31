@secure()
param kubeConfig string
param containerImage string
param replicas int
param namespaceName string
param workloadName string
param clusterName string
param clusterId string

var plsName = 'pls-${guid(clusterId, namespaceName, workloadName)}'

import 'kubernetes@1.0.0' with {
  namespace: namespaceName
  kubeConfig: kubeConfig
}

resource namespace 'core/Namespace@v1' = {
  metadata: {
    name: namespaceName
  }
}

resource zonetestDeployment 'apps/Deployment@v1' = {
  dependsOn: [ namespace ]
  metadata: {
    name: workloadName
  }
  spec: {
    replicas: replicas
    selector: {
      matchLabels: {
        app: workloadName
      }
    }
    template: {
      metadata: {
        labels: {
          app: workloadName
        }
      }
      spec: {
        nodeSelector: {
          'beta.kubernetes.io/os': 'linux'
        }
        containers: [
          {
            name: workloadName
            image: containerImage
            ports: [
              {
                containerPort: 80
              }
            ]
            env: [
              {
                name: 'pod_name'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.name'
                  }
                }
              }
              {
                name: 'k8s_hostname'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'spec.nodeName'
                  }
                }
              }
              {
                name: 'cluster_name'
                value: clusterName
              }
            ]
          }
        ]
      }
    }
  }
}

resource zonetestServiceExternal 'core/Service@v1' = {
  dependsOn: [ namespace ]
  metadata: {
    name: '${workloadName}-external'
  }
  spec: {
    type: 'LoadBalancer'
    ports: [
      {
        port: 80
      }
    ]
    selector: {
      app: workloadName
    }
  }
}

resource zonetestServiceInternal 'core/Service@v1' = {
  dependsOn: [ namespace ]
  metadata: {
    name: '${workloadName}-internal'
    annotations: {
      'service.beta.kubernetes.io/azure-load-balancer-internal': 'true'
      'service.beta.kubernetes.io/azure-pls-create': 'true'
      'service.beta.kubernetes.io/azure-pls-name': plsName
    }
  }
  spec: {
    type: 'LoadBalancer'
    ports: [
      {
        port: 80
      }
    ]
    selector: {
      app: workloadName
    }
  }
}

resource zonetestServiceNodeId 'core/Service@v1' = {
  dependsOn: [ namespace ]
  metadata: {
    name: '${workloadName}-nodeport'
  }
  spec: {
    type: 'NodePort'
    ports: [
      {
        port: 80
      }
    ]
    selector: {
      app: workloadName
    }
  }
}

output internalServiceName string = zonetestServiceInternal.metadata.name
output privateLinkServiceName string = plsName
