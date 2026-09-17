# Changelog

## v1.3.0 - 2026-09-18

### Changed

- Time-bucketed keys now prefer `Time.current` (when ActiveSupport is loaded) over `Time.now`, so bucket boundaries follow the application's configured time zone instead of each host's TZ

### Fixed

- Daily window keys are now built by calendar-day arithmetic; elapsed-seconds arithmetic could skip a date around a DST transition

## v1.2.0 - 2026-09-16

### Changed

- `union` now reuses an existing destination key instead of always recomputing it, so its 900 second TTL works as a cache
- `union_dest` now includes `decay_factor` so decayed and non-decayed results no longer share a cache entry

## v1.1.0 - 2026-04-17

### Added

- `#rank` returns the 1-indexed ranking position of an instance; returns `nil` if unranked
- `#remove_hits` removes all recorded hits for an instance across all keys

### Changed

- Bucket count unified to 90 across all time granularities; data is retained longer
- `hit_counts` now uses a single ZMSCORE call instead of N ZSCORE calls

## v1.0.0 - 2026-04-15

### Added

- `.top` now accepts a required `limit` keyword argument; pass `nil` to retrieve all results

### Fixed

- `require "weathercock"` now loads `Weathercock::Scorable` automatically

## v0.1.0 - 2026-04-15

Initial release.
