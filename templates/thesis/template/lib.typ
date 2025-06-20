#import "elements.typ" as elems
#import "settings.typ" as settings

#import "partial/affidavit.typ" as affidavit
#import "partial/title.typ" as title-page
#import "partial/glossar.typ" as glossar

#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.8": *
#import "@preview/glossarium:0.5.6": make-glossary

#let whs-thesis(
  title,
  title-size,
  author,
  first-name,
  last-name,
  date,
  keywords,
  font: settings.FONT_PRIMARY,
  math-font: settings.FONT_MATH,
  raw-font: settings.FONT_ACCENT,
  abstract,
  bibliography,
  acronyms,
  degree,
  place,
  thesis-type,
  study-course,
  department,
  first-examiner,
  second-examiner,
  date-of-submission,
  background: image("partial/images/background.jpg"),
  body,
) = {
  // ========== global definitions ============

  set document(title: title, author: author, date: date, keywords: keywords)


  set text(lang: "de")
  set text(ligatures: false)

  set page("a4")

  set page(
    margin: (
      bottom: 2cm,
    ),
  )

  set cite(style: "ieee")

  // ========== Plugins ============

  show: make-glossary

  show: codly-init.with()
  codly(zebra-fill: none, languages: codly-languages, display-icon: false)

  // ------ text, paragraph and block ------

  set text(
    11pt,
    font: font,
    lang: "de",
  )
  show raw: set text(font: raw-font)
  show math.equation: set text(font: math-font)
  set par(leading: 0.7em, justify: true)
  set block(below: 1.7em)

  // ----------- headings ----------

  // heading settings
  show heading.where(level: 1): set text(size: 16pt)
  show heading.where(level: 2): set text(size: 14pt)
  show heading.where(level: 3): set text(size: 12pt)

  // numbering
  show heading: it => {
    let elems = ()
    if (it.numbering != none and it.body != [Inhaltsverzeichnis]) {
      elems.push(counter(heading).display())
    }
    elems.push(it.body)
    grid(
      columns: 2,
      column-gutter: 4mm,
      ..elems
    )
  }

  show heading: set block(below: 0pt)

  // spacing
  show heading: it => {
    if it.level == 1 {
      it
      v(8mm, weak: true)
      // pad(bottom: 8mm, it)
    } else if it.level == 2 {
      v(3mm)
      it
      v(6mm, weak: true)
    } else {
      pad(top: 0mm, bottom: 4mm, it)
    }
  }

  // -------- figures --------

  set figure(gap: 3.5mm)
  show figure: set block(below: 8mm)

  // --------- outline and bibliography -------

  // add outlines to table of contents, except for itself
  show outline.where(title: [Inhaltsverzeichnis]): it => {
    set heading(outlined: false)
    it
  }
  show outline: set heading(outlined: true)
  show outline: set heading(numbering: "1")

  // ------- Common Elements -------------

  //show link: underline

  set list(
    indent: 6mm,
    marker: (
      [$circle.filled.small$],
      [$circle.stroked.small$],
      [$square.filled.tiny$],
    ),
    body-indent: 3mm,
  )
  set enum(
    indent: 6mm,
    numbering: "1.a.i.",
    body-indent: 3mm,
  )

  // =============== Content ==============

  // -------- Predefined pages -------

  title-page.title(
    background,
    thesis-type,
    title,
    degree,
    author,
    place,
    study-course,
    department,
    first-examiner,
    second-examiner,
    date-of-submission,
    title-size,
  )
  affidavit.affidavit(
    background,
    last-name,
    first-name,
    title,
    place,
    date,
    title-size,
  )
  pagebreak()
  abstract
  pagebreak()

  // set correct header margin
  set page(
    margin: (
      top: settings.HEADER_HEIGHT,
    ),
  )
  // set common header and footer
  set page(numbering: "I")
  counter(page).update(1)

  set page(
    header: elems.common_header(title),
    footer: none,
  )

  set par(leading: 1em)
  heading(outlined: false, numbering: none)[Inhaltsverzeichnis]
  show outline.entry: it => link(
    it.element.location(),
    [#it.indented(it.prefix(), it.inner()) #v(12pt, weak: true)],
  )
  set outline.entry(fill: repeat[.])
  show outline.entry.where(level: 1): it => {
    v(18pt, weak: true)
    if it.at("label", default: none) == <modified-entry> {
      // prevent infinite recursion
      if it.element.supplement.text == "Abschnitt" {
        strong(it)
      } else {
        it
      }
    } else {
      if it.element.supplement.text == "Abschnitt" {
        [#outline.entry(
            it.level,
            it.element,
            fill: "",
          ) <modified-entry>]
      } else {
        [#outline.entry(
            it.level,
            it.element,
            fill: "",
          ) <modified-entry>]
      }
    }
  }
  outline(
    title: none,
    indent: 2em,
  )
  set par(leading: 0.65em) // Reset par leading
  pagebreak()

  glossar.glossar(acronyms)
  pagebreak()

  // Reset outline entries
  show outline.entry: it => link(
    it.element.location(),
    it.indented(it.prefix(), it.inner()),
  )
  set outline.entry(fill: repeat[.])

  heading(outlined: false, numbering: none)[Abbildungsverzeichnis]
  outline(
    title: none,
    target: figure.where(kind: image),
  )

  heading(outlined: false, numbering: none)[Tabellenverzeichnis]
  outline(
    title: none,
    target: figure.where(kind: table),
  )

  heading(outlined: false, numbering: none)[Codeverzeichnis]
  outline(
    title: none,
    target: figure.where(kind: "code"),
  )

  // -------------------------------

  // Set page numbering
  set page(numbering: "1")
  counter(page).update(1)

  set par(justify: true, spacing: 1.5em)

  set page(
    header: elems.common_header(title),
    footer: none,
    margin: (
      top: settings.HEADER_HEIGHT,
    ),
  )

  // Set chapter numbering
  set heading(numbering: "1.1")
  counter(heading).update(0)


  // add pagebreak before each level 1 heading (except for first heading after outline)
  show heading.where(level: 1): it => {
    if counter(heading).at(it.location()).first() != 1 {
      pagebreak()
    }
    it
  }

  // start of actual writing
  body


  // -------- Predefined pages --------

  set page(numbering: "I", number-align: right)
  counter(page).update(1)
  set page(
    header: elems.common_header(title),
    footer: none,
    margin: (
      top: settings.HEADER_HEIGHT,
    ),
  )

  // Literaturverzeichnis
  heading(outlined: false, numbering: none)[Literaturverzeichnis]
  bibliography(
    title: none,
    style: "ieee",
  )
}
