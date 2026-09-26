#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis.rkt")

;; Exact fixture occurrence objects; their names and registered `kind` values
;; intentionally do not determine profile membership.
(define S (singleton-hypersequent '() '(S)))
(define S0 (make-component-incidence '() S '()))

(define a-occ
  (make-concrete-occurrence
   'core-a '() S #:kind 'logical #:tag 'same-looking
   #:instance 'material-leaf #:incidence S0))
(define u-occ
  (make-concrete-occurrence
   'core-u (list S) S #:kind 'logical #:tag 'same-looking
   #:instance 'material-unary #:incidence 'opaque-core-incidence))
(define m-occ
  (make-concrete-occurrence
   'core-m (list S S) S #:kind 'logical #:tag 'same-looking
   #:instance 'material-binary #:incidence 'opaque-core-incidence))
(define x-occ
  (make-concrete-occurrence
   'core-x '() S #:kind 'material #:tag 'same-looking
   #:instance 'extension-leaf #:incidence S0))
(define n-occ
  (make-concrete-occurrence
   'core-n (list S) S #:kind 'material #:tag 'same-looking
   #:instance 'extension-unary #:incidence 'opaque-core-incidence))
(define e-occ
  (make-concrete-occurrence
   'core-e (list S S) S #:kind 'material #:tag 'same-looking
   #:instance 'extension-binary #:incidence 'opaque-core-incidence))

(define occurrences (list a-occ u-occ m-occ x-occ n-occ e-occ))
(define calculus (make-equipped-calculus occurrences))

(define (checked raw #:calculus [registry calculus])
  (define result (validate-candidate registry raw #:expected S))
  (check-false (validation-error? result))
  result)

(define profile
  (make-material-profile calculus (list a-occ u-occ m-occ)))
(define selector (prepare-material-hopf-selector profile))

(define a (checked (raw-app 'core-a)))
(define x (checked (raw-app 'core-x)))
(define ua (checked (raw-app 'core-u (raw-app 'core-a))))
(define na (checked (raw-app 'core-n (raw-app 'core-a))))
(define maa
  (checked (raw-app 'core-m (raw-app 'core-a) (raw-app 'core-a))))
(define eaa
  (checked (raw-app 'core-e (raw-app 'core-a) (raw-app 'core-a))))

(define empty-forest (empty-proof-forest calculus))
(define (singleton term) (make-proof-forest calculus (list term)))
(define a-forest (singleton a))
(define x-forest (singleton x))
(define ua-forest (singleton ua))
(define na-forest (singleton na))
(define maa-forest (singleton maa))
(define eaa-forest (singleton eaa))
(define aa-forest (make-proof-forest calculus (list a a)))

(define (core sum)
  (material-hopf-selector-relative-core selector sum))

;; Independent test oracle: filter the native collected coproduct by rescanning
;; exact occurrence objects, apply the native antipode, then collect explicit
;; forest unions directly with `make-formal-sum`.
(define (oracle-pure? forest)
  (for/and ([factor (in-list (proof-forest-factors forest))])
    (for/and ([address (in-list (vertex-addresses factor))])
      (material-profile-designates?
       profile
       (checked-node-occurrence (vertex-at-address factor address))))))

(define (direct-core-oracle sum)
  (define delta (coproduct sum))
  (make-formal-sum
   calculus 1
   (append-map
    (lambda (delta-term)
      (define delta-key (car delta-term))
      (define delta-coefficient (cdr delta-term))
      (define left (vector-ref delta-key 0))
      (define right (vector-ref delta-key 1))
      (if (oracle-pure? left)
          (for/list ([antipode-term
                      (in-list (formal-sum-terms
                                (forest-antipode left)))])
            (cons
             (vector
              (forest-union
               (vector-ref (car antipode-term) 0)
               right))
             (* delta-coefficient (cdr antipode-term))))
          '()))
    (formal-sum-terms delta))))

(define (eta-epsilon sum)
  (formal-sum-scale (counit sum) (algebra-unit calculus)))

(define (unit-left sum)
  (make-formal-sum
   calculus 2
   (for/list ([term (in-list (formal-sum-terms sum))])
     (cons (vector empty-forest (vector-ref (car term) 0))
           (cdr term)))))

(define (multiply-tensor-coordinates tensor)
  (make-formal-sum
   calculus 1
   (for/list ([term (in-list (formal-sum-terms tensor))])
     (define key (car term))
     (cons (vector (forest-union (vector-ref key 0)
                                 (vector-ref key 1)))
           (cdr term)))))

(define (reconstruct-via-core sum)
  (define rho (material-hopf-selector-coaction selector sum))
  (define right-cored
    (formal-sum-expand-coordinate
     rho 2 1
     (lambda (forest) (core (forest-basis forest)))))
  (multiply-tensor-coordinates right-cored))

;; 1. Native zero and the empty-forest unit remain distinct and are fixed.
(define zero (formal-zero calculus))
(define one (algebra-unit calculus))
(check-false (equal? zero one))
(check-true (formal-zero? zero))
(check-false (formal-zero? one))
(check-equal? (core zero) zero)
(check-equal? (core one) one)

;; 2-3. Positive wholly material elements map to additive zero.  The
;; nontrivial u(a) case traverses a three-term coaction and nonzero antipodes;
;; this is full signed convolution, not an early purity shortcut.
(check-true (formal-zero? (core (checked-node-basis a))))
(define ua-basis (checked-node-basis ua))
(define ua-rho (material-hopf-selector-coaction selector ua-basis))
(check-true (> (formal-sum-support-size ua-rho) 2))
(check-false (formal-zero? (forest-antipode ua-forest)))
(check-true (formal-zero? (core ua-basis)))
(check-equal? (core ua-basis) (direct-core-oracle ua-basis))

;; 4. A nonmaterial nullary proof has only its empty-cut coaction term and is
;; fixed.  Its witness-free whole endpoint is filtered, never made a root cut.
(define x-basis (checked-node-basis x))
(define x-rho (material-hopf-selector-coaction selector x-basis))
(check-equal?
 x-rho
 (pure-tensor calculus (vector empty-forest x-forest)))
(check-equal? (core x-basis) x-basis)
(check-equal?
 (formal-sum-coefficient x-rho (vector x-forest empty-forest))
 0)

;; A pure one-vertex input retains both coproduct endpoints; antipode
;; cancellation makes its core zero.  The whole endpoint is still not a cut.
(define a-rho
  (material-hopf-selector-coaction selector (checked-node-basis a)))
(check-equal? (formal-sum-support-size a-rho) 2)
(check-equal?
 (formal-sum-coefficient a-rho (vector a-forest empty-forest))
 1)
(define root-attempt (make-cut-witness a (list root-address)))
(check-true (cut-error? root-attempt))
(check-equal? (cut-error-code root-attempt) 'root-cut)

;; 5-6. Exact mixed chain t=n(a).  Its native canonical remainder is n(Box),
;; while the algebraic relative core is the signed formal expression
;; t - a*n(Box); these are different objects and different theorems.
(define na-basis (checked-node-basis na))
(define na-witness (make-cut-witness na '((1))))
(check-true (cut-witness? na-witness))
(define n-box (cut-witness-remainder na-witness))
(define n-box-forest (singleton n-box))
(define a-times-n-box (forest-union a-forest n-box-forest))
(define expected-na-rho
  (formal-sum-add
   (pure-tensor calculus (vector empty-forest na-forest))
   (pure-tensor
    calculus (vector (cut-witness-forest na-witness) n-box-forest))))
(define expected-na-core
  (formal-sum-subtract na-basis (forest-basis a-times-n-box)))
(check-equal?
 (material-hopf-selector-coaction selector na-basis)
 expected-na-rho)
(check-equal? (core na-basis) expected-na-core)
(check-equal? (core na-basis) (direct-core-oracle na-basis))
(check-equal?
 (material-hopf-selector-coaction selector expected-na-core)
 (unit-left expected-na-core))
(check-equal? (reconstruct-via-core na-basis) na-basis)
(check-equal? (core (forest-basis n-box-forest))
              (forest-basis n-box-forest))

(define na-slice (make-base-certificate-slice na profile))
(check-equal? (base-certificate-slice-kind na-slice) 'proper)
(check-equal? (base-certificate-slice-remainder na-slice) n-box)
(check-true (checked-term? (base-certificate-slice-remainder na-slice)))
(check-true (formal-sum? expected-na-core))
(check-false (checked-term? expected-na-core))
(check-not-equal? expected-na-core n-box)

;; 7. A branching mixed tree retains every admissible material cut.  The two
;; singleton terms have negative coefficients and the simultaneous term has
;; the positive inclusion-exclusion coefficient.
(define eaa-basis (checked-node-basis eaa))
(define e-left (make-cut-witness eaa '((1))))
(define e-right (make-cut-witness eaa '((2))))
(define e-both (make-cut-witness eaa '((1) (2))))
(for ([witness (in-list (list e-left e-right e-both))])
  (check-true (cut-witness? witness)))
(define (product-with-remainder detached-forest witness)
  (forest-union
   detached-forest
   (singleton (cut-witness-remainder witness))))
(define eaa-expected-core
  (make-formal-sum
   calculus 1
   (list
    (cons (vector eaa-forest) 1)
    (cons (vector (product-with-remainder a-forest e-left)) -1)
    (cons (vector (product-with-remainder a-forest e-right)) -1)
    (cons (vector (product-with-remainder aa-forest e-both)) 1))))
(define eaa-core (core eaa-basis))
(check-equal? eaa-core eaa-expected-core)
(check-equal? eaa-core (direct-core-oracle eaa-basis))
(check-equal? (formal-sum-support-size eaa-core) 4)
(define eaa-slice (make-base-certificate-slice eaa profile))
(check-equal?
 (cut-witness-addresses (base-certificate-slice-witness eaa-slice))
 '((1) (2)))
(check-not-equal? eaa-core
                  (base-certificate-slice-remainder eaa-slice))

;; 8. Multifactor multiplication, repeated occurrences, collected coefficient
;; -2, and negative input coefficients all remain in the native Z-algebra.
(define na-core (core na-basis))
(define na-square-input
  (forest-basis (make-proof-forest calculus (list na na))))
(define na-square-core (core na-square-input))
(check-equal? na-square-core
              (formal-sum-multiply na-core na-core))
(define na-times-a-nbox
  (forest-union na-forest a-times-n-box))
(check-equal? (forest-coefficient na-square-core na-times-a-nbox) -2)

(define na-times-x-input
  (forest-basis (make-proof-forest calculus (list na x))))
(check-equal?
 (core na-times-x-input)
 (formal-sum-multiply na-core x-basis))

(define signed-input
  (formal-sum-add
   (formal-sum-scale -3 na-basis)
   (formal-sum-add
    (formal-sum-scale 2 x-basis)
    ua-basis)))
(define signed-expected
  (formal-sum-add
   (formal-sum-scale -3 expected-na-core)
   (formal-sum-scale 2 x-basis)))
(check-equal? (core signed-input) signed-expected)
(check-equal? (core signed-input) (direct-core-oracle signed-input))

;; Declared generated family: all checked unary trees through vertex degree 2
;; over the two leaves and the material/extension unary constructors.
(define generated-degree-bound 2)
(define generated-raw
  (append
   (list (raw-app 'core-a) (raw-app 'core-x))
   (for*/list ([constructor (in-list '(core-u core-n))]
               [leaf (in-list '(core-a core-x))])
     (raw-app constructor (raw-app leaf)))))
(define generated (map checked generated-raw))
(check-equal? (length generated) 6)
(for ([term (in-list generated)])
  (check-true (<= (derivation-vertex-count term) generated-degree-bound)))
(define generated-bases (map checked-node-basis generated))
(define selected-sums (list signed-input expected-na-core eaa-basis))

;; 9. Every displayed projector/Hopf-module law on the bounded family and
;; selected linear combinations.
(for ([sum (in-list (append generated-bases selected-sums))])
  (define value (core sum))
  (define projected (material-hopf-selector-project selector sum))
  (check-equal? value (direct-core-oracle sum))
  (check-equal? (core projected) (eta-epsilon sum))
  (check-equal? (material-hopf-selector-project selector value)
                (eta-epsilon sum))
  (check-equal? (material-hopf-selector-coaction selector value)
                (unit-left value))
  (check-equal? (core value) value)
  (check-equal? (reconstruct-via-core sum) sum))

(for* ([left (in-list generated-bases)]
       [right (in-list generated-bases)])
  (check-equal?
   (core (formal-sum-multiply left right))
   (formal-sum-multiply (core left) (core right))))

;; 10. Ambient antipode support stays in the selected material sector for
;; every selected left coordinate encountered by the bounded family.
(for ([sum (in-list
            (append generated-bases selected-sums
                    (list na-square-input eaa-basis)))])
  (define rho (material-hopf-selector-coaction selector sum))
  (for ([term (in-list (formal-sum-terms rho))])
    (define left (vector-ref (car term) 0))
    (check-true (oracle-pure? left))
    (define antipode-value (forest-antipode left))
    (for ([antipode-term (in-list (formal-sum-terms antipode-value))])
      (define support-forest (vector-ref (car antipode-term) 0))
      (check-true (oracle-pure? support-forest))
      (check-true
       (material-hopf-selector-forest-pure? selector support-forest)))))

;; 11. Foreign zero, unit and positive basis values are rejected before the
;; coaction or antipode fold begins.
(define foreign-calculus (make-equipped-calculus occurrences))
(define foreign-a
  (checked (raw-app 'core-a) #:calculus foreign-calculus))
(define foreign-values
  (list (formal-zero foreign-calculus)
        (algebra-unit foreign-calculus)
        (checked-node-basis foreign-a)))
(for ([foreign (in-list foreign-values)])
  (check-exn
   exn:fail:contract?
   (lambda ()
     (material-hopf-selector-relative-core selector foreign))))

(define foreign-profile
  (make-material-profile foreign-calculus (list a-occ u-occ m-occ)))
(define foreign-selector (prepare-material-hopf-selector foreign-profile))
(check-exn
 exn:fail:contract?
 (lambda ()
   (material-hopf-selector-relative-core foreign-selector one)))

(printf
 "MATERIAL RELATIVE CORE: ~a generated checked trees through degree ~a; Pi(n(a)) = n(a) - a*n(Box), coinvariance/idempotence/reconstruction/multiplicativity agree with the direct native fold.\n"
 (length generated)
 generated-degree-bound)
