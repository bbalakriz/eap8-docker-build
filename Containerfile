## EAP 8 builder image
FROM registry.redhat.io/jboss-eap-8/eap8-openjdk17-builder-openshift-rhel8:latest AS builder

# set environment variables
ENV POSTGRESQL_DRIVER_VERSION=42.5.1
ENV GALLEON_PROVISION_FEATURE_PACKS=org.jboss.eap:wildfly-ee-galleon-pack,org.jboss.eap.cloud:eap-cloud-galleon-pack,org.jboss.eap:eap-datasources-galleon-pack
ENV GALLEON_PROVISION_LAYERS=postgresql-datasource,jaxrs-server
ENV GALLEON_PROVISION_CHANNELS=org.jboss.eap.channels:eap-8.0
# ENV GALLEON_MAVEN_ARGS="-X -e"  # for debugging

# add custom Maven settings
# COPY settings.xml /home/jboss/.m2/settings.xml

# execute the s2i assemble script from the base image
RUN /usr/local/s2i/assemble

## EAP 8 runtime image
FROM registry.redhat.io/jboss-eap-8/eap8-openjdk17-runtime-openshift-rhel8:latest AS runtime

# copy the EAP server provisioned using galleon from the builder image and set ownership and permissions for $JBOSS_HOME
COPY --from=builder --chown=jboss:root $JBOSS_HOME $JBOSS_HOME

# copy the application war (renamed as ROOT.war) and the IBM MQ 9.3.0.2 resource adapter archive
COPY --chown=jboss:root wmq.jmsra.rar $JBOSS_HOME/standalone/deployments/
COPY --chown=jboss:root ROOT.war $JBOSS_HOME/standalone/deployments/

# set IBM MQ 9.3.0.2 configurations
RUN $JBOSS_HOME/bin/jboss-cli.sh --commands="embed-server, \
    /subsystem=resource-adapters:add(), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar:add(archive=wmq.jmsra.rar, transaction-support=XATransaction), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar/admin-objects=topic-ao:add(class-name=com.ibm.mq.connector.outbound.MQTopicProxy, jndi-name=java:jboss/MQ_TOPIC_NAME), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar/admin-objects=topic-ao/config-properties=baseTopicName:add(value=MQ_TOPIC_NAME), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar/admin-objects=topic-ao/config-properties=brokerPubQueueManager:add(value=MQ_QUEUE_MANAGER), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar/connection-definitions=mq-cd:add(class-name=com.ibm.mq.connector.outbound.ManagedConnectionFactoryImpl, jndi-name=java:jboss/MQ_CONNECTIONFACTORY_NAME, tracking=false), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar/connection-definitions=mq-cd/config-properties=hostName:add(value=MQ_HOST_NAME), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar/connection-definitions=mq-cd/config-properties=port:add(value=MQ_PORT), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar/connection-definitions=mq-cd/config-properties=channel:add(value=MQ_CHANNEL_NAME), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar/connection-definitions=mq-cd/config-properties=transportType:add(value=MQ_CLIENT), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar/connection-definitions=mq-cd/config-properties=queueManager:add(value=MQ_QUEUE_MANAGER), \
    /subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar:activate()"

# add an application user for ejb remoting
RUN $JBOSS_HOME/bin/add-user.sh -a -u ejbremote -p ejbremoteconnect 

#ENV CONFIG_IS_FINAL=true # in case the configuration doesn't need any deployment change

# ensure appropriate permissions for $JBOSS_HOME
RUN chmod -R ug+rwX $JBOSS_HOME