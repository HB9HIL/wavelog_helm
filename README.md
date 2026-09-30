# Wavelog Helm chart

Deploys [Wavelog](https://github.com/wavelog/wavelog), the amateur radio logbook, on Kubernetes.

| Component | Kind | Notes |
|---|---|---|
| `wavelog` | Deployment | PHP app, `ghcr.io/wavelog/wavelog` |
| `wavelog-worker` | Deployment | [wavelog_worker](https://github.com/wavelog/wavelog_worker) for WebSockets, nodes coordinate via Valkey |
| `wavelog-valkey` | Deployment | HAProxy in front of the Valkey nodes, always routes to the current master |
| `wavelog-valkey-node` | StatefulSet | 3 Valkey nodes with Sentinel sidecars: sessions, cache, worker pub/sub. No persistence, the replicas carry the data across node restarts |
| `wavelog-cron` | Deployment | curl loop calling `/index.php/cron/run` every minute |
| `wavelog-db` | Deployment | MariaDB, optional (`mariadb.deploy_db`) |

The Ingress routes `/ws` to the worker and `/` to the app on the same host. It is
required for WebSockets in the browser.

## Install

```bash
helm install wavelog oci://ghcr.io/hb9hil/charts/wavelog \
  --namespace wavelog --create-namespace \
  --set ingress.host=log.example.com \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt \
  --set mariadb.password="$(openssl rand -hex 16)" \
  --set worker.secret="$(openssl rand -hex 32)"
```

The Ingress expects its certificate in the Secret `wavelog-tls`. The
cert-manager annotation creates it. Replace `letsencrypt` with your
ClusterIssuer. Without cert-manager, create `wavelog-tls` yourself. With TLS in
front of the cluster, drop the annotation and set `ingress.tls=false`.

The installer and `worker.php` need the generated secrets. Read them back with
`helm get values wavelog -n wavelog`.

Keep the release name `wavelog`. Service names derive from it, and you will
write them into `redis.php` and `worker.php` by hand. `helm install log ...`
gives you `log-wavelog-valkey` instead of `wavelog-valkey`.

`worker.secret` and `mariadb.password` are required. Put them in a values
file you do not commit rather than on the command line.

## First run

1. Open `https://<ingress.host>` and run the web installer. `helm install`
   prints the database host, name and user (`helm get notes wavelog`).

   **The installer does not configure the worker.** The `wavelog-worker` pods
   run, but Wavelog ignores them and has no WebSockets until you add
   `worker.php` in step 2. The installer does not set up Valkey either, so
   you add `redis.php` yourself as well.
2. Add your own PHP config files to `application/config/docker`. Two ways:

   **a) config PVC (default).** The PVC is shared by all replicas, copying into
   one pod is enough:

   ```bash
   POD=$(kubectl -n wavelog get pod -l app.kubernetes.io/name=wavelog -o name | head -1)
   for f in config.php redis.php worker.php; do
     kubectl -n wavelog cp $f ${POD#pod/}:/var/www/html/application/config/docker/$f
   done
   kubectl -n wavelog rollout restart deploy/wavelog
   ```

   **b) Secrets (`wavelog.configSecrets`).** One Secret per file, all mounted
   together, the config PVC is not created. Suited for GitOps with SOPS:

   ```bash
   kubectl -n wavelog create secret generic wavelog-config-php --from-file=config.php
   kubectl -n wavelog create secret generic wavelog-database-php --from-file=database.php
   # ...
   ```
   ```yaml
   wavelog:
     configSecrets: [wavelog-config-php, wavelog-database-php, wavelog-redis-php, wavelog-worker-php]
   ```
   `database.php` is written by the installer, copy it out of the pod first.

   Values for `redis.php` and `worker.php` are in the notes. `worker_secret`
   in `worker.php` must equal `worker.secret`.

3. Scale up. `wavelog.replicas: 1` is the default so only one pod runs the
   installer.

   **Before scaling, move sessions to Valkey in `config.php`.** The default
   `files` driver keeps sessions in the pod's `/tmp`. With more than one
   replica, users get logged out whenever a request hits a different pod.

   ```php
   $config['sess_driver'] = 'redis2';
   $config['sess_save_path'] = 'tcp://wavelog-valkey:6379';
   ```

   More replicas also need `ReadWriteMany` storage for the shared volumes:

   ```yaml
   wavelog:
     replicas: 3
   persistence:
     uploads:  { storageClass: cephfs, accessMode: ReadWriteMany }
     userdata: { storageClass: cephfs, accessMode: ReadWriteMany }
     appcache: { storageClass: cephfs, accessMode: ReadWriteMany }
     backup:   { storageClass: cephfs, accessMode: ReadWriteMany }
     updates:  { storageClass: cephfs, accessMode: ReadWriteMany }
     config:   { storageClass: cephfs, accessMode: ReadWriteMany }   # unless configSecrets
   ```

## External database

```yaml
mariadb:
  deploy_db: false
```

Nothing MariaDB-related is rendered, the connection goes into `database.php`.
If your CNI masquerades egress, the database sees the node IPs, not the pod
IPs. Grant the user for every node.

## Values

| Key | Default | Description |
|---|---|---|
| `wavelog.replicas` | `1` | raise after the installer has finished and `sess_driver` is `redis2` |
| `wavelog.image.tag` | `""` | empty = `Chart.appVersion` |
| `wavelog.configSecrets` | `[]` | Secrets with PHP config files, replaces the config PVC |
| `wavelog.imagePullSecrets` | unset | for private registries |
| `wavelog.apache.mpm` | see values | Apache prefork limits, `replicas * MaxRequestWorkers < max_connections` of the DB |
| `worker.replicas` | `3` | scales freely |
| `worker.secret` | required | shared secret with `worker.php` |
| `mariadb.deploy_db` | `true` | `false` = external database |
| `mariadb.password` | required if `deploy_db` | set before first install |
| `mariadb.config` | see values | rendered into `99-tuning.cnf` |
| `valkey.resources`, `valkey.sentinel.resources` | see values | per Valkey node |
| `valkey.haproxy.replicas` | `3` | |
| `persistence.storageClass` | `""` | fallback for all volumes |
| `persistence.<vol>.{size,storageClass,accessMode}` | see values | per-volume settings |
| `ingress.className` | `""` | cluster default |
| `ingress.host` | `wavelog.example.com` | canonical host, also used by cron and `worker_client_url` |
| `ingress.extraHosts` | `[]` | additional hosts, `config.php` must accept them |
| `ingress.tls` | `true` | `false` when TLS terminates in front of the cluster |
| `ingress.annotations` | `{}` | e.g. `cert-manager.io/cluster-issuer` |
| `priorityClassName` | `""` | applied to all pods |
| `*.metadata.annotations` | `{}` | on the Deployment, e.g. for Keel |

Keel example for auto-updating the `dev` tag:

```yaml
wavelog:
  image: { tag: dev, pullPolicy: Always }
  metadata:
    annotations:
      keel.sh/policy: force
      keel.sh/match-tag: "true"
      keel.sh/trigger: poll
      keel.sh/pollSchedule: "@every 5m"
```

## Good to know

- The cron pod calls the service directly with `Host: <ingress.host>`, so it
  never leaves the cluster. `429` in its log is Wavelog's own 30 s lock, not an error.
- `helm upgrade` does not touch the PHP files in the config PVC. Deleting the
  PVC does.
- NetworkPolicies are not part of the chart. With default-deny (e.g. Cilium),
  allow at least traffic within the namespace, egress `443` for updates and
  lookups, and your SMTP port.
- Switching `deploy_db` to `false` keeps the `dbdata` PVC (`helm.sh/resource-policy: keep`).
