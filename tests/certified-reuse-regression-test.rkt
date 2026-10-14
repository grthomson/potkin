#lang racket/base

;; One targeted command exercises the public import and the relevant earlier
;; native order/closure regressions. This is not the full repository suite.
(require "ck-rational-semantics-test.rkt"
         "ck-protected-reuse-test.rkt"
         "certified-modular-reuse-test.rkt"
         "typed-reuse-comparison-test.rkt"
         "ck-boundary-certification-test.rkt")
