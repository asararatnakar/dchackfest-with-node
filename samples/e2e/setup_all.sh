#!/bin/bash

UP_DOWN=$1
CH_NAME=$2

COMPOSE_FILE=docker-compose.yaml

function printHelp () {
	echo "Usage: ./network_setup <up|down> <channel-name>"
}

function validateArgs () {
	if [ -z "${UP_DOWN}" ]; then
		echo "Option up / down / restart not mentioned"
		printHelp
		exit 1
	fi
	if [ -z "${CH_NAME}" ]; then
		echo "setting to default channel 'mychannel'"
		CH_NAME=mychannel
	fi
}

function clearContainers () {
        CONTAINER_IDS=$(docker ps -aq)
        if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" = " " ]; then
                echo "---- No containers available for deletion ----"
        else
                docker rm -f $CONTAINER_IDS
        fi
}

function removeUnwantedImages() {
        DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
        if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" = " " ]; then
                echo "---- No images available for deletion ----"
        else
                docker rmi -f $DOCKER_IMAGE_IDS
        fi
}

function replacePrivateKey () {
        cp docker-compose-template.yaml docker-compose.yaml
	 CURRENT_DIR=$PWD
	 cd crypto-config/peerOrganizations/org1.example.com/ca/
        PRIV_KEY=$(ls *_sk)
	 cd $CURRENT_DIR
        sed -i "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
	 cd crypto-config/peerOrganizations/org2.example.com/ca/
        PRIV_KEY=$(ls *_sk)
	 cd $CURRENT_DIR
        sed -i "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
        PRIV_KEY=$(ls crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/keystore/)
        sed -i "s/ORDERER_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
        PRIV_KEY=$(ls crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/keystore/)
        sed -i "s/PEER0_ORG1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
        PRIV_KEY=$(ls crypto-config/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/keystore/)
        sed -i "s/PEER1_ORG1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
        PRIV_KEY=$(ls crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/keystore/)
        sed -i "s/PEER0_ORG2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
        PRIV_KEY=$(ls crypto-config/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/keystore/)
        sed -i "s/PEER1_ORG2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
}

function generateArtifacts () {
        os_arch=$(echo "$(uname -s)-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

        echo "OS_ARCH "$os_arch
	echo
	echo "##########################################################"
	echo "############## Generate certificates #####################"
	echo "##########################################################"
        ./../../$os_arch/bin/cryptogen generate --config=./crypto-config.yaml
	echo
	echo

        replacePrivateKey

	echo "##########################################################"
	echo "#########  Generating Orderer Genesis block ##############"
	echo "##########################################################"
	export ORDERER_CFG_PATH=$PWD
	./../../$os_arch/bin/configtxgen -profile TwoOrgs -outputBlock orderer.block
	echo
	echo

	echo "#################################################################"
	echo "### Generating channel configuration transaction 'channel.tx' ###"
	echo "#################################################################"
	./../../$os_arch/bin/configtxgen -profile TwoOrgs -outputCreateChannelTx channel.tx -channelID $CH_NAME
	echo
	echo

}
function installNodeModules() {
	echo
	if [ -d node_modules ]; then
		echo "============== node modules installed already ============="
	else
		echo "============== Installing node modules ============="
		npm install
	fi
	echo
}

function networkUp () {
	#Lets generate all the artifacts which includes org certs, orderer.block,
        # channel configuration transaction and Also generate a docker-compose file
        generateArtifacts
        export ARCH_TAG=$(uname -m)
	CHANNEL_NAME=$CH_NAME docker-compose -f $COMPOSE_FILE up -d 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR !!!! Unable to pull the images "
		exit 1
	fi
	####TODO: when used node we don't need CLI container
	#docker logs -f cli

	installNodeModules

	PORT=4000 node app
}

function networkDown () {
        docker-compose -f $COMPOSE_FILE down

        #Cleanup the chaincode containers
	clearContainers

	#Cleanup images
	removeUnwantedImages

        # remove orderer block and channel transaction
	rm -rf orderer.block channel.tx crypto-config

	#Cleanup the material
	rm -rf /tmp/hfc-test-kvs_peerOrg* $HOME/.hfc-key-store/ /tmp/fabric-client-kvs_peerOrg*
}

validateArgs

#Create the network using docker compose
if [ "${UP_DOWN}" == "up" ]; then
	networkUp
elif [ "${UP_DOWN}" == "down" ]; then ## Clear the network
	networkDown
elif [ "${UP_DOWN}" == "restart" ]; then ## Restart the network
	networkDown
	networkUp
else
	printHelp
	exit 1
fi
