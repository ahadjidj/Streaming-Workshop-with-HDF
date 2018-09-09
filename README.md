# Streaming-Workshop-with-HDF

# Contents
- [Introduction](#introduction) - Workshop Introduction
- [Use case](#use-case) - Building a 360 view for customers
- [Lab 1](#lab-1) - Cluster installation
  - Create an HDF 3.2 cluster
  - Access your cluster
- [Lab 2](#lab-2) - Platform preparation (admin persona)
  - Create schemas in Schema Registry
  - Create record readers and writters in NiFi
  - Create process groups and variables in NiFi
  - Create 

  
  ---------------
# Introduction

The objective of this workshop is to build an end to end streaming use case with HDF. This include edge collection, flow management and stream processing. A focus is also put on governance and best practices using tools such Schema Registry, Flow Registry and Variable Registry. At the end of the workshop, you will understand why HDF is a complete streaming platform that offers entreprise features to build, test and deploy any advanced streaming application. In addition, you will learn details on some of the new features brought by the latest HDF versions:
  - Use NiFi to ingest CDC data in real time
  - Use Record processors to benefit from improved performance and integration with schema registry
  - Route and filter data using SQL
  - Deploy and use MiNiFi agents with NiFi
  - Version flow developments and propagate flows from dev to prod
  - Integration between NiFi and Kafka to benefit from latest Kafka improvments (transactions, message headers, etc)
  - Test mode in Stream Analytics Manager to mock a streaming application before deploying it

# Use case

In this workshop, we will build a simplified streaming use case for a retail company. We will ingest data from MySQL Database and web apps logs to build a 360 view of a customer in realtime. This data can be stored on modern databases such as HDP or ElasticSearch to offer more scalability and agility compared to legacy DBs. Based on this two data streams, we will implement a fraud detection algorithm based on business rule. For instance, if a user update his account (for instance address) and buy an item that's expensive than his usual expenses, we may decide to investigate. This can be a sign that his account has been hacked and used to buy an expensive item that will be shipped to a new address. The following picture explains the high level architecture of the use case.

Image to add

# Lab 1

## Create an HDF 3.2 cluster

For the coming labs, we will install a one node HDF cluster with NiFi, NiFi Registry, Kafka, Storm, Schema Registry and Stream Analytics Manager. We will use field cloud for this workshop but the instructions will work for any cloud provider (AWS for instance).

  - Connect to your OpenStack account on field cloud and create a VM with 16 GB of RAM (this corresponds to a m3.xlarge instance). Keep the default parameters and num_vms to 1. Note the stack name that you defined as it will be used to access to your cluster. Let's assume that your stack name is hdfcluster.
  - SSH to your cluster using the field PEM key ``` ssh -i field.pem centos@hdfcluster0.field.hortonworks.com ```
  - Launch the cluster install using with the following instruction
  ```
  curl -sSL https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/scripts/install_hdf3-2_cluster.sh | sudo -E sh
  ```
This instruction downloads and runs a script that initialize install a MySQL Database, ElasticSearch, MiNiFi, Ambari agent and server,  HDF MPack and HDF services required for this workshop. Cluster installation will take about 10 minutes.

## Access your Cluster

  - When the script finishes the work, login to Ambari web UI by opening http://{YOUR_IP}:8080 and log in with **admin/StrongPassword**
  - Open the different UI and check that all services are running and are healthy (NiFi, NiFi Registry, SR, SAM, etc)
  - Connect to the MySQL DB using bash or tools like MySQLWorkbench. A workshop DB has been created for the lab. You have also two users:
    - **root/StrongPassword** usable from localhost only
    - **workshop/StrongPassword** usable from remote and has full privileges on the workshop DB 
    
# Lab 2

To enforce best practices and a minimal governance, there are few tasks that an admin should do before granting access to the platform. These tasks include:
  - Defining users roles and previliges on each tool (SAM, NiFi, Etc)
  - Define the schemas of events that we be used. This avoid having developpers using their own schemas making applications integration and evolution a real nightmare.
  - Define and enforce naming convention that make easier managing applications lifecycle (eg. NiFi PG and processors names)
  - Define global variables that should be used to make application migration between environment simple
  - etc

In this lab, we will implement some of these best practices to set the right environnement for our developments.

## Create schemas in Schema Registry

In this workshop, we will manipulate three type of events.

### Customer events

These events are data coming from the MySQL DB through the CDC layer. Each event has different fields describing the customer (id, first name, last name, etc). To declare this schema, go to Schema Registry and add a new schema with these details:
  - Name: customers
  - Descrption: schema for CDC events
  - Type: Avro Schema Provider
  - Schema Group: Kafka
  - Compatibility: both
  - Evolve: true
 
For the schema text, use the following Avro description, also available [here](https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/schemas/customers.asvc)
 
  ```
{
  "type": "record",
  "name": "customers",
  "fields" : [
    {"name": "id", "type": "int"},
    {"name": "first_name", "type": ["null", "string"]},
    {"name": "last_name", "type": ["null", "string"]},
    {"name": "gender", "type": ["null", "string"]},
    {"name": "phone", "type": ["null", "string"]},   
    {"name": "email", "type": ["null", "string"]},    
    {"name": "countrycode", "type": ["null", "string"]},
    {"name": "country", "type": ["null", "string"]},
    {"name": "city", "type": ["null", "string"]},
    {"name": "state", "type": ["null", "string"]},
    {"name": "address", "type": ["null", "string"]},
    {"name": "zipcode", "type": ["null", "string"]},
    {"name": "ssn", "type": ["null", "string"]},
    {"name": "timezone", "type": ["null", "string"]},
    {"name": "currency", "type": ["null", "string"]},
    {"name": "averagebasket", "type": ["null", "int"]}
  ]
} 
  ```
### Logs events

These events are data coming from Web Application through the MiNiFi agents deployed on application servers. Each event, describe a customer browsing behavior on a webpage. The provided informations are the customer id, the product page being consulted, session duration and if the customer bought the product at the end of the session or not. To declare this schema, go to Schema Registry and add a new schema with these details:
  - Name: logs
  - Descrption: schema for logs events
  - Type: Avro Schema Provider
  - Schema Group: Kafka
  - Compatibility: both
  - Evolve: true
 
 For the schema text, use the following Avro description, also available [here](https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/schemas/logs.asvc)
 
  ```
{
  "type": "record",
  "name": "logs",
  "fields" : [
    {"name": "id", "type": "int"},
    {"name": "product", "type": ["null", "string"]},
    {"name": "sessionduration", "type": ["null", "int"]},
    {"name": "buy", "type": ["null", "boolean"]},
    {"name": "price", "type": ["null", "int"]}
  ]
}
  ```
We need also to define another logs event (logs_view) that conains only the product browsing session information with the buy and price fields.

  ```
{
  "type": "record",
  "name": "logs",
  "fields" : [
    {"name": "id", "type": "int"},
    {"name": "product", "type": ["null", "string"]},
    {"name": "sessionduration", "type": ["null", "int"]}
  ]
}
  ```
### Alerts events

At the end of the workshop, we will use the different events to detect eventual frauds. If a fraud is detected, we will send an event to inform an application or a supervisor. To achieve this, we need a new schema for these events. To declare this schema, go to Schema Registry and add a new schema with these details:
  - Name: alerts
  - Descrption: schema for alerts events
  - Type: Avro Schema Provider
  - Schema Group: Kafka
  - Compatibility: both
  - Evolve: true
 
For the schema text, use the following Avro description, also available [here](https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/schemas/alerts.asvc)
 
  ```
{
  "type": "record",
  "name": "alerts",
  "fields" : [
    {"name": "_id", "type": "int"},
    {"name": "price", "type": ["null", "int"]},
    {"name": "first_name", "type": ["null", "string"]},
    {"name": "last_name", "type": ["null", "string"]},
    {"name": "averagebasket", "type": ["null", "int"]}
  ]
}
  ```
## Create record readers and writters in NiFi

To use these schema in NiFi, we will leverage record based processor. These processors use record readers and writter to benefit from improved performances and schemas defined globally in a Schema Registry. Our sources (MySQL CDC event and Web App logs) generate data in JSON format so we will need a JSON reader to deserialise data. We will store this data in ElasticSearch and publish it to Kafka. Hence, we need JSON and Avro writters to serialize the data. To add a reader/writter accessible by all our NiFi flows, navigate to the canvas, click on Configure, Controller service and click on "+" button.

### Add a HortonworksSchemaRegistry
Before adding any record reader/writter, we need to add a Hortonworks Schema Registry to tell NiFi where to look for schemas definition. Add a HortonworksSchemaRegistry controller and congure it with your SR URL as show below:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/HortonworksSchemaRegistry.png)

### Add JsonTreeReader
To deserialize any JSON data for which we have a schema, add a JsonTreeReader and configure it as shown below. Note the that the **Schema Access Strategy** is set to **Use 'Schema Name' Property**. This means that flow files going through this serializer must have an attribute **schema.name** that specifies the name of the schema that should be used.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/JsonTreeReader.png)

### Add JsonRecordSetWriter
To serialize JSON data for which we have a defined schema, add a JsonRecordSetWriter and configure it as shown below.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/JsonRecordSetWriter.png)

### Add AvroRecordSetWriter
Event collected by NiFi will be published to Kafka for further consumption. In the second use case, we will use SAM to analyse data in realtime and detect potential frauds. SAM expects event to be in Avro format with the first byte containing an encoded schema reference. To prepare data for SAM consumption, we need to add AvroRecordSetWriter and set **Schema Write Strategy** to **HWX Content-Encoded Schema Reference** as shown below:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/AvroRecordSetWriter.png)

## Create process groups and variables in NiFi
