@secure()
param kubeConfig string
param containerImage string
param replicas int
//param hops int

var namespaceName = 'zonetest'

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
    name: 'zone-test-fwd-0'
  }
  spec: {
    replicas: replicas
    selector: {
      matchLabels: {
        app: 'zone-test-fwd-0'
      }
    }
    template: {
      metadata: {
        labels: {
          app: 'zone-test-fwd-0'
        }
      }
      spec: {
        nodeSelector: {
          'beta.kubernetes.io/os': 'linux'
        }
        containers: [
          {
            name: 'zone-test-fwd-0'
            image: containerImage
            ports: [
              {
                containerPort: 80
              }
            ]
            resources: {
              requests: {
                cpu: '250m'
              }
              limits: {
                cpu: '500m'
              }
            }
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
            ]
          }
        ]
      }
    }
  }
}

resource zonetestService 'core/Service@v1' = {
  dependsOn: [ namespace ]
  metadata: {
    name: 'zone-test-fwd-0'
  }
  spec: {
    type: 'LoadBalancer'
    ports: [
      {
        port: 80
      }
    ]
    selector: {
      app: 'zone-test-fwd-0'
    }
  }
}
