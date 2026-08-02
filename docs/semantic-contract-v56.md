# Semantic contract: v56 static kernel

This repository implements the static calculus-relative proof/context kernel described around Definitions 1.1--1.4, Proposition 1.5, the two root profiles, the address-indexed CK factorisation, and compatible base extension in the v56 manuscript. The supplied PDF and TeX source are read-only mathematical references and are not part of the implementation.

## Implemented representation

- Formula contexts are canonical finite multisets of immutable formula data.
- A sequent is a pair of formula contexts. A hypersequent is a nonempty finite multiset of sequents. Equal displayed components retain distinct, local 1-based occurrence indices.
- A concrete occurrence has a unique registry key, a disjoint kind/tag, opaque fully instantiated data, an ordered vector of whole-hypersequent premises, one whole-hypersequent conclusion, and optional opaque incidence data.
- An equipped calculus is a finite immutable registry. Profile equality never grants admission: raw applications identify the exact registered occurrence key.
- Raw candidates use the Redex-friendly shared syntax `(puncture)` or `(app occurrence-key child ...)`. Checked nodes and typed holes are separate values whose constructors are private to the checker.
- Validation reports structured errors and checks registry membership, exact arity, exact ordered premise boundaries, and an optional expected root boundary. Checked terms expose root boundary, completeness, and vertex count.
- Punctures have positive premise-slot addresses (with `()` reserved for the typed nodeless identity), and their requirements are read from retained parent occurrences. The premise telescope sorts these address/whole-boundary pairs lexicographically.
- A corolla is one admitted occurrence with every premise vacant. Typed insertion prefixes the inserted context's internal addresses, context composition fills the current telescope, and complete filling requires a complete proof at every entry. These operations recheck exact boundary and registry provenance; their validity never depends on a filler search.
- Calculus provenance is retained for rechecking but excluded from structural proof-presentation equality. A term may be inserted into another registry only when all of its exact concrete occurrences are admitted there.
- A compatible calculus revision is an immutable source registry, exact withdrawn-ID set, fresh addition set, and internally constructed target `(K0 - D) + A`. Every retained occurrence is reused exactly; profile mutation, substitution, renaming, and component reindexing are absent. Historical validity remains source-relative, while target liveness checks every vertex's full occurrence identity and reports every retired, unknown, or incompatible/redefined address.
- Checked lifting is explicit rebasing: a source-certified live term or open context is converted to shared raw syntax and revalidated under the target with its exact root boundary. This preserves its presentation, addresses, puncture requirements, and telescope while changing registry provenance. No unchecked cast is exposed.
- A proof forest is a commutative finite multiset of positive-vertex checked connected terms within one fixed equipped calculus. Multiplicity is retained. Its block-root profile remembers one hypersequent per connected factor, while its flattened root unions all displayed component occurrences. The empty forest has no `HSeq` flattened root, and a nodeless identity context is rejected as a factor. Forest union rejects operands from unequal registries rather than choosing an implicit extension.
- A CK cut is a finite prefix-free set of existing nonroot vertex addresses in a complete or punctured positive-vertex derivation. A witness retains the sorted address/subtree tuple, its commutative forest image, and the punctured remainder. Empty cuts are included; root cuts are rejected because the whole-tree tensor endpoint is algebraic bookkeeping, not a cut. Witness reconstruction fills only the newly cut addresses, preserving any older punctures. Cut enumeration structurally generates a lazy sequence without scanning inadmissible subsets.

The implemented CK API deliberately stops at occurrence-level witnesses. It does not collect them into formal linear coproduct sums.

## Equality and indexing

The implementation uses structural proof-presentation equality. Boundary multisets absorb exchange and preserve counts. Component indices are deterministic local presentation indices; a future representation may implement the manuscript's more general equality by coherent component reindexing. Premise slots and tree addresses remain ordered even when their boundaries are equal. Forest factors are instead collected commutatively with multiplicity.

## Explicitly deferred

This slice does not yet implement basis-level constructor deletion or the exact nullary-ground repair theorem. It also defers general persistent-calculus functoriality; formula substitution and coherent component reindexing; collected formal coproduct sums, Hopf ideals as linear subspaces, counits, or antipodes; general repair-frontier search and positive-arity repair; repair of already-punctured source terms; prospective constructor-free proof enumeration; proof search or filling-fibre enumeration; nested noncrossing cut coherence; component-incidence semantics; HCP, communication, execution, concurrency, or effects; resource polynomials; harmony; proof quotients; implicit structural rules; GUIs; and a custom `#lang`.
