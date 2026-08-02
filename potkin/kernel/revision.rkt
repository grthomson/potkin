#lang racket/base

(require racket/list
         "calculus.rkt"
         "check.rkt"
         "context.rkt"
         "cut.rkt")

(provide calculus-revision?
         make-calculus-revision
         identity-calculus-revision
         calculus-revision-source
         calculus-revision-target
         calculus-revision-withdrawn-ids
         calculus-revision-additions
         revision-chain?
         make-revision-chain
         revision-chain-source
         revision-chain-target
         revision-chain-steps
         revision-error?
         revision-error-code
         revision-error-message
         revision-error-details
         liveness-diagnostic?
         liveness-diagnostic-address
         liveness-diagnostic-occurrence
         liveness-diagnostic-classification
         liveness-diagnostic-target-occurrence
         term-historically-valid?
         term-liveness-diagnostics
         term-live-in?
         revision-liveness-diagnostics
         revision-term-live?
         lift-term
         lift-context
         lift-proof-forest
         lift-term-through
         lift-context-through
         lift-proof-forest-through)

;; A revision retains the source registry as historical provenance. Ordinary
;; revision construction creates the exact fresh `(K0 minus D) plus A` target;
;; the separately named identity constructor uses K itself at both endpoints.
;; The representation constructor is private so neither invariant can drift.
(struct calculus-revision (source target withdrawn-ids additions)
  #:constructor-name make-calculus-revision/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (calculus-revision? right)
          (eq? (calculus-revision-source left)
               (calculus-revision-source right))
          (eq? (calculus-revision-target left)
               (calculus-revision-target right))
          (recur (calculus-revision-withdrawn-ids left)
                 (calculus-revision-withdrawn-ids right))
          (recur (calculus-revision-additions left)
                 (calculus-revision-additions right))))
   (lambda (value recur)
     (bitwise-xor
      (eq-hash-code (calculus-revision-source value))
      (arithmetic-shift
       (eq-hash-code (calculus-revision-target value)) 1)
      (arithmetic-shift
       (recur (calculus-revision-withdrawn-ids value)) 2)
      (arithmetic-shift
       (recur (calculus-revision-additions value)) 3)))
   (lambda (value recur)
     (bitwise-xor
      #x6d2b79f5
      (arithmetic-shift
       (eq-hash-code (calculus-revision-source value)) 3)
      (arithmetic-shift
       (eq-hash-code (calculus-revision-target value)) 2)
      (arithmetic-shift
       (recur (calculus-revision-withdrawn-ids value)) 1)
      (recur (calculus-revision-additions value))))))

;; A path retains its exact endpoints and its ordered, immutable step list.
;; Consecutive snapshots are compared by identity, not by their structural
;; registry presentations.
(struct revision-chain (source target steps)
  #:constructor-name make-revision-chain/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (revision-chain? right)
          (eq? (revision-chain-source left)
               (revision-chain-source right))
          (eq? (revision-chain-target left)
               (revision-chain-target right))
          (recur (revision-chain-steps left)
                 (revision-chain-steps right))))
   (lambda (value recur)
     (bitwise-xor
      (eq-hash-code (revision-chain-source value))
      (arithmetic-shift
       (eq-hash-code (revision-chain-target value)) 1)
      (arithmetic-shift (recur (revision-chain-steps value)) 2)))
   (lambda (value recur)
     (bitwise-xor
      #x1b873593
      (arithmetic-shift
       (eq-hash-code (revision-chain-source value)) 2)
      (arithmetic-shift
       (eq-hash-code (revision-chain-target value)) 3)
      (recur (revision-chain-steps value))))))

(struct revision-error (code message details)
  #:constructor-name make-revision-error/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (revision-error? right)
          (recur (revision-error-code left) (revision-error-code right))
          (recur (revision-error-message left) (revision-error-message right))
          (recur (revision-error-details left) (revision-error-details right))))
   (lambda (value recur)
     (recur (list (revision-error-code value)
                  (revision-error-message value)
                  (revision-error-details value))))
   (lambda (value recur)
     (recur (list (revision-error-details value)
                  (revision-error-message value)
                  (revision-error-code value))))))

(struct liveness-diagnostic
  (address occurrence classification target-occurrence)
  #:constructor-name make-liveness-diagnostic/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (liveness-diagnostic? right)
          (recur (liveness-diagnostic-address left)
                 (liveness-diagnostic-address right))
          (recur (liveness-diagnostic-occurrence left)
                 (liveness-diagnostic-occurrence right))
          (recur (liveness-diagnostic-classification left)
                 (liveness-diagnostic-classification right))
          (recur (liveness-diagnostic-target-occurrence left)
                 (liveness-diagnostic-target-occurrence right))))
   (lambda (value recur)
     (recur (list (liveness-diagnostic-address value)
                  (liveness-diagnostic-occurrence value)
                  (liveness-diagnostic-classification value)
                  (liveness-diagnostic-target-occurrence value))))
   (lambda (value recur)
     (recur (list (liveness-diagnostic-target-occurrence value)
                  (liveness-diagnostic-classification value)
                  (liveness-diagnostic-occurrence value)
                  (liveness-diagnostic-address value))))))

(define (make-revision-error code message details)
  (make-revision-error/internal code message details))

(define (interned-symbol? value)
  (and (symbol? value) (symbol-interned? value)))

(define (symbol-id<? left right)
  (string<? (symbol->string left) (symbol->string right)))

(define (canonical-ids ids)
  (for/list ([id (in-list (sort ids symbol-id<?))]) id))

(define (canonical-occurrences occurrences)
  (for/list
      ([occurrence
        (in-list
         (sort occurrences
               symbol-id<?
               #:key concrete-occurrence-id))])
    occurrence))

(define (duplicate-ids ids)
  (define counts
    (for/fold ([result (hasheq)]) ([id (in-list ids)])
      (hash-update result id add1 0)))
  (canonical-ids
   (for/list ([(id count) (in-hash counts)] #:when (> count 1))
     id)))

(define (make-calculus-revision source withdrawn-ids additions)
  (unless (equipped-calculus? source)
    (raise-argument-error
     'make-calculus-revision "equipped-calculus?" source))
  (unless (and (list? withdrawn-ids)
               (andmap interned-symbol? withdrawn-ids))
    (raise-argument-error
     'make-calculus-revision "(listof interned-symbol?)" withdrawn-ids))
  (unless (and (list? additions)
               (andmap concrete-occurrence? additions))
    (raise-argument-error
     'make-calculus-revision "(listof concrete-occurrence?)" additions))

  (define duplicate-withdrawals (duplicate-ids withdrawn-ids))
  (define addition-ids (map concrete-occurrence-id additions))
  (define duplicate-additions (duplicate-ids addition-ids))
  (define canonical-withdrawals (canonical-ids withdrawn-ids))
  (define canonical-additions (canonical-occurrences additions))
  (define missing-withdrawals
    (for/list ([id (in-list canonical-withdrawals)]
               #:unless (calculus-lookup source id))
      id))
  ;; Fresh means fresh relative to all of K0, including the portion withdrawn
  ;; by this same revision.  Thus delete-and-redefine is not a revision.
  (define colliding-additions
    (canonical-ids
     (remove-duplicates
      (for/list ([id (in-list addition-ids)]
                 #:when (calculus-lookup source id))
        id)
      eq?)))

  (cond
    [(pair? duplicate-withdrawals)
     (make-revision-error
      'duplicate-withdrawal
      "withdrawn occurrence identities must be distinct"
      (hash 'duplicate-ids duplicate-withdrawals))]
    [(pair? duplicate-additions)
     (make-revision-error
      'duplicate-addition
      "fresh additions must have distinct occurrence identities"
      (hash 'duplicate-ids duplicate-additions))]
    [(pair? missing-withdrawals)
     (make-revision-error
      'unknown-withdrawal
      "every withdrawn occurrence identity must exist in the source calculus"
      (hash 'unknown-ids missing-withdrawals))]
    [(pair? colliding-additions)
     (make-revision-error
      'nonfresh-addition
      "addition identities must be globally fresh relative to the source calculus"
      (hash 'colliding-ids colliding-additions))]
    [else
     (define withdrawn-set
       (for/hasheq ([id (in-list canonical-withdrawals)])
         (values id #t)))
     (define retained
       (for/list ([occurrence (in-list (calculus-occurrences source))]
                  #:unless
                  (hash-has-key? withdrawn-set
                                 (concrete-occurrence-id occurrence)))
         occurrence))
     ;; make-equipped-calculus always constructs a distinct immutable registry,
     ;; including for an identity revision with empty D and A.
     (define target
       (make-equipped-calculus (append retained canonical-additions)))
     (make-calculus-revision/internal
      source target canonical-withdrawals canonical-additions)]))

;; Unlike `(make-calculus-revision K '() '())`, which deliberately builds a
;; fresh structurally equal target registry, this is the exact identity arrow
;; at K.  It is useful both directly and as a step in a revision chain.
(define (identity-calculus-revision calculus)
  (unless (equipped-calculus? calculus)
    (raise-argument-error
     'identity-calculus-revision "equipped-calculus?" calculus))
  (make-calculus-revision/internal calculus calculus '() '()))

(define (make-revision-chain source steps)
  (unless (equipped-calculus? source)
    (raise-argument-error
     'make-revision-chain "equipped-calculus?" source))
  (unless (and (list? steps) (andmap calculus-revision? steps))
    (raise-argument-error
     'make-revision-chain "(listof calculus-revision?)" steps))
  ;; Copy the spine so the stored finite path is an immutable value owned by
  ;; the chain. Standard Racket lists are immutable, but this also avoids
  ;; retaining an incidental caller list identity.
  (define canonical-steps
    (for/list ([step (in-list steps)]) step))
  (let loop ([remaining canonical-steps]
             [expected-source source]
             [step-index 1])
    (cond
      [(null? remaining)
       (make-revision-chain/internal
        source expected-source canonical-steps)]
      [else
       (define step (car remaining))
       (define actual-source (calculus-revision-source step))
       (if (eq? actual-source expected-source)
           (loop (cdr remaining)
                 (calculus-revision-target step)
                 (add1 step-index))
           (make-revision-error
            'noncomposable-revision-chain
            "every revision step must start at the exact target snapshot of its predecessor"
            (hash 'operation 'make-revision-chain
                  'chain-source source
                  'step-index step-index
                  'step step
                  'expected-source expected-source
                  'actual-source actual-source)))])))

;; Checked constructors are private, but historical validity is still checked
;; explicitly: every stored provenance must be the same registry, and replaying
;; the shared raw presentation in that registry must recover the same term.
(define (uniform-provenance? term source)
  (and (eq? (checked-term-calculus term) source)
       (or (checked-hole? term)
           (andmap (lambda (child) (uniform-provenance? child source))
                   (checked-node-children term)))))

(define (term-historically-valid? term)
  (and
   (checked-term? term)
   (let* ([source (checked-term-calculus term)]
          [replayed
           (and (uniform-provenance? term source)
                (validate-candidate
                 source
                 (checked-term->raw term)
                 #:expected (derivation-root-boundary term)))])
     (and (validation-success? replayed)
          (equal? replayed term)))))

(define (check-retired-ids who retired-ids)
  (unless (and (list? retired-ids) (andmap interned-symbol? retired-ids))
    (raise-argument-error who "(listof interned-symbol?)" retired-ids)))

;; Liveness is vertexwise exact admission.  Punctures are typed vacancies, not
;; vertices, so they never produce liveness diagnostics.
(define (term-liveness-diagnostics target term
                                   #:retired-ids [retired-ids '()])
  (unless (equipped-calculus? target)
    (raise-argument-error
     'term-liveness-diagnostics "equipped-calculus?" target))
  (unless (checked-term? term)
    (raise-argument-error
     'term-liveness-diagnostics "checked-term?" term))
  (check-retired-ids 'term-liveness-diagnostics retired-ids)
  (define retired-set
    (for/hasheq ([id (in-list retired-ids)]) (values id #t)))

  (define (walk current address)
    (cond
      [(checked-hole? current) '()]
      [else
       (define occurrence (checked-node-occurrence current))
       (define id (concrete-occurrence-id occurrence))
       (define target-occurrence (calculus-lookup target id))
       (define here
         (cond
           [(equal? occurrence target-occurrence) '()]
           [else
            (define classification
              (cond
                [target-occurrence 'incompatible/redefined]
                [(hash-has-key? retired-set id) 'retired]
                [else 'unknown]))
            (list
             (make-liveness-diagnostic/internal
              address occurrence classification target-occurrence))]))
       (append
        here
        (append-map
         (lambda (slot+child)
           (walk (cdr slot+child)
                 (append address (list (car slot+child)))))
         (for/list ([child (in-list (checked-node-children current))]
                    [slot (in-naturals 1)])
           (cons slot child))))]))

  (walk term '()))

(define (term-live-in? target term #:retired-ids [retired-ids '()])
  (null? (term-liveness-diagnostics
          target term #:retired-ids retired-ids)))

(define (revision-liveness-diagnostics revision term)
  (unless (calculus-revision? revision)
    (raise-argument-error
     'revision-liveness-diagnostics "calculus-revision?" revision))
  (unless (checked-term? term)
    (raise-argument-error
     'revision-liveness-diagnostics "checked-term?" term))
  (term-liveness-diagnostics
   (calculus-revision-target revision)
   term
   #:retired-ids (calculus-revision-withdrawn-ids revision)))

(define (revision-term-live? revision term)
  (null? (revision-liveness-diagnostics revision term)))

(define (wrong-exact-source-error operation expected actual)
  (make-revision-error
   'wrong-source-calculus
   "the value must carry the exact source registry of this revision path"
   (hash 'operation operation
         'expected-source expected
         'actual-source actual)))

(define (wrong-source-error operation revision actual)
  (make-revision-error
   'wrong-source-calculus
   "the value must carry the exact source registry of this revision"
   (hash 'operation operation
         'expected-source (calculus-revision-source revision)
         'actual-source actual)))

(define (lift-term revision term)
  (unless (calculus-revision? revision)
    (raise-argument-error 'lift-term "calculus-revision?" revision))
  (unless (checked-term? term)
    (raise-argument-error 'lift-term "checked-term?" term))
  (define source (calculus-revision-source revision))
  (cond
    [(not (eq? (checked-term-calculus term) source))
     (wrong-source-error 'lift-term revision (checked-term-calculus term))]
    [(not (term-historically-valid? term))
     (make-revision-error
      'historically-invalid
      "the checked term is not valid under its stored source provenance"
      (hash 'term term))]
    [else
     (define diagnostics (revision-liveness-diagnostics revision term))
     (cond
       [(pair? diagnostics)
        (make-revision-error
         'inactive-occurrences
         "every retained vertex must be admitted unchanged by the target calculus"
         (hash 'diagnostics diagnostics))]
       [else
        (define lifted
          (validate-candidate
           (calculus-revision-target revision)
           (checked-term->raw term)
           #:expected (derivation-root-boundary term)))
        (if (validation-error? lifted)
            (make-revision-error
             'revalidation-failed
             "revalidating a live term under the target calculus failed"
             (hash 'validation-error lifted))
            lifted)])]))

(define (lift-context revision context)
  (unless (calculus-revision? revision)
    (raise-argument-error 'lift-context "calculus-revision?" revision))
  (unless (checked-term? context)
    (raise-argument-error 'lift-context "checked-term?" context))
  (cond
    [(not (proof-context? context))
     (make-revision-error
      'not-context
      "context lifting requires a well-typed checked term with a puncture"
      (hash 'term context))]
    [else
     (define lifted (lift-term revision context))
     (cond
       [(revision-error? lifted) lifted]
       [(proof-context? lifted) lifted]
       [else
        (make-revision-error
         'revalidation-failed
         "lifting unexpectedly changed an open context into a complete proof"
         (hash 'lifted-term lifted))])]))

(define (lift-proof-forest revision forest)
  (unless (calculus-revision? revision)
    (raise-argument-error 'lift-proof-forest "calculus-revision?" revision))
  (unless (proof-forest? forest)
    (raise-argument-error 'lift-proof-forest "proof-forest?" forest))
  (define source (calculus-revision-source revision))
  (cond
    [(not (eq? (proof-forest-calculus forest) source))
     (wrong-source-error
      'lift-proof-forest revision (proof-forest-calculus forest))]
    [else
     (define lifted-factors
       (for/list ([factor (in-list (proof-forest-factors forest))])
         (lift-term revision factor)))
     (define failed (findf revision-error? lifted-factors))
     (if failed
         failed
         (make-proof-forest
          (calculus-revision-target revision)
          lifted-factors))]))

;; Through-lifts are the executable action of a finite revision path.  Empty
;; chains return their input unchanged after the exact source check; nonempty
;; chains deliberately use the public one-step lifting operations in order.
(define (lift-term-through chain term)
  (unless (revision-chain? chain)
    (raise-argument-error
     'lift-term-through "revision-chain?" chain))
  (unless (checked-term? term)
    (raise-argument-error 'lift-term-through "checked-term?" term))
  (cond
    [(not (eq? (checked-term-calculus term)
               (revision-chain-source chain)))
     (wrong-exact-source-error
      'lift-term-through
      (revision-chain-source chain)
      (checked-term-calculus term))]
    [else
     (let loop ([current term]
                [steps (revision-chain-steps chain)])
       (cond
         [(null? steps) current]
         [else
          (define lifted (lift-term (car steps) current))
          (if (revision-error? lifted)
              lifted
              (loop lifted (cdr steps)))]))]))

(define (lift-context-through chain context)
  (unless (revision-chain? chain)
    (raise-argument-error
     'lift-context-through "revision-chain?" chain))
  (unless (checked-term? context)
    (raise-argument-error
     'lift-context-through "checked-term?" context))
  (cond
    [(not (proof-context? context))
     (make-revision-error
      'not-context
      "context lifting through a path requires a well-typed checked term with a puncture"
      (hash 'operation 'lift-context-through
            'term context))]
    [(not (eq? (checked-term-calculus context)
               (revision-chain-source chain)))
     (wrong-exact-source-error
      'lift-context-through
      (revision-chain-source chain)
      (checked-term-calculus context))]
    [else
     (let loop ([current context]
                [steps (revision-chain-steps chain)])
       (cond
         [(null? steps) current]
         [else
          (define lifted (lift-context (car steps) current))
          (if (revision-error? lifted)
              lifted
              (loop lifted (cdr steps)))]))]))

(define (lift-proof-forest-through chain forest)
  (unless (revision-chain? chain)
    (raise-argument-error
     'lift-proof-forest-through "revision-chain?" chain))
  (unless (proof-forest? forest)
    (raise-argument-error
     'lift-proof-forest-through "proof-forest?" forest))
  (cond
    [(not (eq? (proof-forest-calculus forest)
               (revision-chain-source chain)))
     (wrong-exact-source-error
      'lift-proof-forest-through
      (revision-chain-source chain)
      (proof-forest-calculus forest))]
    [else
     (let loop ([current forest]
                [steps (revision-chain-steps chain)])
       (cond
         [(null? steps) current]
         [else
          (define lifted (lift-proof-forest (car steps) current))
          (if (revision-error? lifted)
              lifted
              (loop lifted (cdr steps)))]))]))
