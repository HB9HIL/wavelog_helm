# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.2.1] - 2026-10-03

### Added
- `cron.timeout` is now configurable and set to a default of 1200 seconds. On large instances the cron job may take longer... (by @HB9HIL)

## [2.2.0] - 2026-10-02

### Added
- Sidecar `wavelog-applog` prints the Wavelog application log (`application/logs/`, now a per-pod `emptyDir`) to stdout and deletes older days. Requires `one_log = false` and an empty `log_path` in `config.php`. (by @HB9HIL)

## [2.1.1] - 2026-09-30

### Fixed
- Fixed a small syntax error in renovate config (by @HB9HIL)

## [2.1.0] - 2026-09-30

This will cause a complete cache wipeout and all users need to relogin

### Changed
- valkey is now high available and users won't notice any longer that there are cluster reboots and reschedules. Since we have now multiple replicas of valkey there is no need to persist anything (by @HB9HIL)

## [2.0.1] - 2026-09-28

### Changed
- NOTES show how to read back `mariadb.password` and `worker.secret`, and warn when TLS is on without a cert-manager annotation. They also list the `sess_driver`/`sess_save_path` settings for Valkey. (by @HB9HIL)

### Docs
- README install sets the cert-manager annotation, explains the `wavelog-tls` Secret and mentions NetworkPolicies. Scaling up requires `sess_driver = 'redis2'` in `config.php`. The web installer does not configure the worker, `worker.php` has to be added by hand. (by @HB9HIL)

## [2.0.0] - 2026-09-26

### Changed
- MariaDB updated to 12.3 LTS. `MARIADB_AUTO_UPGRADE` is now set, so existing databases run `mariadb-upgrade` on start. (by @HB9HIL)
- Valkey updated to 9.1. (by @HB9HIL)

### Added
- GitHub release with notes from this changelog on every tag. (by @HB9HIL)

### Chore
- Dependency updates via Renovate. (by @renovate)

## [1.1.1] - 2026-09-26

### Changed
- Better load distribution: topology spread for Wavelog and worker now uses `DoNotSchedule` with `nodeTaintsPolicy: Honor` and `matchLabelKeys: pod-template-hash`. (by @HB9HIL)

## [1.1.0] - 2026-09-23

### Added
- `wavelog.apache.mpm` to tune Apache prefork limits, so `replicas * MaxRequestWorkers` stays below the DB `max_connections` with pconnect. (by @HB9HIL)

## [1.0.1] - 2026-09-22

### Fixed
- Cron drift, the cron job now runs hardcoded every minute. (by @HB9HIL)

## [1.0.0] - 2026-09-22

### Added
- Initial release of the Wavelog Helm chart.
