export MICROFAB_CONFIG='{
    "endorsing_organizations":[
        {
            "name": "DigiBank"
        }
    ],
    "channels":[
        {
            "name": "assetnet",
            "endorsing_organizations":[
                "DigiBank"
            ]
        }
    ],
    "capability_level":"V2_0"
}'
LOGGING_SPEC=ccprovider=debug:couchdb=debug:ledgermgmt=debug:lifecycle=debug:privacyenabledstate=debug:statecouchdb=debug:info
docker run --name microfab  --network cc_network --rm -ti -p 8080:8080 -e MICROFAB_CONFIG="${MICROFAB_CONFIG}" -e FABRIC_LOGGING_SPEC=$LOGGING_SPEC ibmcom/ibp-microfab
#docker run --name microfab --network cc_network  --rm -ti -p 8080:8080 -e MICROFAB_CONFIG="${MICROFAB_CONFIG}"  mymicrofab

