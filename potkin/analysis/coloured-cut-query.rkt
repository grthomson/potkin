#lang racket/base

;; Root-colour observations of ordinary CK cuts.
;;
;; Paper proof (PROVED mathematically, not mechanised by this module).  For a
;; nonroot vertex v, an admissible cut in its subtree either selects v, in
;; which case it selects nothing below v, or does not select v, in which case
;; it is a tuple of independent cuts in the ordered child subtrees.  Induction
;; on the checked tree therefore gives
;;
;;   F_v = x_colour(v) + product_w F_w
;;
;; at a coloured vertex and just the product at an uncoloured vertex.
;; Omitting the selection summand at the whole root enforces POTKIN's native
;; prohibition on root cuts.  Removing the unit monomial excludes the empty
;; cut, so the resulting coefficients count proper, nonempty CK cuts.  In a
;; product, intersecting colour supports are discarded; hence every retained
;; monomial is squarefree and counts exactly the cuts whose distinct selected
;; root colours form that support.
;;
;; The recurrence retains one address list for each monomial only long enough
;; to ask `make-cut-witness` for the corresponding native witness.  It does
;; not define a second cut, proof, forest, context, or enumeration.  The work
;; bound makes the whole recurrence inconclusive before exposing a partial
;; polynomial; finite tests are bounded evidence, not the proof above.

(require racket/list
         "../kernel/address.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "ancestry.rkt")

(provide ck-colour-assignment?
         make-ck-colour-assignment
         ck-colour-assignment-calculus
         ck-colour-assignment-entries
         ck-colour-assignment-colours
         ck-colour-assignment-colour-of

         coloured-cut-result?
         coloured-cut-result-source
         coloured-cut-result-assignment
         coloured-cut-result-requested-colours
         coloured-cut-result-polynomial
         coloured-cut-result-coefficient
         coloured-cut-result-witness
         coloured-cut-result-work
         coloured-cut-result-positive?
         coloured-cut-result-detached
         coloured-cut-result-remainder
         query-coloured-ck-cuts)

;; Entries are immutable (colour . exact-occurrence) pairs.  The table is an
;; eq?-keyed certificate: structurally equal foreign occurrences never acquire
;; a colour accidentally.
(struct ck-colour-assignment
  (calculus entries colours occurrence-table colour-ranks)
  #:constructor-name make-ck-colour-assignment/internal
  #:transparent)

(struct coloured-cut-result
  (source assignment requested-colours polynomial coefficient witness work)
  #:constructor-name make-coloured-cut-result/internal
  #:transparent)

;; Internal recurrence entry: an exact coefficient and one representative
;; native address list.  This is polynomial bookkeeping, not a cut carrier.
(struct polynomial-entry (coefficient addresses)
  #:transparent)

(define (exact-registry-occurrence? calculus occurrence)
  (and (concrete-occurrence? occurrence)
       (eq? occurrence
            (calculus-lookup
             calculus
             (concrete-occurrence-id occurrence)))))

(define (make-ck-colour-assignment calculus entries)
  (define who 'make-ck-colour-assignment)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (and (list? entries)
               (for/and ([entry (in-list entries)])
                 (and (pair? entry)
                      (symbol? (car entry))
                      (symbol-interned? (car entry))
                      (concrete-occurrence? (cdr entry)))))
    (raise-argument-error
     who
     "(listof (cons/c interned-symbol? concrete-occurrence?))"
     entries))
  (define occurrences (map cdr entries))
  (define duplicate-occurrence (check-duplicates occurrences eq?))
  (when duplicate-occurrence
    (raise-arguments-error
     who
     "each exact rule occurrence may receive at most one colour"
     "duplicate occurrence" duplicate-occurrence))
  (for ([entry (in-list entries)])
    (unless (exact-registry-occurrence? calculus (cdr entry))
      (raise-arguments-error
       who
       "every colour member must be the exact occurrence stored in this calculus"
       "calculus" calculus
       "colour" (car entry)
       "occurrence" (cdr entry))))
  (define certified-entries
    (for/list ([entry (in-list entries)])
      (cons (car entry) (cdr entry))))
  (define colours (remove-duplicates (map car certified-entries) eq?))
  (make-ck-colour-assignment/internal
   calculus
   certified-entries
   colours
   (for/hasheq ([entry (in-list certified-entries)])
     (values (cdr entry) (car entry)))
   (for/hasheq ([colour (in-list colours)]
                [rank (in-naturals)])
     (values colour rank))))

(define (ck-colour-assignment-colour-of assignment occurrence)
  (unless (ck-colour-assignment? assignment)
    (raise-argument-error
     'ck-colour-assignment-colour-of "ck-colour-assignment?" assignment))
  (unless (concrete-occurrence? occurrence)
    (raise-argument-error
     'ck-colour-assignment-colour-of "concrete-occurrence?" occurrence))
  (hash-ref (ck-colour-assignment-occurrence-table assignment)
            occurrence
            #f))

(define (canonical-colours who assignment colours)
  (unless (and (list? colours)
               (andmap (lambda (colour)
                         (and (symbol? colour) (symbol-interned? colour)))
                       colours))
    (raise-argument-error who "(listof interned-symbol?)" colours))
  (define duplicate (check-duplicates colours eq?))
  (when duplicate
    (raise-arguments-error
     who "requested colours must be distinct" "duplicate colour" duplicate))
  (define ranks (ck-colour-assignment-colour-ranks assignment))
  (for ([colour (in-list colours)])
    (unless (hash-has-key? ranks colour)
      (raise-arguments-error
       who
       "every requested colour must occur in the certified assignment"
       "requested colour" colour
       "assignment colours" (ck-colour-assignment-colours assignment))))
  (sort colours < #:key (lambda (colour) (hash-ref ranks colour))))

(define (monomial-union assignment left right)
  (sort (append left right)
        <
        #:key
        (lambda (colour)
          (hash-ref (ck-colour-assignment-colour-ranks assignment) colour))))

(define (monomial-overlap? left right)
  (for/or ([colour (in-list left)])
    (and (memq colour right) #t)))

(define (polynomial-add-entry polynomial monomial coefficient addresses)
  (define prior (hash-ref polynomial monomial #f))
  (hash-set
   polynomial
   monomial
   (if prior
       (polynomial-entry
        (+ (polynomial-entry-coefficient prior) coefficient)
        (polynomial-entry-addresses prior))
       (polynomial-entry coefficient addresses))))

(define (coloured-cut-result-positive? result)
  (unless (coloured-cut-result? result)
    (raise-argument-error
     'coloured-cut-result-positive? "coloured-cut-result?" result))
  (positive? (coloured-cut-result-coefficient result)))

(define (coloured-cut-result-detached result)
  (unless (coloured-cut-result? result)
    (raise-argument-error
     'coloured-cut-result-detached "coloured-cut-result?" result))
  (define witness (coloured-cut-result-witness result))
  (and witness (cut-witness-detached witness)))

(define (coloured-cut-result-remainder result)
  (unless (coloured-cut-result? result)
    (raise-argument-error
     'coloured-cut-result-remainder "coloured-cut-result?" result))
  (define witness (coloured-cut-result-witness result))
  (and witness (cut-witness-remainder witness)))

(define (query-coloured-ck-cuts
         source assignment requested-colours
         #:limit [limit analysis-default-limit])
  (define who 'query-coloured-ck-cuts)
  (unless (checked-node? source)
    (raise-argument-error who "checked-node?" source))
  (unless (ck-colour-assignment? assignment)
    (raise-argument-error who "ck-colour-assignment?" assignment))
  (unless (exact-nonnegative-integer? limit)
    (raise-argument-error who "exact-nonnegative-integer?" limit))
  (define calculus (ck-colour-assignment-calculus assignment))
  (unless (eq? (checked-term-calculus source) calculus)
    (raise-arguments-error
     who
     "the proof and colour assignment must share one exact calculus snapshot"
     "proof calculus" (checked-term-calculus source)
     "assignment calculus" calculus))
  (define canonical-request
    (canonical-colours who assignment requested-colours))

  (let/ec inconclusive
    (define work 0)
    (define (charge!)
      (set! work (add1 work))
      (when (> work limit)
        (inconclusive
         (analysis-limit
          'not-computed-limit
          "the exact coloured-cut recurrence exceeds its configured work limit"
          who limit work 'squarefree-recurrence-work
          (hash 'requested-colours canonical-request)))))

    (define polynomial-one
      (hash '() (polynomial-entry 1 '())))

    (define (multiply left right)
      (for*/fold ([result (hash)])
                 ([(left-monomial left-entry) (in-hash left)]
                  [(right-monomial right-entry) (in-hash right)])
        (charge!)
        (if (monomial-overlap? left-monomial right-monomial)
            result
            (polynomial-add-entry
             result
             (monomial-union assignment left-monomial right-monomial)
             (* (polynomial-entry-coefficient left-entry)
                (polynomial-entry-coefficient right-entry))
             (sort
              (append (polynomial-entry-addresses left-entry)
                      (polynomial-entry-addresses right-entry))
              address<?)))))

    (define (evaluate node address root?)
      (charge!)
      (unless (checked-node? node)
        (raise-arguments-error
         who
         "the query requires a complete native checked proof"
         "non-proof child address" address
         "child" node))
      (unless (eq? (checked-node-calculus node) calculus)
        (raise-arguments-error
         who
         "every proof node must retain the exact assignment calculus"
         "address" address
         "node calculus" (checked-node-calculus node)
         "assignment calculus" calculus))
      (define occurrence (checked-node-occurrence node))
      (unless (exact-registry-occurrence? calculus occurrence)
        (raise-arguments-error
         who
         "every proof node must retain its exact registered occurrence"
         "address" address
         "occurrence" occurrence))
      (define child-product
        (for/fold ([product polynomial-one])
                  ([child (in-list (checked-node-children node))]
                   [slot (in-naturals 1)])
          (multiply product
                    (evaluate child (append address (list slot)) #f))))
      (define colour
        (ck-colour-assignment-colour-of assignment occurrence))
      (if (and colour (not root?))
          (polynomial-add-entry
           child-product (list colour) 1 (list address))
          child-product))

    (define with-empty (evaluate source root-address #t))
    ;; There is exactly one unit contribution: selecting no coloured vertex.
    ;; Proper cuts are nonempty, so it is not part of the public polynomial.
    (define proper (hash-remove with-empty '()))
    (define polynomial
      (for/hash ([(monomial entry) (in-hash proper)])
        (values monomial (polynomial-entry-coefficient entry))))
    (define selected-entry (hash-ref proper canonical-request #f))
    (define coefficient
      (if selected-entry (polynomial-entry-coefficient selected-entry) 0))
    (define witness
      (and selected-entry
           (make-cut-witness
            source
            (polynomial-entry-addresses selected-entry))))
    (when (cut-error? witness)
      (error who "the recurrence produced a non-native cut: ~e" witness))
    (when witness
      (unless (and (pair? (cut-witness-addresses witness))
                   (eq? (cut-witness-source witness) source)
                   (equal? (map detached-entry-address
                                (cut-witness-detached witness))
                           (cut-witness-addresses witness))
                   (checked-term-has-exact-calculus?
                    (cut-witness-remainder witness) calculus)
                   (cut-witness-reconstructs? witness))
        (error who "native cut witness reconstruction invariant failed")))
    (make-coloured-cut-result/internal
     source assignment canonical-request polynomial coefficient witness work)))
