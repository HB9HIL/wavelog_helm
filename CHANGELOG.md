# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
