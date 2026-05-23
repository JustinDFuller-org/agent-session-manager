---
name: observation-documentation
description: Observation official doc index — load when building Observation features, @Observable, withObservationTracking, ObservationRegistrar, or any Observation framework behavior.
user-invocable: false
allowed-tools:
  - WebFetch(domain:developer.apple.com)
---

# Observation Documentation Index

Fetch from this index before implementing any Observation feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://developer.apple.com/documentation/observation` — Main Observation framework page; overview, topic sections, and sample code.

## Observable Conformance

- `https://developer.apple.com/documentation/observation/observable()` — `@Observable` macro: declares and implements conformance to the `Observable` protocol at compile time.
- `https://developer.apple.com/documentation/observation/observable` — `Observable` protocol: type that emits notifications to observers when underlying data changes.

## Change Tracking

- `https://developer.apple.com/documentation/observation/withobservationtracking(_:onchange:)` — `withObservationTracking` function: tracks access to properties within a closure and calls `onChange` when a tracked property changes.
- `https://developer.apple.com/documentation/observation/observationregistrar` — `ObservationRegistrar` struct: provides storage for tracking and access to data changes.
- `https://developer.apple.com/documentation/observation/observationregistrar/init()` — `init()`: creates an instance of the observation registrar.
- `https://developer.apple.com/documentation/observation/observationregistrar/willset(_:keypath:)` — `willSet(_:keyPath:)`: property observation called before setting the value of the subject.
- `https://developer.apple.com/documentation/observation/observationregistrar/didset(_:keypath:)` — `didSet(_:keyPath:)`: property observation called after setting the value of the subject.
- `https://developer.apple.com/documentation/observation/observationregistrar/access(_:keypath:)` — `access(_:keyPath:)`: registers access to a specific property for observation.
- `https://developer.apple.com/documentation/observation/observationregistrar/withmutation(of:keypath:_:)` — `withMutation(of:keyPath:_:)`: identifies mutations to the transactions registered for observers.

## Async Observation

- `https://developer.apple.com/documentation/observation/observations` — `Observations` struct: async sequence generated from a closure that tracks transactional changes of `@Observable` types.
- `https://developer.apple.com/documentation/observation/observations/init(_:)` — `init(_:)`: constructs an async sequence by tracking changes of `@Observable` types.
- `https://developer.apple.com/documentation/observation/observations/untilfinished(_:)` — `untilFinished(_:)`: constructs an async sequence for a given closure, tracking changes of `@Observable` types.
- `https://developer.apple.com/documentation/observation/observations/iterator` — `Observations.Iterator`: iterator for the `Observations` async sequence.
- `https://developer.apple.com/documentation/observation/observations/iteration` — `Observations.Iteration`: enumeration for iteration state.

## Selective Observation

- `https://developer.apple.com/documentation/observation/observationignored()` — `@ObservationIgnored` macro: disables observation tracking of a property.
- `https://developer.apple.com/documentation/observation/observationtracked()` — `@ObservationTracked` macro: synthesizes a property for accessors (used internally by `@Observable`).

## SwiftUI Integration

- `https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app` — Managing model data in your app: creating connections between your app's data model and views.
- `https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro` — Migrating from ObservableObject to Observable: updating existing apps to leverage Observation.
