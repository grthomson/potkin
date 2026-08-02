#lang racket

(require redex/reduction-semantics
         "model/kernel-redex.rkt")

(provide PotkinSmoke
         smoke-join
         (all-from-out "model/kernel-redex.rkt"))

;; Installation smoke test only. This toy language makes no semantic claims;
;; PotkinKernel above is the committed proof-theoretic Redex model.
(define-language PotkinSmoke
  (p ground
     (fork p p)))

(define smoke-join
  (reduction-relation
   PotkinSmoke
   (--> (fork ground ground)
        ground
        "join")))
