#lang racket

;; Public facade for the checked kernel and its exact-provenance operations.

(require "kernel/boundary.rkt"
         "kernel/calculus.rkt"
         "kernel/syntax.rkt"
         "kernel/check.rkt"
         "kernel/address.rkt"
         "kernel/context.rkt"
         "kernel/cut.rkt"
         "kernel/revision.rkt"
         "kernel/deletion.rkt"
         "kernel/repair.rkt")

(provide (all-from-out "kernel/boundary.rkt")
         (all-from-out "kernel/calculus.rkt")
         (all-from-out "kernel/syntax.rkt")
         (all-from-out "kernel/check.rkt")
         (all-from-out "kernel/address.rkt")
         (all-from-out "kernel/context.rkt")
         (all-from-out "kernel/cut.rkt")
         (all-from-out "kernel/revision.rkt")
         (all-from-out "kernel/deletion.rkt")
         (all-from-out "kernel/repair.rkt"))
