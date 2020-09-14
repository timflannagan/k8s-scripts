#! /bin/bash

hostname=$(oc -n openshift-console get routes console -o jsonpath={.spec.host})
/usr/bin/google-chrome $hostname
