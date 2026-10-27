# Stuff Markdown

**Version 1** · [Changelog](CHANGELOG.md) · Licensed [CC BY 4.0](LICENSE-SPEC)

Stuff Markdown is the plain-text format [Stuff](https://themitycompany.com/stuff) uses when you export or copy Tasks, and the format it reads back when you paste or drop them in. It's regular Markdown, so an export looks right in Obsidian, GitHub, Bear, or anywhere else Markdown shows up, and it carries a Task's Plan, Deadline, Tags, Notes, and more in a way any app can read.

This is the full specification. The [shared test suite](suite/README.md) turns every rule here into an example with its expected result, so any implementation can check itself against it.

## An example

```markdown
<!-- stuff-markdown: 1 -->
# 🛒 Groceries *Plan: 2026-10-24* **Deadline: 2026-10-31** #Home
> Weekly shop. Costco on Saturdays

- [ ] Buy milk *Plan: 2026-10-24 09:00* **Deadline: 2026-10-25** #Errands #DeepWork
  > 2% if they have it
  > Check the date
- [~] Compare cereal prices *Someday*
- [ ] Water the plants *Plan: 2026-10-25* #Home (repeats every week on Saturday)
- [ ] Renew passport *Plan: 2026-11-12* (repeats on 2026-11-12, 2026-11-19 and 2026-11-26)
- [ ] Pick up the cake (dependent on "Order the cake")
- [x] Order the cake
- [/] Buy flowers

## Party supplies *Plan: 2026-10-30* #Party
> For Saturday's party

- [ ] Balloons **Deadline: 2026-10-31**
- [ ] Candles
```

## The basics

- **Plain Markdown first.** Every Stuff Markdown document is valid [CommonMark](https://commonmark.org) with [GitHub-style task lists](https://github.github.com/gfm/#task-list-items-extension-), so it reads well in apps that know nothing about Stuff.
- **English labels, always.** Labels like `Plan:` and `dependent on` are never translated, whatever language the writing app is in. Names, Notes, and headers stay exactly as written.
- **ISO dates.** Days are always `YYYY-MM-DD` and times are 24-hour `HH:MM`, both local with no time zone, so `2026-03-04` means March 4th everywhere.

## Structure

A document is made of these pieces, in this order:

1. **Version marker** (optional): `<!-- stuff-markdown: 1 -->` on the first line. Markdown apps hide it. Full exports include it; a single copied Task leaves it out.
2. **Title** (optional): `# ` followed by the name of what was exported, such as a List, a Space, or a view like Today. It can carry the same details as an item, with Notes on the lines below it quoted with `> `.
3. **Items**: one line per Task, List, Heading, or Space, in the order the app shows them.
4. **Sections** (optional): `## ` followed by a section's name, such as a Heading, a day, a Tag, or Completed. A section header carries details and Notes just like the title. A section with no items can still appear, the same way an empty Heading does.

Writers put a blank line between the title and the first items, between sections, and after a header's Notes. A blank line between two items starts a new group of items without a header, which is how an app keeps rows apart that it shows apart.

## Item lines

Each item is one line: a marker, the name, then its details in a fixed order.

```text
- [ ] Name (dependent on "Other Task") *Plan: …* **Deadline: …** #Tag (repeats …)
```

Every detail is optional, but writers always put them in this order, each after a single space.

### Markers

| Marker | Status |
| --- | --- |
| `- [ ] ` | Available |
| `- [x] ` | Complete (`- [X] ` is read too) |
| `- [/] ` | Cancelled |
| `- [~] ` | In progress |
| `- ` (no box) | No status, which is how a Space is written |

Lists and Headings use the same checkboxes as Tasks.

### Details

| Detail | Written as | Notes |
| --- | --- | --- |
| Dependency | `(dependent on "Order the cake")` | The name of the item this one waits on. |
| Plan | `*Plan: 2026-10-24*` | Add a time when there's a reminder: `*Plan: 2026-10-24 09:00*`. |
| Someday | `*Someday*` | Written instead of a Plan. |
| Deadline | `**Deadline: 2026-10-31**` | |
| Tags | `#Errands #DeepWork` | One word each. Writers remove spaces, so "Deep Work" becomes `#DeepWork`. |
| Repeats | `(repeats every week on Saturday)` | A readable English description, in one of three shapes: `repeats every …`, `repeats on YYYY-MM-DD…` listing every date, or `repeats N days after each one is completed` (also `a day`, and weeks, months, or years). |
| Extensions | `<!-- id: 7Kc2 -->` | Details added by a later version. See [Extensions](#extensions). |

### Notes

Notes go on the lines right below their item, each line quoted with `>` and indented two spaces so Markdown apps keep them inside that item:

```markdown
- [ ] Buy milk
  > 2% if they have it
  >
  > Check the date
```

A blank line inside Notes is written as `  >` on its own. Under a title or section header, Notes are quoted without the indent.

### Escaping

When a name contains something that would read as a detail, writers put a backslash in front of it so it stays part of the name:

- a `#` that starts a word: `Fix issue \#12`
- any `*`: `5 \* 3`
- a `(` that opens `(dependent on "` or `(repeats `
- a `<` that opens `<!--`
- a `\` that comes right before any of these characters: `Folder \\#Archive`

Markdown apps hide the backslash. Readers remove a backslash before `#`, `*`, `(`, `<`, or `\`, and keep any other backslash.

### Extensions

A trailing HTML comment on an item or header line, such as `<!-- id: 7Kc2 -->`, holds a detail from a later version of Stuff Markdown. Markdown apps hide it. Readers that don't understand an extension keep its contents aside rather than in the name, so a newer export still imports cleanly into an older reader. Version 1 defines no extensions of its own.

## Reading

A reader should accept everything a writer produces, and be forgiving about everything else:

- **Details are read from the end of the line.** Each must follow whitespace, and they can come in any order. Reading stops at the first text that isn't a detail, and everything before it is the name.
- **Only exact matches count.** A detail is read only when it matches this page exactly, and only real dates and times are read: `2026-02-30` or `25:00` stays in the name. A Task like "Call mom (urgent)" keeps its parentheses, and so does "(repeats weekly)".
- **Each detail is read once.** If one appears twice, the one closer to the start stays in the name. Repeated Tags are read once, keeping their first spelling.
- **A line that's only details keeps its text as the name,** so `- [ ] *Someday*` is a Task named "\*Someday\*".
- **Apps can limit Tags to the ones they have.** Matching ignores spaces and capitalization, so `#deepwork` matches "Deep Work". A `#Tag` that matches none stays at the end of the name.
- **Headers:** the first `#` line before any items is the title. Every other header line, at any level from `#` to `######`, opens a section.
- **Notes:** under any item or header, a line starting with `>` is a note. Under an item, an indented line is also a note, and so is unindented text that isn't Markdown structure (a header, bullet, quote, comment, or numbered item), which is how hard-wrapped Markdown continues an item. A blank line or other structure ends the Notes, and blank quoted lines at the end are dropped.
- **Nested items:** an indented checkbox line is an item too. An indented plain bullet under an item is one of its Notes.
- **Lost line breaks:** when a checkbox line holds another ` - [ ] ` marker partway through, each marker starts another item.
- **Everything else is skipped:** paragraphs outside an item, numbered lists, `*` and `+` bullets, and quotes that don't belong to an item or header.
- **Line endings:** `\r\n` and `\r` read the same as `\n`.
- **Older Stuff exports** wrote Notes as `   >  Note`; readers remove both spaces after the `>` there.

## Versions

The version marker names the version a document was written in. A new version number is used only when a change would make existing readers misread documents. New details that older readers can safely ignore arrive as [extensions](#extensions) within the same version.

| Version | Released | Changes |
| --- | --- | --- |
| 1 | Coming with Stuff 2.4.6 | The first version: English labels, ISO dates, repeats, quoted Notes, extensions, and the version marker. |
