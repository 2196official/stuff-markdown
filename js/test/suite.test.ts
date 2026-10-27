// Runs every case in the shared suite (suite/cases) against the TypeScript implementation.

import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { parse, write, type Document } from "../src/index.ts";

const casesFolder = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "suite", "cases");
const cases = readdirSync(casesFolder)
  .filter((name) => statSync(join(casesFolder, name)).isDirectory())
  .sort();

test("the suite is present", () => {
  assert.ok(cases.length > 30);
});

for (const name of cases) {
  const folder = join(casesFolder, name);
  const input = readFileSync(join(folder, "input.md"), "utf8");
  const settings = JSON.parse(readFileSync(join(folder, "case.json"), "utf8"));
  const expected: Document = JSON.parse(readFileSync(join(folder, "expected.json"), "utf8"));

  test(`${name}: parses to the expected document`, () => {
    const document = parse(input, { knownTags: settings.knownTags });
    assert.deepEqual(document, expected, settings.description);
    assert.equal(JSON.stringify(document), JSON.stringify(expected), "keys are in the suite's order");
  });

  if (settings.canonical) {
    test(`${name}: writes the input back`, () => {
      assert.equal(write(expected) + "\n", input, settings.description);
    });
  }
}
