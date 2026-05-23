---
name: opentelemetry-swift-documentation
description: OpenTelemetry Swift official doc index — load when building or working with OpenTelemetry Swift features, tracing, metrics, logging, span export, instrumentation, or any OpenTelemetry Swift behavior.
allowed-tools: WebFetch(domain:opentelemetry.io) WebFetch(domain:github.com)
metadata:
  user-invocable: "false"
---

# OpenTelemetry Swift Documentation Index

Fetch from this index before implementing any OpenTelemetry Swift feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://opentelemetry.io/llms.txt` — Complete index of all OpenTelemetry doc pages; fetch when you need a URL not listed here.
- `https://github.com/open-telemetry/opentelemetry-swift` — GitHub repo; README, source layout, package structure, and contribution guide.
- `https://github.com/open-telemetry/opentelemetry-swift/blob/main/Package.swift` — Package manifest; all library products and their dependencies.

## Getting Started & Overview

- `https://opentelemetry.io/docs/languages/swift/` — Main Swift docs hub; status matrix (traces=stable, metrics/logs=dev), releases, and section page index.
- `https://opentelemetry.io/docs/languages/swift/getting-started/` — Quickstart: SPM setup, Vapor example, TracerProvider init, StdoutExporter, span lifecycle.
- `https://opentelemetry.io/ecosystem/registry/?language=swift` — Ecosystem registry filtered for Swift; instrumentation libraries, exporters, and contributed components.

## Instrumentation

- `https://opentelemetry.io/docs/languages/swift/instrumentation/` — Manual instrumentation: OTLP export config (gRPC + HTTP), traces (Tracer, SpanBuilder, nested spans, active span, attributes, events, status, exceptions), metrics API, logs API, SDK processors (SimpleSpanProcessor, BatchSpanProcessor, MultiSpanProcessor), and all exporters (InMemory, Datadog, Jaeger, Persistence, Prometheus, Stdout, Zipkin).

## Instrumentation Libraries

- `https://opentelemetry.io/docs/languages/swift/libraries/` — SDKResourceExtension (device/OS/app resource attributes for `service.*`, `device.*`, `os.*`), NSURLSession instrumentation (config callbacks, network status attributes, distributed tracing header injection), SignPostIntegration / OSSignposterIntegration (Instruments profiling via os_signpost).

## GitHub Examples

- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/ConcurrencyContext` — Context propagation in concurrent Swift code.
- `https://github.com/open-telemetry/opentelemetry-swift/blob/main/Examples/ConcurrencyContext/main.swift` — Active span management and context propagation across tasks.
- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/Custom%20HTTPClient` — Custom HTTP client instrumentation.
- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/Logging%20Tracer` — Simple API tracer that logs every API call to stdout.
- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/Logs%20Sample` — Logs signal example with log record creation and export.
- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/Metric%20Sample` — Legacy metrics API example (pre-stable metrics spec).
- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/Network%20Sample` — URLSessionInstrumentation in a real app; automatic network span creation.
- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/OTLP%20Exporter` — OTLP gRPC exporter sending traces and metrics to an OpenTelemetry Collector.
- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/OTLP%20HTTP%20Exporter` — OTLP HTTP exporter sending traces and metrics to an OpenTelemetry Collector.
- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/Prometheus%20Sample` — Prometheus exporter reporting metrics to a Prometheus instance.
- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/Simple%20Exporter` — MultiSpanExporter combining Jaeger and Stdout exporters.
- `https://github.com/open-telemetry/opentelemetry-swift/tree/main/Examples/Stable%20Metric%20Sample` — Stable metrics API example using the current metrics spec.

## Core Concepts

- `https://opentelemetry.io/docs/concepts/signals/traces/` — Traces: spans, span kinds (CLIENT, SERVER, PRODUCER, CONSUMER, INTERNAL), parent-child relationships, span lifecycle.
- `https://opentelemetry.io/docs/concepts/signals/baggage/` — Baggage: propagating key-value pairs alongside distributed context.
- `https://opentelemetry.io/docs/concepts/context-propagation/` — Context propagation; how trace context flows across process boundaries.
- `https://opentelemetry.io/docs/concepts/instrumentation/` — Instrumentation concepts; code-based vs zero-code, signals, resources, semantic conventions.

## Specification

- `https://opentelemetry.io/docs/specs/otel/` — Main OTel specification overview; all signal specs, SDK behavior, semantic conventions.
- `https://opentelemetry.io/docs/specs/otel/trace/api/` — Tracing API spec: TracerProvider, Tracer, Span, SpanContext, SpanKind, Links, timestamp handling.
- `https://opentelemetry.io/docs/specs/otel/metrics/api/` — Metrics API spec: MeterProvider, Meter, Counter, Histogram, Gauge, UpDownCounter, async instruments.
- `https://opentelemetry.io/docs/specs/semconv/general/trace/` — Trace semantic conventions; standard attribute names for spans and events.
- `https://opentelemetry.io/docs/specs/otel/versioning-and-stability/` — Stability guarantees; signal lifecycle (Development → Stable → Deprecated → Removed), versioning rules.
