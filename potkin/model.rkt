#lang racket

(require redex/reduction-semantics)

(provide PotkinSmoke
         smoke-join)

;; Installation smoke test only.  The project language will be specified from
;; the current paper before any proof-theoretic grammar is committed here.
(define-language PotkinSmoke
  (p ground
     (fork p p)))

(define smoke-join
  (reduction-relation
   PotkinSmoke
   (--> (fork ground ground)
        ground
        "join")))

