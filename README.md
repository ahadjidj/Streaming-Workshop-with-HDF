# Streaming-Workshop-with-HDF

# Contents
- [Lab 1](#lab-1) - Workshop preparation
  - Create an HDF 3.2 cluster
  - Access your cluster

  
  ---------------

# Lab 1

## Create an HDF 3.2 cluster

For this workshop, we will install a one node HDF cluster with NiFi, NiFi Registry, Kafka, Storm, Schema Registry and Stream Analytics Manager. We will use field cloud for this workshop but the instructions will work for any cloud provider (AWS for instance).

- Connect to your OpenStack account on field cloud and create a VM with 16 GB of RAM (this corresponds to a m3.xlarge instance). Keep the default parameters and num_vms to 1. Note the stack name that you defined as it will be used to access to your cluster. Let's assume that your stack name is hdfcluster.
- SSH to your cluster using the field PEM key ``` ssh -i field.pem centos@hdfcluster0.field.hortonworks.com ```
- Launch the cluster install using with the following instruction
  ```
  curl -sSL https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/scripts/install_hdf3-2_cluster.sh | sudo -E sh
  ```
This instruction downloads and runs a script that initialize install a MySQL Database, Ambari agent and server, HDF MPack and HDF services required for this workshop. Cluster installation will take about 10 minutes. 

## Access your Cluster

- When the script finishes the work, login to Ambari web UI by opening http://{YOUR_IP}:8080 and log in with **admin/StrongPassword**

- Open the different UI and check that all services are running and are healthy (NiFi, NiFi Registry, SR, SAM
