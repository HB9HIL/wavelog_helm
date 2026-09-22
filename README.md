# Wavelog Helm chart

Deploys [Wavelog](https://github.com/wavelog/wavelog), the amateur radio logbook, on Kubernetes.

| Component | Kind | Notes |
|---|---|---|
| `wavelog` | Deployment | PHP app, `ghcr.io/wavelog/wavelog` |
| `wavelog-worker` | Deployment | [wavelog_worker](https://github.com/wavelog/wavelog_worker) for WebSockets, nodes coordinate via Valkey |
| `wavelog-valkey` | Deployment | sessions, cache, worker pub/sub |
| `wavelog-cron` | Deployment | curl loop calling `/index.php/cron/run` every minute |
| `wavelog-db` | Deployment | MariaDB, optional (`mariadb.deploy_db`) |

The Ingress routes `/ws` to the worker and `/` to the app on the same host. It is
required for WebSockets in the browser.

## Install

```bash
helm install wavelog oci://ghcr.io/hb9hil/charts/wavelog \
  --namespace wavelog --create-namespace \
  --set ingress.host=log.example.com \
  --set mariadb.password="$(openssl rand -hex 16)" \
  --set worker.secret="$(openssl rand -hex 32)"
```

Keep the release name `wavelog`. Service names derive from it, and you will
write them into `redis.php` and `worker.php` by hand. `helm install log ...`
gives you `log-wavelog-valkey` instead of `wavelog-valkey`.

`worker.secret` and `mariadb.password` are required. Put them in a values
file you do not commit rather than on the command line.

## First run

1. Open `https://<ingress.host>` and run the web installer. `helm install`
   prints the database host, name and user (`helm get notes wavelog`).
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
   installer. More replicas need `ReadWriteMany` storage for the shared volumes:

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
| `wavelog.replicas` | `1` | raise after the installer has finished |
| `wavelog.image.tag` | `""` | empty = `Chart.appVersion` |
| `wavelog.configSecrets` | `[]` | Secrets with PHP config files, replaces the config PVC |
| `wavelog.imagePullSecrets` | unset | for private registries |
| `worker.replicas` | `3` | scales freely |
| `worker.secret` | required | shared secret with `worker.php` |
| `mariadb.deploy_db` | `true` | `false` = external database |
| `mariadb.password` | required if `deploy_db` | set before first install |
| `mariadb.config` | see values | rendered into `99-tuning.cnf` |
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
- Switching `deploy_db` to `false` keeps the `dbdata` PVC (`helm.sh/resource-policy: keep`).
- Apache access/error logs go to the container's stdout/stderr. Wavelog's own
  `log_message()` output does not: CodeIgniter writes it to a file under `log_path`,
  and the file name is hardcoded. With `one_log = true` the name becomes
  `log-<base_url without scheme and slashes>.php`, which a symlink can point at stderr.
  In `config.php`:

  ```php
  $config['log_path'] = '/tmp';
  $config['one_log'] = true;
  @symlink('/proc/self/fd/2', '/tmp/log-wavelog.example.com.php');
  ```

  Adjust the file name to your `base_url`. The lines then show up in the `wavelog`
  container log as `ERROR - <timestamp> --> <message>`.
