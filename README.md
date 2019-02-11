# Streaming-Workshop-with-HDF

# Contents
- [Introduction](#introduction) - Workshop Introduction
- [Use case](#use-case) - Building a 360 view for customers
- [Lab 1](#lab-1) - Cluster installation
  - Create an HDF 3.2 cluster
  - Access your cluster
- [Lab 2](#lab-2) - Simple flow management
- [Lab 3](#lab-3) - Platform preparation (admin persona)
  - Create schemas in Schema Registry
  - Create record readers and writters in NiFi
  - Create process groups and variables in NiFi
  - Create events topics in Kafka
  - Create bucket in NiFi Registry
- [Lab 4](#lab-4) - MySQL CDC data ingestion (DataEng persona)
  - Configure MySQL to enable binary logs
  - Ingest and format data in NiFi
  - Store events in ElasticSearch
  - Publish update events in Kafka
- [Lab 5](#lab-5) - Version flow in NiFi Registry (DataEng persona)
- [Lab 6](#lab-6) - Logs data collection with MiNiFi(DataEng persona)
  - Design MiNiFi pipeline
  - Deploy MiNiFi agent
  - Deploy MiNiFi pipeline 
  - Design NiFi pipeline
- [Lab 7](#lab-7) - TODO Fraud detection with Kafka Streams (Dev persona)
- [Lab 7](#lab-7) - TODO Realtime analytics with Kudu/Impala (Analyst persona)

  ---------------
# Introduction

The objective of this workshop is to build an end to end streaming use case with HDF. This includes edge collection, flow management and stream processing. A focus is also put on governance and best practices using tools such Schema Registry, Flow Registry and Variable Registry. At the end of the workshop, you will understand why HDF is a complete streaming platform that offers entreprise features to build, test and deploy any advanced streaming application. In addition, you will learn details on some of the new features brought by the latest HDF versions:
  - Use NiFi to ingest CDC data in real time
  - Use Record processors to benefit from improved performance and integration with schema registry
  - Route and filter data using SQL
  - Version flow developments and propagation from dev to prod
  - Integration between NiFi and Kafka to benefit from latest Kafka improvements (transactions, message headers, etc)
  - Deploy and use MiNiFi agents


# Use case
In this workshop, we will build a simplified streaming use case for a retail company. We will ingest customer data from MySQL Database and web apps logs from web applications to build a 360 view of a customer in real-time. This data can be stored on modern datastores such as HBase, Kudu or ElasticSearch depending on the use case.

Based on these two data streams, we can implement a fraud detection algorithm in real time. For instance, if a user updates his account (ex postal address) and buys an item that's more expensive than its average purchase, we may decide to investigate. This can be a sign that his account has been hacked and used to buy an expensive item that will be shipped to a new address. The following picture explains the high level architecture of the use case. 

For today's lab, we have only 2h30 so we will focus only on the platform and flow management parts. You can come back to this lab later to work on the edge collection, stream processing or analytics parts.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/use_cases.png)

# Lab 1 

## Create an HDF 3.2 cluster

For this workshop, we will use a one-node HDF cluster with NiFi, NiFi Registry, Kafka, Storm, Schema Registry and Stream Analytics Manager on AWS. These HDF clusters have been previsioned for you. We will work in groups of two SEs. Go to this Google spreadsheet and add your names to one of the available clusters: https://docs.google.com/spreadsheets/d/1SYs7jPPsiMl7pAU14dx_ALenkp1X1YARPmHiKmQqb3w/edit#gid=0

To access your cluster with SSH, you should use the field PEM key available here https://drive.google.com/drive/folders/1B5GpIfg_WTlWFavSokqN41CvFoEYZNIL

Download the field key, change its persmission (chmod 400 field.pem) and connect to the cluster:
``` ssh -i .ssh/field.pem centos@ip ```

If you would like to create your own cluster (for this lab or later), you can follow the instructions below
  - Connect to your AWS account and create a CentOs 7 VM with at least 16 GB of RAM (ex: m4.xlarge instance)
  - Make sure to add at least 150GB of storage to the VM
  - Add tags to your VM as per AWS expense policy : owner, business justification and end date(if applicable)
  - Open ports required for the lab : 22 (SSH), 8080 (Ambari), 9090 (NiFi), 7788 (SR), 61080 (NiFi Registry), 3306 (MySQL)
  - Make sure to create and download an SSH key
  - Once your VM is ready, SSH to your cluster using your PEM key ``` ssh -i field.pem centos@ip ```
  - Launch the cluster install using the following instruction
  ```
  curl -sSL https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/scripts/install_hdf3-2_cluster.sh | sudo -E sh
  ```
This scripts installs a MySQL Database, ElasticSearch, MiNiFi, Ambari agent and server, HDF MPack and HDF services required for this workshop. Cluster installation will take about 10 minutes.

## Access your Cluster

  - Login to Ambari Web UI by opening http://{YOUR_IP}:8080 and log in with **admin/StrongPassword**
  - From Ambari, navigate to the different services, check that all services are running and healthy and try to access their UI from the right panel (NiFi, NiFi Registry & SR)
  - Connect to the MySQL DB using bash or tools like MySQLWorkbench. A workshop DB has been created for the lab. You have also two users:
    - **root/StrongPassword** usable from localhost only
    - **workshop/StrongPassword** usable from remote and has full privileges on the workshop DB 

# Lab 2 Simple flow management
Great! now that you have your HDF cluster up and running, and that you got familiar with it, let's warm up with a simple NiFi exercise that will help us introduce basic NiFi notions. If you are already familiar with NiFi, you can skip this section and work on Lab 3 directly.

Let's create a simple NiFi flow that watch the /tmp/input directory, and each time a file is present, compresses it, and moves it to /tmp/output. Go to the main canvas of NiFi, locate the add processor button, drag it onto the canvas and release. Explore the list of available processors. You can use the filter bar to search for a particular processor.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/NiFi.png)

Add and configure the following processors:
1. Select the GetFile Processor and add it
1. Configure the GetFile Processor
   1. Double-click on the new processor
   1. The tabbed dialog should show settings, give the processor a name (ex. Get File From TMP)
   1. Select the properties tab
   1. Set Input Directory to "/tmp/input" (before doing this use "sudo su nifi" to become the nifi user, and make sure you create this directory on your NiFi box, and that it is owned by the nifi user - chown -R nifi:nifi /tmp/input)
1. Now add an UpdateAttribute processor
   1. Configure it with a new dynamic property
      1. In the properties tab, press the plus sign in the top right of the dialog
      1. Call the property "filename" and set the value to something meaningful
      1. Add a property called "mime.type" and set this to "application/gzip"
1. Connect the two processors
   1. Hover over the GetFile processor, until the begin connection icon appears
   1. Drag this onto the UpdateAttribute processor
   1. This brings up the connection configuration dialog
      1. For now just leave this on defaults.
1. Add a CompressContent processor and look at its properties, the defaults should work fine here.
1. On settings, make sure you set "Auto-terminate relationships" on for failure
1. Now connect up the output of our UpdateAttributes processor to the new CompressContent
1. Add a PutFile processor
1. Configure the Directory in the PutFile processor properties (nifi will create this directory for you). Note the conflict resolution strategy, and set it to replace.
1. Set both success and failure relationships to auto-terminate in the settings tab
1. Setup the connection between the CompressContent processor and the PutFile processor (only for the success relation!)

Now that you have you first flow completed, select the GetFile processor and press play at the left panel. If you copy a file (for example /var/log/ambari-agent/ambari-agent.log) to the input folder you chose, NiFi will pick it up and send it to the next processor. You can see that there's one flow file in the queue. 

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Queue.png)

To inspect the content of the queue, right click on the queue, list queue, then on the small "i" at the left of the first row. You can see all the details of this flow file, its content if you click on "view" button and it's attributes if you move to the attributes tab. A flow flow is always a content and a list of attributes.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Attributes.png)

Now start the next processor (UpdateAttribute), and inspect the attributes of the flow file in the next queue. You should see new attributes added by the processor.

Next, start the remaining processor and the flow file will processed by the remaining processors. Notice the statistics of the CompressContent as show below. The size of input data is bigger than output data which shows that our processor is really compressing files. Now check that "/tmp/output" has your file compressed. 

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Compress.png)

Congratulations!! you are now a NiFi flow designer :) note that it's possible to select all the processors (ex. with ctr-A) and start them in a batch. By doing this, your flow will be quickly ingested, compressed and stored in the new location. We did it step by step only to show how NiFi works in slow motion. Test your flow again by copying a new file into /tmp/input. You should see the number of IN and OUT files moves to 2 in all the processors.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Two.png)

Adding processors to the root canvas is not a best practice. Things will get messy very quickly. To organise things, NiFi has an object called a process group (PG). PGs can be used to logically organize your NiFi environment, setup ACLs, reuse code, etc. Process Groups can be created beforehand and processors will be added to them directly. Since we have already added several processors, we can select them (ctr-A), right click on one of them, select 'Group', add a name and click on add. ET voila! We are already ready to tackle advanced topics now.

# Lab 3 Platform preparation (admin persona)
To enforce best practices and governance, there are a few tasks that an admin should do before granting access to the platform. These tasks include:
  - Define users, roles and privileges on each tool (SAM, NiFi, Etc)
  - Define the schemas of events that we will use. This avoids having developpers using their own schemas which makes applications integration and evolution a real nightmare.
  - Define and enforce naming convention that makes it easier to manage applications lifecycle (eg. NiFi PG and processors names)
  - Define global variables that should be used to make application migration between environments simple
  - etc

In this lab, we will implement some of these best practices to set the right environment for our developpers.

## Create schemas in Schema Registry

In this workshop, we will manipulate three type of events. Go to Schema Registry from Ambari and create the following schemas as shown below:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/SR.png)

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
These events are data coming from Web Application through the MiNiFi agents deployed on application servers. Each event, describe a customer browsing behavior on a webpage. The provided information is the customer id, the product page being viewed, session duration and if the customer bought the product at the end of the session or not. Go to Schema Registry and add a new schema with these details:
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
### Logs_view events
We also need another logs event (logs_view) that contain only the product browsing session information with the buy and price fields. We will see why later in the labs. Go to Schema Registry and add a new schema with these details:
  - Name: logs
  - Descrption: schema for logs events
  - Type: Avro Schema Provider
  - Schema Group: Kafka
  - Compatibility: both
  - Evolve: true
  
For the schema text, use the following Avro description:

  ```
{
  "type": "record",
  "name": "logs_view",
  "fields" : [
    {"name": "id", "type": "int"},
    {"name": "product", "type": ["null", "string"]},
    {"name": "sessionduration", "type": ["null", "int"]}
  ]
}
  ```
## Create record readers and writters in NiFi
To use these schema in NiFi, we will leverage record based processors. These processors use record readers and writers to offer improved performances and to use schemas defined globally in a Schema Registry. Our sources (MySQL CDC event and Web App logs) generate data in JSON format so we will need a JSON reader to deserialise data. We will store this data in ElasticSearch and publish it to Kafka. Hence, we need JSON and Avro writers to serialize the data. 

To add a reader/writer accessible by all our NiFi flows, click on Configure on the left panel, Controller services and click on "+" button. Note that you can add a Reader/Writter inside a particular process group to isolate them. Readers/Writters created inside a process group will be visible only for processors inside this PG. 

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Configure.png)

### Add a HortonworksSchemaRegistry
Before adding any record reader/writer, we need to add a Schema Registry to tell NiFi where to look for schema definitions. NiFi supports several Schema Registries (Hortonworks, Confluent, NiFi schema registry). Hortonworks Schema registry is a cross tool registry that's integrated with NiFi, Kafka and SAM. Add a HortonworksSchemaRegistry controller to NiFi and configure it with your SR URL as shown below. Once created, make sure to start it by clicking on the lightning icon.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/HortonworksSchemaRegistry.png)

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Lightning.png)


### Add JsonTreeReader
To deserialize JSON data, add a JsonTreeReader and configure it as shown below. Note that the **Schema Access Strategy** is set to **Use 'Schema Name' Property**. This means that flow files going through this serializer must have an attribute **schema.name** that specifies the name of the schema that should be used. Start the Reader by clicking on the lightning icon.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/JsonTreeReader.png)

### Add JsonRecordSetWriter
To serialize JSON data for which we have a defined schema, add a JsonRecordSetWriter and configure it as shown below. Start the Writter by clicking on the lightning icon.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/JsonRecordSetWriter.png)

### Add AvroRecordSetWriter
Event collected by NiFi will be published to Kafka for further consumption. To prepare data for streaming engine consumption, we need to add AvroRecordSetWriter and set **Schema Write Strategy** to **HWX Content-Encoded Schema Reference** as shown below. Start the Writter by clicking on the lightning icon.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/AvroRecordSetWriter.png)

## Create process groups and variables in NiFi
It's critical to organize your flows when you have a shared NiFi instance. NiFi flows can be organized per data sources where each Process Group defines the processing that should be applied to data coming from this source. If you have several flow developers working on different projects, you can assign roles and privileges to each one of them on those process groups. The PG organisation is also useful to declare variables for each source or project and make flow migration from one environment to another one easier. 

Add 3 PGs as shown below. Note the naming convention (sourceID_description). It highly recommeneded to use a naming convention to leverage it in flows migration and monitoring.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Add_PG.png)

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/PGS.png)

To add variable to a process group, right click on the process group and then variables.

  - SRC1_CDCIngestion: ingest data from MySQL. This PG will use the below variables. For instance, we can change the variable elastic.url from localhost to the production Elastic cluster URL in a central location instead of updating it in every Elastic processor.

  ```
mysql.driver.location : /usr/share/java/mysql-connector-java.jar
mysql.username : root
mysql.serverid : 123
mysql.host : localhost:3306
source.schema : customers
elastic.url : http://localhost:9200
kafka.url : USE-YOUR-INTERNAL-CLUSTER-ADDRESS:6667 # You can get this address from Ambari config or from the Google Spreadsheet
  ```  
![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/PG1.png)

  - SRC2_LogsIngestion: ingest data from Web applications. This PG will use the following variables:
  
  ```
source.schema : logs
elastic.url : http://localhost:9200
kafka.url : USE-YOUR-INTERNAL-CLUSTER-ADDRESS:6667
  ```  
  - Agent1_LogsIngestion: the template that will be deployed in each MiNiFi agent for log ingestion. This PG don't use any variable.
 
 ## Create events topics in Kafka

 As an admin, we need to provision Kafka topics and define their access policies. Use the following instructions to create the topics that we will use. In the future, topic provisioning will be possible through SMM.

  ```
/usr/hdf/current/kafka-broker/bin/kafka-topics.sh --zookeeper localhost:2181 --create --topic customers --partitions 1 --replication-factor 1
/usr/hdf/current/kafka-broker/bin/kafka-topics.sh --zookeeper localhost:2181 --create --topic logs --partitions 1 --replication-factor 1
/usr/hdf/current/kafka-broker/bin/kafka-topics.sh --zookeeper localhost:2181 --create --topic alerts --partitions 1 --replication-factor 1

  ```  
 ## Create events topics in Kafka
 
As a last step of this lab, let's prepare our NiFi Registry instance. NiFi Registry is a Git like service for your NiFi flow developments. It has flow versionning features that handles the streaming aspect of it: data inflight management, stop/start processors, queue, controller services, etc. Flows are organised in Buckets, which are logical entities that group a set of flows together. A bucket can define a project, an environment, a developper or a team. So let's create a bucket for our lab:

 - Go to NiFi Registry on YOUR-CLUSTER-ADDRESS:61080/nifi-registry
 - Click on the tool icon at the top right of the UI (settings)
 - Click on "New bucket", name it HDF Workshop and click on create

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/NewBucket.png)

# Lab 4
In this lab, we will use NiFi to ingest CDC data from MySQL. The MySQL DB has a table "customers" that stores information on our customers. We would like to receive each change in the table as an event (insert, update, etc) and use it with other sources to build a customer 360 view in ElasticSearch. The high level flow can be described as follows:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/UC1.png)

  - Ingest events from MySQL (SRC1_CDCMySQL)
  - Keep only Insert and Update events and formate them in a usable JSON format (SRC1_RouteSQLVerbe to SRC1_SetSchemaName)
  - Insert and update customer data in ElasticSearch where we will build the 360 view (SRC1_MergeRecord to SRC1PutElasticRecord)
  - Publish update events in Kafka to use them for fraud detection use case (SRC1_PublishKafkaUpdate)

## Enable MySQL binary logs
NiFi has a native CDC feature for MySQL databases. To use it, the MySQL DB must be configured to use binary logs. Use the following instructions to enable binary logs for the workshop DB and use ROW format CDC events.

  ```
sudo bash -c 'sudo cat <<EOF >> /etc/my.cnf
server_id = 1
log_bin = delta
binlog_format=row
binlog_do_db = workshop
EOF'

sudo systemctl restart mysqld.service
  ``` 

## Ingest and format data in NiFi
In the first step of this lab, we will start by a template that we have prepared for the workshop. Templates is a feature of NiFi that can be used to save, export and import NiFi flows as XML files. Start by doawnloading the template from here and save it as an XML file: https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/scripts/HDF-Workshop-Bootstrap.xml

Go to SRC1_DCIngestion PG, click on the upload template button on the left panel (see below), select the flow template that you have previously downloaded and click on Upload. Once the template is uploaded, ckick on the template button in the top menu, drag it on the canvas and release. Select your template and click add. Several processors have been added to your flow now. 

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Templates.png)

Take some time to open each processor and review its configuration. NiFi has embedded documentation for each processor. If you want to have more information on a particular processor or its parameters, right click on the processor then click on "View Usage".

Note that we are leveraging the variables we defined previously. As you can see in the CaptureChangeMySQL configuration below, we are using variable to set the MySQL configurations rather than setting static configurations. This makes flow versionning, migration and reuse easier.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/CDC.png)

The yellow "!" icon at the top left of the CDC processor show that the processor is in error state. To investigate the error, put your mouse on the "!" icon and read the error. It says that the processor is using "A Distributed Map Cache Client" that's disabled. We need to enable it to start using the processor.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Error.png)

The CaptureChangeMySQL is a stateful processor. It needs to keep track of information on the latest data ingested: binlog position and transaction ID. To do this, NiFi uses a component called Distributed MapCache service which comes with a client and a server parts. The Distributed MapCache Client is already created and configured for you by the template. However, you need to start it as we saw in the previous paragraph. Also, you need to add a Distributed MapCache Server from the controller services menu and enable it. 

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/MapCacheServices.png)

We still need to do one last thing before testing our flow. When you use NiFi templates to export/import flows, NiFi protects your passwords and delete them. This means that the password property of the CDC processor is not set. Make sure to update the "Password" property with "StrongPassword".

Now, you can generate some data to see how CDC events look like. Use the following instructions to insert 10 customers to the MySQL DB: 

  ```
curl "https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/scripts/create-customers-table.sql" > "create-customers-table.sql"

mysql -h localhost -u workshop -p"StrongPassword" --database=workshop < create-customers-table.sql
  ``` 
Now, select and start the CDC processor: you should get several flow files in the first queue. Start the next processor (RouteOnAttribute) and observe how data is distributed over the different relations. Go to each queue and see how the data looks like for each event. Make sure that you have 10 flow files in "insert,update" relation, 20 in "unmatched" and 1 in "ddl".

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/cdcresults.png)

To get update events, you can connect to the MySQL DB and update some customer information. You should get 11 flow files in the "insert,update" relation now.

  ```
mysql -h localhost -u root -pStrongPassword
USE workshop;
UPDATE customers SET phone='0645341234' WHERE id=1;
  ```
If you right click on the CDC processor, then select "view state", you can see what information the processor is keeping to do the incremental work (see below). During the development phase, it useful to delete the state and make the processor ingest the data again. This avoids touching the database again to get new events. To delete the state of a processor, you need to stop it first. This is a general thing in NiFi: each component needs to be stopped before modifying its configuration.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/State.png)

Now, let's examine what's happening in our flow end-to-end. For teaching purposes, the CDC processor is configured to listen to all events. The Begin/Commit/DDL statements are not useful for us, so we need to filter them with a RouteOnAttribute processor configured as follows:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Route1.png)

Each configuration row adds a relation to the processor and defines which flow files should be routed to this relation. We use NiFi [Expression Langage (EL)](https://nifi.apache.org/docs/nifi-docs/html/expression-language-guide.html) to implement our logic. Here, we are comparing the value of the Flow File Attribute "cdc.event.type" with the keywords we are looking for: insert, update, etc. NiFi has a rich expression langage that can be used to work with String, Arithmetic or Logical operators. Here we are using the "equals" function.  

The next step of the flow is an EvaluateJsonPath processor that extracts the table name. This processor is used to extract information from the content of the flow file (the JSON document) and adds them as a flow file attribute. This is often required if you want to dynamically extract data that should be in an attribute (routing for instance). Here, we are looking to each JSON file, looking for the field "table_name" and adding it as an attribute called "tableName". 

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/ExtractTableName.png)

As you can see, each event has a lot of additional information that are not useful for us. The next step is to keep only data of interest and reformat the JSON file to be useful for us. NiFi has several processors that transform data that we can use here. JoltTransformationProcessor is a very powerful transformation processor that can easily do complex transformation on Json data. We use it here with the following Jolt specification. 

  ```
[
  {
    "operation": "shift",
    "spec": {
      "columns": {
        "*": {
          "@(value)": "[#1].@(1,name)"
        }
      }
    }
  }
]
  ``` 
This Jolt specification is telling NiFi to keep only attributes from the "columns" object, to shift them to the left and keep only "value" and "name" fields as follow:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Jolt.png)

Now that we have our data in the target Json format, the last processor (UpdateAttribute) is adding an attribute schema.name with the value of the variable ${source.schema} to set the data schema for the upcoming steps (source.schema is set to customers). This prepares our data to be used by the record-based processors, the customers schema that we added in the SR as well as the different record readers/writters.

Once you have a clear understaing of what the template is doing, move to the next step to continue the flow development.

## Store events in ElasticSearch
Before storing data in ES, let's separate between Insert and Update events. This is not required since the PutElasticSearchRecord processor supports both insert and update operations. But for other processors, this may be required. Also, some CDC tools generate different schemas for insert and update operations so routing data is required in some cases. 

For routing the data, add a RouteOnAttribute processor and configure it to separate between inserts and updates like the following. Connect the UpdateAttribute to this RouteOnAttribute processor.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Route.png)

Storing data in ElasticSearch event by event is not efficient and will create huge load on the indexing service. To achieve better performance, we need to batch these events in groups. Add two MergeRecord processors (one for Inserts and one for Updates) and configure them as follows. **Note:** you can use copy paste to create the second MergeRecord processors.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Merge.png)

This configuration means that the flow files will be merged by groups of 5 events: flow files will be queued up until we have at least 5 events in the queue, then grouped into one flow file and passed to the next processor. The value 5 is for demo only, you would set a higher value in real life (1000 events for instance). To avoid waiting too long if data rate is not high, we can set the "Max Bin Age" property. Here, we are telling NiFi to merge data after 10 seconds even if we don't reached the minimum of 5 flow files. You can also set a maximum number of record to merge if you want to avoid having big batches. Min/Max settings can be set on the number of flow files or the size of data.

Connect the RouteOnAttribute to these MergeRecord processors and use the appropriate relation. Auto-terminate the "Unmatched" relation of the RouteOnAttribute processor.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Relations.png)

Add two PutElasticSearchHttpRecord and configure them as follows. Use the Index operation for the Insert CDC events and Update operation for Update CDC events. Note how easy it is to use Record-based processors now since we have already prepared our Schema and Reader/Writer. The Elastic processor configuration should be:

- ElasticSearch URL : ${elastic.url}
- Record Reader : JsonTreeReader
- Identifier Record Path : /id
- Index : ${tableName}
- Type : default
- Index Operation : index (for the first processor), update (for the second one)

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/PutES.png)

Add a LogAttribute processor after the PutElasticSearchHttpRecord processors: this will be used for debugging only. Connect the different processors (RouteOnAttribute -> MergeRecord -> PutElasticSearch -> LogAttribute) as show in the following screenshoot. Be careful to the name of the relations. For instance, connect the Merge processors to the Elastic processors using the merged relation, and auto-terminate the other relations. Start all the processor except the LogAttribute Processor. Notice that data is queued before the merge processors for 10 seconds. Notice also the number of input and output flow files at the Merge processor. 

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Results.png)

Now, open ElasticSearch UI and check that your customer data has been indexed: http://YOUR-CLUSTER-IP:9200/customers/_search?pretty

## Publish update events in Kafka
The last step for this lab is to publish "update" cdc events in Kafka. These events will be used by the stream processing applictaion to check if there's a risk of fraud. Add a PublishKafkaRecord_1_0 and configure it to use the Avro record writer as follow.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/KafkaPublish1.png)

Now, connect the Publish Kafka processor to the Log Attribute processor and start it. To check that data is published in Kafka, use the Kafka consumer utility with this command:

  ```
/usr/hdf/current/kafka-broker/bin/kafka-console-consumer.sh --bootstrap-server YOUR-INTERNAL-SERVER-ADDRESS:6667 --topic customers --from-beginning
  ```

# Lab 5 Version flow in NiFi Registry
Now that we have our first use case implemented, let's explore the NiFi Flow Registry service. To save our flow:
 - Navigate to the root NiFi canvas In NiFi
 - Right click on the PG SRC1_CDCIngestion
 - Click on "versions" and "Start version control"
 - In the popup window, you can see that the Registry an Bucket are already populated because we have only one Registry and one bucket configured. If you have several once, you can use the list menu to chose the right one. Notice also the version which is set to "1"
 - Add a flow name, a flow description and a version commit, then click on save.
 
![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Flowv1.png)

Notice now the new green check mark on the processor group. This tells us that the processor group has the last version of flows in the registry. 

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/ok.png)

Now, go to NiFi registry and check that your flow has been successfuly saved.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/ok.png)

Now let's explore the behavior of the registry when we edit our flow. 
 - Go inside the process group and make several changes (processor position, processor names, processor settings). As you can see, the PG icone turned to a gray star that shows that there are local changes not pushed to the registry. 
 - Right click on the processor, select "version" menu then "show local changes" to see what are these changes
 - Right click on the processor, select "version" menu then "commit local changes" to save the new version
 - Go to the NiFi registry and check that the new version has been successfully saved

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Flowv2.png)

Now let's try to import our flow. Unfortunately, we don't have another cluster to deploy it so let's deploy it in the same instance. 
 - Click on the PG icon in the top toolbar, drag it and release. 
 - Click on Import instead of clicking on add
 - Select your flow, and then select the version you would like to import
 - Click on import and your PG and its dependencies are added to NiFi
 
![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Import.png)

To finish this lab, change the value of a variable in the original PG, commit the updates, and then pull the new version in the second PG. This should not impact your local variables.

# Lab 6
The objective of this lab is to ingest web applications logs with MiNiFi. Each web application generates logs on customer behaviour on the website. An event is a JSON line that describes a user behaviour on a product web page and gives information on:
  - Id: the user browsing the website. id = 0 means that the user is not connected or not known.
  - Product: the product id that the customer has looked at.
  - Sessionduration: how long the customer stayed on the product web page. A short duration means that the user is not interested by the product and is only browsing.
  - Buy: a boolean that indicates if the user bought the product or not
  - Price: the total amount of money that the customer spent

We will simulate the web apps by writing directly events to the files inside the tmp folder. The final objective will be to add browsing information to customer data in Elasticsearch. This will be the first step for the customer 360 view. 
 
## Design MiNiFi pipeline
Before working on the MiNiFi pipeline, we need to prepare an Input port to receive data from the agent. In the NiFi root Canvas, add an Input port and call it **SRC2_InputFromWebApps**. 

Now, inside the NiFi Agent1_logsIngestion process group, create the MiNiFi flow as follows:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/minifi.png)

As you can see, it's a very simple pipeline that tails all web-appXXX.log files inside /tmp and send them to our NiFi via S2S. You can enrich this pipeline with more steps such as compression or filtering on session duration later if you like. The tail fail configuration is described below:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/tail.png)

Save the flow as a template and download the associated XML file.

## Deploy MiNiFi agent
MiNiFi is part of the NiFi ecosystem but should be deployed separately. Currently, the deployment should be automated by the user. In the near future, we will build a Command & Control tool (C2) that can be used to deploy, monitor and manage a number of MiNiFi agents from a central location. Run the following instructions to install MiNiFi in /usr/hdf/current/minifi

  ``` 
sudo mkdir /usr/hdf/current/minifi
sudo mkdir /usr/hdf/current/minifi/toolkit
wget http://apache.claz.org/nifi/minifi/0.5.0/minifi-0.5.0-bin.tar.gz
tar -xvf minifi-0.5.0-bin.tar.gz
sudo cp -R minifi-0.5.0/. /usr/hdf/current/minifi
  ``` 

In addition to NiFi, we will need the MiNiFi toolkit to convert our XML template file into YAML file understandable by MiNiFi.

  ``` 
wget http://apache.claz.org/nifi/minifi/0.5.0/minifi-toolkit-0.5.0-bin.tar.gz
tar -xvf minifi-toolkit-0.5.0-bin.tar.gz
sudo cp -R minifi-toolkit-0.5.0/. /usr/hdf/current/minifi/toolkit
  ``` 

## Deploy MiNiFi pipeline 
SCP the template you downloaded from your NiFi node to your HDF cluster. You can Curl mine and change it to add your NiFi URL in the S2S section.

  ``` 
sudo curl -sSL -o /usr/hdf/current/minifi/conf/minifi.xml https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/scripts/minifi.xml
  ``` 
Use the toolkit to convert your XML file to YAML format:

  ``` 
sudo /usr/hdf/current/minifi/toolkit/bin/config.sh transform /usr/hdf/current/minifi/conf/minifi.xml /usr/hdf/current/minifi/conf/config.yml
  ``` 

Now start the MiNiFi agent and look to the logs:

  ``` 
sudo /usr/hdf/current/minifi/bin/minifi.sh start
tail -f /usr/hdf/current/minifi/logs/minifi-app.log
  ``` 
## Design NiFi pipeline
Inside the SRC2_LogIngestion PG, create the NiFi pipeline that will process data coming from our agent. The general flow is:
  - Receive data through S2S
  - Filter events based on the sessionduration. We consider that a customer who spends less than 20 seconds on a product page is not interested. We will filter these events and ignore them.
  - Filter unknown users browsing events (id=0). These events can be browsing activity from a non-logged-in customer or a customer who is not yet logged in. We can store these events in HDFS for other use cases such as product recommendations. In a real life scenario, a browsing session will have an ID and can be used to link browsing history to a user once logged in.
  - For the other events, we will do two things:
    - Update customer data in Elasticsearch to include the products that the customer has looked at. For the sake of simplicity, we will store only the last item. If you want to keep a complete list, you can use ElasticSearch API with scripts feature (eg. "source": "ctx.source.products.add(params.product)")
    - Convert logs event to Avro and publish them to Kafka. These events will be used by SAM in the fraud detection use case. The final flow looks like the below:
    
![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/UC3.png)

Start by adding an Input port followed by an update attribute that adds an attribute schema.name with the value ${source.schema}.

To route events based on the different business rules, we will use an interesting Record processor that leverage Calcite to do SQL on flow files. Add a query record processor and configure it as shown below:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/query.png)

As you can see, this processor will create two relations (unknown and validsessions) and route data according to the SQL query. Note that a subset of fields can be selected also (ex. SELECT id, sessionduration from FLOWFILE).

Route data coming from the unknown relation to HDFS.

Route data coming from validsessions to Kafka. In the PublishKafkaRecord, use the AvroRecordSetWriter as Record Writer to publish data in Avro format. Remember that we set **Schema Write Strategy** of the Avro Writer to **HWX Content-Encoded Schema Reference**. This means that each Kafka message will have the schema reference encoded in the first byte of the message (required by SAM).

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/avro.png)

Now let's update our Elasticsearch index to add data on customer browsing behaviors. To learn how to do schema conversion with record based processors, let's consider that we want to add the browsed product ID and sessionduration as opposed to the information on whether the customer bought the product or not. To implement this, we need a ConvertRecord processor.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/convert.png)

As you can see, I had to create a new JsonSetWritter to specify the write Schema which is different from the read schema referenced by the attribute **schema.name**. The **Views JsonRecordSetWriter** should be configured as below. Note that the Schema Name field is set to logs_view that we have already defined in our schema registry. We can avoid fixing the schema directly in the record writer by creating global Read/Write controller and use two attributes : schema.name.input and schema.name.output.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/views.png)

Add a PutElasticSearchHTTPRecord and configure it to update your customer data.

Now let's test the end-to-end flow by creating a file in /tmp with some logs events.

  ``` 
cat <<EOF >> /tmp/web-app.log
{"id":2,"product":"12321","sessionduration":60,"buy":"false"}
{"id":0,"product":"24234","sessionduration":120,"buy":"false"}
{"id":10,"product":"233","sessionduration":5,"buy":"true","price":2000}
{"id":1,"product":"98547","sessionduration":30,"buy":"true","price":1000}
EOF
  ``` 
You should see data coming from the MiNiFi agent to NiFi through S2S. Data will be filtered, routed and stored in Kafka and Elasticsearch. Check data in ElasticSearch and confirm that browsing information has been added to customer 1 and 2. Check also that you have one event that go through the unknown connection.
