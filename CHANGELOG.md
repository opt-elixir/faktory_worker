## 1.9.7 - 2024-02-27

- Heartbeat can recover from an error condition. [#201](https://github.com/opt-elixir/faktory_worker/pull/201)
- Maintenance - minor alignment with conventions, and fix lingering test issues. [#200](https://github.com/opt-elixir/faktory_worker/pull/200)
- Bump ex_doc from 0.30.6 to 0.31.1. [#199](https://github.com/opt-elixir/faktory_worker/pull/199)
- Bump excoveralls from 0.17.1 to 0.18.0 [#196](https://github.com/opt-elixir/faktory_worker/pull/196)

## 1.9.6 - 2023-07-25

- fix queue distribution [#195](https://github.com/opt-elixir/faktory_worker/pull/195)
- Bump mox from 1.0.2 to 1.1.0 dependencies [#193](https://github.com/opt-elixir/faktory_worker/pull/193)
- Bump ex_doc from 0.29.4 to 0.30.6 dependencies [#192](https://github.com/opt-elixir/faktory_worker/pull/192)
- Bump excoveralls from 0.14.6 to 0.17.1 dependencies [#192](https://github.com/opt-elixir/faktory_worker/pull/191)
- Bump jason from 1.4.0 to 1.4.1 dependencies [#189](https://github.com/opt-elixir/faktory_worker/pull/189)
- Bump ex_doc from 0.29.4 to 0.30.3 dependencies [#188](https://github.com/opt-elixir/faktory_worker/pull/188)

## 1.9.5 - 2023-07-25

- acks running jobs whenever a worker is terminated, as successful via `ACK` if
  the job just completed, or as failed via `FAIL` if the job was incomplete;
  this should fix the issue in continuous deployment environments when a
  deployment is terminated and replaced by a newer instance where any in-progress
  jobs are left hanging ([#186](https://github.com/opt-elixir/faktory_worker/pull/186))

## 1.9.4 - 2023-07-18

### Updates

- adds queue and duration to relevant push/ack telemetry events, allowing improved observability around how long jobs take to complete and allowing telemetry events to be aggregated by queue in addition to job type. Logger messages now also include the queue (when it's anything other than default) and job duration in the case of either success or failure. ([#184](https://github.com/opt-elixir/faktory_worker/pull/185))

## 1.9.3 - 2022-12-02

### Fixes

- Add ability to test code that contains faktory batches by returning default values for these rather than crashing/timing out

## [1.9.2] - 2022-10-31

### Fixes

- Fixes issue where ports that timed our of were closed upstream were not closed in faktory_worker ([#172](https://github.com/opt-elixir/faktory_worker/pull/172))

### Updates

- Bump jason from 1.3.0 to 1.4.0 ([#170](https://github.com/opt-elixir/faktory_worker/pull/170))
- Bump ex_doc from 0.28.4 to 0.28.5 ([#169](https://github.com/opt-elixir/faktory_worker/pull/169))

## [1.9.1] - 2022-08-24

- Add more granular warn/error level logging for various events in telemetry ([#166](https://github.com/opt-elixir/faktory_worker/pull/166))

## [1.9.0] - 2022-05-11

- `FaktoryWorker.send_command/2` added to make one-off commands more ergonomic
- support added for `TRACK GET` and `TRACK SET` commands

## [1.8.1] - 2022-04-04

- Push timeouts will no longer `raise` by default (instead of raising, they will
  now return `{:error, :timeout}`).

## [1.8.0] - 2022-04-04

- Fix `parent_id` vs `parent_bid`
This was a typo making passing of children batches require using `parent_id` over `parent_bid` which the docs say
- Bump some deps with dependabot (`telemetry` 1.0.0 to 1.1.0, `ex_doc` from `0.28` to `0.28.3`

## [1.7.0] - 2022-02-09

### Removed

- Removed Broadway to simplify supervision tree [#149](https://github.com/opt-elixir/faktory_worker/pull/149)

## Updates

- Updated exDoc [#151](https://github.com/opt-elixir/faktory_worker/pull/151)

## [1.6.0] - 2021-11-05

### Added

- Enterprise batching support in [#139](https://github.com/opt-elixir/faktory_worker/pull/139)

### Changed

- Bump excoveralls from 0.14.1 to 0.14.4 [#140](https://github.com/opt-elixir/faktory_worker/pull/140)
- Bump ex_doc from 0.24.2 to 0.25.5 [#141](https://github.com/opt-elixir/faktory_worker/pull/141)
- Bump mox from 1.0.0 to 1.0.1 [#142](https://github.com/opt-elixir/faktory_worker/pull/142)
- Bump broadway from 1.0.0 to 1.0.1 [#143](https://github.com/opt-elixir/faktory_worker/pull/143)
