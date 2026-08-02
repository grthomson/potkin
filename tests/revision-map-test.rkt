#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "../potkin/algebra.rkt"
         "../potkin/hopf.rkt"
         "hopf-fixtures.rkt"
         (prefix-in running: "revision-fixtures.rkt"))

(define (key . forests)
  (vector->immutable-vector (list->vector forests)))

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

(define (check-map-error value code)
  (cond
    [(revision-map-error? value)
     (check-equal? (revision-map-error-code value) code)
     (check-equal? (revision-map-error-operation value)
                   'formal-revision-map)
     (check-true (string? (revision-map-error-message value)))
     (check-false (string=? (revision-map-error-message value) ""))
     (check-true (hash? (revision-map-error-details value)))
     (check-true (immutable? (revision-map-error-details value)))]
    [else
     (check-true
      #f
      (format "expected revision-map error ~a, received ~e" code value))])
  (void))

(define g
  (validate-candidate hopf-calculus hopf-g-raw #:expected hopf-S))
(define u-Box
  (validate-candidate
   hopf-calculus (hopf-u-raw raw-hole) #:expected hopf-S))
(define b-Box-Box
  (validate-candidate
   hopf-calculus (hopf-b-raw raw-hole raw-hole) #:expected hopf-S))
(define g-forest (singleton-forest g))
(define u-Box-forest (singleton-forest u-Box))
(define b-Box-Box-forest (singleton-forest b-Box-Box))
(define one/H (empty-proof-forest hopf-calculus))

;; Exact-ID revisions used as independent finite oracles.  The fresh ground
;; has the same boundary profile as g but a globally fresh identity.
(define g-prime-occurrence
  (make-concrete-occurrence
   'g-prime '() hopf-S #:kind 'material #:tag 'ground-prime))
(define addition-only-revision
  (make-calculus-revision hopf-calculus '() (list g-prime-occurrence)))
(define delete-g-revision
  (make-calculus-revision hopf-calculus '(g) '()))
(define delete-u-revision
  (make-calculus-revision hopf-calculus '(u) '()))
(define delete-b-revision
  (make-calculus-revision hopf-calculus '(b) '()))
(define delete-g+u-revision
  (make-calculus-revision hopf-calculus '(g u) '()))
(define delete-all-revision
  (make-calculus-revision hopf-calculus '(g u b) '()))
(define delete-g+add-prime-revision
  (make-calculus-revision
   hopf-calculus '(g) (list g-prime-occurrence)))

(define law-revisions
  (list addition-only-revision
        delete-g-revision
        delete-u-revision
        delete-b-revision
        delete-g+u-revision
        delete-all-revision
        delete-g+add-prime-revision))

(for ([revision (in-list law-revisions)])
  (check-true (calculus-revision? revision))
  (check-true (eq? (calculus-revision-source revision) hopf-calculus))
  (check-false (eq? (calculus-revision-target revision) hopf-calculus)))

;; Zero and the empty-forest unit map at every positive tensor rank without
;; visiting a basis coordinate.  Target identity is operationally exact.
(for* ([revision (in-list law-revisions)]
       [rank (in-list '(1 2 3))])
  (define target (calculus-revision-target revision))
  (define mapped-zero
    (formal-revision-map revision (formal-zero hopf-calculus rank)))
  (check-equal? mapped-zero (formal-zero target rank))
  (check-exact-formal-provenance mapped-zero target rank))

(for ([revision (in-list law-revisions)])
  (define target (calculus-revision-target revision))
  (define mapped-unit
    (formal-revision-map revision (algebra-unit hopf-calculus)))
  (check-equal? mapped-unit (algebra-unit target))
  (check-exact-formal-provenance mapped-unit target 1))

;; Addition-only revision is the persistent inclusion: presentations are
;; unchanged while every coordinate is explicitly recertified in the target.
(define addition-target
  (calculus-revision-target addition-only-revision))
(for ([forest (in-list hopf-forests)])
  (define mapped
    (formal-revision-map addition-only-revision (forest-basis forest)))
  (check-false (formal-zero? mapped))
  (check-exact-formal-provenance mapped addition-target 1)
  (define mapped-forest (vector-ref (car (formal-sum-support mapped)) 0))
  (check-equal? mapped-forest forest)
  (check-equal? (forest-degree mapped-forest) (forest-degree forest)))

;; Rank-two and rank-three mapping is componentwise and retains coordinate
;; order.  Any killed coordinate kills its whole tensor basis monomial.
(define clean-rank-three
  (pure-tensor
   hopf-calculus (key u-Box-forest one/H b-Box-Box-forest)))
(define mapped-clean-rank-three
  (formal-revision-map delete-g-revision clean-rank-three))
(define delete-g-target (calculus-revision-target delete-g-revision))
(define lifted-u-Box
  (survivor-value
   (constructor-delete delete-g-revision u-Box-forest)))
(define lifted-b-Box-Box
  (survivor-value
   (constructor-delete delete-g-revision b-Box-Box-forest)))
(define target-one (empty-proof-forest delete-g-target))
(check-equal?
 mapped-clean-rank-three
 (pure-tensor
  delete-g-target (key lifted-u-Box target-one lifted-b-Box-Box)))
(check-exact-formal-provenance mapped-clean-rank-three delete-g-target 3)

(for ([coordinates
       (in-list
        (list (key g-forest u-Box-forest b-Box-Box-forest)
              (key u-Box-forest g-forest b-Box-Box-forest)
              (key u-Box-forest b-Box-Box-forest g-forest)))])
  (check-equal?
   (formal-revision-map
    delete-g-revision (pure-tensor hopf-calculus coordinates))
   (formal-zero delete-g-target 3)))

(define mixed-rank-two
  (formal-sum-add
   (formal-sum-scale
    5 (pure-tensor hopf-calculus (key g-forest u-Box-forest)))
   (formal-sum-scale
    -3 (pure-tensor hopf-calculus (key u-Box-forest one/H)))))
(check-equal?
 (formal-revision-map delete-g-revision mixed-rank-two)
 (formal-sum-scale
  -3 (pure-tensor delete-g-target (key lifted-u-Box target-one))))

;; Deleting g leaves no nullary constructor and therefore no finite complete
;; S-rooted filler, but the locally admitted open u(Box) corolla survives.
(check-true
 (for/and ([occurrence
            (in-list (calculus-occurrences delete-g-target))])
   (positive? (occurrence-arity occurrence))))
(define mapped-u-Box
  (formal-revision-map delete-g-revision
                       (forest-basis u-Box-forest)))
(check-false (formal-zero? mapped-u-Box))
(check-exact-formal-provenance mapped-u-Box delete-g-target 1)
(define target-u-Box
  (car (proof-forest-factors
        (vector-ref (car (formal-sum-support mapped-u-Box)) 0))))
(check-true (proof-context? target-u-Box))
(check-equal? (checked-term->raw target-u-Box)
              (checked-term->raw u-Box))

;; A fresh same-profile ground is a new target generator, never the image of
;; the withdrawn historical g occurrence.
(define delete+fresh-target
  (calculus-revision-target delete-g+add-prime-revision))
(define g-prime
  (validate-candidate
   delete+fresh-target (raw-app 'g-prime) #:expected hopf-S))
(define g-prime-forest (singleton-forest g-prime))
(check-equal?
 (formal-revision-map delete-g+add-prime-revision
                      (forest-basis g-forest))
 (formal-zero delete+fresh-target))
(check-not-equal? (forest-basis g-prime-forest)
                  (formal-zero delete+fresh-target))

;; The manuscript's running exact-ID deletion is exercised directly as well
;; as by the exhaustive one-colour oracle above. Any displayed forest
;; monomial containing historical bS maps to genuine target formal zero, and
;; every individual tensor term of Delta(t) is killed on at least one side.
(define running-bS-forest
  (make-proof-forest running:K0 (list running:bS-proof)))
(define running-t-forest
  (make-proof-forest running:K0 (list running:t)))
(define running-bad-forests
  (list running-bS-forest
        running-t-forest
        (make-proof-forest
         running:K0 (list running:bS-proof running:bS-proof))
        (make-proof-forest
         running:K0
         (list running:retained-proof running:t running:bT-proof))))
(for ([forest (in-list running-bad-forests)])
  (define image
    (formal-revision-map running:retire-bS-revision
                         (forest-basis forest)))
  (check-equal? image (formal-zero running:K1))
  (check-exact-formal-provenance image running:K1 1))
(for ([delta-term
       (in-list (formal-sum-terms
                 (forest-coproduct running-t-forest)))])
  (define one-tensor-term
    (make-formal-sum
     running:K0 2 (list (cons (car delta-term) (cdr delta-term)))))
  (check-equal?
   (formal-revision-map running:retire-bS-revision one-tensor-term)
   (formal-zero running:K1 2)))
(define running-bS-prime
  (validate-candidate
   running:K1 (raw-app 'bS-prime) #:expected running:S))
(check-equal?
 (formal-revision-map running:retire-bS-revision
                      (forest-basis running-bS-forest))
 (formal-zero running:K1))
(check-false
 (formal-zero?
  (checked-node-basis running-bS-prime)))

;; Deleting every source constructor sends every nonempty bounded basis forest
;; to zero, so an arbitrary finite combination retains only its Z-unit term.
(define all-bounded-sum
  (for/fold ([sum (formal-sum-scale 11
                                   (algebra-unit hopf-calculus))])
            ([forest (in-list (filter-not proof-forest-empty?
                                          hopf-forests))]
             [coefficient (in-naturals 2)])
    (formal-sum-add
     sum (formal-sum-scale coefficient (forest-basis forest)))))
(define delete-all-target
  (calculus-revision-target delete-all-revision))
(check-equal?
 (formal-revision-map delete-all-revision all-bounded-sum)
 (formal-sum-scale 11 (algebra-unit delete-all-target)))
(for ([forest (in-list hopf-forests)])
  (define mapped
    (formal-revision-map delete-all-revision (forest-basis forest)))
  (check-equal?
   mapped
   (if (proof-forest-empty? forest)
       (algebra-unit delete-all-target)
       (formal-zero delete-all-target))))

;; Test-local caches avoid recomputing source CK and antipode values across
;; independent revisions.  Every cache remains scoped to the exact source K.
(define source-delta-cache (make-hash))
(define (source-delta forest)
  (hash-ref! source-delta-cache forest
             (lambda () (forest-coproduct forest))))
(define source-antipode-cache (make-hash))
(define (source-antipode forest)
  (hash-ref! source-antipode-cache forest
             (lambda () (forest-antipode forest))))

(define (check-basis-revision-laws revision forest)
  (define target (calculus-revision-target revision))
  (define source-basis (forest-basis forest))
  (define image (formal-revision-map revision source-basis))
  (check-exact-formal-provenance image target 1)

  ;; Coalgebra, counit, and antipode naturality are exact normalized formal
  ;; equalities, including the case in which this whole basis value is killed.
  (define mapped-delta
    (formal-revision-map revision (source-delta forest)))
  (check-exact-formal-provenance mapped-delta target 2)
  (check-equal? (coproduct image) mapped-delta)
  (check-equal? (counit image) (counit source-basis))
  (define mapped-antipode
    (formal-revision-map revision (source-antipode forest)))
  (check-exact-formal-provenance mapped-antipode target 1)
  (check-equal? (antipode image) mapped-antipode)

  ;; A survivor retains vertex degree; a killed monomial is genuine empty
  ;; support and receives no artificial homogeneous degree.
  (cond
    [(formal-zero? image)
     (check-equal? (formal-sum-support-degrees image) '())]
    [else
     (check-equal? (formal-sum-support-degrees image)
                   (list (forest-degree forest)))
     (check-equal? (formal-sum-homogeneous-degree image)
                   (forest-degree forest))]))

;; All 210 connected roots through degree four and all 92 forests through
;; degree three are checked for seven independent exact-ID revisions.
(define bounded-root-forests
  (for/list ([term (in-list hopf-terms)]) (singleton-forest term)))
(for* ([revision (in-list law-revisions)]
       [forest (in-list bounded-root-forests)])
  (check-basis-revision-laws revision forest))
(for* ([revision (in-list law-revisions)]
       [forest (in-list hopf-forests)])
  (check-basis-revision-laws revision forest))

;; q(xy)=q(x)q(y) for every bounded ordered pair under each deletion profile.
(for* ([revision (in-list law-revisions)]
       [pair (in-list hopf-ordered-forest-pairs)])
  (define left (first pair))
  (define right (second pair))
  (check-equal?
   (formal-revision-map
    revision (forest-basis (forest-union left right)))
   (formal-sum-multiply
    (formal-revision-map revision (forest-basis left))
    (formal-revision-map revision (forest-basis right)))))

;; For every bounded monomial killed by deleting g, each individual collected
;; coproduct tensor basis term is killed in at least one coordinate.  This is
;; the executable coideal witness and does not inspect or reorder coordinates.
(define delete-g-killed-forests
  (filter
   (lambda (forest)
     (formal-zero?
      (formal-revision-map delete-g-revision (forest-basis forest))))
   (append bounded-root-forests hopf-forests)))
(check-true (pair? delete-g-killed-forests))
(for* ([forest (in-list delete-g-killed-forests)]
       [delta-term (in-list (formal-sum-terms (source-delta forest)))])
  (define one-tensor-term
    (make-formal-sum
     hopf-calculus 2 (list (cons (car delta-term) (cdr delta-term)))))
  (check-equal?
   (formal-revision-map delete-g-revision one-tensor-term)
   (formal-zero delete-g-target 2)))

;; Wrong exact source provenance is a stable map error, even for formal zero
;; over a structurally equal target snapshot; it is never interpreted as zero.
(define hopf-calculus-clone
  (make-equipped-calculus (calculus-occurrences hopf-calculus)))
(check-equal? hopf-calculus-clone hopf-calculus)
(check-false (eq? hopf-calculus-clone hopf-calculus))
(define wrong-source
  (formal-revision-map
   delete-g-revision (formal-zero hopf-calculus-clone)))
(check-map-error wrong-source 'wrong-source-calculus)
(check-true
 (eq? (hash-ref (revision-map-error-details wrong-source)
                'expected-source)
      hopf-calculus))
(check-true
 (eq? (hash-ref (revision-map-error-details wrong-source)
                'actual-source)
      hopf-calculus-clone))
