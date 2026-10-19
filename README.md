# rs-server-deployment

Deployment of the services of [RS-Python](https://github.com/RS-PYTHON/rs-documentation) on a Kubernetes cluster:
[rs-server](https://github.com/RS-PYTHON/rs-server) services, [rs-dpr-service](https://github.com/RS-PYTHON/rs-dpr-service),
STAC browsers, databases and station mockups.

## Overview

This repository is a *package* of applications deployed on the cluster created by
[rs-infra-core](https://github.com/RS-PYTHON/rs-infra-core), with its `apps.yaml` playbook, after
[rs-workflow-env](https://github.com/RS-PYTHON/rs-workflow-env). Each folder of [apps](apps) is an application,
made of a [Kustomize](https://kustomize.io/) file that references a Helm chart of
[rs-helm](https://github.com/RS-PYTHON/rs-helm) and Kubernetes manifests, templated with the variables of the
inventory. The `NN-` prefixes give the deployment order.

| Applications | Description |
|---|---|
| `01-cloudnative-pgstac` | The catalog database: a [PostgreSQL](https://www.postgresql.org/) cluster managed by [CloudNativePG](https://cloudnative-pg.io/), with the [pgSTAC](https://stac-utils.github.io/pgstac/) schema, its scheduled backups in the object storage, its metrics and its Grafana data source. |
| `01-pi-db`, `01-pygeoapi-db`, `01-s3quotamonitoring-db` | The databases of the [performance indicators](https://github.com/RS-PYTHON/rs-client-libraries/blob/develop/docs/doc/operation/performance-indicators.md), of the jobs of the staging service ([pygeoapi](https://pygeoapi.io/)) and of the [object storage quota monitoring](https://github.com/RS-PYTHON/rs-client-libraries/blob/develop/docs/doc/operation/quota-monitoring.md), with their Grafana data sources. |
| `01-dask-cluster-staging` | A launcher that keeps a Dask cluster running in Dask Gateway, for the [staging service](https://github.com/RS-PYTHON/rs-server/blob/develop/docs/doc/users/staging.md). |
| `01-rs-catalog-staging-configmap` | The bucket configuration of the catalog and of the staging: the bucket and the expiration delay of the products, per owner, collection and product type, see [Object storage buckets and data lifecycle](https://github.com/RS-PYTHON/rs-documentation/blob/develop/docs/administration/update-rs-server.md#object-storage-buckets-and-data-lifecycle). |
| `01-rs-server-station-secrets` | The URLs and credentials of the external stations (CADIP, AUXIP, PRIP, LTA...), see [External data sources](https://github.com/RS-PYTHON/rs-server/blob/develop/docs/doc/users/external-data-sources.md). |
| `02-rs-server-osam` | The [Object Storage Access Manager](https://github.com/RS-PYTHON/rs-server/blob/develop/docs/doc/users/osam.md). |
| `rs-server-adgs`, `rs-server-cadip`, `rs-server-prip` | The services that give a STAC access to the external stations. |
| `rs-server-catalog` | The [catalog service](https://github.com/RS-PYTHON/rs-server/blob/develop/docs/doc/users/catalog.md). |
| `rs-server-staging` | The [staging service](https://github.com/RS-PYTHON/rs-server/blob/develop/docs/doc/users/staging.md). |
| `rs-server-frontend` | The [frontend](https://github.com/RS-PYTHON/rs-server/blob/develop/docs/doc/users/frontend.md): home page and aggregated OpenAPI documentation of the services. |
| `rs-dpr-service-py-<python>-dask-<dask>` | The instances of [rs-dpr-service](https://github.com/RS-PYTHON/rs-dpr-service), one per Python and Dask version used by the processors, see [rs-dpr-service deployment](https://github.com/RS-PYTHON/rs-dpr-service/blob/develop/docs/doc/index.md#deployment). |
| `stac-browser-auxip`, `stac-browser-cadip`, `stac-browser-catalog`, `stac-browser-prip` | The [STAC Browser](https://github.com/radiantearth/stac-browser) web interfaces of the stations and of the catalog, see [Browse products](https://github.com/RS-PYTHON/rs-documentation/blob/develop/docs/services/browse-products.md). |
| `mockup-*` | The station mockups of [rs-testmeans](https://github.com/RS-PYTHON/rs-testmeans), for the test platforms only. |

All the services are deployed in the `processing` namespace, and the databases in the `database` namespace.

### Catalog database initialization

At each deployment of `01-cloudnative-pgstac`, the `init-pgstac-db` job
([job-init-pgstac.yaml](apps/01-cloudnative-pgstac/job-init-pgstac.yaml)) initializes or updates the catalog
database. All its SQL can be run again on an existing database:

1. `pypgstac migrate` creates the pgSTAC schema, or migrates it to the version of the job image.
2. The catalog user gets the `pgstac_read`, `pgstac_ingest` and `pgstac_admin` roles, and the `pgstac, public`
   search path.
3. The script of [configmap-extensions.yaml](apps/01-cloudnative-pgstac/configmap-extensions.yaml) customizes pgSTAC
   for rs-server-catalog:
   - it enables the `context` setting of pgSTAC (number of matching items in the search results);
   - it registers in `pgstac.stac_extensions` the STAC extensions of the inventory variable
     `rs_server_catalog.extensions`, with their JSON schemas, downloaded by an init container;
   - it registers in `pgstac.queryables` the queryables of the inventory variable `rs_server_catalog.queryables`,
     and sets the definition of the `expires` queryable (a UTC date-time);
   - it sets up the search by `externalIds` (see
     [Search by external identifiers](https://github.com/RS-PYTHON/rs-server/blob/develop/docs/doc/users/catalog.md#search-by-external-identifiers)):
     the `externalIds` queryable, the `external_ids_contains` CQL2 operator in `pgstac.cql2_ops`, whose SQL template
     is a jsonb containment on `properties.externalIds`, and the GIN indexes on this expression that serve it,
     `items_external_ids_idx` on `pgstac.items` (so on all its partitions) and
     `queryable_index_template_external_ids_idx` on `pgstac.queryable_index_template` (so that the pgSTAC
     maintenance never drops it). It also removes the `external_ids_tokens` function used before pgSTAC 0.10.

The local mode of [rs-demo](https://github.com/RS-PYTHON/rs-demo/blob/develop/local-mode/scripts/pgstac_post_actions.py)
sets up the search by `externalIds` with the same SQL, and the tests of rs-server-catalog with
`SQL_CREATE_EXTERNAL_IDS_OPERATOR` and `SQL_CREATE_EXTERNAL_IDS_INDEXES` of
[external_ids.py](https://github.com/RS-PYTHON/rs-server/blob/develop/services/catalog/rs_server_catalog/data_management/external_ids.py):
keep them aligned.

## Getting started

Deploy the applications from the bastion, after the
[infrastructure installation](https://github.com/RS-PYTHON/rs-infra-core/blob/develop/docs/installation.md) and the
deployment of [rs-workflow-env](https://github.com/RS-PYTHON/rs-workflow-env):

```shell
cd ~
git clone https://github.com/RS-PYTHON/rs-server-deployment.git
cd ~/rs-infra-core
ansible-playbook apps.yaml -i inventory/mycluster/hosts.yaml -e '{"package_paths": ["~/rs-server-deployment/apps/"]}'

# Deploy (or update) a single application, e.g. the catalog service
ansible-playbook apps.yaml -i inventory/mycluster/hosts.yaml -e '{"package_paths": ["~/rs-server-deployment/apps/"]}' -e app=rs-server-catalog
```

On a production platform, don't deploy the `mockup-*` applications: remove them from your copy of the package. The
parameters of the applications (`rspy`, `rs_server_station_secrets`, `rs_station_mockup`... sections: image versions,
buckets, stations, resources) are in the `host_vars/setup/apps.yml` file of the inventory.

## Documentation

- [Deploy RS-Python](https://github.com/RS-PYTHON/rs-documentation/blob/develop/docs/administration/deploy.md)
- [Update rs-server](https://github.com/RS-PYTHON/rs-documentation/blob/develop/docs/administration/update-rs-server.md):
  versions, stations, buckets and other parameters of the services.
- [rs-helm](https://github.com/RS-PYTHON/rs-helm): parameters of the Helm charts.

## Related repositories

- [rs-helm](https://github.com/RS-PYTHON/rs-helm): Helm charts of the applications.
- [rs-server](https://github.com/RS-PYTHON/rs-server), [rs-dpr-service](https://github.com/RS-PYTHON/rs-dpr-service):
  source code of the services.
- [rs-testmeans](https://github.com/RS-PYTHON/rs-testmeans): station mockups.
- [rs-infra-core](https://github.com/RS-PYTHON/rs-infra-core): Kubernetes infrastructure and deployment playbooks.

## Contributing

See the [contribution guidelines](https://github.com/RS-PYTHON/rs-documentation/blob/develop/docs/developers/contributing.md).
Report bugs in the [issue tracker](https://github.com/RS-PYTHON/rs-server-deployment/issues). In case of sensitive bugs like
security vulnerabilities, please contact <ops_coprs@airbus.com> directly instead of using the issue tracker.

## Licensing

The code in this project is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

---

![](https://raw.githubusercontent.com/RS-PYTHON/.github/refs/heads/main/profile/banner_logo.jpg)

This project is funded by the EU and ESA.
