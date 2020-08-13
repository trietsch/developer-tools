#!/bin/bash
kubectl get deployments.apps,svc -o json | jq \
   	'del(.items[]?.metadata.resourceVersion,
   	.items[]?.metadata.resourceVersion,
   	.items[]?.metadata.selfLink,
   	.items[]?.metadata.selfLink,
   	.items[]?.metadata.annotations,
   	.items[]?.status,
   	.items[]?.metadata.creationTimestamp,
   	.items[]?.metadata.namespace,
   	.items[]?.metadata.uid,
   	.items[]?.metadata.generation)' | json2yaml  > all.yaml
