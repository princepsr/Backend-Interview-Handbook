# Build all 7 books: combined handbook + 6 individual volumes
#
# Usage (run from project root):
#   .\build.ps1              # build all 7
#   .\build.ps1 -Volume 3   # build only Volume 3
#   .\build.ps1 -Combined   # build only the combined book
#
# How per-volume builds work:
#   A temporary flat src directory (_build\volN) is assembled per volume.
#   mdBook builds from it, then the temp dir is deleted.
#   Source chapter files are never permanently duplicated.

param(
    [int]$Volume = 0,
    [switch]$Combined
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# ---- Volume definitions ------------------------------------------------------

$volumes = @(
    @{
        Num      = 1
        Title    = 'Volume 1: Core Java'
        Desc     = 'Core Java fundamentals for SDE2 interviews. OOP, Collections, Java 8+, JVM Internals, Multithreading and Concurrency. 6 chapters, 100+ Q&As.'
        PDF      = 'Volume1_CoreJava.pdf'
        Chapters = @(
            @{ Label = 'Chapter 1 - OOP Fundamentals';               File = 'Volume1_CoreJava\Chapter1_OOP.md' }
            @{ Label = 'Chapter 2 - Strings, Wrappers and Exceptions'; File = 'Volume1_CoreJava\Chapter2_Strings_Wrappers_Exceptions.md' }
            @{ Label = 'Chapter 3 - Collections and Data Structures'; File = 'Volume1_CoreJava\Chapter3_Collections.md' }
            @{ Label = 'Chapter 4 - Java 8+ Modern Features';        File = 'Volume1_CoreJava\Chapter4_Java8Plus.md' }
            @{ Label = 'Chapter 5 - JVM Internals and GC';           File = 'Volume1_CoreJava\Chapter5_JVM_Internals.md' }
            @{ Label = 'Chapter 6 - Multithreading and Concurrency'; File = 'Volume1_CoreJava\Chapter6_Multithreading_Concurrency.md' }
        )
        Revision = @{ Label = 'Chapter 23 - Core Java Revision'; File = 'Volume6_Revision_Pack\Chapter23_CoreJava_Revision.md' }
    }
    @{
        Num      = 2
        Title    = 'Volume 2: Spring Ecosystem'
        Desc     = 'Spring Core, Spring Boot, Spring Data JPA and Hibernate for SDE2 interviews. 2 deep-dive chapters.'
        PDF      = 'Volume2_SpringEcosystem.pdf'
        Chapters = @(
            @{ Label = 'Chapter 7 - Spring Core and Boot';           File = 'Volume2_Spring\Chapter7_Spring_Core_Boot.md' }
            @{ Label = 'Chapter 8 - Spring Data JPA and Hibernate';  File = 'Volume2_Spring\Chapter8_JPA_Hibernate.md' }
        )
        Revision = @{ Label = 'Chapter 24 - Spring and JPA Revision'; File = 'Volume6_Revision_Pack\Chapter24_Spring_JPA_Revision.md' }
    }
    @{
        Num      = 3
        Title    = 'Volume 3: Backend Systems'
        Desc     = 'REST APIs, Microservices, Kafka, Redis and Security for SDE2 interviews. 5 chapters.'
        PDF      = 'Volume3_BackendSystems.pdf'
        Chapters = @(
            @{ Label = 'Chapter 9 - REST APIs and Web';              File = 'Volume3_BackendSystems\Chapter9_REST_APIs.md' }
            @{ Label = 'Chapter 10 - Microservices Architecture';    File = 'Volume3_BackendSystems\Chapter10_Microservices.md' }
            @{ Label = 'Chapter 11 - Apache Kafka';                  File = 'Volume3_BackendSystems\Chapter11_Kafka.md' }
            @{ Label = 'Chapter 12 - Redis and Caching';             File = 'Volume3_BackendSystems\Chapter12_Redis_Caching.md' }
            @{ Label = 'Chapter 13 - Security (OAuth2, JWT, TLS)';   File = 'Volume3_BackendSystems\Chapter13_Security.md' }
        )
        Revision = @{ Label = 'Chapter 25 - Backend Systems Revision'; File = 'Volume6_Revision_Pack\Chapter25_BackendSystems_Revision.md' }
    }
    @{
        Num      = 4
        Title    = 'Volume 4: Databases and Performance'
        Desc     = 'SQL, Indexing, ACID, Distributed Databases and Advanced DB topics for SDE2 interviews. 5 chapters.'
        PDF      = 'Volume4_Databases.pdf'
        Chapters = @(
            @{ Label = 'Chapter 14 - SQL Deep Dive';                      File = 'Volume4_Databases\Chapter14_SQL.md' }
            @{ Label = 'Chapter 15 - Indexing and Query Optimization';    File = 'Volume4_Databases\Chapter15_Indexing.md' }
            @{ Label = 'Chapter 16 - ACID, Transactions and Normalization'; File = 'Volume4_Databases\Chapter16_ACID_Transactions.md' }
            @{ Label = 'Chapter 17 - Distributed Databases and Sharding'; File = 'Volume4_Databases\Chapter17_Distributed_DBs.md' }
            @{ Label = 'Chapter 18 - Advanced DB Topics';                 File = 'Volume4_Databases\Chapter18_Advanced_DB.md' }
        )
        Revision = @{ Label = 'Chapter 26 - Databases Revision'; File = 'Volume6_Revision_Pack\Chapter26_Databases_Revision.md' }
    }
    @{
        Num      = 5
        Title    = 'Volume 5: System Design and LLD'
        Desc     = 'Design Patterns, SOLID, LLD Case Studies and System Design HLD for SDE2 interviews. 4 chapters.'
        PDF      = 'Volume5_SystemDesign_LLD.pdf'
        Chapters = @(
            @{ Label = 'Chapter 19 - Design Patterns';            File = 'Volume5_SystemDesign_LLD\Chapter19_Design_Patterns.md' }
            @{ Label = 'Chapter 20 - SOLID and Clean Architecture'; File = 'Volume5_SystemDesign_LLD\Chapter20_SOLID_CleanArch.md' }
            @{ Label = 'Chapter 21 - LLD Case Studies';           File = 'Volume5_SystemDesign_LLD\Chapter21_LLD_Case_Studies.md' }
            @{ Label = 'Chapter 22 - System Design HLD';          File = 'Volume5_SystemDesign_LLD\Chapter22_System_Design_HLD.md' }
        )
        Revision = @{ Label = 'Chapter 27 - System Design and LLD Revision'; File = 'Volume6_Revision_Pack\Chapter27_SystemDesign_LLD_Revision.md' }
    }
    @{
        Num      = 6
        Title    = 'Volume 6: Revision Pack'
        Desc     = 'Rapid revision across all 5 volumes + 100 mock Q&As + interview-day checklist. Use in the final week before your interview.'
        PDF      = 'Volume6_RevisionPack.pdf'
        Chapters = @(
            @{ Label = 'Chapter 23 - Core Java Revision';           File = 'Volume6_Revision_Pack\Chapter23_CoreJava_Revision.md' }
            @{ Label = 'Chapter 24 - Spring and JPA Revision';      File = 'Volume6_Revision_Pack\Chapter24_Spring_JPA_Revision.md' }
            @{ Label = 'Chapter 25 - Backend Systems Revision';     File = 'Volume6_Revision_Pack\Chapter25_BackendSystems_Revision.md' }
            @{ Label = 'Chapter 26 - Databases Revision';           File = 'Volume6_Revision_Pack\Chapter26_Databases_Revision.md' }
            @{ Label = 'Chapter 27 - System Design and LLD Revision'; File = 'Volume6_Revision_Pack\Chapter27_SystemDesign_LLD_Revision.md' }
        )
        Revision = $null
    }
)

# ---- Shared files copied into every per-volume build -------------------------

$sharedFiles = @(
    'INDEX.md'
    'STUDY_GUIDE.md'
    'COMPANY_GUIDE.md'
    'APPENDIX_Architecture_Diagrams.md'
    'APPENDIX_Tables.md'
    'APPENDIX_CodeSnippets.md'
    'custom.css'
    'custom.js'
)

# ---- Build combined book -----------------------------------------------------

function Build-Combined {
    Write-Host ''
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor DarkGray
    Write-Host '  Building: Combined Handbook (all 6 volumes)' -ForegroundColor Cyan
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor DarkGray
    Push-Location $root
    mdbook build
    if ($LASTEXITCODE -ne 0) { Write-Host '  FAILED' -ForegroundColor Red; Pop-Location; exit 1 }
    Write-Host '  Done  ->  docs\combined\html\' -ForegroundColor Green
    Pop-Location
}

# ---- Build one volume --------------------------------------------------------

function Build-Volume($vol) {
    $n      = $vol.Num
    $tmpDir = Join-Path $root "_build\vol$n"

    Write-Host ''
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor DarkGray
    Write-Host "  Building: $($vol.Title)" -ForegroundColor Cyan
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor DarkGray

    # 1. Create fresh temp src dir
    if (Test-Path $tmpDir) { Remove-Item -Recurse -Force $tmpDir }
    New-Item -ItemType Directory -Force $tmpDir | Out-Null

    # 2. Copy chapter files (preserve subdir structure)
    $allChapterFiles = [System.Collections.Generic.List[object]]::new()
    foreach ($ch in $vol.Chapters) { $allChapterFiles.Add($ch) }
    if ($vol.Revision) { $allChapterFiles.Add($vol.Revision) }
    foreach ($ch in $allChapterFiles) {
        $src     = Join-Path $root $ch.File
        $dest    = Join-Path $tmpDir $ch.File
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force $destDir | Out-Null }
        Copy-Item $src $dest
    }

    # 3. Copy shared files
    foreach ($f in $sharedFiles) {
        $src = Join-Path $root $f
        if (Test-Path $src) { Copy-Item $src (Join-Path $tmpDir $f) }
    }

    # 4. Copy this volume's cover and intro pages
    $coverSrc = Join-Path $root "books\vol$n\cover.md"
    if (Test-Path $coverSrc) { Copy-Item $coverSrc (Join-Path $tmpDir 'cover.md') }
    $introSrc = Join-Path $root "books\vol$n\intro.md"
    if (Test-Path $introSrc) { Copy-Item $introSrc (Join-Path $tmpDir 'intro.md') }

    # 5. Write SUMMARY.md
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Summary')
    $lines.Add('')
    $lines.Add('[Cover](cover.md)')
    $lines.Add('')
    $lines.Add('---')
    $lines.Add('')
    $lines.Add("[$(($vol.Title))](intro.md)")
    $lines.Add('')
    $lines.Add('---')
    $lines.Add('')
    $lines.Add('# Navigation and Study Guides')
    $lines.Add('')
    $lines.Add('- [Master Index (A-Z)](INDEX.md)')
    $lines.Add('- [Study Plans](STUDY_GUIDE.md)')
    $lines.Add('- [Company-Specific Guide](COMPANY_GUIDE.md)')
    $lines.Add('')
    $lines.Add('---')
    $lines.Add('')
    $lines.Add("# $($vol.Title)")
    $lines.Add('')
    foreach ($ch in $vol.Chapters) {
        $mdPath = $ch.File -replace '\\', '/'
        $lines.Add("- [$($ch.Label)]($mdPath)")
    }
    if ($vol.Revision) {
        $lines.Add('')
        $lines.Add('---')
        $lines.Add('')
        $lines.Add('# Revision')
        $lines.Add('')
        $mdPath = $vol.Revision.File -replace '\\', '/'
        $lines.Add("- [$($vol.Revision.Label)]($mdPath)")
    }
    $lines.Add('')
    $lines.Add('---')
    $lines.Add('')
    $lines.Add('# Appendices')
    $lines.Add('')
    $lines.Add('- [Appendix A - Architecture Diagrams](APPENDIX_Architecture_Diagrams.md)')
    $lines.Add('- [Appendix B - Master Reference Tables](APPENDIX_Tables.md)')
    $lines.Add('- [Appendix C - Must-Know Code Snippets](APPENDIX_CodeSnippets.md)')
    [System.IO.File]::WriteAllLines((Join-Path $tmpDir 'SUMMARY.md'), $lines)

    # 6. Write book.toml
    $outDir = '../../docs/vol' + $n
    $tomlLines = [System.Collections.Generic.List[string]]::new()
    $tomlLines.Add('[book]')
    $tomlLines.Add('title = "' + $vol.Title + '"')
    $tomlLines.Add('authors = ["Prince Singh"]')
    $tomlLines.Add('description = "' + $vol.Desc + '"')
    $tomlLines.Add('language = "en"')
    $tomlLines.Add('src = "."')
    $tomlLines.Add('')
    $tomlLines.Add('[build]')
    $tomlLines.Add('build-dir = "' + $outDir + '"')
    $tomlLines.Add('create-missing = false')
    $tomlLines.Add('')
    $tomlLines.Add('[output.html]')
    $tomlLines.Add('default-theme = "light"')
    $tomlLines.Add('preferred-dark-theme = "navy"')
    $tomlLines.Add('no-section-label = false')
    $tomlLines.Add('fold = { enable = true, level = 1 }')
    $tomlLines.Add('additional-css = ["custom.css"]')
    $tomlLines.Add('additional-js = ["custom.js"]')
    $tomlLines.Add('')
    $tomlLines.Add('[output.html.print]')
    $tomlLines.Add('enable = true')
    $tomlLines.Add('page-break = true')
    $tomlLines.Add('')
    $tomlLines.Add('[output.html.search]')
    $tomlLines.Add('enable = true')
    $tomlLines.Add('limit-results = 30')
    $tomlLines.Add('use-boolean-and = true')
    $tomlLines.Add('boost-title = 2')
    $tomlLines.Add('boost-hierarchy = 1')
    $tomlLines.Add('boost-paragraph = 1')
    $tomlLines.Add('expand = true')
    $tomlLines.Add('heading-split-level = 3')
    $tomlLines.Add('')
    $tomlLines.Add('[output.pdf]')
    $tomlLines.Add('enable = true')
    $tomlLines.Add('output-filename = "' + $vol.PDF + '"')
    $tomlLines.Add('print-background = true')
    $tomlLines.Add('prefer-css-page-size = true')
    $tomlLines.Add('landscape = false')
    $tomlLines.Add('display-header-footer = false')
    [System.IO.File]::WriteAllLines((Join-Path $tmpDir 'book.toml'), $tomlLines)

    # 7. Build
    Push-Location $tmpDir
    mdbook build
    $exitCode = $LASTEXITCODE
    Pop-Location

    # 8. Clean up temp dir
    Remove-Item -Recurse -Force $tmpDir

    if ($exitCode -ne 0) {
        Write-Host "  FAILED: $($vol.Title)" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Done  ->  docs\vol$n\html\" -ForegroundColor Green
}

# ---- Main --------------------------------------------------------------------

$start = Get-Date

if ($Volume -ge 1 -and $Volume -le 6) {
    Build-Volume $volumes[$Volume - 1]
} elseif ($Combined) {
    Build-Combined
} else {
    Build-Combined
    foreach ($v in $volumes) { Build-Volume $v }
}

$elapsed = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
Write-Host ''
Write-Host "All builds complete in ${elapsed}s" -ForegroundColor Green
Write-Host ''
Write-Host 'Output locations:' -ForegroundColor DarkGray
Write-Host '  Combined   ->  docs\combined\html\'
for ($i = 1; $i -le 6; $i++) {
    Write-Host "  Volume $i   ->  docs\vol$i\html\"
}
