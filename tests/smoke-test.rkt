#lang racket

(require rackunit
         redex/reduction-semantics
         "../potkin/model.rkt")

(check-true
 (redex-match? PotkinSmoke p
               (term (fork ground ground))))

(check-equal?
 (apply-reduction-relation
  smoke-join
  (term (fork ground ground)))
 (list (term ground)))

