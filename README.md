# Step by step instructions

### Fork or Clone repo

```
git clone https://github.com/asararatnakar/dchackfest-with-node.git

cd dchackfest-with-node/samples/e2e

```



### Generate Org certificates

**Make sure to set the os_arch env**

```
os_arch=$(echo "$(uname -s)-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
```

```
./../../$os_arch/bin/cryptogen generate --config=./crypto-config.yaml
```

### Generate the orderer.block and channel configuration transactions

##### export the env variable, so that configtxgen will pick the certs and configtx.yaml from current DIR
`export ORDERER_CFG_PATH=$PWD`

Generate the orderer genesis block

```
./../../$os_arch/bin/configtxgen -profile TwoOrgs -outputBlock orderer.block
```

Generate the channel configuration block
```
./../../$os_arch/bin/configtxgen -profile TwoOrgs -outputCreateChannelTx channel.tx -channelID mychannel
```

### Launch the docker based local network

Use the helper commands given [here](https://github.com/asararatnakar/dchackfest-with-node#helper-commands),
				OR
change the entries manually in your docker-compose.yaml and launch the network with following command

**Make sure to export the OS ARCH_TAG**

```
export ARCH_TAG=$(uname -m)
CHANNEL_NAME=mychannel docker-compose up -d
```

### Launch the docker based local network

Install the required node modules

```
npm install 
```

### start the node app in TERMINAL-1

```
	node app
```

### Issue the REST API commands from TERMINAL-2

```
	./testAPIs.sh
```
------------------------------------------ O R ---------------------------------------------

## Let the script do every thing for you "All In One"

#### Generate all artifacts in Terminal 1

Excute the **setup_all.sh** script to generate the following
	* Certificates for all the orgs - **crypto-config/**
	* orderer genesis block - **orderer.block**
	* channel configuration transaction - **channel.tx**

```
	setup_all.sh restart
```

#### Call REST End Points from another script in Terminal 2

```
	./testAPIs.sh
```

-------------------------------------------------------------------------------------------------

## Helper commands

Use these commands to update the private key entries in your docker-compose file

```
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
```
