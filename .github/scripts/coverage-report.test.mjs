import assert from "node:assert/strict";
import test from "node:test";

import { filterReport, validateReport } from "./coverage-report.mjs";

const root = "/workspace/project";
const covered = (file) => `TN:\nSF:${root}/${file}\nFN:1,run\nFNDA:1,run\nFNF:1\nFNH:1\nDA:1,1\nLF:1\nLH:1\nend_of_record\n`;

test("validates covered output", () => {
  assert.equal(validateReport(covered("Sources/AgentSessionManager/App.swift"), root), 1);
});

test("validates multiple files in both repository source roots", () => {
  const report = covered("Sources/AgentSessionManager/App.swift") + covered("Sources/AgentSessionManagerMCPBridgeCore/Bridge.swift");
  assert.equal(validateReport(report, root), 2);
});

test("filters dependency and build paths", () => {
  const report = covered(".build/checkouts/Dependency/Sources/Thing.swift") + covered("Sources/AgentSessionManager/App.swift");
  const filtered = filterReport(report, root);
  assert.equal(validateReport(filtered, root), 1);
  assert.match(filtered, /Sources\/AgentSessionManager\/App.swift/);
  assert.doesNotMatch(filtered, /.build\/checkouts/);
});

test("rejects disallowed paths in a validated report", () => {
  assert.throws(() => validateReport(covered(".build/debug/Agent.swift"), root), /outside repository sources/);
});

test("rejects malformed and empty reports", () => {
  for (const report of ["", "TN:\n", "TN:\nSF:Sources/AgentSessionManager/App.swift\nend_of_record\n"]) {
    assert.throws(() => validateReport(report, root), /malformed|empty/);
  }
});

test("rejects reports without repository sources", () => {
  assert.throws(() => filterReport(covered("vendor/Thing.swift"), root), /no repository source files/);
});
