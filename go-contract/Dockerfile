ARG GO_VER

FROM golang:${GO_VER} as golang
ADD . /
WORKDIR /

FROM golang as peer
RUN go build -o /chaincode-server .

FROM registry.access.redhat.com/ubi8/ubi-minimal
ENV STARTASSERVER true
COPY --from=peer /chaincode-server /usr/local/bin/chaincode-server

EXPOSE 9999
CMD ["/usr/local/bin/chaincode-server"]