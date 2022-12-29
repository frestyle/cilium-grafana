# Cilium and Prometheus Network Monitoring for Kubernetes

A project to set up a Kubernetes cluster with Cilium as the network CNI plugin, MetalLB for load balancing, and Prometheus for monitoring and metrics. The project also includes a script to enable the Hubble UI for real-time network traffic analysis.

Prerequisites

    Kubernetes 1.20 or higher
    Cilium 1.12 or higher
    MetalLB 0.9 or higher
    Helm 3 or higher

Installation

To install and set up the project, first run the registry.sh script to start a local registry:

```
./registry.sh
```

Then, run the install.sh script to create the Kind cluster and install the other components

```sh
./install.sh [CILIUM_VERSION] [INGRESS_VERSION] [METALLB_VERSION]

```

The install.sh script will install Cilium, MetalLB, and the NGINX ingress controller, and configure them to work together.

The Kind cluster is configured using the config/kind-config.yaml file, which sets up a local registry mirror and disables the default CNI plugin in favor of Cilium. It also sets the kubeProxyMode to none to allow Cilium to fully replace the cluster proxy.

By default, the script will install the latest versions of Cilium, the NGINX ingress controller, and MetalLB. You can specify specific versions by passing them as arguments to the script.


## Usage


Create a MetalLB load balancer service in your cluster, specifying the IP addresses that you want MetalLB to use for load balancing.

    It is important to ensure that the IP address range of the MetalLB pool matches the Docker subnet range of the Kind cluster. If the ranges do not match, it is possible that the MetalLB load balancer will not be able to reach the pods in the cluster, resulting in connectivity issues.

To check the Docker subnet range of the Kind cluster, you can run the following command:

```sh
$ docker network inspect kind
```


## Connecting to the Grafana UI

Once the Prometheus and Grafana addons have been deployed, you can access the Grafana UI to view the metrics of your cluster. To do this, you will need to port forward the Grafana service to your local machine.

To port forward the Grafana service, run the following command:


    $ kubectl -n cilium-monitoring port-forward svc/grafana 3000:3000

This will forward the Grafana service on port 3000 in the cilium-monitoring namespace to port 3000 on your local machine.

To access the Grafana UI, open a web browser and navigate to http://localhost:3000. You should see the Grafana dashboard.

In this deployment example, the Grafana service does not require a username and password to access the UI. 

    

Troubleshooting

If you encounter any issues while using the project:

    Make sure that cgroup v2 is enabled on the host operating system.
    Check the logs for the Cilium and MetalLB controllers for any error messages.
    If you are unable to access the Grafana dashboard, check the logs for the Prometheus and Grafana services to see if there are any issues.


The Hubble UI installation via the cilium helm chart appears to fail in the first attempt, with a message error.

    ```
    Unable to execute "kubectl port-forward -n kube-system svc/hubble-ui --address 0.0.0.0 --address :: 12000:80":
     Error from server (NotFound): services "hubble-ui" not found
    ```

you need to reinstall/upgrade the helm chart to enable Hubble UI by calling the helm upgrade function and using reuse-values flag

```
helm upgrade cilium cilium/cilium --version "$CILIUM_V" \
   --namespace kube-system \
   --reuse-values \
   --set hubble.relay.enabled=true \
   --set hubble.ui.enabled=true
```

Contribution guidelines

We welcome contributions to the project! If you would like to contribute, please follow these guidelines:

    Follow the project's code style and formatting standards.
    Write tests for any new features or bug fixes.
    Open a pull request with a clear description of your changes.

License

The project is licensed under the MIT License. See the LICENSE file for details.