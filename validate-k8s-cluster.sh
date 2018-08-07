#!/usr/bin/env bash
export NAME="diamondbacksolutionsllc.com"
export KOPS_STATE_STORE="s3://kops-state-bk5678"
kops validate cluster \
	       $NAME \
	      --state=$KOPS_STATE_STORE \
