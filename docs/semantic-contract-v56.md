# Semantic contract: v56 static kernel

This repository implements the first static vertical slice of the calculus-relative proof/context kernel described around Definitions 1.1--1.4, Proposition 1.5, the two root profiles, and the address-indexed CK factorisation in the v56 manuscript. The supplied PDF is a read-only reference; the named TeX source is not present in this checkout.

## Implemented representation

- Formula contexts are canonical finite multisets of immutable formula data.
- A sequent is a pair of formula contexts. A hypersequent is a nonempty finite multiset of sequents. Equal displayed components retain distinct, local 1-based occurrence indices.
- A concrete occurrence has a unique registry key, a disjoint kind/tag, opaque fully instantiated data, an ordered vector of whole-hypersequent premises, one whole-hypersequent conclusion, and optional opaque incidence data.
- An equipped calculus is a finite immutable registry. Profile equality never grants admission: raw applications identify the exact registered occurrence key.
- Raw candidates use the Redex-friendly shared syntax `(puncture)` or `(app occurrence-key child ...)`. Checked nodes and typed holes are separate values whose constructors are private to the checker.
- Validation reports structured errors and checks registry membership, exact arity, exact ordered premise boundaries, and an optional expected root boundary. Checked terms expose root boundary, completeness, and vertex count.
- Punctures have positive premise-slot addresses (with `()` reserved for the typed nodeless identity), and their requirements are read from retained parent occurrences. The premise telescope sorts these address/whole-boundary pairs lexicographically.
- A corolla is one admitted occurrence with every premise vacant. Typed insertion prefixes the inserted context's internal addresses, context composition fills the current telescope, and complete filling requires a complete proof at every entry. These operations recheck exact boundary and registry provenance; their validity never depends on a filler search.
- Calculus provenance is retained for rechecking but excluded from structural proof-presentation equality. A term may be inserted into another registry only when all of its exact concrete occurrences are admitted there. Explicit lifting of an old context to a persistent calculus extension is deferred.

The final commit in this slice adds commutative forests with block and flattened roots, and address-indexed CK cut witnesses with lazy admissible-cut enumeration.

## Equality and indexing

The implementation uses structural proof-presentation equality. Boundary multisets absorb exchange and preserve counts. Component indices are deterministic local presentation indices; a future representation may implement the manuscript's more general equality by coherent component reindexing. Premise slots and tree addresses remain ordered even when their boundaries are equal. Forest factors are instead collected commutatively with multiplicity.

## Explicitly deferred

This slice does not implement constructor deletion or withdrawal, historical liveness, the exact nullary-ground repair theorem, or any broader repair operation. It also defers collected formal coproduct sums, counits, or antipodes; proof search or filling-fibre enumeration; nested noncrossing cut coherence beyond the basic witness operations; component-incidence semantics; HCP, communication, execution, concurrency, or effects; resource polynomials; harmony; proof quotients; implicit structural rules; GUIs; and a custom `#lang`. Those first three deferred items form the next milestone.
