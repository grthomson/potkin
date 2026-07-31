# Potkin

Scaffold for an executable Racket/Redex presentation of the project’s
Hopf-algebraic proof-calculus framework.

## Status

This repository intentionally contains only:

- Racket package metadata;
- a neutral module layout;
- the standard tiny Redex smoke example; and
- a smoke test.

No proof language, carrier, typing judgment, CK cut operation, filling
operation, or liveness semantics has been fixed yet. Those definitions will be
implemented from the current paper specification.

## Layout

```text
potkin/
  model.rkt       Redex language and judgments (currently smoke test only)
  kernel.rkt      Ordinary Racket algorithms (currently reserved)
  main.rkt        Public package entry point
examples/
  smoke.rkt
tests/
  smoke-test.rkt
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

