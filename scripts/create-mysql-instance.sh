#! /bin/bash

OUTPUT_FILE=${METERING_CR_FILE}
OUTPUT_SECRET_NAME=${OUTPUT_SECRET_NAME:=tflannag-mysql-secret}
CREATE_OUTPUT_FILE=${CREATE_OUTPUT_FILE:=false}

echo "Creating the namespace"
oc create ns $METERING_NAMESPACE

echo "Creating the mysql instance"
oc -n $METERING_NAMESPACE new-app \
	--image-stream mysql:5.7 \
	MYSQL_USER=testuser \
	MYSQL_PASSWORD=testpass \
	MYSQL_DATABASE=metastore \
	-l db=mysql 2>/dev/null

echo "Creating the secret name containing the username and password"
oc -n $METERING_NAMESPACE create secret generic $OUTPUT_SECRET_NAME \
    --from-literal=username=testuser --from-literal=password=testpass 2>/dev/null

res=$(kubectl -n $METERING_NAMESPACE get svc -l db=mysql --no-headers 2>/dev/null | wc -l)
while [[ $? -ne 0 || res -le 0 ]]; do
	echo "No services matching the -l db=mysql label selector yet, retrying..."
	sleep 1
	res=$(kubectl -n $METERING_NAMESPACE get svc -l db=mysql --no-headers 2>/dev/null | wc -l)
done

echo "Grabbing the ClusterIP for the -l db=mysql service"
SERVICE_IP=$(kubectl -n $METERING_NAMESPACE get svc -l db=mysql -o json | faq -f json '.items[0].spec.clusterIP' | tr -d '"')

# check if the $METERING_CR_FILE is unset, generate boilerplate CR
if [[ ! -f $METERING_CR_FILE || $CREATE_OUTPUT_FILE == "true" ]]; then
	echo "Generating boiletplate MeteringConfig custom resource"
	OUTPUT_FILE="tmp.yaml"

	cat <<EOF > tmp.yaml
apiVersion: metering.openshift.io/v1
kind: MeteringConfig
metadata:
  name: operator-metering
spec:
  hive:
    spec:
      config:
        db:
          driver: com.mysql.jdbc.Driver
          secretName: ""
          url: ""
      metastore:
        storage:
          create: false
  storage:
    hive:
      hdfs:
        namenode: hdfs-namenode-0.hdfs-namenode:9820
      type: hdfs
    type: hive
  unsupportedFeatures:
    enableHDFS: true
EOF
fi

echo "Updating $OUTPUT_FILE to point to the new MySQL Service ClusterIP URL"
faq -f yaml -o json '.' ${OUTPUT_FILE} | jq --arg ip "jdbc:mysql://$SERVICE_IP:3306/metastore" --arg name "$OUTPUT_SECRET_NAME" '.spec.hive.spec.config.db.url=$ip|.spec.hive.spec.config.db.secretName=$name' | faq -f json -o yaml > /tmp/tmp.yaml && mv /tmp/tmp.yaml ${OUTPUT_FILE}
