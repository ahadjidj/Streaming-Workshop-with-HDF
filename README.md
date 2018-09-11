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
  - Create events topics in Kafka
  - Create environment and service pool in SAM
- [Lab 3](#lab-3) - MySQL CDC data ingestion (Dev persona)
  - Configure MySQL to enable binary logs
  - Ingest and format data in NiFi
  - Store events in ElasticSearch
  - Publish update events in Kafka
- [Lab 4](#lab-4) - Logs data collection with MiNiFi(Dev persona)
  - Design MiNiFi pipeline
  - Deploy MiNiFi agent
  - Deploy MiNiFi pipeline 
  - Design NiFi pipeline
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
It's critical to well organize your flows when you have a shared NiFi instance. Usually, NiFi flows are organized per data sources where each Process Group defines the pipeline for each source. If you have several flow developpers working on different projects, you can assign roles and privileges to each one of them. The PG organisation is also usefull to declare variables for each source or project and make flow migration from one environment to another one easier. In this workshop, we will define 3 PGs as shown below. Note the naming convention (sourceID_description) that will be useful for flows migration and monitoring.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/PGS.png)

  - SRC1_CDCIngestion to ingest data from MySQL. This PG will use the following variables. For instance, we can change the variable elastic.url from localhost to the production Elastic cluster URL in a central location instead of updating every Elastic processor.
  
  ```
mysql.driver.location : /usr/share/java/mysql-connector-java.jar
mysql.username : root
mysql.serverid : 123
mysql.host : 127.0.0.1:3306
source.schema : customers
elastic.url : http://localhost:9200
kafka.url : hdfcluster0.field.hortonworks.com:6667
  ```  
![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/PG1.png)

  - SRC2_LogsIngestion to ingest data from Web applications. This PG will use the following variables:
  
  ```
source.schema : logs
elastic.url : http://localhost:9200
kafka.url : hdfcluster0.field.hortonworks.com:6667
  ```  
  - Agent1_LogsIngestion is the template that will be deployed in each MiNiFi agent for log ingestion. This PG don't use any variable.
 
 ## Create events topics in Kafka

 As an admin, we need to provision Kafka topics and define their access policies. Use the following instructions to create the topics that we will use. In the future, topic provisioning will be possible through SMM.

  ```
/usr/hdf/current/kafka-broker/bin/kafka-topics.sh --zookeeper hdfcluster0.field.hortonworks.com:2181 --create --topic customers --partitions 1 --replication-factor 1
/usr/hdf/current/kafka-broker/bin/kafka-topics.sh --zookeeper hdfcluster0.field.hortonworks.com:2181 --create --topic logs --partitions 1 --replication-factor 1
/usr/hdf/current/kafka-broker/bin/kafka-topics.sh --zookeeper hdfcluster0.field.hortonworks.com:2181 --create --topic alerts --partitions 1 --replication-factor 1

  ```  
 ## Create service pool and application environment in SAM  
Finally, we need to provision a service pool and an environment in SAM for our application. For the service pool, use the HDF cluster URL : http://hdfcluster0.field.hortonworks.com:8080/api/v1/clusters/hdfcluster

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/ServicePool.png)

# Lab 3
In this lab, we will use NiFi to ingest CDC data from MySQL. The MySQL DB has a table that stores information on our customers. We would like to receive each change in the table as an event (insert, update, etc) and use with other source to build a customer 360 view in ElasticSearch. The high level flow can be described as follows:

  - Ingest events from MySQL (SRC1_CDCMySQL)
  - Keep only Insert and Delete events and format them in a usable JSON format (SRC1_RouteSQLVerbe to SRC1_SetSchemaName)
  - Insert and update customer data in ElasticSearch (SRC1_MergeRecord to SRC1PutElasticRecord)
  - Publish update event in Kafka to use them for fraud detection use cases (SRC1_PublishKafkaUpdate)
  
![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/UC1.png)

## Configure MySQL to enable binary logs
NiFi has a natif CDC feature for MySQL databases. To use it, the MySQL DB must be configured to use binary logs. Use the following instructions to enable binary log for the workshop DB and use ROW format CDC events.

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
Add a CaptureChangeMySQL processor and configure it as follows:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/CDC.png)

Note that we are leveraging the variables we defined previously. The CaptureChangeMySQL needs a MapCache service to store its state (binlog position and transaction ID). Add a MapCache client and service. 

The CDC processor can be configured to listen to some events only. In our use case, we won't use Begin/Commit/DDL statements. But for teaching purposes, we will receive those events and filter them later. Add a RouteOnAttribute processor and configure it as follows:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Route1.png)

At this level, you can generate some data to see how CDC events looks like. Use the following instructions to insert 10 customers to the MySQL DB:

  ```
curl "https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/scripts/create-customers-table.sql" > "create-customers-table.sql"

mysql -h localhost -u workshop -p"StrongPassword" --database=workshop < create-customers-table.sql
  ``` 

Use the different relations to see how data looks like for each event. To get update events, you can connect to MySQL and update some customer informations.

  ```
mysql -h localhost -u root -pStrongPassword
UPDATE customers SET phone='0645341234' WHERE id=1;
  ```
For the next step, add an EvaluatteJsonPath processor to extract the table name. Connect the Route processor to the EvaluateJsonProcessor with insert and update relations only. 

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/ExtractTableName.png)

As you can see, each event has lot of additional information that are not useful for us. To keep only data on our new customers, we can use a JoltTransformationProcessor with the following Jolt specification:

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
Now that we have our target data in Json format, let's add an attribute schema.name with the value ${source.schema} to prepare for using Record based processors and our customers schema defined in SR.

## Store events in ElasticSearch
Before storing data in ES, let's separate between Insert and Updates events first. This is not required since the PutElasticSearchRecord processor supports both insert and update operations. But for other processors, this may be required. Also, some CDC tools generate different schema for insert and update operations so routing data is required. 

Add a RouteOnAttribute processor as previously and separate between inserts and updates. For each type of event, add a MergeRecord and PutElasticSearchHttpRecord configured as follows. Use Index operation for insert event and update operation for update events.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/Merge.png)
![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/PutES.png)

Note how easy it is to use Record based processor now that we have prepared our Schema and Reader/Writter.

Open ElasticSearch UI and check that your customer data has been indexed : http://hdfcluster0.field.hortonworks.com:9200/customers/_search?pretty

## Publish update events in Kafka
The last step for this lab is to publish Insert events in Kafka. This event will be used by SAM to check if there's a risk of fraud. Hence, we need to use Avro record writter in the Kafka processor configuration.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/KafkaPublish1.png)

# Lab 4
The objective of this lab is to ingest web applications logs with MiNiFi. Each Web application generates logs on customer behaviour on the website. An event is a JSON line that describe a user behaviour on a product web page and gives information on:
  - Id: the user id browsing the retailer website. id = 0 means that the user is not connected and not known
  - Product: the product id that the customer visited.
  - Sessionduration: how long the customer spent on the product web page. A short duration means that the user is not interesed by the product and is only browsing.
  - Buy: is a boolean that indicates if the user bought the product or not
  - Price: the total amount that the customer spent

We will simulate the web apps by writting directly events to files inside the tmp folder. The final objective will be to add browsing information to customer data in Elasticsearch. This will be the first step for the customer 360 view. 
 
## Design MiNiFi pipeline
Before working on the MiNiFi pipeline, we need to prepare an Input port to receive data from the agent. In the NiFi root Canvas, add an Input port and call it **SRC2_InputFromWebApps**. 

Now, inside the NiFi Agent1_logsIngestion process group, create the MiNiFi flow as follows:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/minifi.png)

As you can see, it's a very simple pipeline that tails all web-appXXX.log files inside /tmp and send them to our NiFi via S2S. You can enrich this pipeline with more steps such as compression or filtering on session duration later if you like. The tail fail configuration is described below:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/tail.png)

Save the flow as a template and download the associated XML file.

## Deploy MiNiFi agent
MiNiFi is part of the NiFi ecosystem but should be deployed separately. Currently, the deployment should be automated by the user. In near future, we will build a Command & Control tool (C2) that can be used to deploy, monitor and manage a number of MiNiFi agents from a central location. Run the following instructions to install MiNiFi in /usr/hdf/current/minifi

  ``` 
sudo mkdir /usr/hdf/current/minifi
sudo mkdir /usr/hdf/current/minifi/toolkit
wget http://apache.claz.org/nifi/minifi/0.5.0/minifi-0.5.0-bin.tar.gz
tar -xvf minifi-0.5.0-bin.tar.gz
sudo cp -R minifi-0.5.0/. /usr/hdf/current/minifi
  ``` 

In addition to NiFi, we will need MiNiFi toolkit to convert our XML template file into YAML file understeable by MiNiFi.

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
  - Route events based on the sessionduration
  - We consider that a customer that spend less than 20 secondes on a product page is not really interested. We will filter these events and ignore them.
  - Filter unkown users browsing events (id=0). These can be browsing activity from a non-logged customer or not-yet customer. We can store these events in HDFS for other use cases such as product recommendation. In real life scenario, a browsing session will have an ID and can be used link to a user once logged in.
  - For the other events, we will do three things:
    - Update customer data in Elastic to include products that the customer were looking to. For the sake of simplicity, we will store only the last item. If you want to keep a complete list, you can use ElasticSearch API with scripts feature (eg. "source": "ctx.source.products.add(params.product)")
    - Convert logs event to avro and publish them to Kafka. These events will be used by SAM in the fraud detection use cas. The final flow looks like the below:
    
![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/UC3.png)

Start by adding an Input port followed by an update attribute that adds an attribute schema.name with the value ${source.schema}.

To route events based on the different business rules, we will use an interesting Record processor that can be used to SQL on flow files. Add a query record processor and configure it as show below:

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/query.png)

As you can see, this processor will create two relations (unknown and validsessions) and route data according the SQL query. Note that a subset of fields can be selected also (ex. SELECT id, sessionduration from FLOWFILE).

Route data coming from the unkown relation to HDFS.

Route data coming from validsessions to Kafka. In the PublishKafkaRecord, use the AvroRecordSetWritter as Record Writter to publish data in Avro format for SAM consumption. Remember that we set **Schema Write Strategy** of the Avro Writter to **HWX Content-Encoded Schema Reference**. This means that each Kafka message will have the schema reference encoded in the first byte of the message.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/avro.png)

Now let's update our Elastic index to add data on customer browsing behaviors. To learn how to schema conversion in record based processor, let's consider that we want to update our customer data by the browsed produt ID and sessionduration. We don't want to add information on wether the customer bought or no the product. To implement this, we need a ConvertRecord processor.

![Image](https://github.com/ahadjidj/Streaming-Workshop-with-HDF/raw/master/images/convert.png)

As you can see, I had to create a new JsonSetWritter to specify the write Schema which is different from the read schema define in the attribute **schema.name**. The **Views JsonRecordSetWriter** should be configured as below. Note that the Schema Name field is set to logs_views that we have already defined in our schema registry. We can avoid fixing the schema directly in the record writter by creating global Read/Write controller and use two attributes : schema.name.input and schema.name.output.

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
You should see data coming from MiNiFi agent to NiFi through S2S, then filtered, routed and stored in Kafka and Elasticsearch. Check data in ElasticSearch and confirm that browsing information has been added to customer 1 and 2. Check also that you have one event that go through the unkown connection.
