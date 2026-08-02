#lang racket/base

(require racket/list
         rackunit
         "../potkin/algebra.rkt"
         "../potkin/hopf.rkt"
         "../potkin/kernel.rkt"
         "../potkin/analysis/ancestry.rkt"
         "../potkin/analysis/cocycle.rkt"
         "../potkin/analysis/component-trace.rkt"
         "cocycle-fixtures.rkt")

(define (check-grafting-certificate certificate expected-source)
  (check-true (typed-grafting-cocycle-certificate? certificate))
  (when (typed-grafting-cocycle-certificate? certificate)
    (check-equal?
     (typed-grafting-cocycle-certificate-grafted certificate)
     expected-source)
    (check-true
     (typed-grafting-cocycle-certificate-forward-valid? certificate))
    (check-true
     (typed-grafting-cocycle-certificate-reverse-valid? certificate))
    (check-true
     (typed-grafting-cocycle-certificate-witness-bijection? certificate))
    (check-true (typed-grafting-cocycle-certificate-equal? certificate))
    (check-equal?
     (typed-grafting-cocycle-certificate-direct-coproduct certificate)
     (typed-grafting-cocycle-certificate-recursive-coproduct certificate))))

(define (check-protected-certificate certificate)
  (check-true (protected-factorization-certificate? certificate))
  (when (protected-factorization-certificate? certificate)
    (check-true
     (protected-factorization-certificate-cancellation-bijection?
      certificate))
    (check-true
     (protected-factorization-certificate-support-theorem? certificate))
    (check-true
     (protected-factorization-certificate-collected-coefficients-agree?
      certificate))
    (check-equal?
     (protected-factorization-certificate-defect certificate)
     (protected-factorization-certificate-residual-witness-sum
      certificate))))

(define (single-tensor-key tensor)
  (check-true (rank-two-formal-sum? tensor))
  (check-equal? (formal-sum-support-size tensor) 1)
  (car (car (formal-sum-terms tensor))))

(define (check-exact-formal-provenance sum calculus)
  (check-true (formal-sum? sum))
  (when (formal-sum? sum)
    (check-true (eq? (formal-sum-calculus sum) calculus))
    (check-equal? (formal-sum-rank sum) 2)
    (for ([key (in-list (formal-sum-support sum))])
      (for ([forest (in-vector key)])
        (check-true (eq? (proof-forest-calculus forest) calculus))
        (for ([factor (in-list (proof-forest-factors forest))])
          (check-true
           (checked-term-has-exact-calculus? factor calculus)))))))

(define (forward-addresses certificate)
  (for/list
      ([forward
        (in-list
         (typed-grafting-cocycle-certificate-forward-certificates
          certificate))])
    (cut-witness-addresses
     (grafting-choice-certificate-global-witness forward))))

(define (find-forward certificate addresses)
  (findf
   (lambda (forward)
     (equal?
      (cut-witness-addresses
       (grafting-choice-certificate-global-witness forward))
      addresses))
   (typed-grafting-cocycle-certificate-forward-certificates certificate)))

(define (find-cut-record certificate addresses)
  (findf
   (lambda (record)
     (equal? (protected-cut-record-addresses record) addresses))
   (protected-factorization-certificate-cut-records certificate)))

(define (check-address-family actual expected)
  (check-equal? (length actual) (length expected))
  (for ([addresses (in-list expected)])
    (check-not-false (member addresses actual equal?))))

;; Nullary constructor decomposition has one empty tuple below the new root;
;; the separately adjoined whole-tree endpoint is not represented by a root
;; CK cut.
(define nullary-cocycle
  (typed-grafting-cocycle
   cocycle-calculus cocycle-g-occurrence '()))
(check-grafting-certificate nullary-cocycle cocycle-g)
(check-equal?
 (typed-grafting-cocycle-certificate-premise-profile nullary-cocycle)
 '())
(check-equal?
 (typed-grafting-cocycle-certificate-positions nullary-cocycle)
 '())
(check-equal?
 (pointed-input-coaction-certificate-tuple-count
  (typed-grafting-cocycle-certificate-input-coaction nullary-cocycle))
 1)
(check-equal? (forward-addresses nullary-cocycle) '(()))
(check-equal?
 (formal-sum-support-size
  (typed-grafting-cocycle-certificate-direct-coproduct nullary-cocycle))
 2)

;; A formal input hole has one retained choice and is never inserted into a
;; proof forest.  A complete ground has the pointed whole and empty choices.
(define unary-open-cocycle
  (typed-grafting-cocycle
   cocycle-calculus
   cocycle-unary-occurrence
   (list cocycle-box-S)))
(check-grafting-certificate unary-open-cocycle cocycle-u-box)
(check-equal?
 (map pointed-coaction-choice-kind
      (car
       (pointed-input-coaction-certificate-choice-families
        (typed-grafting-cocycle-certificate-input-coaction
         unary-open-cocycle))))
 '(hole))
(check-equal? (forward-addresses unary-open-cocycle) '(()))

(define unary-complete-cocycle
  (typed-grafting-cocycle
   cocycle-calculus
   cocycle-unary-occurrence
   (list cocycle-g)))
(check-grafting-certificate unary-complete-cocycle cocycle-u-g)
(check-equal?
 (map pointed-coaction-choice-kind
      (car
       (pointed-input-coaction-certificate-choice-families
        (typed-grafting-cocycle-certificate-input-coaction
         unary-complete-cocycle))))
 '(whole empty))
(check-address-family
 (forward-addresses unary-complete-cocycle)
 '(() ((1))))

;; Equal S-premises remain distinct ordered positions.  Detaching both equal
;; ground inputs creates one commutative forest containing two occurrences of
;; the same factor; it does not create a false coefficient-two tensor term.
(define binary-equal-cocycle
  (typed-grafting-cocycle
   cocycle-calculus
   cocycle-binary-occurrence
   (list cocycle-g cocycle-g)))
(check-grafting-certificate binary-equal-cocycle cocycle-b-g-g)
(define binary-positions
  (typed-grafting-cocycle-certificate-positions binary-equal-cocycle))
(check-equal? (map pointed-input-position-index binary-positions) '(1 2))
(check-equal?
 (map pointed-input-position-outer-address binary-positions)
 '((1) (2)))
(check-equal?
 (map pointed-input-position-boundary binary-positions)
 (list cocycle-S cocycle-S))
(check-equal?
 (pointed-input-coaction-certificate-tuple-count
  (typed-grafting-cocycle-certificate-input-coaction
   binary-equal-cocycle))
 4)
(check-address-family
 (forward-addresses binary-equal-cocycle)
 '(() ((1)) ((1) (2)) ((2))))

(define both-whole
  (find-forward binary-equal-cocycle '((1) (2))))
(check-true (grafting-choice-certificate? both-whole))
(define repeated-left-forest
  (pointed-choice-tuple-detached-forest
   (grafting-choice-certificate-choice-tuple both-whole)))
(check-equal? (proof-forest-size repeated-left-forest) 2)
(check-equal? (proof-forest-count repeated-left-forest cocycle-g) 2)
(check-equal?
 (grafting-choice-certificate-grafted-remainder both-whole)
 cocycle-b-box-box)
(define both-whole-key
  (single-tensor-key
   (grafting-choice-certificate-tensor both-whole)))
(check-equal?
 (formal-sum-coefficient
  (typed-grafting-cocycle-certificate-direct-coproduct
   binary-equal-cocycle)
  both-whole-key)
 1)

(define left-whole (find-forward binary-equal-cocycle '((1))))
(define right-whole (find-forward binary-equal-cocycle '((2))))
(check-not-equal?
 (grafting-choice-certificate-grafted-remainder left-whole)
 (grafting-choice-certificate-grafted-remainder right-whole))

;; For u(g), constructor recursion gives three pointed choices: whole input,
;; empty cut, or the proper cut at its child.  The binary product is 3*3=9;
;; each tuple has one forward CK witness and each direct witness has one
;; prefix-stripped reverse tuple.
(define binary-product-cocycle
  (typed-grafting-cocycle
   cocycle-calculus
   cocycle-binary-occurrence
   (list cocycle-u-g cocycle-u-g)))
(check-grafting-certificate
 binary-product-cocycle cocycle-b-u-g-u-g)
(define product-input-coaction
  (typed-grafting-cocycle-certificate-input-coaction
   binary-product-cocycle))
(check-equal?
 (map (lambda (family) (map pointed-coaction-choice-kind family))
      (pointed-input-coaction-certificate-choice-families
       product-input-coaction))
 '((whole empty proper) (whole empty proper)))
(check-equal?
 (pointed-input-coaction-certificate-tuple-count product-input-coaction)
 9)
(check-equal?
 (length
  (typed-grafting-cocycle-certificate-forward-certificates
   binary-product-cocycle))
 9)
(check-equal?
 (length
  (typed-grafting-cocycle-certificate-reverse-certificates
   binary-product-cocycle))
 9)
(for ([forward
       (in-list
        (typed-grafting-cocycle-certificate-forward-certificates
         binary-product-cocycle))])
  (define tuple (grafting-choice-certificate-choice-tuple forward))
  (define witness (grafting-choice-certificate-global-witness forward))
  (check-equal? (pointed-choice-tuple-global-addresses tuple)
                (cut-witness-addresses witness))
  (check-true (grafting-choice-certificate-reconstructs? forward))
  (check-true (grafting-choice-certificate-forest-agrees? forward))
  (check-true (grafting-choice-certificate-remainder-agrees? forward)))
(for ([reverse
       (in-list
        (typed-grafting-cocycle-certificate-reverse-certificates
         binary-product-cocycle))])
  (check-not-false
   (grafting-reverse-certificate-matched-forward reverse))
  (check-true
   (grafting-reverse-certificate-addresses-round-trip? reverse))
  (check-true
   (grafting-reverse-certificate-choices-round-trip? reverse)))

;; Opaque component incidence blocks the open component trace, not the typed
;; algebraic equation, which depends only on local constructor admission.
(define opaque-open-cocycle
  (typed-grafting-cocycle
   cocycle-calculus
   cocycle-binary-occurrence
   (list cocycle-box-S cocycle-box-S)))
(check-grafting-certificate opaque-open-cocycle cocycle-b-box-box)
(check-true
 (component-trace-unavailable?
  (component-trace-of
   (typed-grafting-cocycle-certificate-grafted opaque-open-cocycle))))

;; Every one-vertex corolla has zero all-input protected defect.  Its empty
;; cut and all independent whole-input choices are matched explicitly.
(define protected-corolla
  (protected-context-factorization-defect
   (corolla cocycle-calculus cocycle-binary-occurrence)
   (list cocycle-g cocycle-g)
   '(1 2)))
(check-protected-certificate protected-corolla)
(check-true
 (formal-zero?
  (protected-factorization-certificate-defect protected-corolla)))
(check-equal?
 (filter
  (lambda (record)
    (memq (protected-cut-record-disposition record)
          '(residual-fixed-context
            residual-unprotected
            residual-mixed)))
  (protected-factorization-certificate-cut-records protected-corolla))
 '())
(for ([record
       (in-list
        (protected-factorization-certificate-cut-records
         protected-corolla))])
  (check-not-false (protected-cut-record-matching-choice record))
  (check-not-false (protected-cut-record-recovered-choice-tuple record))
  (check-true (protected-cut-record-cancellation-round-trip? record)))

;; The positive multi-vertex context s(x)=i(m(x,b_T)) has exactly the three
;; manuscript residues: fixed m, fixed b_T, and the mixed b_S+b_T cut.
(define running-defect
  (protected-context-factorization-defect
   cocycle-running-context
   (list cocycle-g)
   '(1)))
(check-protected-certificate running-defect)
(check-equal?
 (protected-factorization-certificate-output running-defect)
 cocycle-running-proof)
(check-false
 (formal-zero?
  (protected-factorization-certificate-defect running-defect)))
(define running-residuals
  (filter
   (lambda (record)
     (memq (protected-cut-record-disposition record)
           '(residual-fixed-context
             residual-unprotected
             residual-mixed)))
   (protected-factorization-certificate-cut-records running-defect)))
(check-equal?
 (map protected-cut-record-addresses running-residuals)
 '(((1)) ((1 2)) ((1 1) (1 2))))
(check-equal?
 (map protected-cut-record-disposition running-residuals)
 '(residual-fixed-context residual-fixed-context residual-mixed))
(check-equal? (length running-residuals) 3)
(check-equal?
 (formal-sum-support-size
  (protected-factorization-certificate-defect running-defect))
 3)
(for ([record (in-list running-residuals)])
  (define key (single-tensor-key (protected-cut-record-tensor record)))
  (check-equal?
   (formal-sum-coefficient
    (protected-factorization-certificate-defect running-defect)
    key)
   1))
(check-equal?
 (map protected-cut-record-addresses
      (filter
       (lambda (record)
         (memq (protected-cut-record-disposition record)
               '(cancelled-empty cancelled-protected)))
       (protected-factorization-certificate-cut-records running-defect)))
 '(() ((1 1))))
(check-equal?
 (vertex-origin-kind
  (findf
   (lambda (origin) (equal? (vertex-origin-address origin) '(1 1)))
   (protected-factorization-certificate-vertex-origins running-defect)))
 'protected-input)
(check-equal?
 (vertex-origin-kind
  (findf
   (lambda (origin) (equal? (vertex-origin-address origin) '(1 2)))
   (protected-factorization-certificate-vertex-origins running-defect)))
 'fixed-context)
(define running-mixed
  (find-cut-record running-defect '((1 1) (1 2))))
(check-equal?
 (proof-forest-count
  (cut-witness-forest (protected-cut-record-witness running-mixed))
  cocycle-g)
 1)
(check-equal?
 (proof-forest-count
  (cut-witness-forest (protected-cut-record-witness running-mixed))
  cocycle-t-ground)
 1)

;; Partial protection cancels only the first input's cut family.  Cuts wholly
;; inside the second input remain, as do all combinations touching both.
(define partial-defect
  (protected-context-factorization-defect
   (corolla cocycle-calculus cocycle-binary-occurrence)
   (list cocycle-u-g cocycle-u-g)
   '(1)))
(check-protected-certificate partial-defect)
(check-equal?
 (map protected-cut-record-addresses
      (filter
       (lambda (record)
         (memq (protected-cut-record-disposition record)
               '(cancelled-empty cancelled-protected)))
       (protected-factorization-certificate-cut-records partial-defect)))
 '(() ((1)) ((1 1))))
(check-equal?
 (protected-cut-record-disposition
  (find-cut-record partial-defect '((2))))
 'residual-unprotected)
(check-equal?
 (protected-cut-record-disposition
  (find-cut-record partial-defect '((2 1))))
 'residual-unprotected)
(check-equal?
 (protected-cut-record-disposition
  (find-cut-record partial-defect '((1) (2))))
 'residual-mixed)
(check-equal?
 (count
  (lambda (record)
    (eq? (protected-cut-record-disposition record) 'residual-unprotected))
  (protected-factorization-certificate-cut-records partial-defect))
 2)
(check-equal?
 (count
  (lambda (record)
    (eq? (protected-cut-record-disposition record) 'residual-mixed))
  (protected-factorization-certificate-cut-records partial-defect))
 4)

;; A protected formal hole remains unresolved.  It contributes no vertex and
;; no forest factor; evaluating the other protected input still gives a
;; positive corolla context and zero all-input defect.
(define unresolved-defect
  (protected-context-factorization-defect
   (corolla cocycle-calculus cocycle-binary-occurrence)
   (list cocycle-box-S cocycle-g)
   '(1 2)))
(check-protected-certificate unresolved-defect)
(check-true
 (proof-context?
  (protected-factorization-certificate-output unresolved-defect)))
(check-true
 (formal-zero?
  (protected-factorization-certificate-defect unresolved-defect)))
(check-equal?
 (pointed-input-coaction-certificate-tuple-count
  (protected-factorization-certificate-input-coaction unresolved-defect))
 2)
(check-false
 (findf
  (lambda (origin)
    (address-prefix? '(1) (vertex-origin-address origin)))
  (protected-factorization-certificate-vertex-origins unresolved-defect)))

;; Compatible local contexts have exact finite replacement residues.  The
;; identities are checked in the integral formal tensor rather than inferred
;; from an unimplemented quotient or coideal solver.
(check-equal?
 (premise-telescope cocycle-local-context-0)
 (premise-telescope cocycle-local-context-1))
(check-equal?
 (premise-telescope cocycle-local-context-1)
 (premise-telescope cocycle-local-context-2))
(define identity-residue
  (protected-local-replacement-residue
   cocycle-local-context-0
   cocycle-local-context-0
   (list cocycle-g)
   '(1)))
(check-true (protected-local-residue-certificate? identity-residue))
(check-true
 (formal-zero?
  (protected-local-residue-certificate-residue identity-residue)))
(check-true
 (protected-local-residue-certificate-identity-law? identity-residue))
(check-true
 (protected-local-residue-certificate-antisymmetry-law? identity-residue))

(define forward-residue
  (protected-local-replacement-residue
   cocycle-local-context-0
   cocycle-local-context-1
   (list cocycle-g)
   '(1)))
(check-true (protected-local-residue-certificate? forward-residue))
(check-equal?
 (protected-local-residue-certificate-reverse-residue forward-residue)
 (formal-sum-negate
  (protected-local-residue-certificate-residue forward-residue)))
(check-true
 (protected-local-residue-certificate-identity-law? forward-residue))
(check-true
 (protected-local-residue-certificate-antisymmetry-law? forward-residue))

(define residue-laws
  (protected-local-residue-laws
   cocycle-local-context-0
   cocycle-local-context-1
   cocycle-local-context-2
   (list cocycle-g)
   '(1)))
(check-true (protected-local-residue-laws-certificate? residue-laws))
(check-true
 (protected-local-residue-laws-certificate-identity-law? residue-laws))
(check-true
 (protected-local-residue-laws-certificate-antisymmetry-law? residue-laws))
(check-true
 (protected-local-residue-laws-certificate-telescoping-law? residue-laws))

;; Structural presentation equality does not license a provenance cast.
(check-equal? cocycle-g cocycle-clone-g)
(check-false
 (eq? (checked-term-calculus cocycle-g)
      (checked-term-calculus cocycle-clone-g)))
(define foreign-graft
  (typed-grafting-cocycle
   cocycle-calculus
   cocycle-unary-occurrence
   (list cocycle-clone-g)))
(check-true (analysis-error? foreign-graft))
(check-equal? (analysis-error-code foreign-graft)
              'wrong-calculus-provenance)
(define foreign-protected
  (protected-context-factorization-defect
   (corolla cocycle-calculus cocycle-unary-occurrence)
   (list cocycle-clone-g)
   '(1)))
(check-true (analysis-error? foreign-protected))
(check-equal? (analysis-error-code foreign-protected)
              'wrong-calculus-provenance)

(for ([sum
       (in-list
        (list
         (typed-grafting-cocycle-certificate-direct-coproduct
          binary-product-cocycle)
         (typed-grafting-cocycle-certificate-recursive-coproduct
          binary-product-cocycle)
         (protected-factorization-certificate-defect running-defect)
         (protected-local-residue-certificate-residue forward-residue)))])
  (check-exact-formal-provenance sum cocycle-calculus))

;; Limits are decided by the saturated constructor recurrence before either
;; the Cartesian choice family or the direct cut family is materialised.
(define limited-pointed
  (pointed-input-coaction-choices
   (pointed-input-position 1 '(1) cocycle-S cocycle-u-g)
   #:limit 2))
(check-true (analysis-limit? limited-pointed))
(check-equal? (analysis-limit-metric limited-pointed)
              'pointed-choice-count)
(check-equal?
 (length
  (pointed-input-coaction-choices
   (pointed-input-position 1 '(1) cocycle-S cocycle-u-g)
   #:limit 3))
 3)

(define limited-grafting
  (typed-grafting-cocycle
   cocycle-calculus
   cocycle-binary-occurrence
   (list cocycle-u-g cocycle-u-g)
   #:limit 8))
(check-true (analysis-limit? limited-grafting))
(check-equal? (analysis-limit-metric limited-grafting)
              'grafting-cut-witness-count)
(check-true
 (typed-grafting-cocycle-certificate?
  (typed-grafting-cocycle
   cocycle-calculus
   cocycle-binary-occurrence
   (list cocycle-u-g cocycle-u-g)
   #:limit 9)))

(define limited-protected
  (protected-context-factorization-defect
   (corolla cocycle-calculus cocycle-binary-occurrence)
   (list cocycle-u-g cocycle-u-g)
   '(1)
   #:limit 8))
(check-true (analysis-limit? limited-protected))
(check-equal? (analysis-limit-metric limited-protected)
              'protected-factorization-witness-count)
