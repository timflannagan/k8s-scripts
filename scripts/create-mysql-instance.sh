#! /bin/bash

NAMESPACE=${1:?}
SECRET_NAME=${2:-"${NAMESPACE}-mysql-secret"}

CREATE_OUTPUT_FILE=${CREATE_OUTPUT_FILE:=false}
OUTPUT_FILE=${METERING_CR_FILE}

if ! oc get ns ${NAMESPACE} > /dev/null 2>&1; then
  echo "Creating the namespace"
  oc create ns ${NAMESPACE}
fi

echo "Creating the mysql instance"
oc -n ${NAMESPACE} new-app \
  --image-stream mysql:5.7 \
	MYSQL_USER=testuser \
	MYSQL_PASSWORD=testpass \
	MYSQL_DATABASE=metastore \
	-l db=mysql > /dev/null 2>&1

echo "Creating the secret name containing the username and password"
oc -n ${NAMESPACE} create secret generic ${SECRET_NAME} \
    --from-literal=username=testuser \
    --from-literal=password=testpass 2>/dev/null

export CLUSTER_IP=$(kubectl --namespace ${NAMESPACE} get svc/mysql -o jsonpath='{.spec.clusterIP}')
while [[ $? != 0 ]]; do
    echo "Waiting for the 'mysql' Service to have a populated spec.ClusterIP"
    export CLUSTER_IP=$(kubectl --namespace ${NAMESPACE} get svc/mysql --jsonpath='{.spec.clusterIP}')
done
echo "Grabbed the MySQL Service ClusterIP: ${CLUSTER_IP}"

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

echo "Updating the ${OUTPUT_FILE} to point to the new MySQL Service ClusterIP URL"
faq -f yaml -o json '.' ${OUTPUT_FILE} | jq --arg ip "jdbc:mysql://${CLUSTER_IP}:3306/metastore" --arg name "${SECRET_NAME}" '.spec.hive.spec.config.db.url=$ip|.spec.hive.spec.config.db.secretName=$name' | faq -f json -o yaml > /tmp/tmp.yaml && mv /tmp/tmp.yaml ${OUTPUT_FILE}
