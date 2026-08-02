#lang racket/base

(require racket/list
         "address.rkt"
         "calculus.rkt"
         "check.rkt"
         "cut.rkt"
         "revision.rkt")

(provide constructor-delete
         survivor?
         survivor-value
         algebraic-zero?
         algebraic-zero-historical-source
         algebraic-zero-offenses
         deletion-domain-error?
         deletion-domain-error-code
         deletion-domain-error-message
         deletion-domain-error-details
         constructor-offense?
         constructor-offense-factor
         constructor-offense-address
         constructor-offense-occurrence
         constructor-offense-occurrence-id
         constructor-offense-multiplicity)

;; These two variants are the basis-level computational image of constructor
;; deletion.  They do not represent formal linear combinations or construct a
;; Hopf quotient: a basis value either lifts intact or its whole monomial is
;; sent to an explicit algebraic zero.
(struct survivor (value)
  #:constructor-name make-survivor/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (survivor? right)
          (recur (survivor-value left) (survivor-value right))))
   (lambda (value recur) (recur (survivor-value value)))
   (lambda (value recur) (recur (survivor-value value)))))

(struct algebraic-zero (historical-source offenses)
  #:constructor-name make-algebraic-zero/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (algebraic-zero? right)
          (recur (algebraic-zero-historical-source left)
                 (algebraic-zero-historical-source right))
          (recur (algebraic-zero-offenses left)
                 (algebraic-zero-offenses right))))
   (lambda (value recur)
     (recur (list (algebraic-zero-historical-source value)
                  (algebraic-zero-offenses value))))
   (lambda (value recur)
     (recur (list (algebraic-zero-offenses value)
                  (algebraic-zero-historical-source value))))))

;; A typed nodeless context is a valid kernel value but not a positive-vertex
;; Hopf basis tree. Keep this domain failure distinct from algebraic zero.
(struct deletion-domain-error (code message details)
  #:constructor-name make-deletion-domain-error/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (deletion-domain-error? right)
          (recur (deletion-domain-error-code left)
                 (deletion-domain-error-code right))
          (recur (deletion-domain-error-message left)
                 (deletion-domain-error-message right))
          (recur (deletion-domain-error-details left)
                 (deletion-domain-error-details right))))
   (lambda (value recur)
     (recur (list (deletion-domain-error-code value)
                  (deletion-domain-error-message value)
                  (deletion-domain-error-details value))))
   (lambda (value recur)
     (recur (list (deletion-domain-error-details value)
                  (deletion-domain-error-message value)
                  (deletion-domain-error-code value))))))

;; Addresses are local to the displayed connected factor.  A connected term
;; is its own factor with multiplicity one.  For a commutative forest, equal
;; factors have one set of local offense records carrying the forest count;
;; no arbitrary occurrence index is imposed on equal forest factors.
(struct constructor-offense (factor address occurrence multiplicity)
  #:constructor-name make-constructor-offense/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (constructor-offense? right)
          (recur (constructor-offense-factor left)
                 (constructor-offense-factor right))
          (recur (constructor-offense-address left)
                 (constructor-offense-address right))
          (recur (constructor-offense-occurrence left)
                 (constructor-offense-occurrence right))
          (recur (constructor-offense-multiplicity left)
                 (constructor-offense-multiplicity right))))
   (lambda (value recur)
     (recur (list (constructor-offense-factor value)
                  (constructor-offense-address value)
                  (constructor-offense-occurrence value)
                  (constructor-offense-multiplicity value))))
   (lambda (value recur)
     (recur (list (constructor-offense-multiplicity value)
                  (constructor-offense-occurrence value)
                  (constructor-offense-address value)
                  (constructor-offense-factor value))))))

(define (constructor-offense-occurrence-id offense)
  (unless (constructor-offense? offense)
    (raise-argument-error
     'constructor-offense-occurrence-id "constructor-offense?" offense))
  (concrete-occurrence-id (constructor-offense-occurrence offense)))

(define (factor-sort-key factor)
  ;; Raw terms contain only symbols and lists, so their printed form gives a
  ;; deterministic total key within one equipped calculus.  Equal raw forms
  ;; cannot denote distinct factors there because occurrence IDs are unique.
  (format "~s" (checked-term->raw factor)))

(define (factor-offenses revision factor multiplicity)
  (define withdrawn-ids (calculus-revision-withdrawn-ids revision))
  ;; Constructor deletion is indexed by exact withdrawn occurrence IDs, not
  ;; by profile or by a best-effort target lookup.  Source provenance and
  ;; historical validity are established before this scan; the revision's
  ;; checked lifting operation performs the corresponding target-liveness
  ;; check for every clean survivor.
  (reverse
   (for/fold ([offenses '()])
             ([address (in-list (sort (vertex-addresses factor) address<?))])
     (define vertex (vertex-at-address factor address))
     (define occurrence (checked-node-occurrence vertex))
     (if (memq (concrete-occurrence-id occurrence) withdrawn-ids)
         (cons
          (make-constructor-offense/internal
           factor address occurrence multiplicity)
          offenses)
         offenses))))

(define (term-offenses revision term)
  (factor-offenses revision term 1))

(define (forest-offenses revision forest)
  (define distinct-factors
    (sort (remove-duplicates (proof-forest-factors forest) equal?)
          string<?
          #:key factor-sort-key))
  (append-map
   (lambda (factor)
     (factor-offenses revision
                      factor
                      (proof-forest-count forest factor)))
   distinct-factors))

(define (basis-calculus value)
  (cond
    [(checked-node? value) (checked-term-calculus value)]
    [(proof-forest? value) (proof-forest-calculus value)]))

(define (propagate-domain-error revision value)
  ;; The lifting operations own the structured diagnostics for wrong source
  ;; provenance and historical invalidity, so deletion returns those same
  ;; revision-error values instead of confusing misuse with algebraic zero.
  (if (checked-node? value)
      (lift-term revision value)
      (lift-proof-forest revision value)))

(define (first-historically-invalid-factor forest)
  (findf (lambda (factor) (not (term-historically-valid? factor)))
         (proof-forest-factors forest)))

(define (constructor-delete revision value)
  (unless (calculus-revision? revision)
    (raise-argument-error
     'constructor-delete "calculus-revision?" revision))
  (unless (or (checked-term? value) (proof-forest? value))
    (raise-argument-error
     'constructor-delete
     "(or/c checked-term? proof-forest?)"
     value))

  (define source (calculus-revision-source revision))
  (cond
    [(checked-hole? value)
     (make-deletion-domain-error/internal
      'not-positive-vertex-basis
      "constructor deletion is defined on positive-vertex checked nodes and proof forests"
      (hash 'value value
            'calculus (checked-term-calculus value)))]
    [(not (eq? (basis-calculus value) source))
     (propagate-domain-error revision value)]
    [(and (checked-node? value)
          (not (term-historically-valid? value)))
     (propagate-domain-error revision value)]
    [(and (proof-forest? value)
          (first-historically-invalid-factor value))
     =>
     (lambda (invalid-factor)
       ;; lift-term checks historical validity before target liveness, so a
       ;; withdrawn vertex elsewhere in the forest cannot mask this error.
       (lift-term revision invalid-factor))]
    [else
     (define offenses
       (if (checked-node? value)
           (term-offenses revision value)
           (forest-offenses revision value)))
     (cond
       [(pair? offenses)
        (make-algebraic-zero/internal value offenses)]
       [else
        (define lifted
          (if (checked-node? value)
              (lift-term revision value)
              (lift-proof-forest revision value)))
        (if (revision-error? lifted)
            lifted
            (make-survivor/internal lifted))])]))
