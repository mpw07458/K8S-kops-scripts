#!/usr/bin/env bash
export NAME="diamondbacksolutionsllc.com"
export KOPS_STATE_STORE="s3://kops-state-bk5678"
rm -fr ~/.kube
export KUBECONFIG=~/.kube/config
kops export kubecfg --name $NAME --config=$KUBECONFIG --state=$KOPS_STATE_STORE