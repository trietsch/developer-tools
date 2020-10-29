#!/bin/bash

for ns in core foundation customer
do
    printf "\nNAMESPAGE $ns\n"
    kubectl get pods --namespace=$ns \
        -o=jsonpath='{range .items[*]}{..qosClass}{"\t"}{.metadata.name}{"\n"}{end}' | sort
done
