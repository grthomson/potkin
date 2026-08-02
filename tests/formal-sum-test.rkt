#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "../potkin/algebra.rkt"
         "revision-fixtures.rkt")

(define (key . forests)
  (vector->immutable-vector (list->vector forests)))

(define (check-algebra-error value code operation)
  (cond
    [(algebra-error? value)
     (check-equal? (algebra-error-code value) code)
     (check-equal? (algebra-error-operation value) operation)
     (check-true (string? (algebra-error-message value)))
     (check-false (string=? (algebra-error-message value) ""))
     (check-true (hash? (algebra-error-details value)))
     (check-true (immutable? (algebra-error-details value)))
     ;; These fields may contain arbitrary calculus/rank/coordinate values;
     ;; invoking both accessors here keeps the complete diagnostic API tested.
     (void (algebra-error-expected value)
           (algebra-error-actual value))]
    [else
     (check-true #f
                 (format "expected algebra error ~a from ~a, received ~e"
                         code operation value))])
  (void))

(define (check-exact-sum-provenance sum calculus rank)
  (check-true (formal-sum? sum))
  (when (formal-sum? sum)
    (check-true (eq? (formal-sum-calculus sum) calculus))
    (check-equal? (formal-sum-rank sum) rank)
    (for ([support-key (in-list (formal-sum-support sum))])
      (check-true (immutable? support-key))
      (check-equal? (vector-length support-key) rank)
      (for ([forest (in-vector support-key)])
        (check-true (eq? (proof-forest-calculus forest) calculus))
        (for ([factor (in-list (proof-forest-factors forest))])
          (check-true
           (checked-term-has-exact-calculus? factor calculus)))))))

;; Exact-snapshot fixtures. Presentation equality deliberately omits the
;; provenance distinction that the formal carrier must retain operationally.
(define Kclone
  (make-equipped-calculus (calculus-occurrences K0)))
(define bS/clone
  (validate-candidate Kclone (raw-app 'bS) #:expected S))
(define bS-forest (make-proof-forest K0 (list bS-proof)))
(define bT-forest (make-proof-forest K0 (list bT-proof)))
(define t-forest (make-proof-forest K0 (list t)))
(define empty-forest (empty-proof-forest K0))
(define bS-forest/clone
  (make-proof-forest Kclone (list bS/clone)))

(check-equal? K0 Kclone)
(check-false (eq? K0 Kclone))
(check-equal? bS-forest bS-forest/clone)
(check-false (eq? (proof-forest-calculus bS-forest)
                  (proof-forest-calculus bS-forest/clone)))

;; Formal zero is calculus- and rank-indexed. The algebra unit is instead the
;; empty-forest basis monomial, so it has one nonzero support coefficient.
(define zero (formal-zero K0))
(define zero/clone (formal-zero Kclone))
(define rank-two-zero (tensor-zero K0 2))
(define one (formal-one K0))
(define unit (algebra-unit K0))
(define rank-two-unit (tensor-unit K0 2))

(check-true (formal-zero? zero))
(check-equal? (formal-sum-support-size zero) 0)
(check-equal? (formal-sum-support zero) '())
(check-equal? (formal-sum-terms zero) '())
(check-false (formal-zero? one))
(check-equal? one unit)
(check-false (equal? zero one))
(check-equal? (forest-coefficient one empty-forest) 1)
(check-equal? (forest-coefficient zero empty-forest) 0)
(check-true (rank-one-formal-sum? zero))
(check-false (rank-two-formal-sum? zero))
(check-true (rank-two-formal-sum? rank-two-zero))
(check-false (rank-one-formal-sum? rank-two-zero))
(check-equal? (formal-sum-rank rank-two-unit) 2)
(check-equal? rank-two-unit (formal-one K0 2))
(check-exact-sum-provenance one K0 1)
(check-exact-sum-provenance rank-two-unit K0 2)

;; Custom equality and hashing include eq?-calculus provenance and tensor
;; rank, even when coefficient supports and registries are structural clones.
(check-false (equal? zero zero/clone))
(check-false (equal? zero rank-two-zero))
(define provenance-table (hash zero 'K0 zero/clone 'Kclone))
(define rank-table (hash zero 'rank-one rank-two-zero 'rank-two))
(check-equal? (hash-count provenance-table) 2)
(check-equal? (hash-ref provenance-table zero) 'K0)
(check-equal? (hash-ref provenance-table zero/clone) 'Kclone)
(check-equal? (hash-count rank-table) 2)
(check-equal? (hash-ref rank-table zero) 'rank-one)
(check-equal? (hash-ref rank-table rank-two-zero) 'rank-two)

;; Sparse construction collects duplicate keys over arbitrary-precision exact
;; integers, removes zero coefficients, and copies mutable input keys.
(define huge (+ (expt 2 256) 37))
(define normalized
  (make-formal-sum
   K0
   1
   (list (cons (key bS-forest) huge)
         (cons (key bS-forest) (- huge))
         (cons (key bS-forest) 17)
         (cons (key bT-forest) (- huge))
         (cons (key t-forest) 0))))
(check-equal? (formal-sum-support-size normalized) 2)
(check-equal? (forest-coefficient normalized bS-forest) 17)
(check-equal? (forest-coefficient normalized bT-forest) (- huge))
(check-equal? (forest-coefficient normalized t-forest) 0)
(for ([term (in-list (formal-sum-terms normalized))])
  (check-true (pair? term))
  (check-true (immutable? (car term)))
  (check-true (exact-integer? (cdr term)))
  (check-false (zero? (cdr term))))

(define mutable-input-key (vector bS-forest))
(define copied-input
  (make-formal-sum K0 1 (list (cons mutable-input-key 4))))
(vector-set! mutable-input-key 0 bT-forest)
(check-equal? (forest-coefficient copied-input bS-forest) 4)
(check-equal? (forest-coefficient copied-input bT-forest) 0)
(define exposed-key (first (formal-sum-support copied-input)))
(check-true (immutable? exposed-key))
(check-exn exn:fail:contract?
           (lambda () (vector-set! exposed-key 0 bT-forest)))

(define bS-sum (forest-basis bS-forest))
(define bT-sum (checked-node-basis bT-proof))
(define t-sum (checked-node-basis t))
(check-equal? (checked-node-basis bS-proof) bS-sum)
(check-equal? (forest-coefficient bS-sum bS-forest) 1)
(check-equal?
 (make-formal-sum K0 1
                  (list (cons (key bS-forest) 2)
                        (cons (key bS-forest) -2)))
 zero)
(check-equal?
 (formal-sum-subtract (formal-sum-scale 2 bS-sum)
                      (formal-sum-scale 2 bS-sum))
 zero)

;; Rank-one addition and forest multiplication satisfy the integral
;; commutative-algebra laws on inhomogeneous positive/negative fixtures.
(define x
  (formal-sum-add (formal-sum-scale 2 bS-sum)
                  (formal-sum-scale -3 bT-sum)))
(define y (formal-sum-subtract t-sum bS-sum))
(define z (formal-sum-add one bT-sum))

(check-equal? (formal-sum-scale 1 x) x)
(check-equal? (formal-sum-scale 0 x) zero)
(check-equal? (formal-sum-negate x) (formal-sum-scale -1 x))
(check-equal? (formal-sum-add x (formal-sum-negate x)) zero)
(check-equal? (formal-sum-add x y) (formal-sum-add y x))
(check-equal?
 (formal-sum-add (formal-sum-add x y) z)
 (formal-sum-add x (formal-sum-add y z)))
(check-equal? (formal-sum-multiply one x) x)
(check-equal? (formal-sum-multiply x one) x)
(check-equal? (formal-sum-multiply zero x) zero)
(check-equal? (formal-sum-multiply x zero) zero)
(check-equal? (formal-sum-multiply x y)
              (formal-sum-multiply y x))
(check-equal?
 (formal-sum-multiply (formal-sum-multiply x y) z)
 (formal-sum-multiply x (formal-sum-multiply y z)))
(check-equal?
 (formal-sum-multiply x (formal-sum-add y z))
 (formal-sum-add (formal-sum-multiply x y)
                 (formal-sum-multiply x z)))

(define separate-ST-forest
  (make-proof-forest K0 (list bS-proof bT-proof)))
(define huge-product
  (formal-sum-multiply (formal-sum-scale huge bS-sum)
                       (formal-sum-scale (- huge) bT-sum)))
(check-equal? (forest-coefficient huge-product separate-ST-forest)
              (- (* huge huge)))

;; Repeated equal factors remain multiplicities inside one forest monomial;
;; they are not collapsed into a set or into a scalar coefficient.
(define bS2-forest
  (make-proof-forest K0 (list bS-proof bS-proof)))
(define bS3-forest
  (make-proof-forest K0 (list bS-proof bS-proof bS-proof)))
(check-equal? (proof-forest-count bS2-forest bS-proof) 2)
(check-equal? (proof-forest-count bS3-forest bS-proof) 3)
(check-equal? (formal-sum-multiply bS-sum bS-sum)
              (forest-basis bS2-forest))
(check-equal?
 (formal-sum-multiply (formal-sum-multiply bS-sum bS-sum) bS-sum)
 (forest-basis bS3-forest))

;; Positive-vertex punctured roots are basis trees. Typed nodeless Box values
;; are neither checked nodes nor forests and cannot be basis-injected.
(define m-corolla (corolla K0 m-occ))
(define punctured-forest (make-proof-forest K0 (list m-corolla)))
(define punctured-sum (checked-node-basis m-corolla))
(define Box-S (identity-context K0 S))
(check-true (checked-node? m-corolla))
(check-true (proof-context? m-corolla))
(check-equal? (forest-coefficient punctured-sum punctured-forest) 1)
(check-exact-sum-provenance punctured-sum K0 1)
(check-exn exn:fail:contract? (lambda () (checked-node-basis Box-S)))
(check-exn exn:fail:contract? (lambda () (forest-basis Box-S)))

;; A connected proof with flattened root S|T remains distinct from the forest
;; of independent S and T proofs despite their equal flattened boundaries.
(define connected-m
  (validate-candidate
   K0
   (raw-app 'm (raw-app 'bS) (raw-app 'bT))
   #:expected ST))
(define connected-ST-forest
  (make-proof-forest K0 (list connected-m)))
(check-equal? (forest-flattened-root connected-ST-forest)
              (forest-flattened-root separate-ST-forest))
(check-false
 (equal? (forest-block-root-profile connected-ST-forest)
         (forest-block-root-profile separate-ST-forest)))
(define connected-and-separate
  (formal-sum-add (forest-basis connected-ST-forest)
                  (forest-basis separate-ST-forest)))
(check-equal? (formal-sum-support-size connected-and-separate) 2)
(check-equal? (forest-coefficient connected-and-separate
                                  connected-ST-forest)
              1)
(check-equal? (forest-coefficient connected-and-separate
                                  separate-ST-forest)
              1)
(check-false
 (formal-zero?
  (formal-sum-subtract (forest-basis connected-ST-forest)
                       (forest-basis separate-ST-forest))))

;; Tensor coordinates are ordered, while multiplication is commutative forest
;; union independently in each coordinate.
(define S-tensor-T (pure-tensor K0 (key bS-forest bT-forest)))
(define T-tensor-S (pure-tensor K0 (key bT-forest bS-forest)))
(check-true (rank-two-formal-sum? S-tensor-T))
(check-false (equal? S-tensor-T T-tensor-S))
(check-equal? (formal-sum-coefficient S-tensor-T
                                     (key bS-forest bT-forest))
              1)
(check-equal? (formal-sum-coefficient S-tensor-T
                                     (key bT-forest bS-forest))
              0)
(check-equal?
 (formal-sum-support-size (formal-sum-add S-tensor-T T-tensor-S))
 2)
(define component-product
  (formal-sum-multiply S-tensor-T T-tensor-S))
(check-equal? component-product
              (pure-tensor K0
                           (key separate-ST-forest separate-ST-forest)))
(check-equal? (formal-sum-multiply rank-two-unit S-tensor-T)
              S-tensor-T)
(check-equal?
 (formal-sum-multiply
  (formal-sum-add S-tensor-T T-tensor-S)
  (formal-sum-add rank-two-unit S-tensor-T))
 (formal-sum-add
  (formal-sum-multiply S-tensor-T
                       (formal-sum-add rank-two-unit S-tensor-T))
  (formal-sum-multiply T-tensor-S
                       (formal-sum-add rank-two-unit S-tensor-T))))

;; Coordinate expansion splices an ordered replacement tensor and multiplies
;; source/replacement coefficients. Formal zero never invokes its mapper.
(define (split-with-unit forest)
  (formal-sum-add
   (pure-tensor K0 (key forest empty-forest))
   (pure-tensor K0 (key empty-forest forest))))

(define expanded-first
  (formal-sum-expand-coordinate S-tensor-T 1 2 split-with-unit))
(check-exact-sum-provenance expanded-first K0 3)
(check-equal? (formal-sum-support-size expanded-first) 2)
(check-equal? (formal-sum-coefficient
               expanded-first
               (key bS-forest empty-forest bT-forest))
              1)
(check-equal? (formal-sum-coefficient
               expanded-first
               (key empty-forest bS-forest bT-forest))
              1)

(define expanded-second
  (formal-sum-expand-coordinate S-tensor-T 2 2 split-with-unit))
(check-equal? (formal-sum-coefficient
               expanded-second
               (key bS-forest bT-forest empty-forest))
              1)
(check-equal? (formal-sum-coefficient
               expanded-second
               (key bS-forest empty-forest bT-forest))
              1)

(define weighted-expansion
  (formal-sum-expand-coordinate
   (formal-sum-scale 3 S-tensor-T)
   1
   2
   (lambda (forest)
     (formal-sum-scale -2
                       (pure-tensor K0 (key forest forest))))))
(check-equal? (formal-sum-coefficient
               weighted-expansion
               (key bS-forest bS-forest bT-forest))
              -6)

(define expansion-called? (box #f))
(define expanded-zero
  (formal-sum-expand-coordinate
   rank-two-zero
   1
   2
   (lambda (_forest)
     (set-box! expansion-called? #t)
     (error 'formal-sum-test "zero expansion invoked its mapper"))))
(check-false (unbox expansion-called?))
(check-equal? expanded-zero (tensor-zero K0 3))

;; Coordinate contraction applies an integer functional, preserves the order
;; of remaining coordinates, and normalizes zero coefficients.
(define rank-three-term
  (pure-tensor K0 (key bS-forest bT-forest t-forest)))
(define contracted-middle
  (formal-sum-contract-coordinate
   rank-three-term
   2
   (lambda (forest) (if (equal? forest bT-forest) 5 0))))
(check-equal? contracted-middle
              (formal-sum-scale
               5
               (pure-tensor K0 (key bS-forest t-forest))))
(check-exact-sum-provenance contracted-middle K0 2)

(define counit-like-tensor
  (formal-sum-add
   (formal-sum-scale
    4
    (pure-tensor K0 (key empty-forest bS-forest)))
   (formal-sum-scale
    3
    (pure-tensor K0 (key bT-forest empty-forest)))))
(define (empty-forest-functional forest)
  (if (proof-forest-empty? forest) 1 0))
(check-equal?
 (formal-sum-contract-coordinate
  counit-like-tensor 1 empty-forest-functional)
 (formal-sum-scale 4 bS-sum))
(check-equal?
 (formal-sum-contract-coordinate
  counit-like-tensor 2 empty-forest-functional)
 (formal-sum-scale 3 bT-sum))

(define contraction-called? (box #f))
(define contracted-zero
  (formal-sum-contract-coordinate
   (tensor-zero K0 3)
   2
   (lambda (_forest)
     (set-box! contraction-called? #t)
     (error 'formal-sum-test "zero contraction invoked its functional"))))
(check-false (unbox contraction-called?))
(check-equal? contracted-zero rank-two-zero)

;; Stable semantic incompatibilities are explicit algebra-error values, never
;; formal zero. Cover every documented code and the required cross-snapshot
;; operations, including coefficient lookup and tensor construction.
(define invalid-rank-error (formal-zero K0 0))
(check-algebra-error invalid-rank-error
                     'invalid-rank
                     'formal-zero)
(check-equal? (algebra-error-expected invalid-rank-error)
              'exact-positive-integer)
(check-equal? (algebra-error-actual invalid-rank-error) 0)

(define rank-mismatch-error
  (formal-sum-add zero rank-two-zero))
(check-algebra-error rank-mismatch-error
                     'rank-mismatch
                     'formal-sum-add)
(check-equal? (algebra-error-expected rank-mismatch-error) 1)
(check-equal? (algebra-error-actual rank-mismatch-error) 2)

(define calculus-add-error
  (formal-sum-add zero zero/clone))
(check-algebra-error calculus-add-error
                     'calculus-mismatch
                     'formal-sum-add)
(check-true (eq? (algebra-error-expected calculus-add-error) K0))
(check-true (eq? (algebra-error-actual calculus-add-error) Kclone))
(check-algebra-error
 (formal-sum-multiply bS-sum (forest-basis bS-forest/clone))
 'calculus-mismatch
 'formal-sum-multiply)
(check-algebra-error
 (formal-sum-coefficient bS-sum (key bS-forest/clone))
 'calculus-mismatch
 'formal-sum-coefficient)
(check-algebra-error
 (forest-coefficient bS-sum bS-forest/clone)
 'calculus-mismatch
 'forest-coefficient)
(check-algebra-error
 (pure-tensor K0 (key bS-forest bS-forest/clone))
 'calculus-mismatch
 'pure-tensor)
(check-algebra-error
 (make-formal-sum K0 1 (list (cons (key bS-forest/clone) 1)))
 'calculus-mismatch
 'make-formal-sum)

(check-algebra-error
 (formal-sum-coefficient bS-sum (key bS-forest bT-forest))
 'rank-mismatch
 'formal-sum-coefficient)
(check-algebra-error
 (forest-coefficient rank-two-unit empty-forest)
 'rank-mismatch
 'forest-coefficient)

(check-algebra-error
 (formal-sum-expand-coordinate S-tensor-T 0 2 split-with-unit)
 'coordinate-out-of-range
 'formal-sum-expand-coordinate)
(check-algebra-error
 (formal-sum-contract-coordinate
  S-tensor-T 3 empty-forest-functional)
 'coordinate-out-of-range
 'formal-sum-contract-coordinate)
(check-algebra-error
 (formal-sum-expand-coordinate
  S-tensor-T 1 2 (lambda (_forest) 'not-a-formal-sum))
 'invalid-coordinate-expansion
 'formal-sum-expand-coordinate)
(check-algebra-error
 (formal-sum-contract-coordinate
  S-tensor-T 1 (lambda (_forest) 1/2))
 'invalid-coordinate-contraction
 'formal-sum-contract-coordinate)

;; A mapper's wrong snapshot/rank remains a stable semantic error, while an
;; algebra error returned by a callback is propagated unchanged.
(check-algebra-error
 (formal-sum-expand-coordinate
  S-tensor-T 1 2 (lambda (_forest) (tensor-zero Kclone 2)))
 'calculus-mismatch
 'formal-sum-expand-coordinate)
(check-algebra-error
 (formal-sum-expand-coordinate
  S-tensor-T 1 2 (lambda (_forest) (formal-zero K0 1)))
 'rank-mismatch
 'formal-sum-expand-coordinate)
(check-true
 (eq? (formal-sum-expand-coordinate
       S-tensor-T 1 2 (lambda (_forest) invalid-rank-error))
      invalid-rank-error))
(check-true
 (eq? (formal-sum-contract-coordinate
       S-tensor-T 1 (lambda (_forest) invalid-rank-error))
      invalid-rank-error))
(check-algebra-error
 (formal-sum-contract-coordinate
  bS-sum 1 empty-forest-functional)
 'invalid-rank
 'formal-sum-contract-coordinate)

;; Ordinary host-type misuse remains a contract failure rather than algebraic
;; zero or a structured snapshot/rank/coordinate incompatibility.
(check-exn exn:fail:contract?
           (lambda () (formal-sum-scale 1/2 bS-sum)))
(check-exn exn:fail:contract?
           (lambda ()
             (make-formal-sum
              K0 1 (list (cons (key bS-forest) 1/2)))))
(check-algebra-error (pure-tensor K0 (vector))
                     'invalid-rank
                     'pure-tensor)
