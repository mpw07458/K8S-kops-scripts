#!/usr/bin/env bash
export NAME="diamondbacksolutionsllc.com"
export KOPS_STATE_STORE="s3://kops-state-bk5678"
export CLOUD="aws"
export AWS_ZONES="us-east-1a"
kops create cluster \
        --name=$NAME \
        --cloud=$CLOUD \
		--node-count=2 \
		--master-size=t2.micro \
		--master-zones=$AWS_ZONES \
		--zones=us-east-1a  \
		--state=$KOPS_STATE_STORE \
		--node-size=t2.micro \
		--dns-zone=$NAME
