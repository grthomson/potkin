# Potkin

Executable Racket/Redex presentation of the project's calculus-relative
proof/context kernel.

## Status

The implemented static slice contains:

- Racket package metadata;
- canonical multiset sequent and hypersequent boundaries;
- immutable equipped-calculus registries of concrete occurrences;
- a shared raw syntax with independent Redex and ordinary-Racket checkers;
- typed punctures, telescopes, context composition, and complete filling;
- commutative proof forests with block and flattened root profiles;
- prefix-free, address-indexed CK cut witnesses and lazy cut enumeration;
- immutable compatible calculus revisions, exact liveness diagnostics, and checked lifting;
- explicit basis-level constructor deletion for terms and proof forests;
- exact repair plans for withdrawn nullary material grounds, including the separate whole-proof endpoint; and
- the preserved standard Redex smoke example and test.

See `docs/semantic-contract-v56.md` for the exact scope and deferred features.

## Layout

```text
potkin/
  model.rkt       Redex language and judgments (plus preserved smoke model)
  model/          Redex static kernel
  kernel.rkt      Ordinary-Racket public facade
  kernel/         Boundaries, checking, contexts, forests, and CK cuts
  main.rkt        Public package entry point
examples/
  smoke.rkt       Preserved installation smoke example
  v56-running-factorisation.rkt
tests/
  smoke-test.rkt  Preserved installation smoke test
```

## Local toolchain

The machine is configured with Racket 9.2 x64 and the distribution-provided
Redex package.

From PowerShell:

```powershell
& 'C:\Program Files\Racket\racket.exe' examples\smoke.rkt
& 'C:\Program Files\Racket\racket.exe' examples\v56-running-factorisation.rkt
& 'C:\Program Files\Racket\raco.exe' test tests\smoke-test.rkt
& 'C:\Program Files\Racket\raco.exe' test -j 4 .
```

The expected example output is:

```text
#t
(ground)
```

The v56 example then prints the four vertex addresses, the five admissible
cuts (including the empty cut), and the two-leaf factorisation:

```text
(() (1) (1 1) (1 2))
()
((1))
((1 1))
((1 2))
((1 1) (1 2))
(detached (((1 1) (app bS)) ((1 2) (app bT))))
(remainder (app i (app m (puncture) (puncture))))
(telescope (((1 1) S) ((1 2) T)))
(reconstructs? #t)
```
