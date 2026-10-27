// Stuff Markdown for JavaScript and TypeScript.
//
// A port of the Swift reference implementation. Both check against the shared suite in suite/cases,
// so they read and write every document the same way. The objects here are exactly the JSON the
// suite's expected.json files use.

/** The version of Stuff Markdown this package reads and writes. */
export const VERSION = 1;

/** An item's checkbox. */
export type Status = "available" | "complete" | "cancelled" | "inProgress";

/** The details written after an item's or header's name. Absent details are left out. */
export interface Details {
  /** The name of the item this one depends on, from `(dependent on "Name")`. */
  dependency?: string;
  /** `"someday"`, `"YYYY-MM-DD"`, or `"YYYY-MM-DD HH:MM"`. */
  plan?: string;
  /** `"YYYY-MM-DD"`. */
  deadline?: string;
  /** Tags as written, without their `#`. */
  tags?: string[];
  /** The repeat's description without its parentheses, such as "repeats every week on Saturday". */
  repeat?: string;
  /** The contents of trailing `<!-- … -->` comments, which hold details a later version adds. */
  extensions?: string[];
}

/** One item line: a Task, List, Heading, or Space. */
export interface Item extends Details {
  /** The checkbox, or absent for a line without one, which is how a Space is written. */
  status?: Status;
  name: string;
  notes?: string;
}

/** A `#` title or `##` section header. */
export interface Header extends Details {
  name: string;
  notes?: string;
}

/** A run of items, under a header or set apart by a blank line. */
export interface Section {
  header?: Header;
  items: Item[];
}

/** A parsed Stuff Markdown document. */
export interface Document {
  /** The version named by the marker on the first line. */
  version?: number;
  title?: Header;
  sections: Section[];
}

/** Choices an app makes about what it can import while parsing. */
export interface ParseOptions {
  /** The Tags the app has. When set, a `#Tag` matching none of them (by `tagKey`) stays in the name. */
  knownTags?: string[];
  /** Reads a date in a format from before Stuff Markdown, returning `"YYYY-MM-DD"` or undefined. */
  readsLegacyDay?: (text: string) => string | undefined;
}

// MARK: - Helpers

const HORIZONTAL_WHITESPACE = /^[\t \p{Zs}]+|[\t \p{Zs}]+$/gu;
const LINE_BREAK = /\r\n|[\n\r\v\f\u0085\u2028\u2029]/;

function trimSpaces(text: string): string {
  return text.replace(HORIZONTAL_WHITESPACE, "");
}

function isWhitespace(character: string | undefined): boolean {
  return character !== undefined && /\s/u.test(character);
}

/** The comment that opens a full document, naming its version. */
export function versionMarker(version: number = VERSION): string {
  return `<!-- stuff-markdown: ${version} -->`;
}

/** A Tag name the way `#Tag` details are matched: without spaces and ignoring capitalization. */
export function tagKey(name: string): string {
  return name.replaceAll(" ", "").toLowerCase();
}

/** Whether a `YYYY-MM-DD` string names a real day on the Gregorian calendar. */
export function isDay(text: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (!match) return false;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (year < 1 || month < 1 || month > 12 || day < 1) return false;
  const isLeapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const length = month === 2 ? (isLeapYear ? 29 : 28) : [4, 6, 9, 11].includes(month) ? 30 : 31;
  return day <= length;
}

/** Whether an `HH:MM` string names a real 24-hour time. */
export function isTime(text: string): boolean {
  const match = /^(\d{2}):(\d{2})$/.exec(text);
  return match !== null && Number(match[1]) < 24 && Number(match[2]) < 60;
}

// MARK: - Details

/** Anchors a detail pattern to the end of the text, after whitespace, so an escaped character never matches. */
function trailing(pattern: string): RegExp {
  return new RegExp(`(?<=\\s)${pattern}\\s*$`, "u");
}

const REPEAT = trailing(String.raw`\((repeats (?:every .+|on \d{4}-\d{2}-\d{2}.*|(?:a|\d+) (?:day|week|month|year)s? after each one is completed))\)`);
const DEPENDENCY = trailing(String.raw`\(dependent on "(.+)"\)`);
const DEADLINE = trailing(String.raw`\*\*Deadline: ([^*]+)\*\*`);
const PLAN = trailing(String.raw`\*Plan: ([^*]+)\*`);
const SOMEDAY = trailing(String.raw`\*Someday\*`);
const TAG = trailing(String.raw`#(\S+)`);
const EXTENSION = trailing(String.raw`<!--((?:(?!-->).)*)-->`);

/** Reads details off the end of one line, leaving the name behind. */
class DetailReader {
  name: string;
  details: Details = {};
  private tagsBackward: string[] = [];
  private keptBackward: string[] = [];
  private knownTagKeys: Set<string> | undefined;
  private readsLegacyDay: ParseOptions["readsLegacyDay"];

  constructor(text: string, knownTagKeys: Set<string> | undefined, readsLegacyDay: ParseOptions["readsLegacyDay"]) {
    this.name = trimSpaces(text);
    this.knownTagKeys = knownTagKeys;
    this.readsLegacyDay = readsLegacyDay;
  }

  read(): void {
    while (this.name.length > 0) {
      const last = this.name[this.name.length - 1];
      let didRead: boolean;
      if (last === ")") didRead = this.readRepeat() || this.readDependency() || this.readTag();
      else if (last === "*") didRead = this.readDeadline() || this.readPlan() || this.readSomeday() || this.readTag();
      else if (last === ">") didRead = this.readExtension() || this.readTag();
      else didRead = this.readTag();
      if (!didRead) break;
    }

    const seen = new Set<string>();
    const tags = this.tagsBackward.reverse().filter((tag) => {
      const key = tagKey(tag);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
    if (tags.length > 0) this.details.tags = tags;

    if (this.keptBackward.length > 0) {
      this.name = [this.name, ...this.keptBackward.reverse()].join(" ");
    }
  }

  private match(regex: RegExp): RegExpExecArray | null {
    return regex.exec(this.name);
  }

  private consume(match: RegExpExecArray): void {
    this.name = trimSpaces(this.name.slice(0, match.index));
  }

  private day(text: string): string | undefined {
    if (isDay(text)) return text;
    const legacy = this.readsLegacyDay?.(text);
    return legacy !== undefined && isDay(legacy) ? legacy : undefined;
  }

  private readRepeat(): boolean {
    if (this.details.repeat !== undefined) return false;
    const match = this.match(REPEAT);
    if (!match) return false;
    this.consume(match);
    this.details.repeat = match[1];
    return true;
  }

  private readDependency(): boolean {
    if (this.details.dependency !== undefined) return false;
    const match = this.match(DEPENDENCY);
    if (!match) return false;
    this.consume(match);
    this.details.dependency = match[1];
    return true;
  }

  private readDeadline(): boolean {
    if (this.details.deadline !== undefined) return false;
    const match = this.match(DEADLINE);
    const day = match ? this.day(match[1]) : undefined;
    if (!match || day === undefined) return false;
    this.consume(match);
    this.details.deadline = day;
    return true;
  }

  private readPlan(): boolean {
    if (this.details.plan !== undefined) return false;
    const match = this.match(PLAN);
    if (!match) return false;
    const parts = match[1].split(" ");
    if (parts.length < 1 || parts.length > 2) return false;
    const day = this.day(parts[0]);
    if (day === undefined) return false;
    if (parts.length === 2 && !isTime(parts[1])) return false;
    this.consume(match);
    this.details.plan = parts.length === 2 ? `${day} ${parts[1]}` : day;
    return true;
  }

  private readSomeday(): boolean {
    if (this.details.plan !== undefined) return false;
    const match = this.match(SOMEDAY);
    if (!match) return false;
    this.consume(match);
    this.details.plan = "someday";
    return true;
  }

  private readTag(): boolean {
    const lastSpace = Math.max(...[...this.name].map((character, index) => (isWhitespace(character) ? index : -1)));
    if (lastSpace < 0 || [...this.name][lastSpace + 1] !== "#") return false;
    const match = this.match(TAG);
    if (!match) return false;
    this.consume(match);
    const word = match[1];
    if (this.knownTagKeys && !this.knownTagKeys.has(tagKey(word))) {
      this.keptBackward.push(`#${word}`);
    } else {
      this.tagsBackward.push(word);
    }
    return true;
  }

  private readExtension(): boolean {
    const match = this.match(EXTENSION);
    if (!match) return false;
    this.consume(match);
    this.details.extensions = [trimSpaces(match[1]), ...(this.details.extensions ?? [])];
    return true;
  }
}

// MARK: - Parsing

const CHECKBOX_LINE = /^[ \t]*- \[([ xX/~])\] (.*)$/u;
const CHECKBOX_LINE_ANYWHERE = /^[ \t]*- \[[ xX/~]\] /mu;
const INLINE_CHECKBOX = / - \[([ xX/~])\] /gu;
const PLAIN_ITEM_LINE = /^- (.*)$/u;
const HEADER_LINE = /^(#{1,6})[ \t]+(.*)$/u;
const VERSION_MARKER = /^<!--[ \t]*stuff-markdown:[ \t]*(\d+)[ \t]*-->$/u;
const STRUCTURE_LINE = /^(?:#|[-*+] |>|<!--|\d+[.)] )/u;

const STATUS_BY_CHARACTER: Record<string, Status> = {
  " ": "available",
  x: "complete",
  X: "complete",
  "/": "cancelled",
  "~": "inProgress",
};

/** Whether the text contains at least one item line with a checkbox. */
export function containsCheckboxItems(text: string): boolean {
  return CHECKBOX_LINE_ANYWHERE.test(text);
}

/** Whether the text opens with a version marker, whatever its version. */
export function startsWithVersionMarker(text: string): boolean {
  const firstLine = text.split(LINE_BREAK).find((line) => trimSpaces(line) !== "");
  return firstLine !== undefined && VERSION_MARKER.test(trimSpaces(firstLine));
}

/** Parses any text as Stuff Markdown. Lines that aren't part of it are skipped. */
export function parse(text: string, options: ParseOptions = {}): Document {
  const knownTagKeys = options.knownTags ? new Set(options.knownTags.map(tagKey)) : undefined;
  const document: Document = { sections: [] };
  let openSection: Section | undefined;
  let owner: { kind: "title" } | { kind: "header" } | { kind: "item"; item: Item } | undefined;
  let noteLines: string[] = [];
  let hasBlankLineSinceItem = false;
  let hasReadContent = false;

  const nameAndDetails = (lineText: string): { name: string; details: Details } => {
    const reader = new DetailReader(lineText, knownTagKeys, options.readsLegacyDay);
    reader.read();
    const name = unescapedName(reader.name);
    return name === "" ? { name: unescapedName(lineText), details: {} } : { name, details: reader.details };
  };

  const closeSection = (): void => {
    if (openSection && (openSection.header !== undefined || openSection.items.length > 0)) {
      document.sections.push(openSection);
    }
    openSection = undefined;
  };

  const finishNotes = (): void => {
    if (owner) {
      while (noteLines.length > 0 && trimSpaces(noteLines[noteLines.length - 1]) === "") noteLines.pop();
      const notes = noteLines.length > 0 ? noteLines.join("\n") : undefined;
      const withNotes = <T extends { notes?: string }>(value: T): T => {
        if (notes === undefined) delete value.notes;
        else value.notes = notes;
        return value;
      };
      if (owner.kind === "title" && document.title) withNotes(document.title);
      if (owner.kind === "header" && openSection?.header) withNotes(openSection.header);
      if (owner.kind === "item") {
        openSection ??= { items: [] };
        openSection.items.push(withNotes(owner.item));
      }
    }
    owner = undefined;
    noteLines = [];
  };

  const startItem = (status: Status | undefined, lineText: string): void => {
    finishNotes();
    const { name, details } = nameAndDetails(lineText);
    if (name === "") return;
    if (hasBlankLineSinceItem && openSection && openSection.items.length > 0) closeSection();
    hasBlankLineSinceItem = false;
    const item: Item = status === undefined ? { name, ...details } : { status, name, ...details };
    owner = { kind: "item", item };
  };

  const readHeader = (level: number, lineText: string): void => {
    hasBlankLineSinceItem = false;
    const { name, details } = nameAndDetails(lineText);
    const header: Header = { name, ...details };
    if (level === 1 && document.title === undefined && document.sections.length === 0 && openSection === undefined) {
      document.title = header;
      owner = { kind: "title" };
      return;
    }
    closeSection();
    openSection = { header, items: [] };
    owner = { kind: "header" };
  };

  const readNoteLine = (line: string, trimmedLine: string): boolean => {
    if (!owner) return false;
    if (trimmedLine.startsWith(">")) {
      let noteText = trimmedLine.slice(1);
      const spacesToRemove = line.startsWith("   >  ") ? 2 : 1;
      for (let index = 0; index < spacesToRemove && noteText.startsWith(" "); index++) noteText = noteText.slice(1);
      noteLines.push(noteText);
      return true;
    }
    if (owner.kind !== "item") return false;
    if (isWhitespace(line[0]) || !STRUCTURE_LINE.test(line)) {
      noteLines.push(trimmedLine);
      return true;
    }
    return false;
  };

  for (const line of text.split(LINE_BREAK)) {
    const trimmedLine = trimSpaces(line);
    if (trimmedLine === "") {
      finishNotes();
      hasBlankLineSinceItem = true;
      continue;
    }
    const isFirstContent = !hasReadContent;
    hasReadContent = true;

    const marker = isFirstContent ? VERSION_MARKER.exec(trimmedLine) : null;
    if (marker) {
      document.version = Number(marker[1]);
      continue;
    }

    const checkbox = CHECKBOX_LINE.exec(line);
    if (checkbox) {
      const lineText = checkbox[2];
      let character = checkbox[1];
      let start = 0;
      for (const inline of lineText.matchAll(INLINE_CHECKBOX)) {
        startItem(STATUS_BY_CHARACTER[character], lineText.slice(start, inline.index));
        character = inline[1];
        start = inline.index + inline[0].length;
      }
      startItem(STATUS_BY_CHARACTER[character], lineText.slice(start));
      continue;
    }

    if (readNoteLine(line, trimmedLine)) continue;
    finishNotes();

    const header = HEADER_LINE.exec(line);
    if (header) {
      readHeader(header[1].length, header[2]);
      continue;
    }
    const plainItem = PLAIN_ITEM_LINE.exec(line);
    if (plainItem) startItem(undefined, plainItem[1]);
  }

  finishNotes();
  closeSection();
  return orderedDocument(document);
}

/** Puts keys in the suite's order so `JSON.stringify` matches expected.json. */
function orderedDocument(document: Document): Document {
  const details = (value: Details): Details => {
    const ordered: Details = {};
    if (value.dependency !== undefined) ordered.dependency = value.dependency;
    if (value.plan !== undefined) ordered.plan = value.plan;
    if (value.deadline !== undefined) ordered.deadline = value.deadline;
    if (value.tags !== undefined) ordered.tags = value.tags;
    if (value.repeat !== undefined) ordered.repeat = value.repeat;
    if (value.extensions !== undefined) ordered.extensions = value.extensions;
    return ordered;
  };
  const header = (value: Header): Header => ({
    name: value.name,
    ...details(value),
    ...(value.notes !== undefined ? { notes: value.notes } : {}),
  });
  const item = (value: Item): Item => ({
    ...(value.status !== undefined ? { status: value.status } : {}),
    name: value.name,
    ...details(value),
    ...(value.notes !== undefined ? { notes: value.notes } : {}),
  });
  return {
    ...(document.version !== undefined ? { version: document.version } : {}),
    ...(document.title !== undefined ? { title: header(document.title) } : {}),
    sections: document.sections.map((section) => ({
      ...(section.header !== undefined ? { header: header(section.header) } : {}),
      items: section.items.map(item),
    })),
  };
}

// MARK: - Writing

const CHECKBOX_BY_STATUS: Record<Status, string> = {
  available: " ",
  complete: "x",
  cancelled: "/",
  inProgress: "~",
};

/** Writes details and notes as they follow a name. */
function detailText(details: Details, notes: string | undefined, quote: string): string {
  let text = "";
  if (details.dependency !== undefined) text += ` (dependent on "${details.dependency}")`;
  if (details.plan !== undefined) text += details.plan === "someday" ? " *Someday*" : ` *Plan: ${details.plan}*`;
  if (details.deadline !== undefined) text += ` **Deadline: ${details.deadline}**`;
  for (const tag of details.tags ?? []) text += ` #${tag.replaceAll(" ", "")}`;
  if (details.repeat !== undefined) text += ` (${details.repeat})`;
  for (const contents of details.extensions ?? []) text += ` <!-- ${contents} -->`;
  if (notes) {
    for (const line of notes.split("\n")) text += line === "" ? `\n${quote}` : `\n${quote} ${line}`;
  }
  return text;
}

/** Writes one item with its notes. */
export function writeItem(item: Item): string {
  const marker = item.status === undefined ? "- " : `- [${CHECKBOX_BY_STATUS[item.status]}] `;
  return marker + escapedName(item.name) + detailText(item, item.notes, "  >");
}

/** Writes a header at the given level with its notes. */
export function writeHeader(header: Header, level: number): string {
  return "#".repeat(Math.max(1, level)) + " " + escapedName(header.name) + detailText(header, header.notes, ">");
}

/** Writes a document as Stuff Markdown. */
export function write(document: Document): string {
  const opening: string[] = [];
  if (document.version !== undefined) opening.push(versionMarker(document.version));
  if (document.title !== undefined) opening.push(writeHeader(document.title, 1));

  const blocks: string[] = [];
  for (const section of document.sections) {
    const lines = section.items.map(writeItem);
    if (section.header !== undefined) {
      if (section.header.notes && lines.length > 0) lines.unshift("");
      lines.unshift(writeHeader(section.header, 2));
    }
    if (lines.length > 0) blocks.push(lines.join("\n"));
  }

  return [...(opening.length > 0 ? [opening.join("\n")] : []), ...blocks].join("\n\n");
}

// MARK: - Escaping

const ESCAPABLE = new Set(["#", "*", "(", "<", "\\"]);

/** Adds a backslash before anything in a name that would otherwise read as a detail. */
export function escapedName(name: string): string {
  const characters = [...name];
  let escaped = "";
  characters.forEach((character, index) => {
    const previous = characters[index - 1];
    const next = characters[index + 1];
    const rest = characters.slice(index).join("");
    if (character === "\\" && next !== undefined && ESCAPABLE.has(next)) escaped += "\\\\";
    else if (character === "#" && (previous === undefined || isWhitespace(previous))) escaped += "\\#";
    else if (character === "*") escaped += "\\*";
    else if (character === "(" && (rest.startsWith('(dependent on "') || rest.startsWith("(repeats "))) escaped += "\\(";
    else if (character === "<" && rest.startsWith("<!--")) escaped += "\\<";
    else escaped += character;
  });
  return escaped;
}

/** Removes the backslash before a `#`, `*`, `(`, `<`, or `\` in a name, and the whitespace around it. */
export function unescapedName(name: string): string {
  let unescaped = "";
  let isEscaping = false;
  for (const character of name) {
    if (isEscaping) {
      if (!ESCAPABLE.has(character)) unescaped += "\\";
      unescaped += character;
      isEscaping = false;
    } else if (character === "\\") {
      isEscaping = true;
    } else {
      unescaped += character;
    }
  }
  if (isEscaping) unescaped += "\\";
  return trimSpaces(unescaped);
}
