#lang racket/base

(require racket/list
         "../potkin/kernel.rkt")

(provide hopf-S
         hopf-g-occurrence
         hopf-u-occurrence
         hopf-b-occurrence
         hopf-calculus
         hopf-g-raw
         hopf-u-raw
         hopf-b-raw
         hopf-terms-by-degree
         hopf-terms-of-degree
         hopf-terms
         hopf-complete-terms
         hopf-punctured-terms
         hopf-term-counts
         hopf-forest-degree
         hopf-forests-by-degree
         hopf-forests-of-degree
         hopf-forests
         hopf-forest-counts
         hopf-ordered-forest-pairs)

;; A one-colour, locally admitted fixture.  Its deliberately small signature
;; makes exhaustive generation useful while still exercising nullary, unary,
;; binary, complete, and punctured rooted terms.
(define hopf-S (singleton-hypersequent '() '(S)))

(define hopf-g-occurrence
  (make-concrete-occurrence
   'g '() hopf-S #:kind 'material #:tag 'ground))
(define hopf-u-occurrence
  (make-concrete-occurrence
   'u (list hopf-S) hopf-S #:kind 'logical #:tag 'unary))
(define hopf-b-occurrence
  (make-concrete-occurrence
   'b
   (list hopf-S hopf-S)
   hopf-S
   #:kind 'logical
   #:tag 'binary))

(define hopf-calculus
  (make-equipped-calculus
   (list hopf-g-occurrence hopf-u-occurrence hopf-b-occurrence)))

(define hopf-g-raw (raw-app 'g))
(define (hopf-u-raw child) (raw-app 'u child))
(define (hopf-b-raw left right) (raw-app 'b left right))

(define maximum-term-degree 4)

;; Raw degree zero is a child-generation seed only.  It is never exported as
;; a rooted term or inserted into a proof forest.
(define raw-layers (make-vector (add1 maximum-term-degree) '()))
(vector-set! raw-layers 0 (list raw-hole))

(for ([degree (in-range 1 (add1 maximum-term-degree))])
  (define ground-candidates
    (if (= degree 1) (list hopf-g-raw) '()))
  (define unary-candidates
    (for/list ([child (in-list (vector-ref raw-layers (sub1 degree)))])
      (hopf-u-raw child)))
  (define binary-candidates
    (for*/list
        ([left-degree (in-range degree)]
         [left (in-list (vector-ref raw-layers left-degree))]
         [right
          (in-list
           (vector-ref raw-layers
                       (- (sub1 degree) left-degree)))])
      (hopf-b-raw left right)))
  (vector-set!
   raw-layers
   degree
   (remove-duplicates
    (append ground-candidates unary-candidates binary-candidates)
    equal?)))

(define (check-generated candidate degree)
  (define checked
    (validate-candidate hopf-calculus candidate #:expected hopf-S))
  (when (validation-error? checked)
    (error
     'hopf-fixtures
     "generated degree-~a candidate failed validation: ~e; error: ~e"
     degree candidate checked))
  (unless (= (derivation-vertex-count checked) degree)
    (error
     'hopf-fixtures
     "generated candidate has the wrong vertex degree: expected ~a, got ~a"
     degree (derivation-vertex-count checked)))
  checked)

;; The first list has degree one; degree zero is deliberately absent because
;; Box is not a positive-vertex rooted carrier element.
(define hopf-terms-by-degree
  (for/list ([degree (in-range 1 (add1 maximum-term-degree))])
    (remove-duplicates
     (for/list ([candidate (in-list (vector-ref raw-layers degree))])
       (check-generated candidate degree))
     equal?)))

(define (hopf-terms-of-degree degree)
  (unless (and (exact-positive-integer? degree)
               (<= degree maximum-term-degree))
    (raise-arguments-error
     'hopf-terms-of-degree
     "degree must be between 1 and 4"
     "degree" degree))
  (list-ref hopf-terms-by-degree (sub1 degree)))

(define hopf-terms (append* hopf-terms-by-degree))
(define hopf-complete-terms (filter complete-proof? hopf-terms))
(define hopf-punctured-terms (filter proof-context? hopf-terms))
(define hopf-term-counts (map length hopf-terms-by-degree))

(define (hopf-forest-degree forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'hopf-forest-degree "proof-forest?" forest))
  (for/sum ([factor (in-list (proof-forest-factors forest))])
    (derivation-vertex-count factor)))

(define maximum-forest-degree 3)
(define forest-factor-pool
  ;; `hopf-terms` is grouped by increasing degree.  Its list position is only
  ;; test-generator bookkeeping; proof-forest equality remains commutative.
  (list->vector
   (filter (lambda (term)
             (<= (derivation-vertex-count term)
                 maximum-forest-degree))
           hopf-terms)))

;; Enumerate nondecreasing factor indices, which chooses each commutative
;; multiset exactly once while allowing repeated equal factors.
(define (factor-multisets total-degree minimum-index)
  (cond
    [(zero? total-degree) (list '())]
    [else
     (append-map
      (lambda (index)
        (define factor (vector-ref forest-factor-pool index))
        (define factor-degree (derivation-vertex-count factor))
        (if (> factor-degree total-degree)
            '()
            (for/list
                ([remaining
                  (in-list
                   (factor-multisets
                    (- total-degree factor-degree)
                    index))])
              (cons factor remaining))))
      (range minimum-index (vector-length forest-factor-pool)))]))

(define hopf-forests-by-degree
  (for/list ([degree (in-range 0 (add1 maximum-forest-degree))])
    (remove-duplicates
     (for/list ([factors (in-list (factor-multisets degree 0))])
       (make-proof-forest hopf-calculus factors))
     equal?)))

(define (hopf-forests-of-degree degree)
  (unless (and (exact-nonnegative-integer? degree)
               (<= degree maximum-forest-degree))
    (raise-arguments-error
     'hopf-forests-of-degree
     "degree must be between 0 and 3"
     "degree" degree))
  (list-ref hopf-forests-by-degree degree))

(define hopf-forests (append* hopf-forests-by-degree))
(define hopf-forest-counts (map length hopf-forests-by-degree))

;; Ordered pairs are useful for bounded multiplicativity checks.  Tensor or
;; function-input order is retained even though multiplication inside each
;; individual proof forest is commutative.
(define hopf-ordered-forest-pairs
  (for*/list ([left (in-list hopf-forests)]
              [right (in-list hopf-forests)]
              #:when
              (<= (+ (hopf-forest-degree left)
                     (hopf-forest-degree right))
                  maximum-forest-degree))
    (list left right)))

(module+ test
  (require rackunit)

  (check-equal? hopf-term-counts '(3 9 36 162))
  (check-equal? (length hopf-terms) 210)
  (check-equal? (length hopf-complete-terms) 8)
  (check-equal? (length hopf-punctured-terms) 202)
  (check-equal? (+ (length hopf-complete-terms)
                   (length hopf-punctured-terms))
                (length hopf-terms))

  (for* ([degree (in-range 1 (add1 maximum-term-degree))]
         [term (in-list (hopf-terms-of-degree degree))])
    (check-true (checked-node? term))
    (check-true (eq? (checked-term-calculus term) hopf-calculus))
    (check-equal? (derivation-vertex-count term) degree)
    (check-true (or (complete-proof? term) (proof-context? term))))

  (check-equal? hopf-forest-counts '(1 3 15 73))
  (check-equal? (length hopf-forests) 92)
  (check-equal? (length (hopf-forests-of-degree 0)) 1)
  (check-true
   (proof-forest-empty? (car (hopf-forests-of-degree 0))))

  (for* ([degree (in-range 0 (add1 maximum-forest-degree))]
         [forest (in-list (hopf-forests-of-degree degree))])
    (check-true (proof-forest? forest))
    (check-true (eq? (proof-forest-calculus forest) hopf-calculus))
    (check-equal? (hopf-forest-degree forest) degree)
    (for ([factor (in-list (proof-forest-factors forest))])
      (check-true (checked-node? factor))
      (check-true (eq? (checked-term-calculus factor) hopf-calculus))))

  (check-equal? (length hopf-ordered-forest-pairs) 282)
  (for ([pair (in-list hopf-ordered-forest-pairs)])
    (check-equal? (length pair) 2)
    (check-true
     (<= (+ (hopf-forest-degree (first pair))
            (hopf-forest-degree (second pair)))
         maximum-forest-degree))))
