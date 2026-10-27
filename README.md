# Stuff Markdown

Stuff Markdown is the plain-text format [Stuff](https://themitycompany.com/stuff) uses to export, copy, paste, and import Tasks. It's ordinary Markdown with GitHub-style task lists, plus a few details written the same way everywhere:

```markdown
- [ ] Buy milk *Plan: 2026-10-24 09:00* **Deadline: 2026-10-25** #Errands
  > 2% if they have it
```

This repository holds:

- [**SPEC.md**](SPEC.md), the specification
- [**suite/**](suite/README.md), the shared test suite every implementation checks against
- a **Swift package** (`Sources/StuffMarkdown`), the reference implementation
- a **JavaScript/TypeScript package** (`js/`)

## Swift

Add the package with Swift Package Manager:

```swift
.package(url: "https://github.com/2196official/stuff-markdown.git", from: "0.1.0")
```

```swift
import StuffMarkdown

let document = StuffMarkdown.parse(text)
for item in document.items where item.status != nil {
    print(item.name, item.details.plan as Any)
}

let markdown = StuffMarkdown.write(document)
```

Pass `StuffMarkdown.ParseOptions(knownTags:)` to read only the Tags your app has; any other `#Tag` stays in the name. Run the suite with `swift test`.

## JavaScript and TypeScript

```ts
import { parse, write } from "@2196official/stuff-markdown";

const document = parse(text);
const markdown = write(document);
```

The parsed objects are exactly the JSON the test suite uses. In `js/`, run `npm test` (Node 22.18 or later runs the TypeScript directly) and `npm run build` to produce `dist/`.

## Licenses

The specification and test suite are [CC BY 4.0](LICENSE-SPEC). The code is [MIT](LICENSE).
