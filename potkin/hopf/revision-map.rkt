#lang racket/base

(require "../algebra/formal-sum.rkt"
         "../kernel/check.rkt"
         "../kernel/cut.rkt"
         "../kernel/deletion.rkt"
         "../kernel/revision.rkt")

(provide formal-revision-map
         formal-revision-map-chain
         revision-map-error?
         revision-map-error-code
         revision-map-error-message
         revision-map-error-operation
         revision-map-error-details)

;; Map failures are values, not additive zero. In particular, wrong source
;; provenance and an unexpected lower-layer result must never silently delete
;; a coefficient from the formal support.
(struct revision-map-error (code message operation details)
  #:transparent)

(define (make-map-error code message details
                        [operation 'formal-revision-map])
  (revision-map-error code message operation details))

(define (support-location-details key coefficient coordinate cause)
  (hash 'support-key key
        'coefficient coefficient
        'coordinate coordinate
        'cause cause))

(define (revision-result-error key coefficient coordinate cause)
  (make-map-error
   'revision-error
   "constructor deletion failed while lifting a retained tensor coordinate"
   (hash-set*
    (support-location-details key coefficient coordinate cause)
    'cause-code (revision-error-code cause)
    'cause-message (revision-error-message cause)
    'cause-details (revision-error-details cause))))

(define (deletion-domain-result-error key coefficient coordinate cause)
  (make-map-error
   'deletion-domain-error
   "a formal support coordinate was outside the constructor-deletion basis domain"
   (hash-set*
    (support-location-details key coefficient coordinate cause)
    'cause-code (deletion-domain-error-code cause)
    'cause-message (deletion-domain-error-message cause)
    'cause-details (deletion-domain-error-details cause))))

(define (unexpected-result-error key coefficient coordinate result reason)
  (make-map-error
   'unexpected-deletion-result
   "constructor deletion returned an unexpected coordinate image"
   (hash-set
    (support-location-details key coefficient coordinate result)
    'reason reason)))

(define killed-support-term (gensym 'killed-support-term))

(define (exact-target-forest? value target)
  (and (proof-forest? value)
       (eq? (proof-forest-calculus value) target)
       (for/and ([factor (in-list (proof-forest-factors value))])
         (checked-term-has-exact-calculus? factor target))))

(define (map-support-key revision key coefficient)
  (define target (calculus-revision-target revision))
  (let loop ([coordinate-index 0]
             [mapped-reversed '()])
    (cond
      [(= coordinate-index (vector-length key))
       (vector->immutable-vector
        (list->vector (reverse mapped-reversed)))]
      [else
       (define coordinate (add1 coordinate-index))
       (define deletion-result
         (constructor-delete revision (vector-ref key coordinate-index)))
       (cond
         ;; One killed coordinate kills the entire ordered tensor monomial.
         ;; No diagnostic algebraic-zero value is retained in formal support.
         [(algebraic-zero? deletion-result) killed-support-term]
         [(revision-error? deletion-result)
          (revision-result-error
           key coefficient coordinate deletion-result)]
         [(deletion-domain-error? deletion-result)
          (deletion-domain-result-error
           key coefficient coordinate deletion-result)]
         [(survivor? deletion-result)
          (define survivor-forest (survivor-value deletion-result))
          (if (exact-target-forest? survivor-forest target)
              (loop (add1 coordinate-index)
                    (cons survivor-forest mapped-reversed))
              (unexpected-result-error
               key
               coefficient
               coordinate
               deletion-result
               'invalid-target-survivor))]
         [else
          (unexpected-result-error
           key
           coefficient
           coordinate
           deletion-result
           'unknown-result-variant)])])))

(define (formal-revision-map revision sum)
  (unless (calculus-revision? revision)
    (raise-argument-error
     'formal-revision-map "calculus-revision?" revision))
  (unless (formal-sum? sum)
    (raise-argument-error 'formal-revision-map "formal-sum?" sum))

  (define source (calculus-revision-source revision))
  (define target (calculus-revision-target revision))
  (define rank (formal-sum-rank sum))
  (cond
    [(not (eq? (formal-sum-calculus sum) source))
     (make-map-error
      'wrong-source-calculus
      "the formal value must carry the exact source calculus of the revision"
      (hash 'expected-source source
            'actual-source (formal-sum-calculus sum)
            'rank rank))]
    ;; Preserve tensor rank and target provenance without visiting any basis
    ;; coordinate. This is both the linear zero law and an important fast path.
    [(formal-zero? sum) (formal-zero target rank)]
    [else
     (let loop ([terms (formal-sum-terms sum)]
                [mapped-terms-reversed '()])
       (cond
         [(null? terms)
          (define rebuilt
            (make-formal-sum
             target rank (reverse mapped-terms-reversed)))
          (if (algebra-error? rebuilt)
              (make-map-error
               'rebuild-error
               "normalizing mapped target support unexpectedly failed"
               (hash 'cause rebuilt
                     'rank rank
                     'mapped-terms (reverse mapped-terms-reversed)))
              rebuilt)]
         [else
          (define term (car terms))
          (define mapped-key
            (map-support-key revision (car term) (cdr term)))
          (cond
            [(revision-map-error? mapped-key) mapped-key]
            [(eq? mapped-key killed-support-term)
             (loop (cdr terms) mapped-terms-reversed)]
            [else
             (loop (cdr terms)
                   (cons (cons mapped-key (cdr term))
                         mapped-terms-reversed))])]))]))

;; Apply a composable revision path one step at a time. In particular, do not
;; flatten the withdrawals and additions: an identity may be absent from an
;; intermediate snapshot and legally reintroduced by a later step. A killed
;; support term therefore becomes formal zero at that intermediate target and
;; remains zero while its exact provenance advances through all later steps.
(define (formal-revision-map-chain chain sum)
  (unless (revision-chain? chain)
    (raise-argument-error
     'formal-revision-map-chain "revision-chain?" chain))
  (unless (formal-sum? sum)
    (raise-argument-error
     'formal-revision-map-chain "formal-sum?" sum))
  (define source (revision-chain-source chain))
  (define rank (formal-sum-rank sum))
  (cond
    [(not (eq? (formal-sum-calculus sum) source))
     (make-map-error
      'wrong-source-calculus
      "the formal value must carry the exact source calculus of the revision chain"
      (hash 'expected-source source
            'actual-source (formal-sum-calculus sum)
            'rank rank)
      'formal-revision-map-chain)]
    [else
     (let loop ([current sum]
                [steps (revision-chain-steps chain)])
       (cond
         [(null? steps) current]
         [else
          (define mapped (formal-revision-map (car steps) current))
          (if (revision-map-error? mapped)
              mapped
              (loop mapped (cdr steps)))]))]))
