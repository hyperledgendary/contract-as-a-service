ARG GO_VER

FROM golang:1.14.15 as golang
ADD . /
WORKDIR /

FROM golang as peer
RUN go build -o /chaincode-server .

FROM registry.access.redhat.com/ubi8/ubi-minimal
COPY --from=peer /chaincode-server /usr/local/bin/chaincode-server

EXPOSE 9999
CMD ["/usr/local/bin/chaincode-server"]