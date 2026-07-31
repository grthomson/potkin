# Potkin

Executable Racket/Redex presentation of the project's calculus-relative
proof/context kernel.

## Status

The implemented static slice contains:

- Racket package metadata;
- canonical multiset sequent and hypersequent boundaries;
- immutable equipped-calculus registries of concrete occurrences;
- a shared raw syntax with independent Redex and ordinary-Racket checkers;
- typed punctures, telescopes, context composition, and complete filling; and
- the preserved standard Redex smoke example and test.

See `docs/semantic-contract-v56.md` for the exact scope and deferred features.

## Layout

```text
potkin/
  model.rkt       Redex language and judgments (plus preserved smoke model)
  model/          Redex static kernel
  kernel.rkt      Ordinary-Racket public facade
  kernel/         Boundaries, checking, addresses, and typed contexts
  main.rkt        Public package entry point
examples/
  smoke.rkt       Preserved installation smoke example
tests/
  smoke-test.rkt  Preserved installation smoke test
```

## Local toolchain

The machine is configured with Racket 9.2 x64 and the distribution-provided
Redex package.

From PowerShell:

```powershell
& 'C:\Program Files\Racket\racket.exe' examples\smoke.rkt
& 'C:\Program Files\Racket\raco.exe' test tests\smoke-test.rkt
```

The expected example output is:

```text
#t
(ground)
```
