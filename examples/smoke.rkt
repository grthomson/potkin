#lang racket

(require redex/reduction-semantics
         "../potkin/model.rkt")

(displayln
 (redex-match? PotkinSmoke p
               (term (fork ground ground))))

(displayln
 (apply-reduction-relation
  smoke-join
  (term (fork ground ground))))

