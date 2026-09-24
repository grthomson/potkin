# AGENTS.md

## Default operating mode: focused

Work only on the user's explicit deliverable. Prefer the smallest correct
change or mathematical result. Do not expand the task merely because related
work is possible.

- Treat the existing repository as the source of truth.
- Inspect the smallest relevant set of files. Use `rg` before broad reading.
- Do not begin with a repository-wide survey, full build, or full test suite.
- Do not browse the web unless explicitly requested or genuinely required.
- Do not spawn subagents unless the user explicitly requests parallel
  investigation or independent review. Use the minimum number required.
- Do not add dependencies, introduce another implementation language, redesign
  APIs, or refactor unrelated code without approval.
- Do not create reports, plans, benchmarks, generated data, or documentation
  unless they contribute directly to the requested deliverable.
- Never treat time spent, number of commands, or volume of output as a success
  criterion.

## Investigation budget

- Form a concrete hypothesis, proof obligation, or proposed diff before doing
  extensive diagnostics.
- If roughly eight exploratory tool actions produce no concrete direction,
  stop and report what is missing instead of broadening the search.
- Ask before undertaking a full-repository scan, lengthy exhaustive
  enumeration, major architectural change, or command expected to take more
  than five minutes.
- Do not rerun an unchanged command merely to reconfirm its result.
- If a focused correction fails twice, report the blocker before beginning a
  general diagnostic campaign.

## Editing

- Preserve existing user changes and unrelated work.
- Make small, reviewable diffs.
- Follow the repository's existing language, structures, and conventions.
- Do not mass-format or mechanically rewrite unrelated files.
- Do not create a parallel Python prototype when the relevant implementation
  already exists in Racket or Lean unless specifically requested.

## Verification

- Run the narrowest relevant check first.
- Test changed files or modules before testing the whole repository.
- Run a full build or full suite at most once at the end, and only when the
  change's scope warrants it or the user requests it.
- Do not investigate unrelated pre-existing failures.
- State exactly which checks were run and which were not run.

## Mathematical and scientific discipline

- Keep the Connes–Kreimer Hopf algebra central to this project.
- Do not introduce mathematical machinery without stating what new theorem,
  invariant, computation, or operational distinction it provides.
- Keep CK admissible cuts distinct from logical Cut, forest product distinct
  from external Mix, and proof trees distinct from formula trees.
- Do not infer a general theorem from a single derivation or bounded
  enumeration.
- Label results accurately as:
  `PROVED`, `MECHANIZED`, `CODE-CHECKED`, `BOUNDED-EVIDENCE`, or `CONJECTURED`.
- Never describe a code check as a proof or claim novelty without evidence.

## Completion

Give a concise report containing:

1. What changed or was established.
2. Why it was necessary.
3. The exact verification performed.
4. Anything still unproved, unverified, or blocked.

Stop once the requested deliverable has been reached.

## POTKIN core invariants

- Raw Redex terms and checked calculus-relative terms are distinct. Only the
  checker constructs checked nodes.
- All checked nodes belong to one immutable equipped-calculus registry and
  retain exact calculus provenance.
- Formula contexts and hypersequents are finite multisets: exchange is
  canonical but multiplicity and occurrence identity are preserved.
- Premise positions are ordered and 1-indexed.
- A puncture is a typed vacant premise slot, not a vertex. `Box^G`, the empty
  forest unit, and algebraic zero are three different objects.
- CK cuts select existing nonroot vertices and are prefix-free. The empty cut
  gives `1 tensor t`; `t tensor 1` is added separately and is not a root cut.
- Preserve occurrence-level cut witnesses and addresses before collecting
  equal algebraic terms.
- Forest multiplication is the algebra product, not filling, Gentzen Cut,
  Mix, reconstruction, or normalization.
- The antipode is algebraic and must not be interpreted as an inverse proof,
  repair operation, or normalization procedure.
- Crossing calculus revisions requires explicit lifting and rechecking; never
  silently reinterpret provenance.
- Report mathematical status as `PROVED`, `MECHANIZED`, `CODE-CHECKED`,
  `BOUNDED-EVIDENCE`, or `CONJECTURED`.

For changes involving incidence, punctures, coproducts, grafting, derivatives,
revision maps, repair, return characters, or convolution powers, read
`docs/SEMANTIC_INVARIANTS.md` before editing the relevant code. Do not load
that document for unrelated tasks.

The detailed document describes the current implementation. It does not
prohibit an explicitly requested extension or alternative construction.