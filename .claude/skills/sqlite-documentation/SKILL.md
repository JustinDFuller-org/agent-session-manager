---
name: sqlite-documentation
description: SQLite official doc index — load when working with SQLite, the C/C++ API, import SQLite3, prepared statements, binding, query execution, result codes, or any SQLite-specific behavior. Any project that uses or interacts with SQLite should load this skill.
user-invocable: false
allowed-tools:
  - WebFetch(domain:www.sqlite.org)
---

# SQLite Documentation Index

Fetch from this index before implementing any SQLite feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://www.sqlite.org/docs.html` — Main documentation index; all docs organized by category (overview, C API, SQL language, extensions, features, tools, technical design).

## Getting Started

- `https://www.sqlite.org/quickstart.html` — SQLite In 5 Minutes Or Less; minimal C program example using `sqlite3_open`, `sqlite3_exec`, `sqlite3_close`.
- `https://www.sqlite.org/cintro.html` — Introduction To The SQLite C/C++ Interface; the two core objects (`sqlite3`, `sqlite3_stmt`) and eight core methods explained.

## Core API — Database Connection

- `https://www.sqlite.org/c3ref/open.html` — `sqlite3_open` / `sqlite3_open_v2` / `sqlite3_open16`: opening/creating database files; all `SQLITE_OPEN_*` flags; URI filenames; `:memory:` special name.
- `https://www.sqlite.org/c3ref/close.html` — `sqlite3_close` / `sqlite3_close_v2`: closing database connections; unfinalized statement handling; transaction rollback on close.

## Core API — Prepared Statement Lifecycle

- `https://www.sqlite.org/c3ref/prepare.html` — `sqlite3_prepare_v2` / `sqlite3_prepare_v3`: compiling SQL text into byte-code; UTF-8 vs UTF-16; `nByte` semantics; automatic re-prepare on schema change in v2.
- `https://www.sqlite.org/c3ref/step.html` — `sqlite3_step`: evaluating a prepared statement; return values (`SQLITE_ROW`, `SQLITE_DONE`, `SQLITE_BUSY`); v2 vs legacy error reporting.
- `https://www.sqlite.org/c3ref/finalize.html` — `sqlite3_finalize`: destroying prepared statements; must finalize every statement to avoid memory leaks; null pointer is a no-op.
- `https://www.sqlite.org/c3ref/reset.html` — `sqlite3_reset`: resetting a prepared statement for reuse; bindings are not cleared by reset.

## Core API — Binding Parameters

- `https://www.sqlite.org/c3ref/bind_blob.html` — All `sqlite3_bind_*` routines: `bind_text`, `bind_int`, `bind_int64`, `bind_double`, `bind_blob`, `bind_null`, `bind_zeroblob`; `SQLITE_STATIC` vs `SQLITE_TRANSIENT` vs destructor; parameter forms (`?`, `?NNN`, `:AAA`, `$AAA`, `@AAA`); `SQLITE_LIMIT_VARIABLE_NUMBER`.

## Core API — Result Columns

- `https://www.sqlite.org/c3ref/column_blob.html` — All `sqlite3_column_*` routines: `column_text`, `column_int`, `column_int64`, `column_double`, `column_blob`, `column_bytes`, `column_type`; zero-indexed columns; automatic type conversion rules; pointer lifetime.

## Core API — One-Step Execution

- `https://www.sqlite.org/c3ref/exec.html` — `sqlite3_exec`: convenience wrapper around prepare/step/finalize; callback per result row; error message via `sqlite3_free`.

## Error Handling

- `https://www.sqlite.org/rescode.html` — Full result & error code reference: all 105 result codes with meanings; primary vs extended codes; `sqlite3_extended_result_codes`; error code ranges.
- `https://www.sqlite.org/c3ref/errcode.html` — `sqlite3_errcode` / `sqlite3_extended_errcode` / `sqlite3_errmsg` / `sqlite3_errstr`: retrieving error information from the most recent API call.

## Constants & Flags

- `https://www.sqlite.org/c3ref/c_open.html` — `SQLITE_OPEN_*` flags: `READONLY`, `READWRITE`, `CREATE`, `NOMUTEX`, `FULLMUTEX`, `SHAREDCACHE`, `PRIVATECACHE`, `URI`, `MEMORY`, `NOFOLLOW`, `EXRESCODE`.
- `https://www.sqlite.org/c3ref/c_any.html` — All compile-time and runtime constants defined in `sqlite3.h`.

## Compilation & Linking

- `https://www.sqlite.org/howtocompile.html` — How To Compile SQLite; compiling C programs that use SQLite; linking with `-lsqlite3`; Swift `Package.swift` linker settings.
- `https://www.sqlite.org/compile.html` — Compilation options: `SQLITE_THREADSAFE`, `SQLITE_MAX_LENGTH`, `SQLITE_MAX_COLUMN`, `SQLITE_MAX_SQL_LENGTH`, `SQLITE_MAX_VARIABLE_NUMBER`, `SQLITE_OMIT_*` flags.

## Multi-threading

- `https://www.sqlite.org/threadsafe.html` — Multi-thread support: `SQLITE_THREADSAFE` compile/start/run-time modes; single-thread vs multi-thread vs serialized; `SQLITE_OPEN_NOMUTEX` / `SQLITE_OPEN_FULLMUTEX`; Swift concurrency implications.

## Limits & Configuration

- `https://www.sqlite.org/limits.html` — Implementation limits: max string/BLOB length, max columns, max SQL statement length, max variable number, max attached databases, max expression depth, max database size.
- `https://www.sqlite.org/c3ref/limit.html` — `sqlite3_limit`: setting per-connection runtime limits (`SQLITE_LIMIT_LENGTH`, `SQLITE_LIMIT_COLUMN`, `SQLITE_LIMIT_SQL_LENGTH`, `SQLITE_LIMIT_VARIABLE_NUMBER`).
- `https://www.sqlite.org/c3ref/config.html` — `sqlite3_config` / `sqlite3_db_config`: global and per-connection configuration (memory allocator, mutex, page cache, error log).

## URI Filenames

- `https://www.sqlite.org/uri.html` — URI filename support: `file:` scheme; query parameters (`mode=ro`, `mode=rw`, `mode=rwc`, `mode=memory`, `cache=shared`, `immutable=1`); hex escaping.

## In-Memory & Temp Databases

- `https://www.sqlite.org/inmemorydb.html` — In-memory databases: `:memory:`; temp databases from empty filename; shared vs private in-memory caches; `SQLITE_OPEN_MEMORY`.

## Data Types

- `https://www.sqlite.org/datatype3.html` — Datatypes and type affinity: storage classes (NULL, INTEGER, REAL, TEXT, BLOB); type affinity rules; `STRICT` tables; comparison and sorting; `CAST` expressions.

## Key Data Structures

- `https://www.sqlite.org/c3ref/sqlite3.html` — `sqlite3` database connection object: the central handle for all operations.
- `https://www.sqlite.org/c3ref/stmt.html` — `sqlite3_stmt` prepared statement object: compiled SQL byte-code program.

## API Reference Index

- `https://www.sqlite.org/c3ref/intro.html` — Full C/C++ API reference: complete index of all objects, constants, and functions; organized into three lists.
