# Faktory Worker Logging

Faktory Worker uses the [Telemetry](https://github.com/beam-telemetry/telemetry) library to emit events that can be handled by either Faktory Worker or the consuming application. This provides the flexibility for the consumer of Faktory Worker to choose how logging should behave.

By default Faktory Worker will not output any log messages. Logging needs to be explicitly enabled by calling the `FaktoryWorker.attach_default_telemetry_handler/0` function.

Events can also be handled in the consuming application by manually attaching to Telemetry specifying the list of Faktory Worker events to handle. For instructions on creating a custom event handler see the Telemetry [README](https://github.com/beam-telemetry/telemetry/blob/master/README.md).

All Faktory Worker events are prefixed with `:faktory_worker` and have a single event name. For example the full event name for the `push` event is `[:faktory_worker, :push]`.

The measurements data included for all events will be a map containing a `status` field that will indicate the outcome of the event being emitted. The available outcomes are listed individually below for each type of event.

## Push Event

Event Name: `[:faktory_worker, :push]`.

The push event is emitted when a job has been sent to Faktory. The `status` of this event indicates whether the job was sent successfully.

The available status outcomes are.
- `:ok` - The job was successfully sent to Faktory.
- `{:error, :not_unique}` - The job was not sent to Faktory because another job with the same uniqueness already exists.

The `metadata` supplied with this event is a map containing the Faktory job arguments.

## Fetch Event

Event Name: `[:faktory_worker, :fetch]`.

The fetch event is emitted when attempting to fetch a job from Faktory. The `status` of this event indicates whether the fetch request was sent successfully.

The available status outcomes are.
- `{:error, reason}` - The request to fetch from Faktory failed. The `reason` will be any valid `term` indicating the reason the fetch failed.

The `metadata` supplied with this event is a map containing the following fields.
- `wid` - A worker identifier that can be used to identify which worker emitted this event.

## Ack Event

Event Name: `[:faktory_worker, :ack]`.

The ack event is emitted when reporting the success or failure of a processed job to Faktory. The `status` of this event indicates the outcome of processing the job.

The available status outcomes are.
- `:ok` - The job completed successfully and has been reported to Faktory.
- `:error` - The job failed to complete and has been reported to Faktory with details about the failure.

The `metadata` supplied with this event is a map containing the Faktory job arguments.

## Failed Ack Event

Event Name: `[:faktory_worker, :failed_ack]`.

The failed ack event is emitted when Faktory Worker was unable to report the outcome of processing a job to Faktory. The `status` of this event indicates the outcome of the processed job that failed to reach Faktory.

The available status outcomes are.
- `:ok` - The job completed successfully.
- `:error` - The job failed to complete.

The `metadata` supplied with this event is a map containing the Faktory job arguments.

## Beat Event

Event Name: `[:faktory_worker, :beat]`.

The beat event is emitted every time a worker has attempted to send a heartbeat message to Faktory. The `status` of this event indicates whether the heartbeat message was successfully received by Faktory.

The available status outcomes are.
- `:ok` - The heartbeat message was successfully received by Faktory.
- `:error` - The heartbeat message failed to reach Faktory.

The `metadata` supplied with this event is a map containing the following fields.
- `wid` - A worker identifier that can be used to identify which worker emitted this event.
- `prev_status` - The `status` that was emitted on the previous `beat` event. This is useful for tracking when the status has changed between hearbeats.