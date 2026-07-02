# Contributor & Maintenance Guide

**Java Backend Interview Handbook — v1.0**
*Read this before making any changes to the handbook.*

---

## Project Overview

This is a Java backend interview preparation handbook built as an **mdBook** — a collection of Markdown files compiled into a searchable HTML book with PDF export support.

| Property | Value |
|---|---|
| Total chapters | 27 across 6 volumes |
| Navigation files | README.md, INDEX.md, STUDY_GUIDE.md, COMPANY_GUIDE.md |
| Appendices | APPENDIX_Architecture_Diagrams.md, APPENDIX_Tables.md, APPENDIX_CodeSnippets.md |
| Book config | book.toml |
| Styling | custom.css, theme/head.hbs |
| Tech stack | Java 17, Spring Boot 3.x, Kafka, Redis, PostgreSQL |

---

## Directory Structure

```
Backend Interview Handbook/
├── book.toml                         # mdBook configuration
├── SUMMARY.md                        # Table of contents (drives sidebar)
├── cover.md                          # Book cover page
├── README.md                         # Auto-used by mdBook as intro/index
├── INDEX.md                          # Master A-Z topic index
├── STUDY_GUIDE.md                    # 4-week / 2-week / 1-week study plans
├── COMPANY_GUIDE.md                  # Company-specific prep (8 companies)
│
├── custom.css                        # All visual styling
├── theme/
│   └── head.hbs                      # Injected into <head> — callout box JS
│
├── Volume1_CoreJava/
│   ├── Chapter1_OOP.md
│   ├── Chapter2_Strings_Wrappers_Exceptions.md
│   ├── Chapter3_Collections.md
│   ├── Chapter4_Java8Plus.md
│   ├── Chapter5_JVM_Internals.md
│   └── Chapter6_Multithreading_Concurrency.md
│
├── Volume2_Spring/
│   ├── Chapter7_Spring_Core_Boot.md
│   └── Chapter8_JPA_Hibernate.md
│
├── Volume3_BackendSystems/
│   ├── Chapter9_REST_APIs.md
│   ├── Chapter10_Microservices.md
│   ├── Chapter11_Kafka.md
│   ├── Chapter12_Redis_Caching.md
│   └── Chapter13_Security.md
│
├── Volume4_Databases/
│   ├── Chapter14_SQL.md
│   ├── Chapter15_Indexing.md
│   ├── Chapter16_ACID_Transactions.md
│   ├── Chapter17_Distributed_DBs.md
│   └── Chapter18_Advanced_DB.md
│
├── Volume5_SystemDesign_LLD/
│   ├── Chapter19_Design_Patterns.md
│   ├── Chapter20_SOLID_CleanArch.md
│   ├── Chapter21_LLD_Case_Studies.md
│   └── Chapter22_System_Design_HLD.md
│
├── Volume6_Revision_Pack/
│   ├── Chapter23_CoreJava_Revision.md
│   ├── Chapter24_Spring_JPA_Revision.md
│   ├── Chapter25_BackendSystems_Revision.md
│   ├── Chapter26_Databases_Revision.md
│   └── Chapter27_SystemDesign_LLD_Revision.md
│
├── APPENDIX_Architecture_Diagrams.md # 12 ASCII architecture diagrams
├── APPENDIX_Tables.md                # 30 consolidated reference tables
├── APPENDIX_CodeSnippets.md          # 38 must-know code patterns
│
└── images/                           # Local images (partial — see Images section)
```

---

## Building & Serving

**Prerequisites:** mdBook installed and on PATH.
Install: `winget install rust-lang.mdbook`

```powershell
# Serve locally with live reload (development)
cd "C:\Users\PrinceSingh\Sciforma\Backend Interview Handbook"
mdbook serve --port 3000
# Open: http://localhost:3000

# Build static output (for PDF export or deployment)
mdbook build
# Output: book_output/
```

**Export to PDF:**
1. Run `mdbook build`
2. Open `book_output/print.html` in Chrome
3. `Ctrl+P` → Save as PDF → enable Background graphics → A4 paper

---

## Question Format (10-item structure)

Every topic in every chapter follows this exact format. **Do not deviate** — the callout box JavaScript in `theme/head.hbs` relies on these exact label names to apply colored styling.

```markdown
### Topic N: Topic Name

**Difficulty:** Easy/Medium/Hard | **Frequency:** Low/Medium/High/Very High | **Companies:** ...

**Q: Question text**

**Short Answer (30-60 seconds):**
One or two sentence answer.

**Deep Explanation:**
Full technical breakdown...

**Real-World Example:**
How this applies in production...

**Code Example:**
```java
// code here
```

**Follow-up Questions:**
1. ...
2. ...

**Common Mistakes:**
- ...

**Interview Traps:**
- ...

**Quick Revision (1-liner):**
One sentence summary.
```

### Callout Box Labels (must be exact)

The JS in `theme/head.hbs` matches these labels and applies colored left-border styling:

| Label | Color | Use for |
|---|---|---|
| `**Interview Traps:**` | Red | Gotchas and edge cases |
| `**Common Mistakes:**` | Orange | Typical candidate errors |
| `**Follow-up Questions:**` | Green | What interviewers ask next |
| `**Quick Revision**` | Grey | One-liner summaries |
| `**Real-World Example:**` | Blue | Production context |

---

## Adding a New Chapter

1. **Create the file** in the correct Volume folder:
   ```
   Volume2_Spring/Chapter28_NewTopic.md
   ```

2. **Add to SUMMARY.md** under the correct volume section:
   ```markdown
   - [Chapter 28 — New Topic](Volume2_Spring/Chapter28_NewTopic.md)
   ```

3. **Follow the 10-item question format** for every topic (see above).

4. **Update INDEX.md** — add new topics to the A-Z index and the Chapter-by-Chapter breakdown section.

5. **Update README.md stats** — update chapter count, line count, question count.

6. **Update STUDY_GUIDE.md** if the chapter affects study plans.

7. **Run `mdbook build`** to verify no broken links.

---

## Adding a New Volume

1. Create a new folder: `Volume7_NewVolume/`
2. Add chapters inside it following the naming pattern: `Chapter28_Topic.md`
3. Add a new `# Volume 7: Name` section in `SUMMARY.md`
4. Update `README.md`, `INDEX.md`, `STUDY_GUIDE.md`

---

## Updating Existing Content

- **Edit the `.md` file directly** — mdBook auto-reloads during `mdbook serve`
- **Encoding:** Always save files as **UTF-8** (not UTF-16 or Windows-1252)
- **Encoding fix** (if you see `â€"` artifacts after editing on Windows):
  ```powershell
  $base = "C:\Users\PrinceSingh\Sciforma\Backend Interview Handbook"
  Get-ChildItem $base -Filter "*.md" -Recurse | ForEach-Object {
      $c = Get-Content $_.FullName -Raw -Encoding utf8
      $c = $c -replace 'â€"', '--' -replace 'â€™', "'" -replace 'â€œ', '"' -replace 'â€', '"'
      Set-Content $_.FullName -Value $c -Encoding utf8
  }
  ```

---

## Styling & Theme

All visual styling lives in **`custom.css`**. Key sections:

| Section | What it controls |
|---|---|
| `@import` | Google Fonts (Source Serif 4, Source Sans 3, Source Code Pro) |
| `body` | Base font, line-height |
| `h1/h2/h3/h4` | Heading hierarchy, colors, borders |
| `pre, code` | Code block styling (Source Code Pro) |
| `table` | Blue header row, alternating rows |
| `.callout-*` | Colored callout boxes (trap/mistake/tip/revision/example) |
| `.badge-*` | Difficulty/frequency pill badges |
| `@media print` | PDF export styles, page breaks |

**To change the color scheme:** find `#3b82f6` (primary blue) and `#1e3a5f` (dark heading) and replace globally.

**To change fonts:** update the `@import` URL and the `font-family` declarations in `body` and `h1,h2,h3,h4`.

---

## Images & Diagrams

### Embedded Images (Wikimedia Commons)
Chapters 3, 5, 15, 17, and 19 contain inline images from Wikimedia Commons SVG URLs:
```markdown
![Alt text](https://upload.wikimedia.org/wikipedia/commons/[path]/[file].svg)
*Caption text*
```

**Note:** Wikimedia rate-limits bulk downloads. If images show as broken:
- Try from a different IP / network
- Or download images manually from the Wikimedia Commons pages and save to the `images/` folder, then update the URLs to relative paths: `![Alt](../images/filename.svg)`

### ASCII Architecture Diagrams
`APPENDIX_Architecture_Diagrams.md` contains 12 full ASCII diagrams for:
JVM memory, Spring bean lifecycle, JPA entity lifecycle, Kafka cluster, OAuth2+PKCE, B-tree index, Consistent hashing, MVCC version chain, Microservices flow, Redis cluster, Thread states, Spring Security filter chain.

These are pure ASCII — no external dependencies, always render correctly.

---

## Appendices

| File | Contents | When to update |
|---|---|---|
| `APPENDIX_Architecture_Diagrams.md` | 12 ASCII architecture diagrams | When adding new architectural topics |
| `APPENDIX_Tables.md` | 30 consolidated reference tables (T1-T30) | When adding new comparison tables in chapters |
| `APPENDIX_CodeSnippets.md` | 38 must-know code patterns (9 categories) | When adding new important code patterns |

---

## SUMMARY.md Structure

`SUMMARY.md` is the **single source of truth** for the sidebar. mdBook ignores any `.md` file not listed here.

```markdown
# Summary

[Cover](cover.md)          ← prefix chapter (shown before numbered sections)

---

# Section Name            ← section headers (bold, non-clickable in sidebar)

- [Page Title](path.md)   ← clickable page
  - [Sub-page](path.md)   ← nested page (indented)
```

**Rules:**
- Items before the first `---` are "prefix chapters" (no section number)
- `# Section` creates a bold non-clickable header
- Indented `  -` items create nested sidebar entries
- Every file referenced must exist or `mdbook build` will error

---

## Java Version Notes

- All code targets **Java 17** (LTS)
- Java 21 features (Virtual Threads, Record Patterns, Sequenced Collections) are noted inline where relevant with a `Java 21` label
- Spring Boot **3.x** (requires Java 17+)
- Spring Security **6.x** (SecurityFilterChain replaces WebSecurityConfigurerAdapter)

---

## Version History

| Version | Date | Changes |
|---|---|---|
| 1.0 | July 2026 | Initial release — 27 chapters, 400+ Q&As, mdBook with custom theme |

---

*For questions or contributions, follow this guide and maintain the 10-item question format throughout.*
