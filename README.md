# Data channels #

This tool is an extention/editing of the fast-data-dev implementation powered by Landoop (please see the basic implementation clicking in this URL: https://github.com/Landoop/fast-data-dev)

### Open source tools

Open source tools installed within this image are:

1. **Confluent** OSS with Apache Kafka including: ZooKeeper, Schema Registry, Kafka REST
2. **Landoop** Fast Data Tools including: kafka-topics-ui, schema-registry-ui


### Customize execution

You can further customize the execution of the container with additional flags:

 optional_parameters            | usage
------------------------------- | ------------------------------------------------------------------------------------------------------------
 `WEB_ONLY=1      `             | Run in combination with `--net=host` and docker will connect to the kafka services running on the local host
 `CONNECT_HEAP=3G`              | Configure the heap size allocated to Kafka Connect
 `PASSWORD=password`            | Protect you kafka resources when running publicly with username `kafka` with the password you set
 `USER=username`                | Run in combination with `PASSWORD` to specify the username to use on basic auth
 `RUNTESTS=0`                   | Disable the (coyote) integration tests from running when container starts
 `DISABLE_JMX=1`                | Disable JMX - enabled by default on ports 9581 - 9585
 `TOPIC_DELETE=0`               | Configure whether you can delete topics. By default topics can be deleted.
 `<SERVICE>_PORT=<PORT>`        | Custom port `<PORT>` for service, where `<SERVICE>` one of `ZK`, `BROKER`, `BROKER_SSL`, `REGISTRY`, `REST`
 `ENABLE_SSL=1`                 | Generate a CA, key-certificate pairs and enable a SSL port on the broker
 `SSL_EXTRA_HOSTS=IP1,host2`    | If SSL is enabled, extra hostnames and IP addresses to include to the broker certificate
 `DEBUG=1`                      | Print stdout and stderr of all processes to container's stdout. Useful for debugging early container exits.



### Building it

To build it just run:

    docker build -t nimble/data-channels .

Also periodically pull from docker hub to refresh your cache.

### Advanced settings

#### Custom Ports

To use custom ports for the various services, you can take advantage of the
`ZK_PORT`, `BROKER_PORT`, `REGISTRY_PORT`, `REST_PORT` and
`WEB_PORT` environment variables. One catch is that you can't swap ports; e.g
to assign 8082 (default REST Proxy port) to the brokers.

    docker run --rm -it \
               -p 3181:3181 -p 3040:3040 -p 7081:7081 \
               -p 7082:7082 -p 7083:7083 -p 7092:7092 \
               -e ZK_PORT=3181 -e WEB_PORT=3040 -e REGISTRY_PORT=8081 \
               -e REST_PORT=7082  -e BROKER_PORT=7092 \
               -e ADV_HOST=127.0.0.1 \
               nimble/data-channels


#### View logs

Every application stores its logs under `/var/log` inside the container.
If you have your container's ID, or name, you could do something like:

    docker exec -it <ID> cat /var/log/broker.log

#### Enable SSL on Broker

Do you want to test your application over an authenticated TLS connection to the
broker? We got you covered. Enable TLS via `-e ENABLE_SSL=1`:

    docker run --rm --net=host \
               -e ENABLE_SSL=1 \
               nimble/data-channels

When data-channels spawns, it will create a self-signed CA. From that it will
create a truststore and two signed key-certificate pairs, one for the broker,
one for your client. You can access the truststore and the client's keystore
from our Web UI, under `/certs` (e.g http://localhost:3030/certs). The password
for both the keystores and the TLS key is `fastdata`.
The SSL port of the broker is `9093`, configurable via the `BROKER_SSL_PORT`
variable.

Here is a simple example of how the SSL functionality can be used. Let's spawn
a data-channels to act as the server:

    docker run --rm --net=host -e ENABLE_SSL=1 -e RUNTESTS=0 nimble/data-channels

On a new console, run another instance of data-channels only to get access to
Kafka command line utilities and use TLS to connect to the broker of the former
container:

    docker run --rm -it --net=host --entrypoint bash nimble/data-channels
    root@data-channels / $ wget localhost:3030/certs/truststore.jks
    root@data-channels / $ wget localhost:3030/certs/client.jks
    root@data-channels / $ kafka-producer-perf-test --topic tls_test \
      --throughput 100000 --record-size 1000 --num-records 2000 \
      --producer-props bootstrap.servers="localhost:9093" security.protocol=SSL \
      ssl.keystore.location=client.jks ssl.keystore.password=fastdata \
      ssl.key.password=fastdata ssl.truststore.location=truststore.jks \
      ssl.truststore.password=fastdata

Since the plaintext port is also available, you can test both and find out
which is faster and by how much. ;)

### Detailed configuration options

#### Web Only Mode

This is a special mode only for Linux hosts, where *only* Landoop's Web UIs
are started and kafka services are expected to be running on the local
machine. It must be run with `--net=host` flag, thus the Linux only
requisite:

    docker run --rm -it --net=host \
               -e WEB_ONLY=true \
               nimble/data-channels

This is useful if you already have a cluster with Confluent's distribution
installed and want just the additional Landoop Fast Data web UI.

#### Connect Heap Size

You can configure Connect's heap size via the environment variable
`CONNECT_HEAP`. The default is `1G`:

    docker run -e CONNECT_HEAP=5G -d nimble/data-channels

#### Basic Auth (password)

We have included a web server to serve Landoop UIs and proxy the schema registry
and kafa REST proxy services, in order to share your docker over the web.
If you want some basic protection, pass the `PASSWORD` variable and the web
server will be protected by user `kafka` with your password. If you want to
setup the username too, set the `USER` variable.

     docker run --rm -it -p 3030:3030 \
                -e PASSWORD=password \
                nimble/data-channels

#### JMX Metrics

JMX metrics are enabled by default. If you want to disable them for some
reason (e.g you need the ports for other purposes), use the `DISABLE_JMX`
environment variable:

    docker run --rm -it --net=host \
               -e DISABLE_JMX=1 \
               imble/data-channels

JMX ports are hardcoded to `9581` for the broker, `9582` for schema registry,
`9583` for REST proxy. Zookeeper is exposed
at `9585`.
