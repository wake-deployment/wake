# Wake

Wake packages, deploys, manages and orchestrates applications and application environments.

## Wake vs. Other Infrastructure Frameworks

Wake is an end-to-end solution for managing applications and application
environments from version control commit to running in production. Wake uses
other pluggable infrastructure frameworks such as Kubernetes or Docker Swarm
to power many of its features. In addition to the functionality that these
frameworks provide, wake also offers other pluggable abstractions over IaaS
providers, logging, and other common infrastructure needs.

# Prereqs

* docker
* docker-machine

_NOTE: On Windows, you'll need to ensure that OpenSSL has access to a certificate
authority bundle.  Download the [Mozilla Certificat bundle](https://raw.githubusercontent.com/bagder/ca-bundle/master/ca-bundle.crt)
locally, and set the `SSL_CERT_FILE` environment variable to reference this file._

You may also want to add wake's bin directory to your path for ease of use.

# Terms

**cluster**: a collection of nodes (hosts) managed together as a unit

**node**: a host in the cluster

**process**: the smallest unit of work (e.g. a web server or background job)

**application**: is a list of related processes defined by a `manifest.json`

**service**: is the collection of all running instances of a process

# Concepts

wake is broken up into these concepts:

**cli**: implimentation of the command line interface

**build**: responsible for building and pushing docker images and for
creating build pipelines

**iaas**: libraries for different iaas providers that expose a unified
interface

**infrastructure**: commands for interacting with iaas actions and
security of vms

**secrets**: implementations for different stores for securely getting
and setting application secrets

**orchestration**: libraries for different orchestration frameworks like
kubernetes and swarm

## Orchestration

Required features for an orchestration framework are:

* anti-affinity: two processes of the same application shouldn't be on
  the same vm
* dns:
    * master nodes should be registered in dns for easy discovery
    * services should be auto-addressable by dns names
* load balancing (internal and external)
* upgrade deployment strategy (replace/rollback)

# Opinions

wake is opinionated about:

* immutable infrastructure
* cluster bootstrap and scaling with iaas cli/http apis
* log aggregation
* secrets management
* ssh access
* building docker images

# CLI conventions

Every command supports these three flags:

* `-v` or `--verbose` which will output lots of extra logging
  information
* `-V` or `--very-verbose` which will output a ton of extra logging
  information that is mostly unecessary
* `-h` or `--help` which will output the usage information

# Cluster

A cluster is a logical collection of nodes.

Clusters are kept track of in `~/.wake/clusters` and can be managed with
the `wake clusters` command.

## Create a cluster

```sh
$ wake clusters create --name wake-test-1 --iaas azure --location eastus --orchestrator kubernetes
```

_NOTE: azure is the only supported IaaS provider at this time._

## List known clusters

```sh
$ wake clusters list
```

## Set the default cluster

Having a default cluster makes everything else easier, since almost
every other command will need to know which cluster to perform the
operation on (like creating a new host, where should it go?).

```sh
$ wake clusters set-default -n wake-test-1
```

## Delete a cluster

```sh
$ wake clusters delete -n wake-test-1
```

_NOTE: `wake-clusters-delete` will ask you to confirm the name of the
cluster before proceeding. It's possible to pass `--pre-confirm` with
the name again to prevent the confirmation prompt._

> *Environments*
>
> There are no environments with wake. Make a new cluster with a different name.

# Application conventions

**Every process must listen on port 8000 for `/_health`**

# `manifest.json`

Here are some examples:

```json
{
  "platform": "ruby",
  "app": "bestsiteever",
  "owners": [
    "nathan.herald@microsoft.com"
  ],
  "processes": {
    "web": {
      "start": "cd /opt/app && bin/puma -c config/puma.rb",
      "cpu": 1,
      "memory": 0.5
    },
    "worker": {
      "start": "cd /opt/app && bundle exec rake jobs:work",
      "cpu": 1,
      "memory": 0.5
    }
  }
}
```

```json
{
  "platform": "sbt",
  "app": "proxy",
  "owners": [
    "nathan.herald@microsoft.com"
  ],
  "processes": {
    "proxy": {
      "cpu": 4,
      "memory": 4,
      "start": "cd /opt/app && sbt run"
    }
  }
}
```

# docker images

wake is opinionated about how docker images are created. wake includes
pre-built `Dockerfile`s for different platforms. If your project does
not include a `Dockerfile` then one will be provided during build.

To build and push a docker image:

```sh
$ cd path/to/project
$ wake build
```

To build an image for a certain commit then specify the sha or branch:

```sh
$ wake build -r b5aedadd
```

# Deploy

Images are deployed with `wake deploy`.

# Scaling

Services are scaled with `wake scale`.

# Secrets

Secrets are configured with `wake secrets`.
