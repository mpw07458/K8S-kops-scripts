#!/usr/bin/env bash
#########################################
# Kubernetes Orchestrator for AWS
# Quali MPW Michael (Mike) P Williams
# disclaimer
# Version 0.2 relies hard-coded values
# does not take advantage of JSON
# Supports only Bash and  AWS via Kops
# supports single region and 3 node cluster
###########################################
# Environment set up for Bash commandline Only
# hard-coded domain and directories
#############################################
export KOPS_HOME=/usr/local/bin
export CFG_HOME=/home/michael
export KUBE_HOME=$KOPS_HOME/kubectl
export NAME="diamondbacksolutionsllc.com"
export KOPS_STATE_STORE="s3://kops-state-bk5678"
export CLOUD="aws"
export AWS_REGION="us-east-1a"
# mpw v0.2
# Does not take advantage of kubeconfig and JSON entries
export KUBE_CFG_HOME=$CFG_HOME/$NAME/kubeconfig
export H_ZONE_FILE=$CFG_HOME/k8-zone.json
export K8_DEF_ENV=$CFG_HOME/k8-def-env.json
export K8_ENV=$CFG_HOME/k8-env.json
export SSH_HOME=$CFG_HOME/$NAME/sshkeys

installAWSClient() {
#  mpw v0.2
	sudo apt-get update
	sudo apt install python-pip
	pip install awscli --upgrade --user
	sudo apt-get install jq
}

getSubDomain() {
# mpw v0.2
# allows input form user for Cluster Domain
    read -p "Hello, what is the Cluster Domain ?. : " NAME
	if [[ $NAME == "" ]]; then
		echo "Exiting... Cluster Domain is MANDATORY"
		exit
	fi
}

installKubectl() {
# mpw v0.2
	curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
	curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.7.0/bin/linux/amd64/kubectl
	chmod +x ./kubectl
	sudo mv ./kubectl /usr/local/bin/kubectl
}

installKops() {
# mpw v0.2
	wget https://github.com/kubernetes/kops/releases/download/1.6.1/kops-linux-amd64
	chmod +x kops-linux-amd64
	sudo mv kops-linux-amd64 /usr/local/bin/kops
}

createS3Bucket() {
# mpw v0.2
	echo "######### Creating S3 Bucket $NAME ######"
	aws s3 rb $KOPS_STATE_STORE
	aws s3 mb $KOPS_STATE_STORE --region us-east-1
	echo "######### export KOPS_STATE_STORE ######"
	export KOPS_STATE_STORE=$S3_STORE
	echo "#########  S3 Bucket Creation Complete ######"
}

createSSHKeys() {
# mpw v0.2
	echo "######### Creating SSH Keys ######"
	mkdir -p ~/$NAME
	touch $KUBE_CFG
	export KUBE_CFG="$CFG_HOME"
	echo "KUBE_CFG=$KUBE_CFG"
	mkdir $SSH_HOME
	ssh-keygen -f $SSH_HOME/id_rsa -t rsa #save the key in the sshkeys
	echo "######### SSH Keys created successfully ######"
}

createSubDomain() {
# mpw v0.2
	rm -rf $H_ZONE_FILE
	ID=$(uuidgen) && aws route53 create-hosted-zone --name $NAME --caller-reference $ID >>$H_ZONE_FILE
}

createComment() {
# mpw v0.2
	COMMENT=$1
	jq '. | .Comment="'"$COMMENT"'"' $K8_DEF_ENV >>$K8_ENV
	echo "Created  $COMMENT"
}

createResourceRecordSet() {
# mpw v0.2
	SUBDOMAIN_NAME=$1
	jq '. | .Changes[0].ResourceRecordSet.Name="'"$NAME"'"' $K8_ENV >>$KOPS_HOME/k8-sub-domain-updated.json
	mv $KOPS_HOME/k8-sub-domain-updated.json $K8_ENV
	echo "Created Sub-Domain $NAME"
	createAddress
}

createAddress() {
	ADDRESS_1=$(jq '. | .DelegationSet.NameServers[0]' $KOPS_HOME/h-zone.json)
	ADDRESS_2=$(jq '. | .DelegationSet.NameServers[1]' $KOPS_HOME/h-zone.json)
	ADDRESS_3=$(jq '. | .DelegationSet.NameServers[2]' $KOPS_HOME/h-zone.json)
	ADDRESS_4=$(jq '. | .DelegationSet.NameServers[3]' $KOPS_HOME/h-zone.json)
	echo "Created Address $NAME"
	jq '. | .Changes[0].ResourceRecordSet.ResourceRecords[0].Value='"$ADDRESS_1"' | .Changes[0].ResourceRecordSet.ResourceRecords[1].Value='"$ADDRESS_2"' | .Changes[0].ResourceRecordSet.ResourceRecords[2].Value='"$ADDRESS_3"' | .Changes[0].ResourceRecordSet.ResourceRecords[3].Value='"$ADDRESS_4"' ' $K8_SUB_DOMAIN_ENV >>$KOPS_HOME/k8-sub-domain-updated.json
	mv $KOPS_HOME/k8-sub-domain-updated.json $K8_SUB_DOMAIN_ENV
}

createRecordInParentDomain() {
	H_ZONE_ID=$(aws route53 list-hosted-zones | jq --raw-output '. | .HostedZones[0].Id')
	CHG_ID=$(aws route53 change-resource-record-sets \
		--hosted-zone-id $H_ZONE_ID \
		--change-batch file://$KOPS_HOME/k8-sub-domain.json | jq --raw-output '. | .ChangeInfo.Id')
	echo "CHANGE CREATED : $CHG_ID"
	waitForINSYNC
}

waitForINSYNC() {
	CHANGE_STATUS="PENDING"
	while [[ $CHANGE_STATUS == "PENDING" ]]; do
		echo "TAKING A NAP FOR 5S"
		sleep 5s
		CHANGE_STATUS=$(aws route53 get-change --id $CHANGE_ID | jq --raw-output '. | .ChangeInfo.Status')
		echo "CHANGE Status : $CHANGE_STATUS"
	done
	createCluster
}

createCluster() {
# mpw v0.2
# does not take advantage for creating new s3 store and SSH keys
# all hardcoed for this version
	# create SSH KEYS
	#createSSHKeys
	# create S3 Bucket 
	#createS3Bucket
	#Execute create cluster
	echo "#### Creating KOPS Cluster ####"
	#SSH_PUBLIC_KEY=$SSH_KEY_HOME/id_rsa.pub
	#echo $SSH_PUBLIC_KEY
	kops create cluster \
        --cloud=${CLOUD} \
		--node-count 2 \
		--master-size=t2.micro \
		--master-zones=${AWS_REGION} \
		--zones=$AWS_REGION  \
		--state=$KOPS_STATE_STORE \
		--name=$NAME \
		--node-size=t2.micro \
		--dns-zone $NAME

	echo "############# UPDATE CLUSTER STARTS ################"
    updateCluster
	echo "############# UPDATE CLUSTER ENDS ################"

	echo "############# VALIDATE CLUSTER STARTS ################"
    until result=$(validateCluster)
    do
    echo "exit status of \"validateCluster\" = $?"
    echo $result
    sleep 60
    done
    echo "############# VALIDATE CLUSTER ENDS ################"
}

deleteCluster() {
# mpw v0.2
# does not take advantage  of JSON fiel or Ubunut filesystem config file
# all hardcoed for this version
    # remove domain info in config file and JSON
	#rm -rf $K8_SUB_DOMAIN_ENV
	#rm -rf $KOPS_HOME/k8-sub-domain-updated.json
	# delete cluster $NAME
	kops delete cluster \
	       $NAME \
	      --state=$S3_STORE \
          --yes
}

updateCluster() {
# mpw v0.2
# does not take advantage  of JSON fiel or Ubunut filesystem config file
# all hardcoed for this version
    # remove domain info in config file and JSON
	#rm -rf $K8_SUB_DOMAIN_ENV
	#rm -rf $KOPS_HOME/k8-sub-domain-updated.json
	# delete cluster $NAME
	kops update cluster \
	       $NAME \
	      --state=$S3_STORE \
          --yes
}

validateCluster() {
# mpw v0.2
# does not take advantage  of JSON fiel or Ubunut filesystem config file
# all hardcoed for this version
    # remove domain info in config file and JSON
	#rm -rf $K8_SUB_DOMAIN_ENV
	#rm -rf $KOPS_HOME/k8-sub-domain-updated.json
	# delete cluster $NAME
	kops validate cluster \
	       $NAME \
	      --state=$S3_STORE
}

clean() {
# future versions will take advantage of JSON and Ubuntu filesystem config file
	#rm -rf $K8_SUB_DOMAIN_ENV
	#rm -rf $KOPS_HOME/k8-sub-domain-updated.jsona
	pwd
}

drawMenu() {
	# clear the screen
	tput clear

	# Move cursor to screen location X,Y (top left is 0,0)

	tput cup 5 17
	# Set reverse video mode
	tput rev
	echo "BASH SHELL K8S CLUSTER INSTALL CONFIG"
	tput sgr0

	tput cup 7 15
	echo "1. Clean Install Entire K8S Suite"

	tput cup 8 15
	echo "2. Install K8S Orchestrator Kops"

	tput cup 9 15
	echo "3. Install K8S Controller Kubectl"

	tput cup 10 15
	echo "4. Create K8S Cluster on AWS"

	tput cup 12 15
	echo "5. Validate K8S Cluster on AWS"

	tput cup 14 15
	echo "6. Delete K8S Cluster on AWS"

    tput cup 16 15
	echo "0. Quit"

	# Set bold mode
	tput bold
	tput cup 18 15

	read -p "Enter your choice [1-6] or 0 for Exit: " choice
}

drawMenu
tput sgr0
# set deployservice list
case $choice in
	1)
		echo "#########################"
		echo "Starting a clean INSTALL."
		#getSubDomain
		clean
		installAWSClient
		installKops
		installKubectl
		createSubDomain
		createComment "k8 subdomain $NAME"
		createResourceRecordSet "$NAME"
		createRecordInParentDomain
		echo "#########################"
		;;
	2)
		echo "#########################"
		echo "Starting a Kops INSTALL."
		installKops
		echo "#########################"
		;;
	3)
		echo "#########################"
		echo "Starting a Kubectl INSTALL."
		installKubectl
		echo "#########################"
		;;
	4)
		echo "#########################"
		echo "Creating Cluster."
		#getSubDomain
		Kube_Cmd="create"
		createCluster
		echo "#########################"
		;;
	5)
		echo "#########################"
		Kube_Cmd="validate"
		echo "Validating Cluster."
        result=$(validateCluster)
        echo "exit status of \"validateCluster\" = $?"
        echo $result
		#getSubDomain
		#ex_stat="1'
		#while true ; do
        #  case "$result" in *True*)
        #    result=$(validateCluster)
        #    break
        #   ;;
        #  esac
        #done
		echo "#########################"
		;;
	6)
		echo "#########################"
		Kube_Cmd="delete"
		echo "Deleting Cluster."
		#getSubDomain
		deleteCluster
		echo "#########################"
		;;
	0)  echo "                         "
	    echo "#########################"
	    echo "Goodbye Now..."
	    ;;
	*)
		echo "Error: Please try again (select 1..3)!"
		;;
esac
