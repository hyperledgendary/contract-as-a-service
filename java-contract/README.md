## Smart Contract
The contract in this example is simple, but it's here just to demonstrate how it can be deployed. It's the basic getting started contract found in the Fabric Docs and the IBP VSCode exentions. The key thing is the dockerfile that is used to package up the contract, a new 'main' class and minor change to the build file.

### Chaincode-as-a-server
'Normally' the Peers will start (directly or indirectly in the case of things like IBP) the chaincode processes running. In this case, when the chaincode starts it 'calls back' to the peer to 'register'.

Here things are a bit different - the chaincode process becomes a server, and it's up to the peer to connect to it when needed to 'register'.

Once this initial 'registration' is complete, logically there's no difference between the two setups.

*Main Application* 

A very basic application needs to be added; the full source is a single class called [ContractBootstrap.java](./src/main/java/org/example/ContractBootstrap.java).
Most of this code is reading environment variables, and setting up basic configuration. 

The final call to start the 'chaincode server' is 

```
ContractRouter contractRouter = new ContractRouter(new String[] {"-i", coreChaincodeIdName});
ChaincodeServer chaincodeServer = new NettyChaincodeServer(contractRouter, chaincodeServerProperties);

contractRouter.startRouterWithChaincodeServer(chaincodeServer);
```

*Note* there are NO changes to the actual contract or libraries use; it's just this main class and a change in the `build.gradle` to run this main class. You may use maven if you want.

The TLS settings are refering to files that will mounted into the chaincode when this is deployed into K8S. The actual locations are arbitrary so you may alter them if you wish. 

### Dockerfile 

Firstly the dockerfile itself. This is a relatively simple node.js dockerfile, you've liberty here construct this as you wish. 

```docker
# the first stage 
FROM gradle:jdk11 AS GRADLE_BUILD
 
# copy the build.gradle and src code to the container
COPY src/ src/
COPY build.gradle ./ 
COPY repository/ repository/

# Build and package our code
RUN gradle build shadowJar


# the second stage of our build just needs the compiled files
FROM openjdk:11-jre-slim
# copy only the artifacts we need from the first stage and discard the rest
COPY --from=GRADLE_BUILD /home/gradle/build/libs/chaincode.jar /chaincode.jar
 
ENV PORT 9999
EXPOSE 9999

# set the startup command to execute the jar
CMD ["java", "-jar", "/chaincode.jar"]
```

Note the PORT is being set as 9999, and the command that is being run. So long as that command is run - and a port is setup that's the key thing. The port can be of your own choosing, 9999 is used here. 



Secondly you need to build and push this to a registry. The registry that I'm using is the container registry connected to the IBM K8S Cluster.
Ensure you've logged into the container registry (`ibmcloud cr login`) and push the docker image. If you don't have a namespace already create one, with for example  `ibmcloud cr namespace-add ibp_caas`


```bash 
just buildcontract java
```
This will build and then tag the image with `uk.icr.io/<my_namespace>/<my_repository>:<my_tag>` and push it for later use.
