#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "../potkin/hopf/ordered-ck.rkt"
         (prefix-in comm: "../potkin/algebra/formal-sum.rkt")
         (prefix-in comm: "../potkin/hopf/ck.rkt")
         (prefix-in comm: "../potkin/hopf/antipode.rkt"))

;; A SMALL FIXED falsification fixture, not an exhaustive theorem oracle.
;; The two ordered binary symbols below test the algebraic orientation issue;
;; neither is being certified here as a logical Gentzen Cut/Communication rule.
(define H (singleton-hypersequent '(a) '(a)))
(define occurrences
  (list (make-concrete-occurrence 'e '() H #:kind 'material)
        (make-concrete-occurrence 'd '() H #:kind 'material)
        (make-concrete-occurrence 'r '() H #:kind 'material)
        (make-concrete-occurrence 'u (list H) H)
        (make-concrete-occurrence 'b (list H H) H)
        (make-concrete-occurrence 'positive (list H H) H)
        (make-concrete-occurrence 'negative (list H H) H)))
(define K (make-equipped-calculus occurrences))
(define (checked raw)
  (define result (validate-candidate K raw #:expected H))
  (unless (checked-node? result)
    (error 'ordered-ck-test "fixture was not natively checked: ~e" result))
  result)
(define e (checked '(app e)))
(define d (checked '(app d)))
(define r (checked '(app r)))
(define unary (checked '(app u (app e))))
(define branch (checked '(app b (app u (app e)) (app d))))
(define open-branch
  (checked (raw-app 'b (raw-app 'u raw-hole)
                    (raw-app 'b (raw-app 'e) raw-hole))))
(define residual
  (checked '(app positive (app negative (app e) (app d)) (app r))))
(define erased
  (checked '(app positive (app positive (app d) (app e)) (app r))))
(define (word . factors) (make-ordered-forest K factors))
(define one (word))
(define edr (word e d r))
(define der (word d e r))

(test-case "ordered word, additive zero, unit, and native provenance are distinct"
  (check-not-equal? edr der)
  (check-equal? (ordered-forest-concatenate (word e d) (word r)) edr)
  (check-equal? (ordered-forest->commutative edr)
                (ordered-forest->commutative der))
  (check-not-equal? (ordered-zero K) (ordered-unit K))
  (check-equal? (ordered-forest-degree one) 0)
  (check-equal? (ordered-forest-size (word e e)) 2)
  (check-equal? (ordered-forest-degree (word open-branch)) 4)
  (check-exn exn:fail:contract?
             (lambda ()
               (make-ordered-forest K (list (identity-context K H)))))
  (define foreign (make-equipped-calculus occurrences))
  (define foreign-e (validate-candidate foreign '(app e) #:expected H))
  (check-exn exn:fail:contract?
             (lambda () (make-ordered-forest K (list foreign-e))))
  (check-exn exn:fail:contract?
             (lambda ()
               (ordered-sum-add (ordered-node-basis e)
                                (ordered-node-basis foreign-e))))
  (check-exn exn:fail:contract?
             (lambda ()
               (ordered-sum-add (ordered-unit K) (ordered-unit K 2)))))

;; Report generated objects, not RackUnit assertion totals. Each native
;; witness below is generated once by this separately labelled finite oracle.
(define native-witnesses-generated 0)
(define fixed-trees (list e unary branch open-branch residual erased))
(for ([tree (in-list fixed-trees)])
  (test-case "fixed native witness oracle and reconstruction"
    (define whole (word tree))
    (define endpoint (ordered-pure-tensor K (vector whole one)))
    (define witnesses
      (for/list ([witness (in-admissible-cut-witnesses tree)])
        (set! native-witnesses-generated (add1 native-witnesses-generated))
        witness))
    (define oracle
      (for/fold ([result endpoint]) ([witness (in-list witnesses)])
        (check-true (cut-witness? witness))
        (check-true (cut-witness-reconstructs? witness))
        (check-equal? (map detached-entry-address (cut-witness-detached witness))
                      (cut-witness-addresses witness))
        (check-equal? (ordered-forest-factors (ordered-cut-forest witness))
                      (map detached-entry-term (cut-witness-detached witness)))
        (check-true
         (checked-term-has-exact-calculus? (cut-witness-remainder witness) K))
        (ordered-sum-add
         result (ordered-pure-tensor
                 K (vector (ordered-cut-forest witness)
                           (word (cut-witness-remainder witness)))))))
    (check-equal? oracle (ordered-connected-coproduct tree))
    (check-equal? (ordered-sum-coefficient oracle (vector whole one)) 1)
    (check-equal? (ordered-sum-coefficient oracle (vector one whole)) 1)
    (check-equal? (cut-error-code (make-cut-witness tree '(()))) 'root-cut)
    (check-equal?
     (ordered-sum->commutative oracle) (comm:connected-coproduct tree))))

(define fixed-words
  (append (map word fixed-trees) (list one (word e d) (word d e) (word e e))))
(for ([forest (in-list fixed-words)])
  (test-case "finite coassociativity, counit, antipode, and projection checks"
    (define basis (ordered-forest-basis forest))
    (define delta (ordered-forest-coproduct forest))
    (check-equal?
     (ordered-sum-expand-coordinate delta 1 ordered-forest-coproduct)
     (ordered-sum-expand-coordinate delta 2 ordered-forest-coproduct))
    (check-equal? (ordered-tensor-counit-left delta) basis)
    (check-equal? (ordered-tensor-counit-right delta) basis)
    (define counit-unit
      (ordered-sum-scale (ordered-forest-counit forest) (ordered-unit K)))
    (check-equal? (ordered-antipode-convolution-left basis) counit-unit)
    (check-equal? (ordered-antipode-convolution-right basis) counit-unit)
    (check-equal?
     (ordered-sum->commutative (ordered-forest-antipode forest))
     (comm:forest-antipode (ordered-forest->commutative forest)))))

(test-case "bialgebra concatenation and antipode reverse factor order"
  (define A (word unary e))
  (define B (word d))
  (check-equal?
   (ordered-forest-coproduct (ordered-forest-concatenate A B))
   (ordered-sum-multiply (ordered-forest-coproduct A)
                        (ordered-forest-coproduct B)))
  (check-equal?
   (ordered-forest-antipode (ordered-forest-concatenate A B))
   (ordered-sum-multiply (ordered-forest-antipode B)
                        (ordered-forest-antipode A)))
  (check-equal? (ordered-forest-antipode (word e d))
                (ordered-forest-basis (word d e)))
  (define signed
    (ordered-sum-add (ordered-unit K)
                     (ordered-sum-scale -2 (ordered-forest-basis A))))
  (check-equal? (ordered-counit signed) 1)
  (check-equal? (ordered-antipode-convolution-left signed) (ordered-unit K))
  (check-equal? (ordered-antipode-convolution-right signed) (ordered-unit K))
  (check-equal?
   (ordered-sum->commutative
    (ordered-sum-multiply (ordered-forest-basis A) (ordered-forest-basis B)))
   (comm:formal-sum-multiply
    (ordered-sum->commutative (ordered-forest-basis A))
    (ordered-sum->commutative (ordered-forest-basis B)))))

(test-case "orientation erasure coefficient lives only in the ordered carrier"
  (define addresses '((1 1) (1 2) (2)))
  (define source-witness (make-cut-witness residual addresses))
  (define target-witness (make-cut-witness erased addresses))
  (check-true (cut-witness-reconstructs? source-witness))
  (check-true (cut-witness-reconstructs? target-witness))
  (check-equal? (ordered-cut-forest source-witness) edr)
  (check-equal? (ordered-cut-forest target-witness) der)
  ;; f replaces the negative binary constructor by positive while exchanging
  ;; its two physical input slots. On the fully punctured source remainder the
  ;; swapped holes have equal boundary but remain native typed holes.
  (define mapped-source-remainder
    (checked (raw-app 'positive
                      (raw-app 'positive raw-hole raw-hole) raw-hole)))
  (check-equal? mapped-source-remainder (cut-witness-remainder target-witness))
  (define source-key
    (vector edr (word (cut-witness-remainder source-witness))))
  (define target-key (vector edr (word mapped-source-remainder)))
  (define target-delta (ordered-connected-coproduct erased))
  (check-equal?
   (ordered-sum-coefficient (ordered-connected-coproduct residual) source-key) 1)
  (check-equal? (ordered-sum-coefficient target-delta target-key) 0)
  (check-equal?
   (ordered-sum-coefficient target-delta
                            (vector der (word mapped-source-remainder))) 1)
  ;; This coefficient obstruction disappears under the explicit quotient.
  (check-equal?
   (comm:formal-sum-coefficient
    (ordered-sum->commutative target-delta)
    (vector (ordered-forest->commutative edr)
            (ordered-forest->commutative (word mapped-source-remainder)))) 1))

(printf "ordered CK bounded oracle: ~a fixed checked trees, ~a ordered words, ~a native cut witnesses generated; no exhaustive fixture generator\n"
        (length fixed-trees) (length fixed-words) native-witnesses-generated)
