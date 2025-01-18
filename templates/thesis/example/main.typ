#import "meta.typ" as meta
#import "@local/whs-thesis:0.1.0": *
#import "chapters/00_abstract.typ" as abstract
#import "acronyms.typ" as acronyms

#show: whs-thesis.with(
   meta.title,
   meta.author,
   meta.date,
   meta.keywords,
   [#abstract],
   meta.bibliography,
   acronyms.acronyms,
   meta.degree,
   meta.place,
   meta.thesisType,
   meta.studyCourse,
   meta.department,
   meta.firstExaminer,
   meta.secondExaminer,
   meta.dateOfSubmission,
)

// ---------------- Main ------------------

#include "chapters/01_introduction.typ"
#include "chapters/02_definitions.typ"
#include "chapters/03_concept.typ"
#include "chapters/04_implementation.typ"
#include "chapters/05_conclusion.typ"