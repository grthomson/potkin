#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "../potkin/algebra.rkt"
         "../potkin/hopf.rkt"
         "revision-fixtures.rkt"
         "hopf-fixtures.rkt")

(define (singleton-forest term)
  (make-proof-forest (checked-term-calculus term) (list term)))

(define (check-exact-formal-provenance sum calculus rank)
  (check-true (formal-sum? sum))
  (when (formal-sum? sum)
    (check-true (eq? (formal-sum-calculus sum) calculus))
    (check-equal? (formal-sum-rank sum) rank)
    (for ([support-key (in-list (formal-sum-support sum))])
      (check-true (immutable? support-key))
      (check-equal? (vector-length support-key) rank)
      (for ([forest (in-vector support-key)])
        (check-true (proof-forest? forest))
        (check-true (eq? (proof-forest-calculus forest) calculus))
        (for ([factor (in-list (proof-forest-factors forest))])
          (check-true
           (checked-term-has-exact-calculus? factor calculus)))))))

(define (check-antipode-error value code operation)
  (cond
    [(antipode-error? value)
     (check-equal? (antipode-error-code value) code)
     (check-equal? (antipode-error-operation value) operation)
     (check-true (string? (antipode-error-message value)))
     (check-false (string=? (antipode-error-message value) ""))
     (check-true (hash? (antipode-error-details value)))
     (check-true (immutable? (antipode-error-details value)))]
    [else
     (check-true
      #f
      (format "expected antipode error ~a from ~a, received ~e"
              code operation value))])
  (void))

(define (unit-after-counit sum)
  (formal-sum-scale
   (counit sum)
   (algebra-unit (formal-sum-calculus sum))))

(define (check-convolution-identities sum)
  (define expected (unit-after-counit sum))
  (check-equal? (antipode-convolution-left sum) expected)
  (check-equal? (antipode-convolution-right sum) expected))

(define (check-degree-preserved forest image)
  (define degree (forest-degree forest))
  (check-equal? (formal-sum-support-degrees image) (list degree))
  (check-equal? (formal-sum-homogeneous-degree image) degree)
  (for ([term (in-list (formal-sum-terms image))])
    (check-equal? (forest-degree (vector-ref (car term) 0)) degree)))

;; Exact connected fixtures.
(define g
  (validate-candidate hopf-calculus hopf-g-raw #:expected hopf-S))
(define u-g
  (validate-candidate
   hopf-calculus (hopf-u-raw hopf-g-raw) #:expected hopf-S))
(define u-Box
  (validate-candidate
   hopf-calculus (hopf-u-raw raw-hole) #:expected hopf-S))
(define g-forest (singleton-forest g))
(define u-g-forest (singleton-forest u-g))
(define u-Box-forest (singleton-forest u-Box))
(define one/H (empty-proof-forest hopf-calculus))
(define g2-forest (make-proof-forest hopf-calculus (list g g)))
(define g3-forest (make-proof-forest hopf-calculus (list g g g)))

;; S(1)=1, primitive positive-vertex roots negate, and repeated primitive
;; factors retain their commutative multiplicity.
(check-equal? (forest-antipode one/H) (algebra-unit hopf-calculus))
(check-equal? (antipode (algebra-unit hopf-calculus))
              (algebra-unit hopf-calculus))
(check-equal? (forest-antipode g-forest)
              (formal-sum-negate (forest-basis g-forest)))
(check-true (proof-context? u-Box))
(check-equal? (derivation-vertex-count u-Box) 1)
(check-equal? (forest-antipode u-Box-forest)
              (formal-sum-negate (forest-basis u-Box-forest)))
(check-equal? (forest-antipode g2-forest) (forest-basis g2-forest))
(check-equal? (forest-antipode g3-forest)
              (formal-sum-negate (forest-basis g3-forest)))

;; S(u(g)) = -u(g) + g join u(Box).  The product is independent forest
;; juxtaposition; it is not a context filling operation.
(define g+u-Box-forest
  (make-proof-forest hopf-calculus (list g u-Box)))
(define expected-S-u-g
  (formal-sum-add
   (formal-sum-negate (forest-basis u-g-forest))
   (forest-basis g+u-Box-forest)))
(check-equal? (forest-antipode u-g-forest) expected-S-u-g)
(check-equal? (antipode (forest-basis u-g-forest)) expected-S-u-g)
(check-equal? (formal-sum-support-size expected-S-u-g) 2)
(check-equal? (forest-coefficient expected-S-u-g u-g-forest) -1)
(check-equal? (forest-coefficient expected-S-u-g g+u-Box-forest) 1)

;; Linear extension handles an inhomogeneous value with positive and negative
;; coefficients.  Convolution returns only its unit coefficient.
(define inhomogeneous
  (formal-sum-add
   (formal-sum-scale 7 (algebra-unit hopf-calculus))
   (formal-sum-add
    (formal-sum-scale 2 (forest-basis g-forest))
    (formal-sum-add
     (formal-sum-scale -3 (forest-basis u-g-forest))
     (formal-sum-scale 5 (forest-basis g2-forest))))))
(define expected-inhomogeneous-antipode
  (formal-sum-add
   (formal-sum-scale 7 (forest-antipode one/H))
   (formal-sum-add
    (formal-sum-scale 2 (forest-antipode g-forest))
    (formal-sum-add
     (formal-sum-scale -3 (forest-antipode u-g-forest))
     (formal-sum-scale 5 (forest-antipode g2-forest))))))
(check-equal? (antipode inhomogeneous)
              expected-inhomogeneous-antipode)
(check-equal? (formal-sum-support-degrees (antipode inhomogeneous))
              '(0 1 2))
(check-convolution-identities inhomogeneous)

;; Complete, punctured, repeated-factor, and running-example values exercise
;; both ordered convolution directions explicitly.
(for ([forest (in-list (list g-forest
                             u-g-forest
                             u-Box-forest
                             g2-forest
                             g3-forest))])
  (check-convolution-identities (forest-basis forest)))
(define t-forest (singleton-forest t))
(check-convolution-identities (forest-basis t-forest))
(check-degree-preserved t-forest (forest-antipode t-forest))
(check-exact-formal-provenance
 (forest-antipode t-forest) K0 1)

;; The bounded connected oracle includes all 210 locally admitted complete
;; and punctured roots through four vertices.  Every antipode is homogeneous
;; of the same degree and is a two-sided convolution inverse.
(for ([term (in-list hopf-terms)])
  (define forest (singleton-forest term))
  (define basis (forest-basis forest))
  (define image (forest-antipode forest))
  (check-exact-formal-provenance image hopf-calculus 1)
  (check-degree-preserved forest image)
  (check-equal? (antipode basis) image)
  (check-convolution-identities basis))

;; Every bounded forest, including the unit and repeated factors, satisfies
;; the same identities.  Commutativity makes S multiplicative, so all 282
;; ordered products through total degree three are checked separately.
(for ([forest (in-list hopf-forests)])
  (define basis (forest-basis forest))
  (define image (forest-antipode forest))
  (check-exact-formal-provenance image hopf-calculus 1)
  (check-degree-preserved forest image)
  (check-equal? (antipode basis) image)
  (check-convolution-identities basis))

(for ([pair (in-list hopf-ordered-forest-pairs)])
  (define left (first pair))
  (define right (second pair))
  (define product (forest-union left right))
  (check-equal?
   (forest-antipode product)
   (formal-sum-multiply (forest-antipode left)
                        (forest-antipode right))))

;; Formal zero is preserved and remains distinct from the unit.  Rank errors
;; are structured values, never zero or an attempted recursion.
(check-equal? (antipode (formal-zero hopf-calculus))
              (formal-zero hopf-calculus))
(check-convolution-identities (formal-zero hopf-calculus))
(define antipode-rank-error
  (antipode (tensor-zero hopf-calculus 2)))
(check-antipode-error antipode-rank-error 'rank-mismatch 'antipode)
(check-equal? (hash-ref (antipode-error-details antipode-rank-error)
                        'expected)
              1)
(check-equal? (hash-ref (antipode-error-details antipode-rank-error)
                        'actual)
              2)
(check-antipode-error
 (antipode-convolution-left (tensor-zero hopf-calculus 2))
 'rank-mismatch
 'antipode-convolution-left)
(check-antipode-error
 (antipode-convolution-right (tensor-zero hopf-calculus 3))
 'rank-mismatch
 'antipode-convolution-right)
