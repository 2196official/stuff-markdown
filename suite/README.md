# Shared test suite

Every folder in `cases/` checks one rule from [SPEC.md](../SPEC.md). Any Stuff Markdown implementation, in any language, should pass all of them. The Swift package and the JavaScript package in this repository both do.

## A case

| File | What it holds |
| --- | --- |
| `input.md` | The text to parse. Line endings are exact, so `.gitattributes` keeps Git from changing them. |
| `expected.json` | The document `input.md` must parse to. |
| `case.json` | `description`: the rule being checked. `canonical`: when `true`, writing `expected.json` must give back `input.md` exactly, without its final newline. `knownTags`: when present, parse with Tags limited to these. |

## The JSON

A document is `{ "version"?, "title"?, "sections": [...] }`. A section is `{ "header"?, "items": [...] }`, and a section without a header is a group of items set apart by blank lines.

Items and headers share these keys. Absent details are left out rather than written as `null` or `[]`.

| Key | Value |
| --- | --- |
| `status` | Items only: `"available"`, `"complete"`, `"cancelled"`, or `"inProgress"`. Left out for an item without a checkbox. |
| `name` | The name, unescaped. |
| `dependency` | The name it depends on. |
| `plan` | `"someday"`, `"YYYY-MM-DD"`, or `"YYYY-MM-DD HH:MM"`. |
| `deadline` | `"YYYY-MM-DD"`. |
| `tags` | Tags as written, without `#`. |
| `repeat` | The repeat's text without its parentheses, such as `"repeats every week on Saturday"`. |
| `extensions` | The contents of trailing `<!-- … -->` comments, trimmed. |
| `notes` | Note lines joined with `\n`. |

## Adding a case

Add the next numbered folder with all three files, and make sure every implementation passes it before merging. A case that changes what an existing case expects is a breaking change to the spec; see Versions in SPEC.md.
