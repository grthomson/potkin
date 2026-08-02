# Potkin semantic invariants

- Keep raw Redex candidates separate from checked calculus-relative terms. Only the checker may construct checked nodes.
- Resolve every node through one immutable finite equipped-calculus registry. Check exact arity and each ordered, 1-indexed premise against its entire hypersequent boundary.
- Treat formula contexts and nonempty hypersequents as finite multisets: exchange is canonical, multiplicity is not discarded. Give equal displayed components separate local occurrence indices; coherent reindexing is future work.
- A puncture is a vacant typed premise slot, never a vertex. Infer its requirement from its retained parent. A typed open context remains valid even when no complete filler is registered.
- Keep premise order separate from commutative forest order. The nodeless `Box^G` context is neither an empty forest nor a CK generator. A connected `S | T` proof is not the forest of separate `S` and `T` proofs.
- Use positive, 1-indexed premise-slot addresses, with `()` at the root. CK cuts contain existing nonroot vertex addresses and are prefix-free.
- Retain every cut's lexicographically address-aligned detached tuple before forming its commutative forest. Preserve equal subtree occurrences and multiplicity. Never encode the whole-tree algebraic endpoint as a root cut.
- Build a compatible revision as an immutable target registry `(K0 - D) + A`: every withdrawn ID belongs to `K0`, additions have globally fresh IDs, and retained concrete occurrences are exactly unchanged.
- Keep historical source certification separate from target-relative exact liveness. Lifting converts checked terms back to the shared raw syntax and revalidates them under the target with the same whole root boundary; never cast or silently reinterpret provenance.
- Constructor deletion is a basis projection with explicit survivor and algebraic-zero results. Kill a whole forest monomial when any factor contains a withdrawn occurrence, retain every factor-local offending address with multiplicity, and let the empty forest survive as the algebra unit.
- Automatic repair is only for all exact inactive occurrences of a complete historical proof when each is explicitly withdrawn, material, and nullary. A nonroot plan retains its historical CK witness and separately lifts only the retained punctured remainder into the target.
- Treat a one-vertex withdrawn ground as a separate whole-proof replacement through target `Box^G`; never manufacture a root CK cut. Filling and extraction require complete, live proofs with exact target provenance and preserve the plan's retained constructor identities and ordered structure.
- Equality is structural proof-presentation equality. Do not add proof quotients, commuting conversions, implicit Weakening, Contraction, Mix, assembly, or Gentzen Cut.
- Keep the raw Redex model and ordinary-Racket algorithms on the shared raw s-expression representation.
