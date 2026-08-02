#lang racket/base

(require racket/list
         racket/port
         racket/string
         rackunit
         "../potkin/main.rkt"
         "revision-fixtures.rkt"
         "hopf-fixtures.rkt")

(define running (analyze-derivation t))
(check-true (derivation-analysis? running))
(check-eq? (derivation-analysis-source running) t)
(check-equal? (derivation-analysis-root running) U)
(check-true (derivation-analysis-complete? running))
(check-equal? (derivation-analysis-vertex-count running) 4)
(check-equal? (length (derivation-analysis-vertex-table running)) 4)
(check-equal? (derivation-analysis-puncture-telescope running) '())
(check-equal? (length (derivation-analysis-cut-witnesses running)) 5)
(check-true
 (andmap cut-analysis-reconstructs?
         (derivation-analysis-cut-witnesses running)))
(check-equal?
 (formal-sum-support-size (derivation-analysis-coproduct running))
 6)
(check-equal?
 (formal-sum-support-size (derivation-analysis-reduced-coproduct running))
 4)
(check-equal?
 (formal-sum-support-size (derivation-analysis-root-coaction running))
 5)
(check-equal? (derivation-analysis-degree running) 4)
(check-equal? (derivation-analysis-counit running) 0)
(check-true
 (final-corolla-factorization?
  (derivation-analysis-final-corolla-factorization running)))
(check-equal?
 (derivation-analysis-final-corolla-projection running)
 (final-corolla-projection t))
(check-equal?
 (derivation-analysis-cut-size-polynomial running)
 '#(0 3 1))
(check-equal? (length (derivation-analysis-ancestry-ideals running)) 6)
(check-equal? (derivation-analysis-ancestry-width running) 2)
(check-equal? (derivation-analysis-weak-order-map-count running) 6)
(check-equal? (derivation-analysis-zeta-convolution-power running) 6)
(check-equal? (derivation-analysis-linear-extension-count running) 2)
(check-equal? (derivation-analysis-omega-one-convolution-power running) 2)
(check-equal? (derivation-analysis-refinement-order-count running) 2)
(check-true
 (andmap
  (lambda (order)
    (refinement-order-reconstructs? (premise-ancestry-of t) order))
  (derivation-analysis-refinement-orders running)))

(define running-laws (derivation-analysis-hopf-laws running))
(check-true (hopf-law-analysis? running-laws))
(define running-law-values
  (list
   (hopf-law-analysis-coassociativity running-laws)
   (hopf-law-analysis-counit-left running-laws)
   (hopf-law-analysis-counit-right running-laws)
   (hopf-law-analysis-antipode-left running-laws)
   (hopf-law-analysis-antipode-right running-laws)
   (hopf-law-analysis-coaction-coassociativity running-laws)
   (hopf-law-analysis-coaction-counit running-laws)
   (hopf-law-analysis-zeta-order-map running-laws)
   (hopf-law-analysis-omega-linear-extension running-laws)))
(for ([law (in-list running-law-values)])
  (check-equal? (law-check-status law) 'pass))

(define running-datum (analysis->datum running))
(define running-output
  (with-output-to-string (lambda () (write-analysis running))))
(check-equal?
 running-output
 (with-output-to-string (lambda () (write-analysis running))))
(for ([fragment
       (in-list
        '("(cut-witness-count 5)"
          "(coproduct-support-size 6)"
          "(expression (+ (* 3 q) (expt q 2)))"
          "(nonroot-ancestry-width 2)"
          "(zeta-convolution-power-2 6)"
          "(omega-one-convolution-power-degree 2)"
          "(refinement-history-count 2)"))])
  (check-true (string-contains? running-output fragment)))

;; Hash construction and support traversal never determine presentation.
(define running-delta (connected-coproduct t))
(define reversed-delta
  (make-formal-sum
   K0 2 (reverse (formal-sum-terms running-delta))))
(check-equal? (formal-sum->datum running-delta)
              (formal-sum->datum reversed-delta))
(define forest-ST (make-proof-forest K0 (list bS-proof bT-proof)))
(define forest-TS (make-proof-forest K0 (list bT-proof bS-proof)))
(check-equal? (proof-forest->datum forest-ST)
              (proof-forest->datum forest-TS))

;; A connected binary node remains visibly different from the independent
;; commutative forest of its two immediate premise proofs.
(define m-proof (vertex-at-address t '(1)))
(check-not-equal?
 (proof-forest->datum (make-proof-forest K0 (list m-proof)))
 (proof-forest->datum forest-ST))

;; Tensor coordinates are ordered even though each coordinate is a
;; commutative forest.
(define bS-forest (make-proof-forest K0 (list bS-proof)))
(define bT-forest (make-proof-forest K0 (list bT-proof)))
(check-not-equal?
 (formal-sum->datum (pure-tensor K0 (vector bS-forest bT-forest)))
 (formal-sum->datum (pure-tensor K0 (vector bT-forest bS-forest))))

;; Typed Box, an embedded puncture, the forest unit, and additive zero have
;; pairwise different presentation constructors.
(define Box/S (identity-context K0 S))
(define box-datum (checked-term->datum Box/S))
(define open-datum (checked-term->datum R))
(define unit-datum (proof-forest->datum (empty-proof-forest K0)))
(define zero-datum (formal-sum->datum (formal-zero K0)))
(check-equal? (car box-datum) 'Box)
(check-not-false (member 'hole (flatten open-datum)))
(check-equal? unit-datum '(forest-unit))
(check-equal? zero-datum '(formal-zero (rank 1)))
(check-equal? (length (remove-duplicates
                       (list box-datum unit-datum zero-datum)
                       equal?))
              3)

(define open-report (analyze-context R))
(check-true (context-analysis? open-report))
(check-true (derivation-analysis? (context-analysis-connected open-report)))
(check-false
 (derivation-analysis-complete?
  (context-analysis-connected open-report)))
(check-true
 (analysis-unavailable?
  (derivation-analysis-final-corolla-factorization
   (context-analysis-connected open-report))))
(define box-report (analyze-context Box/S))
(check-true (context-analysis? box-report))
(check-equal? (context-analysis-vertex-count box-report) 0)
(check-true (analysis-unavailable? (context-analysis-connected box-report)))
(check-equal?
 (analysis-unavailable-reason (context-analysis-connected box-report))
 'nodeless-box)

;; Forest analysis covers the algebra unit without reclassifying it as Box.
(define unit-report (analyze-forest (empty-proof-forest K0)))
(check-true (forest-analysis? unit-report))
(check-equal? (forest-analysis-size unit-report) 0)
(check-equal? (forest-analysis-degree unit-report) 0)
(check-equal? (forest-analysis-counit unit-report) 1)
(check-equal?
 (law-check-status
  (hopf-law-analysis-coassociativity
   (forest-analysis-hopf-laws unit-report)))
 'pass)

;; The compound-work preflight blocks rank-three and antipode work even when
;; a chain's first coproduct alone happens to fit the same small limit.
(define chain-ground
  (validate-candidate hopf-calculus hopf-g-raw #:expected hopf-S))
(define chain4
  (validate-candidate
   hopf-calculus
   (hopf-u-raw (hopf-u-raw (hopf-u-raw hopf-g-raw)))
   #:expected hopf-S))
(check-equal? (derivation-vertex-count chain4) 4)
(check-equal?
 (cut-size-polynomial (premise-ancestry-of chain4))
 '#(0 3))
(define chain4/limited (analyze-derivation chain4 #:limit 5))
(check-true (analysis-limit? (derivation-analysis-coproduct chain4/limited)))
(check-true (analysis-limit? (derivation-analysis-antipode chain4/limited)))
(for ([law
       (in-list
        (list
         (hopf-law-analysis-coassociativity
          (derivation-analysis-hopf-laws chain4/limited))
         (hopf-law-analysis-antipode-left
          (derivation-analysis-hopf-laws chain4/limited))
         (hopf-law-analysis-antipode-right
          (derivation-analysis-hopf-laws chain4/limited))))])
  (check-equal? (law-check-status law) 'not-computed))
(check-true
 (string-contains?
  (with-output-to-string (lambda () (write-analysis chain4/limited)))
  "not computed: limit"))

;; Limit reports for commutative forests and formal support are independent
;; of caller construction order.
(define chain4-forest
  (make-proof-forest hopf-calculus (list chain4 chain-ground)))
(define ground-chain4-forest
  (make-proof-forest hopf-calculus (list chain-ground chain4)))
(define limited-forest-report
  (analyze-forest chain4-forest #:limit 5))
(check-equal?
 (analysis->datum limited-forest-report)
 (analysis->datum (analyze-forest ground-chain4-forest #:limit 5)))
(check-equal?
 (law-check-status
  (hopf-law-analysis-coassociativity
   (forest-analysis-hopf-laws limited-forest-report)))
 'not-computed)
(check-equal?
 (law-check-status
  (hopf-law-analysis-coaction-coassociativity
   (forest-analysis-hopf-laws limited-forest-report)))
 'not-applicable)
(check-equal?
 (law-check-status
  (hopf-law-analysis-zeta-order-map
   (forest-analysis-hopf-laws limited-forest-report)))
 'not-applicable)
(define limited-sum-a
  (make-formal-sum
   hopf-calculus 1
   (list (cons (vector chain4-forest) 1)
         (cons (vector (make-proof-forest hopf-calculus
                                         (list chain-ground)))
               1))))
(define limited-sum-b
  (make-formal-sum
   hopf-calculus 1
   (reverse (formal-sum-terms limited-sum-a))))
(check-equal?
 (analysis->datum (check-hopf-laws limited-sum-a #:limit 5))
 (analysis->datum (check-hopf-laws limited-sum-b #:limit 5)))

;; Adversarial immutable metadata contains two structurally equal but
;; identity-distinct eq?-hash keys and both single/double floats.  Complete
;; key/value structural sorting makes reverse insertion render identically.
(define key-a (list 'same-key))
(define key-b (list 'same-key))
(define metadata-a/base
  (hasheq key-a 'z key-b 'a 1.5 'double))
(define metadata-b/base
  (hasheq 1.5 'double key-b 'a key-a 'z))
(define metadata-a
  (if (single-flonum-available?)
      (hash-set metadata-a/base
                (real->single-flonum 1.5) 'single)
      metadata-a/base))
(define metadata-b
  (if (single-flonum-available?)
      (hash-set metadata-b/base
                (real->single-flonum 1.5) 'single)
      metadata-b/base))
(define meta-occ-a
  (make-concrete-occurrence
   'meta '() S #:kind 'material #:tag 'ground #:instance metadata-a))
(define meta-occ-b
  (make-concrete-occurrence
   'meta '() S #:kind 'material #:tag 'ground #:instance metadata-b))
(define meta-K-a (make-equipped-calculus (list meta-occ-a)))
(define meta-K-b (make-equipped-calculus (list meta-occ-b)))
(define meta-proof-a
  (validate-candidate meta-K-a (raw-app 'meta) #:expected S))
(define meta-proof-b
  (validate-candidate meta-K-b (raw-app 'meta) #:expected S))
(check-equal?
 (analysis->datum (analyze-derivation meta-proof-a))
 (analysis->datum (analyze-derivation meta-proof-b)))
(define equal-always-occ
  (make-concrete-occurrence
   'equal-always '() S
   #:kind 'material #:tag 'ground #:instance (hashalw 'x 1)))
(define equal-always-K (make-equipped-calculus (list equal-always-occ)))
(define equal-always-proof
  (validate-candidate
   equal-always-K (raw-app 'equal-always) #:expected S))
(check-not-false
 (member
  'equal-always
  (flatten
   (analysis->datum (analyze-derivation equal-always-proof)))))

;; The public boundary order is numeric/structural, not a formatted-string
;; order (where "10" would incorrectly precede "2").
(check-true (symbolic-datum<? 2 10))
(check-false (symbolic-datum<? 10 2))

;; A small EDSL declaration remains independently accepted by Redex through
;; the shared raw syntax, and its boundary retains displayed multiplicity.
(define-formula-signature Tool-L #:atoms [A])
(define HA2
  (hseq Tool-L
    (seq Tool-L [] => [A])
    (seq Tool-L [] => [A])))
(define-rule-signature Tool-Rules
  [tool-ground #:kind material #:arity 0])
(define-occurrence tool-a
  #:type tool-ground #:instance A #:premises [] #:conclusion HA2)
(define-calculus Tool-K
  #:language Tool-L #:rules Tool-Rules #:occurrences [tool-a])
(define-proof tool-proof #:in Tool-K #:root HA2 tool-a)
(check-true (redex-check? Tool-K (checked-term->raw tool-proof) HA2))
(check-equal? (hypersequent-size HA2) 2)
(define tool-output
  (with-output-to-string
    (lambda () (write-analysis (analyze-derivation tool-proof)))))
(check-true (string-contains? tool-output "(component 1"))
(check-true (string-contains? tool-output "(component 2"))
