#! /bin/bash

NAMESPACE=${1:?}
SECRET_NAME=${2:-"${NAMESPACE}-mysql-secret"}

MYSQL_IMAGE_STREAM=${MYSQL_IMAGE_STREAM:=mysql:5.7}
CREATE_OUTPUT_FILE=${CREATE_OUTPUT_FILE:=false}
OUTPUT_FILE=${METERING_CR_FILE}

if ! oc get ns ${NAMESPACE} > /dev/null 2>&1; then
  echo "Creating the namespace"
  oc create ns ${NAMESPACE}
fi

echo "Creating the mysql instance"
oc -n ${NAMESPACE} new-app \
  --image-stream ${MYSQL_IMAGE_STREAM} \
	MYSQL_USER=testuser \
	MYSQL_PASSWORD=testpass \
	MYSQL_DATABASE=metastore \
	-l db=mysql > /dev/null 2>&1

echo "Creating the secret name containing the username and password"
oc -n ${NAMESPACE} create secret generic ${SECRET_NAME} \
    --from-literal=username=testuser \
    --from-literal=password=testpass 2>/dev/null


# TODO: not entirely sure why this was needed. Should be able to use the service DNS path instead
# of manually referencing the spec.ClusterIP of the service that gets created from `oc new-app`.
service=$(kubectl --namespace ${NAMESPACE} get svc -l db=mysql --no-headers | awk '{ print $1 }')
export CLUSTER_IP=$(kubectl --namespace ${NAMESPACE} get svc ${service} -o jsonpath='{.spec.clusterIP}')
while [[ $? != 0 ]]; do
    echo "Waiting for the 'mysql' Service to have a populated spec.ClusterIP"
    export CLUSTER_IP=$(kubectl --namespace ${NAMESPACE} get svc ${service} --jsonpath='{.spec.clusterIP}')
done
echo "Grabbed the MySQL Service ClusterIP: ${CLUSTER_IP}"
