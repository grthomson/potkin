#lang racket/base

;; Atomic total-preorder validity, native quotation, and CK evidence.
;;
;; Paper argument (PROVED, not by the bounded checks below).  Falsifying an
;; atomic component a => b means b < a.  Add each generator constraint a <= b
;; as a non-strict edge a -> b and each requested falsity as a strict edge
;; b -> a.  A finite system is inconsistent exactly when a strict edge lies
;; in a strongly connected component.  Such an SCC yields an alternating
;; signed cycle whose non-strict runs retain their concrete generator IDs.  If
;; no SCC contains a strict edge, longest strict-edge distance on the acyclic
;; condensation is a finite rank countervaluation: every base edge is
;; nondecreasing and every requested component is false.
;;
;; Graph edges below are semantic certificates and are deliberately unrelated
;; to POTKIN component-incidence.  Quotation uses only explicitly supplied,
;; exact registry occurrences whose whole premise/conclusion boundaries are
;; checked as atomic identity, atomic Gentzen Cut, genuine binary Avron Com,
;; or external weakening instances.  It never infers a rule role from an ID,
;; kind, tag, or incidence relation and never constructs a checked node.
;;
;; The four-hole R4 transport at the end is intentionally fixture-specific.
;; The current public macro API has one logical port, so this module does not
;; present its address map as a universal multi-hole macro theorem.

(require racket/list
         "../algebra/formal-sum.rkt"
         "../hopf/ck.rkt"
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/component-incidence.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "../kernel/syntax.rkt"
         "ancestry.rkt"
         "material-hopf-selector.rkt"
         "material-stock.rkt")

(provide atomic-generator?
         make-atomic-generator
         atomic-generator-calculus
         atomic-generator-id
         atomic-generator-source
         atomic-generator-target
         atomic-generator-occurrence

         (struct-out atomic-request-component)
         (struct-out atomic-cycle-edge)
         (struct-out atomic-base-path)
         (struct-out atomic-signed-cycle)
         (struct-out atomic-countervaluation)
         (struct-out atomic-preorder-result)
         atomic-countervaluation-verifies?
         decide-atomic-preorder

         atomic-identity-instance?
         make-atomic-identity-instance
         atomic-cut-instance?
         make-atomic-cut-instance
         atomic-com-instance?
         make-atomic-com-instance
         atomic-weakening-instance?
         make-atomic-weakening-instance
         atomic-quotation-kit?
         make-atomic-quotation-kit
         atomic-quotation-kit-calculus
         (struct-out atomic-quotation-unavailable)
         quote-atomic-cycle

         (struct-out atomic-four-cycle-fixture)
         make-atomic-four-cycle-fixture
         (struct-out atomic-removal-certificate)
         (struct-out atomic-cut-transport)
         (struct-out atomic-witness-match)
         (struct-out atomic-coaction-audit)
         (struct-out atomic-target-ck-certificate)
         (struct-out atomic-cycle-ck-certificate)
         certify-atomic-four-cycle)

;; --------------------------------------------------------------------------
;; Exact semantic inputs and graph decision

(struct atomic-generator (calculus id source target occurrence)
  #:constructor-name make-atomic-generator/internal
  #:transparent)

(struct atomic-request-component (index source target sequent)
  #:transparent)

(struct atomic-cycle-edge (kind source target evidence strict?)
  #:transparent)

(struct atomic-base-path (source target edges)
  #:transparent)

(struct atomic-signed-cycle (edges requests base-paths)
  #:transparent)

(struct atomic-countervaluation
  (ranks base-edges-satisfied? components-falsified?)
  #:transparent)

(struct atomic-preorder-result
  (status calculus generators request cycle countervaluation
          quotation-status proof quotation-obstruction work)
  #:transparent)

(define (atomic-boundary source target)
  (singleton-hypersequent (list source) (list target)))

(define (atomic-sequent-endpoints value)
  (and (sequent? value)
       (= (formula-context-size (sequent-left value)) 1)
       (= (formula-context-size (sequent-right value)) 1)
       (let ([source (car (formula-context->list (sequent-left value)))]
             [target (car (formula-context->list (sequent-right value)))])
         (and (symbol? source)
              (symbol-interned? source)
              (symbol? target)
              (symbol-interned? target)
              (cons source target)))))

(define (exact-registry-occurrence? calculus occurrence)
  (and (concrete-occurrence? occurrence)
       (eq? occurrence
            (calculus-lookup
             calculus
             (concrete-occurrence-id occurrence)))))

(define (make-atomic-generator calculus id source target occurrence)
  (define who 'make-atomic-generator)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (and (symbol? id) (symbol-interned? id))
    (raise-argument-error who "interned-symbol?" id))
  (for ([atom (in-list (list source target))])
    (unless (and (symbol? atom) (symbol-interned? atom))
      (raise-argument-error who "interned-symbol? atom" atom)))
  (unless (exact-registry-occurrence? calculus occurrence)
    (raise-arguments-error
     who
     "the generator must be the exact occurrence stored in the calculus"
     "calculus" calculus
     "occurrence" occurrence))
  (unless (and (zero? (occurrence-arity occurrence))
               (equal? (concrete-occurrence-conclusion occurrence)
                       (atomic-boundary source target)))
    (raise-arguments-error
     who
     "the exact occurrence must be a nullary proof of the stated atomic edge"
     "source" source
     "target" target
     "occurrence" occurrence))
  (make-atomic-generator/internal calculus id source target occurrence))

(define (request-components who request)
  (unless (hypersequent? request)
    (raise-argument-error who "hypersequent?" request))
  (for/list ([component (in-list (hypersequent-components request))])
    (define displayed (component-occurrence-sequent component))
    (define endpoints (atomic-sequent-endpoints displayed))
    (unless endpoints
      (raise-arguments-error
       who
       "every requested component must be an occurrence-indexed atomic singleton sequent"
       "component index" (component-occurrence-index component)
       "component" displayed))
    (atomic-request-component
     (component-occurrence-index component)
     (car endpoints)
     (cdr endpoints)
     displayed)))

(define (check-generator-family who calculus generators)
  (unless (and (list? generators) (andmap atomic-generator? generators))
    (raise-argument-error who "(listof atomic-generator?)" generators))
  (define duplicate-id
    (check-duplicates (map atomic-generator-id generators) eq?))
  (when duplicate-id
    (raise-arguments-error
     who "generator IDs must be distinct" "duplicate ID" duplicate-id))
  (for ([generator (in-list generators)])
    (unless (and (eq? (atomic-generator-calculus generator) calculus)
                 (exact-registry-occurrence?
                  calculus (atomic-generator-occurrence generator)))
      (raise-arguments-error
       who
       "every generator must retain the exact supplied calculus snapshot"
       "calculus" calculus
       "generator" generator))))

(define (edge-adjacency edges #:reverse? [reverse? #f])
  (for/fold ([table (hash)]) ([edge (in-list edges)])
    (define key
      (if reverse?
          (atomic-cycle-edge-target edge)
          (atomic-cycle-edge-source edge)))
    (hash-update table key (lambda (prior) (cons edge prior)) '())))

(define (edge-next edge reverse?)
  (if reverse?
      (atomic-cycle-edge-source edge)
      (atomic-cycle-edge-target edge)))

(define (cycle-segments edges)
  (define first-edge (and (pair? edges) (car edges)))
  (unless (and first-edge (eq? (atomic-cycle-edge-kind first-edge) 'request))
    (error 'cycle-segments "a signed cycle must begin with a request edge"))
  (define first-request
    (atomic-cycle-edge-evidence first-edge))
  (let loop ([remaining (cdr edges)]
             [current-request first-request]
             [current-source (atomic-cycle-edge-target first-edge)]
             [reversed-base '()]
             [reversed-requests '()]
             [reversed-paths '()])
    (cond
      [(null? remaining)
       (values
        (reverse (cons current-request reversed-requests))
        (reverse
         (cons
          (atomic-base-path
           current-source
           (atomic-cycle-edge-source first-edge)
           (reverse reversed-base))
          reversed-paths)))]
      [else
       (define edge (car remaining))
       (cond
         [(eq? (atomic-cycle-edge-kind edge) 'base)
          (loop (cdr remaining) current-request current-source
                (cons edge reversed-base)
                reversed-requests reversed-paths)]
         [else
          (loop
           (cdr remaining)
           (atomic-cycle-edge-evidence edge)
           (atomic-cycle-edge-target edge)
           '()
           (cons current-request reversed-requests)
           (cons
            (atomic-base-path
             current-source
             (atomic-cycle-edge-source edge)
             (reverse reversed-base))
             reversed-paths))])])))

(define (atomic-countervaluation-verifies? value)
  (and (atomic-countervaluation? value)
       (atomic-countervaluation-base-edges-satisfied? value)
       (atomic-countervaluation-components-falsified? value)))

(define (decide-atomic-preorder
         calculus generators request
         #:quotation-kit [quotation-kit #f]
         #:limit [limit analysis-default-limit])
  (define who 'decide-atomic-preorder)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (exact-nonnegative-integer? limit)
    (raise-argument-error who "exact-nonnegative-integer?" limit))
  (check-generator-family who calculus generators)
  (define components (request-components who request))
  (when (and quotation-kit
             (not (atomic-quotation-kit? quotation-kit)))
    (raise-argument-error
     who "(or/c #f atomic-quotation-kit?)" quotation-kit))
  (when (and quotation-kit
             (not (eq? (atomic-quotation-kit-calculus quotation-kit)
                       calculus)))
    (raise-arguments-error
     who
     "the quotation kit must carry the exact decision calculus"
     "decision calculus" calculus
     "quotation calculus" (atomic-quotation-kit-calculus quotation-kit)))

  (let/ec not-computed
    (define work 0)
    (define (charge!)
      (set! work (add1 work))
      (when (> work limit)
        (not-computed
         (analysis-limit
          'not-computed-limit
          "the exact atomic SCC decision exceeds its configured work limit"
          who limit work 'atomic-graph-work
          (hash 'generator-count (length generators)
                'component-count (length components))))))

    (define base-edges
      (for/list ([generator (in-list generators)])
        (charge!)
        (atomic-cycle-edge
         'base
         (atomic-generator-source generator)
         (atomic-generator-target generator)
         generator
         #f)))
    (define strict-edges
      (for/list ([component (in-list components)])
        (charge!)
        (atomic-cycle-edge
         'request
         (atomic-request-component-target component)
         (atomic-request-component-source component)
         component
         #t)))
    (define edges (append base-edges strict-edges))
    (define atoms
      (remove-duplicates
       (append-map
        (lambda (edge)
          (list (atomic-cycle-edge-source edge)
                (atomic-cycle-edge-target edge)))
        edges)
       equal?))
    (define forward (edge-adjacency edges))
    (define reverse-adjacency (edge-adjacency edges #:reverse? #t))

    ;; Kosaraju SCCs, with every node/edge examination charged.
    (define seen (make-hash))
    (define finish-order '())
    (define (visit-first atom)
      (unless (hash-ref seen atom #f)
        (charge!)
        (hash-set! seen atom #t)
        (for ([edge (in-list (reverse (hash-ref forward atom '())))])
          (charge!)
          (visit-first (atomic-cycle-edge-target edge)))
        (set! finish-order (cons atom finish-order))))
    (for ([atom (in-list atoms)]) (visit-first atom))
    (define component-of (make-hash))
    (define component-count 0)
    (define (visit-second atom component-id)
      (unless (hash-has-key? component-of atom)
        (charge!)
        (hash-set! component-of atom component-id)
        (for ([edge
              (in-list
               (reverse (hash-ref reverse-adjacency atom '())))])
          (charge!)
          (visit-second (atomic-cycle-edge-source edge) component-id))))
    (for ([atom (in-list finish-order)])
      (unless (hash-has-key? component-of atom)
        (visit-second atom component-count)
        (set! component-count (add1 component-count))))

    (define contradictory-edge
      (for/first ([edge (in-list strict-edges)]
                  #:when
                  (= (hash-ref component-of (atomic-cycle-edge-source edge))
                     (hash-ref component-of (atomic-cycle-edge-target edge))))
        edge))

    (cond
      [contradictory-edge
       (define start (atomic-cycle-edge-target contradictory-edge))
       (define goal (atomic-cycle-edge-source contradictory-edge))
       (define component-id (hash-ref component-of start))
       (define predecessor (make-hash))
       (define discovered (make-hash (list (cons start #t))))
       (define found?
         (if (equal? start goal)
             #t
             (let bfs ([queue (list start)])
               (cond
                 [(null? queue) #f]
                 [else
                  (define atom (car queue))
                  (define next-queue (cdr queue))
                  (define-values (extended found-now?)
                    (for/fold ([queued next-queue] [found-now? #f])
                              ([edge
                                (in-list
                                 (reverse (hash-ref forward atom '())))]
                               #:break found-now?)
                      (charge!)
                      (define next (atomic-cycle-edge-target edge))
                      (cond
                        [(or (not (= (hash-ref component-of next)
                                     component-id))
                             (hash-ref discovered next #f))
                         (values queued #f)]
                        [else
                         (hash-set! discovered next #t)
                         (hash-set! predecessor next edge)
                         (values (append queued (list next))
                                  (equal? next goal))])))
                  (if found-now? #t (bfs extended))]))))
       (unless found?
         (error who "SCC extraction failed to recover its closing path"))
       (define closing-path
         (let rebuild ([atom goal] [path '()])
           (if (equal? atom start)
               path
               (let ([edge (hash-ref predecessor atom)])
                 (rebuild (atomic-cycle-edge-source edge)
                          (cons edge path))))))
       (define cycle-edges (cons contradictory-edge closing-path))
       (define-values (cycle-requests base-paths)
         (cycle-segments cycle-edges))
       (define cycle
         (atomic-signed-cycle cycle-edges cycle-requests base-paths))
       (define quotation
         (if quotation-kit
             (quote-atomic-cycle
              calculus generators request cycle quotation-kit)
             (atomic-quotation-unavailable
              'quotation-kit-missing
              (hash 'request request))))
       (define quoted? (checked-node? quotation))
       (atomic-preorder-result
        (if quoted? 'valid-quoted 'valid-quotation-unavailable)
        calculus generators request cycle #f
        (if quoted? 'quoted 'unavailable)
        (and quoted? quotation)
        (and (atomic-quotation-unavailable? quotation) quotation)
        work)]
      [else
       ;; With no strict edge internal to an SCC there is no positive cycle.
       ;; Repeated relaxation computes longest strict-edge distance.
       (define ranks (make-hash))
       (for ([atom (in-list atoms)]) (hash-set! ranks atom 0))
       (for ([round (in-range (length atoms))])
         (for ([edge (in-list edges)])
           (charge!)
           (define candidate
             (+ (hash-ref ranks (atomic-cycle-edge-source edge))
                (if (atomic-cycle-edge-strict? edge) 1 0)))
           (when (> candidate
                    (hash-ref ranks (atomic-cycle-edge-target edge)))
             (hash-set! ranks (atomic-cycle-edge-target edge) candidate))))
       (define immutable-ranks
         (for/hash ([(atom rank) (in-hash ranks)])
           (values atom rank)))
       (define base-ok?
         (for/and ([generator (in-list generators)])
           (<= (hash-ref immutable-ranks (atomic-generator-source generator))
               (hash-ref immutable-ranks (atomic-generator-target generator)))))
       (define components-false?
         (for/and ([component (in-list components)])
           (< (hash-ref immutable-ranks
                        (atomic-request-component-target component))
              (hash-ref immutable-ranks
                        (atomic-request-component-source component)))))
       (define countervaluation
         (atomic-countervaluation
          immutable-ranks base-ok? components-false?))
       (unless (atomic-countervaluation-verifies? countervaluation)
         (error who "rank construction failed its semantic verification"))
       (atomic-preorder-result
        'invalid-countervaluation calculus generators request #f
        countervaluation 'not-applicable #f #f work)])))

;; --------------------------------------------------------------------------
;; Exact quotation instances

(struct atomic-identity-instance (atom occurrence)
  #:constructor-name make-atomic-identity-instance/internal
  #:transparent)
(struct atomic-cut-instance (source middle target occurrence)
  #:constructor-name make-atomic-cut-instance/internal
  #:transparent)
(struct atomic-com-instance (occurrence left-active-index right-active-index)
  #:constructor-name make-atomic-com-instance/internal
  #:transparent)
(struct atomic-weakening-instance (occurrence added-sequent)
  #:constructor-name make-atomic-weakening-instance/internal
  #:transparent)
(struct atomic-quotation-kit
  (calculus identities cuts communications weakenings)
  #:constructor-name make-atomic-quotation-kit/internal
  #:transparent)
(struct atomic-quotation-unavailable (reason details)
  #:transparent)

(define (check-exact-quotation-occurrence who calculus occurrence arity)
  (unless (and (exact-registry-occurrence? calculus occurrence)
               (= (occurrence-arity occurrence) arity))
    (raise-arguments-error
     who
     "the rule certificate must name an exact occurrence of the required arity"
     "calculus" calculus
     "required arity" arity
     "occurrence" occurrence)))

(define (make-atomic-identity-instance calculus atom occurrence)
  (define who 'make-atomic-identity-instance)
  (check-exact-quotation-occurrence who calculus occurrence 0)
  (unless (equal? (concrete-occurrence-conclusion occurrence)
                  (atomic-boundary atom atom))
    (raise-arguments-error
     who "the occurrence is not the stated atomic identity"
     "atom" atom "occurrence" occurrence))
  (make-atomic-identity-instance/internal atom occurrence))

(define (make-atomic-cut-instance calculus source middle target occurrence)
  (define who 'make-atomic-cut-instance)
  (check-exact-quotation-occurrence who calculus occurrence 2)
  (define expected-premises
    (list (atomic-boundary source middle)
          (atomic-boundary middle target)))
  (unless (and (equal? (vector->list
                        (concrete-occurrence-premises occurrence))
                       expected-premises)
               (equal? (concrete-occurrence-conclusion occurrence)
                       (atomic-boundary source target)))
    (raise-arguments-error
     who "the occurrence is not the stated atomic Gentzen Cut instance"
     "source" source "middle" middle "target" target
     "occurrence" occurrence))
  (make-atomic-cut-instance/internal source middle target occurrence))

(define (remove-index values index)
  (for/list ([value (in-list values)]
             [position (in-naturals 1)]
             #:unless (= position index))
    value))

(define (component-at boundary index)
  (and (exact-positive-integer? index)
       (<= index (hypersequent-size boundary))
       (list-ref (hypersequent-sequents boundary) (sub1 index))))

(define (make-atomic-com-instance
         calculus occurrence left-active-index right-active-index)
  (define who 'make-atomic-com-instance)
  (check-exact-quotation-occurrence who calculus occurrence 2)
  (define premises
    (vector->list (concrete-occurrence-premises occurrence)))
  (define left (first premises))
  (define right (second premises))
  (define left-active (component-at left left-active-index))
  (define right-active (component-at right right-active-index))
  (define left-endpoints (and left-active
                              (atomic-sequent-endpoints left-active)))
  (define right-endpoints (and right-active
                               (atomic-sequent-endpoints right-active)))
  (unless (and left-endpoints right-endpoints)
    (raise-arguments-error
     who
     "the selected Com components must be existing atomic singleton sequents"
     "left active index" left-active-index
     "right active index" right-active-index
     "occurrence" occurrence))
  (define crossed-left
    (make-sequent (list (car left-endpoints))
                  (list (cdr right-endpoints))))
  (define crossed-right
    (make-sequent (list (car right-endpoints))
                  (list (cdr left-endpoints))))
  (define expected
    (make-hypersequent
     (append (remove-index (hypersequent-sequents left) left-active-index)
             (remove-index (hypersequent-sequents right) right-active-index)
             (list crossed-left crossed-right))))
  (unless (equal? expected (concrete-occurrence-conclusion occurrence))
    (raise-arguments-error
     who
     "the occurrence is not genuine binary Avron Com with all passive components retained"
     "expected conclusion" expected
     "actual conclusion" (concrete-occurrence-conclusion occurrence)
     "occurrence" occurrence))
  (make-atomic-com-instance/internal
   occurrence left-active-index right-active-index))

(define (remove-one value values)
  (cond
    [(null? values) #f]
    [(equal? value (car values)) (cdr values)]
    [else
     (define rest (remove-one value (cdr values)))
     (and rest (cons (car values) rest))]))

(define (make-atomic-weakening-instance calculus occurrence added-sequent)
  (define who 'make-atomic-weakening-instance)
  (check-exact-quotation-occurrence who calculus occurrence 1)
  (unless (atomic-sequent-endpoints added-sequent)
    (raise-argument-error who "atomic singleton sequent" added-sequent))
  (define premise
    (vector-ref (concrete-occurrence-premises occurrence) 0))
  (define expected
    (make-hypersequent
     (append (hypersequent-sequents premise) (list added-sequent))))
  (unless (equal? expected (concrete-occurrence-conclusion occurrence))
    (raise-arguments-error
     who
     "the occurrence is not the stated external weakening instance"
     "premise" premise
     "added component" added-sequent
     "occurrence" occurrence))
  (make-atomic-weakening-instance/internal occurrence added-sequent))

(define (make-atomic-quotation-kit
         calculus identities cuts communications weakenings)
  (define who 'make-atomic-quotation-kit)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (define families
    (list (cons atomic-identity-instance? identities)
          (cons atomic-cut-instance? cuts)
          (cons atomic-com-instance? communications)
          (cons atomic-weakening-instance? weakenings)))
  (for ([family (in-list families)])
    (unless (and (list? (cdr family)) (andmap (car family) (cdr family)))
      (raise-argument-error who "well-formed quotation instance lists" family)))
  (define occurrences
    (append (map atomic-identity-instance-occurrence identities)
            (map atomic-cut-instance-occurrence cuts)
            (map atomic-com-instance-occurrence communications)
            (map atomic-weakening-instance-occurrence weakenings)))
  (for ([occurrence (in-list occurrences)])
    (unless (exact-registry-occurrence? calculus occurrence)
      (raise-arguments-error
       who
       "every quotation instance must retain the exact kit calculus"
       "calculus" calculus
       "occurrence" occurrence)))
  (make-atomic-quotation-kit/internal
   calculus identities cuts communications weakenings))

(define (base-path-routing-valid? path generators)
  (let loop ([expected (atomic-base-path-source path)]
             [edges (atomic-base-path-edges path)])
    (cond
      [(null? edges) (equal? expected (atomic-base-path-target path))]
      [else
       (define edge (car edges))
       (and (eq? (atomic-cycle-edge-kind edge) 'base)
            (equal? (atomic-cycle-edge-source edge) expected)
            (atomic-generator? (atomic-cycle-edge-evidence edge))
            (memq (atomic-cycle-edge-evidence edge) generators)
            (equal? (atomic-cycle-edge-source edge)
                    (atomic-generator-source
                     (atomic-cycle-edge-evidence edge)))
            (equal? (atomic-cycle-edge-target edge)
                    (atomic-generator-target
                     (atomic-cycle-edge-evidence edge)))
            (loop (atomic-cycle-edge-target edge) (cdr edges)))])))

(define (cycle-routing-valid? cycle generators)
  (and (atomic-signed-cycle? cycle)
       (pair? (atomic-signed-cycle-requests cycle))
       (= (length (atomic-signed-cycle-requests cycle))
          (length (atomic-signed-cycle-base-paths cycle)))
       (for/and ([request
                  (in-list (atomic-signed-cycle-requests cycle))]
                 [path
                  (in-list (atomic-signed-cycle-base-paths cycle))]
                 [next-request
                  (in-list
                   (append (cdr (atomic-signed-cycle-requests cycle))
                           (list (car (atomic-signed-cycle-requests cycle)))))])
         (and (equal? (atomic-base-path-source path)
                      (atomic-request-component-source request))
              (equal? (atomic-base-path-target path)
                      (atomic-request-component-target next-request))
              (base-path-routing-valid? path generators)))))

(define (checked-occurrence-proof calculus occurrence expected children)
  (define candidate
    (apply raw-app
           (concrete-occurrence-id occurrence)
           (map checked-term->raw children)))
  (define checked
    (validate-candidate calculus candidate #:expected expected))
  (and (checked-node? checked) checked))

(define (quote-base-path calculus generators path kit)
  (define edges (atomic-base-path-edges path))
  (if (null? edges)
      (let ([identity
             (findf
              (lambda (instance)
                (equal? (atomic-identity-instance-atom instance)
                        (atomic-base-path-source path)))
              (atomic-quotation-kit-identities kit))])
        (if identity
            (or (checked-occurrence-proof
                 calculus
                 (atomic-identity-instance-occurrence identity)
                 (atomic-boundary (atomic-base-path-source path)
                                  (atomic-base-path-target path))
                 '())
                (atomic-quotation-unavailable
                 'native-identity-check-failed (hash 'path path)))
            (atomic-quotation-unavailable
             'missing-identity-instance (hash 'path path))))
      (let* ([first-generator
              (atomic-cycle-edge-evidence (car edges))]
             [first-proof
              (checked-occurrence-proof
               calculus
               (atomic-generator-occurrence first-generator)
               (atomic-boundary (atomic-generator-source first-generator)
                                (atomic-generator-target first-generator))
               '())])
        (if (not first-proof)
            (atomic-quotation-unavailable
             'native-generator-check-failed
             (hash 'generator first-generator))
            (let loop ([proof first-proof]
                       [source (atomic-generator-source first-generator)]
                       [middle (atomic-generator-target first-generator)]
                       [remaining (cdr edges)])
              (if (null? remaining)
                  proof
                  (let* ([next-generator
                          (atomic-cycle-edge-evidence (car remaining))]
                         [target
                          (atomic-generator-target next-generator)]
                         [next-proof
                          (checked-occurrence-proof
                           calculus
                           (atomic-generator-occurrence next-generator)
                           (atomic-boundary middle target)
                           '())]
                         [cut
                          (findf
                           (lambda (instance)
                             (and
                              (equal? source
                                      (atomic-cut-instance-source instance))
                              (equal? middle
                                      (atomic-cut-instance-middle instance))
                              (equal? target
                                      (atomic-cut-instance-target instance))))
                           (atomic-quotation-kit-cuts kit))])
                    (cond
                      ((not next-proof)
                       (atomic-quotation-unavailable
                        'native-generator-check-failed
                        (hash 'generator next-generator)))
                      ((not cut)
                       (atomic-quotation-unavailable
                        'missing-cut-instance
                        (hash 'source source
                              'middle middle
                              'target target)))
                      (else
                       (define composed
                         (checked-occurrence-proof
                          calculus
                          (atomic-cut-instance-occurrence cut)
                          (atomic-boundary source target)
                          (list proof next-proof)))
                       (if composed
                           (loop composed source target (cdr remaining))
                           (atomic-quotation-unavailable
                            'native-cut-check-failed
                            (hash 'cut cut))))))))))))

(define (find-com-for kit left right conclusion)
  (for/first
      ([instance (in-list (atomic-quotation-kit-communications kit))]
       #:when
       (let* ([occurrence (atomic-com-instance-occurrence instance)]
              [premises
               (vector->list (concrete-occurrence-premises occurrence))])
         (and (equal? (concrete-occurrence-conclusion occurrence) conclusion)
              (or (and (equal? (first premises) left)
                       (equal? (second premises) right))
                  (and (equal? (first premises) right)
                       (equal? (second premises) left))))))
    instance))

(define (apply-com-instance calculus instance left-proof right-proof expected)
  (define occurrence (atomic-com-instance-occurrence instance))
  (define premises
    (vector->list (concrete-occurrence-premises occurrence)))
  (define children
    (if (and (equal? (first premises) (derivation-root-boundary left-proof))
             (equal? (second premises)
                     (derivation-root-boundary right-proof)))
        (list left-proof right-proof)
        (list right-proof left-proof)))
  (checked-occurrence-proof calculus occurrence expected children))

(define (combine-cycle-paths calculus requests path-proofs kit)
  (define first-request (car requests))
  (let loop ((current (car path-proofs))
             (position 1)
             (remaining-proofs (cdr path-proofs)))
    (if (null? remaining-proofs)
        current
        (let* ((next-proof (car remaining-proofs))
               (next-target-request
                (list-ref requests
                          (modulo (add1 position) (length requests))))
               (fixed
                (for/list ((request-component
                            (in-list (take (cdr requests) position))))
                  (atomic-request-component-sequent request-component)))
               (active
                (make-sequent
                 (list (atomic-request-component-source first-request))
                 (list (atomic-request-component-target next-target-request))))
               (expected
                (make-hypersequent (append fixed (list active))))
               (com
                (find-com-for
                 kit
                 (derivation-root-boundary current)
                 (derivation-root-boundary next-proof)
                 expected)))
          (if (not com)
              (atomic-quotation-unavailable
               'missing-communication-instance
               (hash 'left (derivation-root-boundary current)
                     'right (derivation-root-boundary next-proof)
                     'conclusion expected))
              (let ((combined
                     (apply-com-instance
                      calculus com current next-proof expected)))
                (if combined
                    (loop combined (add1 position) (cdr remaining-proofs))
                    (atomic-quotation-unavailable
                     'native-communication-check-failed
                     (hash 'communication com)))))))))

(define (remove-cycle-components request requests)
  (let loop ((remaining (hypersequent-sequents request))
             (pending (map atomic-request-component-sequent requests)))
    (if (null? pending)
        remaining
        (let ((next (remove-one (car pending) remaining)))
          (if next
              (loop next (cdr pending))
              (atomic-quotation-unavailable
               'cycle-component-not-in-request
               (hash 'component (car pending) 'request request)))))))

(define (weaken-quotation calculus quotation remaining kit)
  (let loop ((current quotation) (pending remaining))
    (if (null? pending)
        current
        (let* ((added (car pending))
               (expected
                (make-hypersequent
                 (append
                  (hypersequent-sequents (derivation-root-boundary current))
                  (list added))))
               (weakening
                (findf
                 (lambda (instance)
                   (define occurrence
                     (atomic-weakening-instance-occurrence instance))
                   (and
                    (equal? (atomic-weakening-instance-added-sequent instance)
                            added)
                    (equal? (vector-ref
                             (concrete-occurrence-premises occurrence) 0)
                            (derivation-root-boundary current))
                    (equal? (concrete-occurrence-conclusion occurrence)
                            expected)))
                 (atomic-quotation-kit-weakenings kit))))
          (if (not weakening)
              (atomic-quotation-unavailable
               'missing-external-weakening-instance
               (hash 'premise (derivation-root-boundary current)
                     'added added
                     'conclusion expected))
              (let ((next
                     (checked-occurrence-proof
                      calculus
                      (atomic-weakening-instance-occurrence weakening)
                      expected
                      (list current))))
                (if next
                    (loop next (cdr pending))
                    (atomic-quotation-unavailable
                     'native-weakening-check-failed
                     (hash 'weakening weakening)))))))))

(define (quote-atomic-cycle calculus generators request cycle kit)
  (define who 'quote-atomic-cycle)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (check-generator-family who calculus generators)
  (unless (hypersequent? request)
    (raise-argument-error who "hypersequent?" request))
  (unless (atomic-quotation-kit? kit)
    (raise-argument-error who "atomic-quotation-kit?" kit))
  (unless (eq? calculus (atomic-quotation-kit-calculus kit))
    (raise-arguments-error
     who "cycle quotation requires exact calculus provenance"
     "calculus" calculus
     "kit calculus" (atomic-quotation-kit-calculus kit)))
  (if (not (cycle-routing-valid? cycle generators))
      (atomic-quotation-unavailable
       'wrong-cycle-routing (hash 'cycle cycle))
      (let* ((requests (atomic-signed-cycle-requests cycle))
             (paths (atomic-signed-cycle-base-paths cycle))
             (path-proofs
              (for/list ((path (in-list paths)))
                (quote-base-path calculus generators path kit)))
             (path-failure
              (findf atomic-quotation-unavailable? path-proofs)))
        (if path-failure
            path-failure
            (let ((quotation
                   (combine-cycle-paths
                    calculus requests path-proofs kit)))
              (if (atomic-quotation-unavailable? quotation)
                  quotation
                  (let ((remaining
                         (remove-cycle-components request requests)))
                    (if (atomic-quotation-unavailable? remaining)
                        remaining
                        (let ((weakened
                               (weaken-quotation
                                calculus quotation remaining kit)))
                          (cond
                            ((atomic-quotation-unavailable? weakened)
                             weakened)
                            ((and (checked-node? weakened)
                                  (equal? (derivation-root-boundary weakened)
                                          request))
                             weakened)
                            (else
                             (atomic-quotation-unavailable
                              'quotation-boundary-mismatch
                              (hash
                               'expected request
                               'actual
                               (and (checked-node? weakened)
                                    (derivation-root-boundary
                                     weakened)))))))))))))))

;; --------------------------------------------------------------------------
;; The decisive four-generator fixture

(struct atomic-four-cycle-fixture
  (calculus request generators generator-proofs r4-occurrence
            communication-occurrences quotation-kit source comb balanced
            decision old-base-profile source-leaf-addresses
            comb-leaf-addresses balanced-leaf-addresses)
  #:transparent)

(define (sequent-index boundary displayed)
  (or
   (for/first ([component (in-list (hypersequent-components boundary))]
               #:when
               (equal? displayed (component-occurrence-sequent component)))
     (component-occurrence-index component))
   (error 'sequent-index "component not found in exact boundary")))

(define (com-incidence premises conclusion left-active-index right-active-index)
  (define left (first premises))
  (define right (second premises))
  (define left-active (component-at left left-active-index))
  (define right-active (component-at right right-active-index))
  (define left-endpoints (atomic-sequent-endpoints left-active))
  (define right-endpoints (atomic-sequent-endpoints right-active))
  (define crossed-left
    (make-sequent (list (car left-endpoints))
                  (list (cdr right-endpoints))))
  (define crossed-right
    (make-sequent (list (car right-endpoints))
                  (list (cdr left-endpoints))))
  (define crossed-indices
    (list (sequent-index conclusion crossed-left)
          (sequent-index conclusion crossed-right)))
  (define edges
    (append-map
     (lambda (slot+boundary+active)
       (define slot (first slot+boundary+active))
       (define boundary (second slot+boundary+active))
       (define active-index (third slot+boundary+active))
       (append-map
        (lambda (component)
          (define source-index (component-occurrence-index component))
          (define targets
            (if (= source-index active-index)
                crossed-indices
                (list
                 (sequent-index
                  conclusion
                  (component-occurrence-sequent component)))))
          (for/list ([target-index (in-list targets)])
            (make-component-edge slot source-index target-index)))
        (hypersequent-components boundary)))
     (list (list 1 left left-active-index)
           (list 2 right right-active-index))))
  (make-component-incidence premises conclusion edges))

(define (r4-incidence premises conclusion)
  (make-component-incidence
   premises
   conclusion
   (for/list ([premise (in-list premises)]
              [slot (in-naturals 1)])
     (define endpoints
       (atomic-sequent-endpoints (car (hypersequent-sequents premise))))
     (define target-index
       (for/first ([component
                    (in-list (hypersequent-components conclusion))]
                   #:when
                   (equal?
                    (car endpoints)
                    (car
                     (atomic-sequent-endpoints
                      (component-occurrence-sequent component)))))
         (component-occurrence-index component)))
     (make-component-edge slot 1 target-index))))

(define (make-com-occurrence id left right conclusion
                             left-active right-active instance)
  (make-concrete-occurrence
   id
   (list left right)
   conclusion
   #:kind 'structural
   #:instance instance
   #:incidence
   (com-incidence
    (list left right) conclusion left-active right-active)))

(define (checked-or-error who calculus raw expected)
  (define result (validate-candidate calculus raw #:expected expected))
  (if (checked-node? result)
      result
      (error who "native fixture checking failed: ~e" result)))

(define (make-atomic-four-cycle-fixture)
  (define x1 'x1)
  (define x2 'x2)
  (define x3 'x3)
  (define x4 'x4)
  (define y1 'y1)
  (define y2 'y2)
  (define y3 'y3)
  (define y4 'y4)
  (define B1 (atomic-boundary x1 y1))
  (define B2 (atomic-boundary x2 y2))
  (define B3 (atomic-boundary x3 y3))
  (define B4 (atomic-boundary x4 y4))
  (define S12
    (make-hypersequent
     (list (make-sequent (list x1) (list y2))
           (make-sequent (list x2) (list y1)))))
  (define S123
    (make-hypersequent
     (list (make-sequent (list x1) (list y3))
           (make-sequent (list x2) (list y1))
           (make-sequent (list x3) (list y2)))))
  (define S34
    (make-hypersequent
     (list (make-sequent (list x3) (list y4))
           (make-sequent (list x4) (list y3)))))
  (define H4
    (make-hypersequent
     (list (make-sequent (list x1) (list y4))
           (make-sequent (list x2) (list y1))
           (make-sequent (list x3) (list y2))
           (make-sequent (list x4) (list y3)))))
  (define boundaries (list B1 B2 B3 B4))
  (define endpoints (list (cons x1 y1) (cons x2 y2)
                          (cons x3 y3) (cons x4 y4)))
  (define generator-occurrences
    (for/list ([id (in-list '(atomic-g1 atomic-g2 atomic-g3 atomic-g4))]
               [edge-id (in-list '(g1 g2 g3 g4))]
               [boundary (in-list boundaries)]
               [endpoint (in-list endpoints)])
      (make-concrete-occurrence
       id '() boundary
       #:kind 'material
       #:instance
       (list 'atomic-generator edge-id (car endpoint) (cdr endpoint))
       #:incidence (make-component-incidence '() boundary '()))))

  (define com12
    (make-com-occurrence
     'atomic-com-12 B1 B2 S12 1 1 '(avron-com 1 2)))
  (define com123
    (make-com-occurrence
     'atomic-com-123 S12 B3 S123
     (sequent-index S12 (make-sequent (list x1) (list y2)))
     1
     '(avron-com comb 3 passive-2)))
  (define com1234
    (make-com-occurrence
     'atomic-com-1234 S123 B4 H4
     (sequent-index S123 (make-sequent (list x1) (list y3)))
     1
     '(avron-com comb 4 passive-2-3)))
  (define com34
    (make-com-occurrence
     'atomic-com-34 B3 B4 S34 1 1 '(avron-com 3 4)))
  (define com-balanced
    (make-com-occurrence
     'atomic-com-balanced S12 S34 H4
     (sequent-index S12 (make-sequent (list x1) (list y2)))
     (sequent-index S34 (make-sequent (list x3) (list y4)))
     '(avron-com balanced passive-2-4)))
  (define communication-occurrences
    (list com12 com123 com1234 com34 com-balanced))
  (define r4
    (make-concrete-occurrence
     'atomic-R4 boundaries H4
     #:kind 'structural
     #:instance '(derived-R4 four-atomic-premises)
     #:incidence (r4-incidence boundaries H4)))
  (define calculus
    (make-equipped-calculus
     (append generator-occurrences communication-occurrences (list r4))))
  (define generators
    (for/list ([edge-id (in-list '(g1 g2 g3 g4))]
               [endpoint (in-list endpoints)]
               [occurrence (in-list generator-occurrences)])
      (make-atomic-generator
       calculus edge-id (car endpoint) (cdr endpoint) occurrence)))
  (define generator-proofs
    (for/list ([occurrence (in-list generator-occurrences)]
               [boundary (in-list boundaries)])
      (checked-or-error
       'make-atomic-four-cycle-fixture
       calculus
       (raw-app (concrete-occurrence-id occurrence))
       boundary)))
  (define com-instances
    (for/list ([occurrence (in-list communication-occurrences)]
               [indices
                (in-list
                 (list
                  (cons 1 1)
                  (cons (sequent-index
                         S12 (make-sequent (list x1) (list y2)))
                        1)
                  (cons (sequent-index
                         S123 (make-sequent (list x1) (list y3)))
                        1)
                  (cons 1 1)
                  (cons (sequent-index
                         S12 (make-sequent (list x1) (list y2)))
                        (sequent-index
                         S34 (make-sequent (list x3) (list y4))))))])
      (make-atomic-com-instance
       calculus occurrence (car indices) (cdr indices))))
  (define kit
    (make-atomic-quotation-kit calculus '() '() com-instances '()))
  (define raw-generators
    (map checked-term->raw generator-proofs))
  (define source
    (checked-or-error
     'make-atomic-four-cycle-fixture calculus
     (apply raw-app 'atomic-R4 raw-generators)
     H4))
  (define comb
    (checked-or-error
     'make-atomic-four-cycle-fixture calculus
     (raw-app
      'atomic-com-1234
      (raw-app
       'atomic-com-123
       (raw-app 'atomic-com-12
                (list-ref raw-generators 0)
                (list-ref raw-generators 1))
       (list-ref raw-generators 2))
      (list-ref raw-generators 3))
     H4))
  (define balanced
    (checked-or-error
     'make-atomic-four-cycle-fixture calculus
     (raw-app
      'atomic-com-balanced
      (raw-app 'atomic-com-12
               (list-ref raw-generators 0)
               (list-ref raw-generators 1))
      (raw-app 'atomic-com-34
               (list-ref raw-generators 2)
               (list-ref raw-generators 3)))
     H4))
  (define decision
    (decide-atomic-preorder
     calculus generators H4 #:quotation-kit kit
     #:limit analysis-default-limit))
  (when (analysis-limit? decision)
    (error 'make-atomic-four-cycle-fixture
           "fixed graph unexpectedly exceeded the default limit"))
  (unless (and (eq? (atomic-preorder-result-status decision) 'valid-quoted)
               (equal? (atomic-preorder-result-proof decision) comb))
    (error 'make-atomic-four-cycle-fixture
           "generic signed-cycle quotation did not recover the comb proof"))
  (define old-base-profile
    (make-material-profile
     calculus (append generator-occurrences communication-occurrences)))
  (atomic-four-cycle-fixture
   calculus H4 generators generator-proofs r4 communication-occurrences
   kit source comb balanced decision old-base-profile
   (hash 'g1 '(1) 'g2 '(2) 'g3 '(3) 'g4 '(4))
   (hash 'g1 '(1 1 1) 'g2 '(1 1 2) 'g3 '(1 2) 'g4 '(2))
   (hash 'g1 '(1 1) 'g2 '(1 2) 'g3 '(2 1) 'g4 '(2 2))))

;; --------------------------------------------------------------------------
;; Bounded native CK/material certificate for that fixture

(struct atomic-removal-certificate (removed-generator decision verified?)
  #:transparent)
(struct atomic-cut-transport
  (source-witness target-witness address-map source-holes target-holes
                  source-refill target-refill classification verified?)
  #:transparent)
(struct atomic-witness-match
  (source-contribution target-contribution address-map
                       detached-forest-equal? source-refills? target-refills?)
  #:transparent)
(struct atomic-coaction-audit
  (proof index result coaction reconstructed equal?
         empty-contributions proper-contributions whole-contributions
         coefficient-mass)
  #:transparent)
(struct atomic-target-ck-certificate
  (name proof leaf-addresses transport witness-matches new-contributions
        coaction full-support-witnesses new-full-support-witnesses
        top-child-block-witness top-child-refill full-excess verified?)
  #:transparent)
(struct atomic-cycle-ck-certificate
  (fixture removals source-coaction comb balanced verified?)
  #:transparent)

(define (contribution-sum calculus contributions)
  (make-formal-sum
   calculus
   2
   (for/list ([contribution (in-list contributions)])
     (cons (material-contribution-tensor contribution) 1))))

(define (formal-coefficient-mass sum)
  (for/sum ([term (in-list (formal-sum-terms sum))])
    (cdr term)))

(define (make-coaction-audit proof profile limit)
  (define index
    (prepare-material-stock-index proof profile #:limit limit))
  (cond
    [(analysis-limit? index) index]
    [else
     (define query
       (make-material-all-query #:include-whole-endpoint? #t))
     (define result (indexed-material-query index query))
     (define selector (prepare-material-hopf-selector profile))
     ;; The exact index preflight above bounds this native coproduct family
     ;; before the selector invokes its unbounded-by-interface enumeration.
     (define coaction
       (material-hopf-selector-coaction selector (checked-node-basis proof)))
     (define contributions
       (material-query-result-contributions result))
     (define reconstructed
       (contribution-sum (material-profile-calculus profile) contributions))
     (define empty-contributions
       (filter
        (lambda (contribution)
          (empty-cut-choice?
           (material-contribution-choice contribution)))
        contributions))
     (define proper-contributions
       (filter
        (lambda (contribution)
          (proper-cut-choice?
           (material-contribution-choice contribution)))
        contributions))
     (define whole-contributions
       (filter
        (lambda (contribution)
          (whole-cut-choice?
           (material-contribution-choice contribution)))
        contributions))
     (atomic-coaction-audit
      proof index result coaction reconstructed (equal? coaction reconstructed)
      empty-contributions proper-contributions whole-contributions
      (formal-coefficient-mass coaction))]))

(define (refill-witness witness)
  (complete-fill
   (cut-witness-remainder witness)
   (map detached-entry-term (cut-witness-detached witness))))

(define (translate-addresses addresses source-map target-map)
  (sort
   (for/list ([address (in-list addresses)])
     (define generator-id
       (for/first ([(id source-address) (in-hash source-map)]
                   #:when (equal? address source-address))
         id))
     (unless generator-id
       (error 'translate-addresses
              "source witness selected a non-R4-premise address: ~e"
              address))
     (hash-ref target-map generator-id))
   address<?))

(define (contribution-at-addresses contributions addresses)
  (findf
   (lambda (contribution)
     (define witness (material-contribution-witness contribution))
     (and witness
          (equal? (cut-witness-addresses witness) addresses)))
   contributions))

(define (make-witness-matches fixture target target-map source-audit target-audit)
  (define source-map
    (atomic-four-cycle-fixture-source-leaf-addresses fixture))
  (define target-contributions
    (material-query-result-contributions
     (atomic-coaction-audit-result target-audit)))
  (for/list
      ([source-contribution
        (in-list
         (material-query-result-contributions
          (atomic-coaction-audit-result source-audit)))])
    (define source-witness
      (material-contribution-witness source-contribution))
    (unless source-witness
      (error 'make-witness-matches
             "the selected R4 source unexpectedly retained its whole endpoint"))
    (define target-addresses
      (translate-addresses
       (cut-witness-addresses source-witness) source-map target-map))
    (define target-witness (make-cut-witness target target-addresses))
    (unless (cut-witness? target-witness)
      (error 'make-witness-matches
             "translated leaf cut is not a native target cut: ~e"
             target-witness))
    (define target-contribution
      (contribution-at-addresses target-contributions target-addresses))
    (unless target-contribution
      (error 'make-witness-matches
             "translated native target witness is absent from its coaction"))
    (define address-map
      (map cons
           (cut-witness-addresses source-witness)
           (cut-witness-addresses target-witness)))
    (atomic-witness-match
     source-contribution target-contribution address-map
     (equal? (cut-witness-forest source-witness)
             (cut-witness-forest target-witness))
     (equal? (refill-witness source-witness)
             (cut-witness-source source-witness))
     (equal? (refill-witness target-witness)
             (cut-witness-source target-witness)))))

(define (make-all-leaf-transport fixture target target-map matches)
  (define source-addresses '((1) (2) (3) (4)))
  (define source-match
    (findf
     (lambda (match)
       (equal?
        (cut-witness-addresses
         (material-contribution-witness
          (atomic-witness-match-source-contribution match)))
        source-addresses))
     matches))
  (unless source-match
    (error 'make-all-leaf-transport "source all-leaf witness was not matched"))
  (define source-witness
    (material-contribution-witness
     (atomic-witness-match-source-contribution source-match)))
  (define target-witness
    (material-contribution-witness
     (atomic-witness-match-target-contribution source-match)))
  (define source-refill (refill-witness source-witness))
  (define target-refill (refill-witness target-witness))
  (define address-map
    (map cons
         (cut-witness-addresses source-witness)
         (cut-witness-addresses target-witness)))
  (define source-holes
    (puncture-addresses (cut-witness-remainder source-witness)))
  (define target-holes
    (puncture-addresses (cut-witness-remainder target-witness)))
  (atomic-cut-transport
   source-witness target-witness address-map source-holes target-holes
   source-refill target-refill 'inherited
   (and (equal? source-holes (cut-witness-addresses source-witness))
        (equal? target-holes (cut-witness-addresses target-witness))
        (equal? source-refill
                (atomic-four-cycle-fixture-source fixture))
        (equal? target-refill target))))

(define (generator-support witness generators)
  (define generator-occurrences
    (map atomic-generator-occurrence generators))
  (for*/list ([entry (in-list (cut-witness-detached witness))]
              [address
               (in-list (vertex-addresses (detached-entry-term entry)))]
              #:do
              [(define occurrence
                 (checked-node-occurrence
                  (vertex-at-address (detached-entry-term entry) address)))]
              #:when (memq occurrence generator-occurrences))
    occurrence))

(define (full-generator-support? witness generators)
  (define support (generator-support witness generators))
  (and (= (length support) (length generators))
       (for/and ([generator (in-list generators)])
         (= (count
             (lambda (occurrence)
               (eq? occurrence (atomic-generator-occurrence generator)))
             support)
            1))))

(define (new-target-contributions matches target-audit)
  (define matched-addresses
    (for/list ([match (in-list matches)])
      (cut-witness-addresses
       (material-contribution-witness
        (atomic-witness-match-target-contribution match)))))
  (filter
   (lambda (contribution)
     (define witness (material-contribution-witness contribution))
     (or (not witness)
         (not (member (cut-witness-addresses witness)
                      matched-addresses equal?))))
   (material-query-result-contributions
    (atomic-coaction-audit-result target-audit))))

(define (make-target-certificate
         name fixture target target-map source-audit target-audit expected-full)
  (define generators (atomic-four-cycle-fixture-generators fixture))
  (define matches
    (make-witness-matches
     fixture target target-map source-audit target-audit))
  (define transport
    (make-all-leaf-transport fixture target target-map matches))
  (define new-contributions
    (new-target-contributions matches target-audit))
  (define full-support-witnesses
    (for/list
        ([contribution
          (in-list (atomic-coaction-audit-proper-contributions target-audit))]
         #:do
         [(define witness (material-contribution-witness contribution))]
         #:when (full-generator-support? witness generators))
      witness))
  (define inherited-addresses
    (cut-witness-addresses (atomic-cut-transport-target-witness transport)))
  (define new-full-support-witnesses
    (filter
     (lambda (witness)
       (not (equal? (cut-witness-addresses witness) inherited-addresses)))
     full-support-witnesses))
  (define top-child-block
    (findf
     (lambda (witness)
       (equal? (cut-witness-addresses witness) '((1) (2))))
     new-full-support-witnesses))
  (define top-child-refill (and top-child-block (refill-witness top-child-block)))
  (define source-count
    (material-query-result-coefficient
     (atomic-coaction-audit-result source-audit)))
  (define target-count
    (material-query-result-coefficient
     (atomic-coaction-audit-result target-audit)))
  (define excess (- target-count source-count))
  (define expected-new (- expected-full 1))
  (define verified?
    (and (= (length matches) source-count)
         (andmap atomic-witness-match-detached-forest-equal? matches)
         (andmap atomic-witness-match-source-refills? matches)
         (andmap atomic-witness-match-target-refills? matches)
         (atomic-cut-transport-verified? transport)
         (= (length full-support-witnesses) expected-full)
         (= (length new-full-support-witnesses) expected-new)
         top-child-block
         (equal? top-child-refill target)
         (= (length new-contributions) excess)
         (atomic-coaction-audit-equal? target-audit)))
  (atomic-target-ck-certificate
   name target target-map transport matches new-contributions target-audit
   full-support-witnesses new-full-support-witnesses
   top-child-block top-child-refill excess verified?))

(define (certify-atomic-four-cycle #:limit [limit 64])
  (define who 'certify-atomic-four-cycle)
  (unless (exact-nonnegative-integer? limit)
    (raise-argument-error who "exact-nonnegative-integer?" limit))
  (define fixture (make-atomic-four-cycle-fixture))
  (define calculus (atomic-four-cycle-fixture-calculus fixture))
  (define generators (atomic-four-cycle-fixture-generators fixture))
  (define request (atomic-four-cycle-fixture-request fixture))
  (define removals
    (for/list ([removed (in-list generators)])
      (define retained (remq removed generators))
      (define decision
        (decide-atomic-preorder
         calculus retained request #:limit analysis-default-limit))
      (when (analysis-limit? decision)
        (error who "fixed removal decision exceeded the default graph limit"))
      (define countervaluation
        (atomic-preorder-result-countervaluation decision))
      (atomic-removal-certificate
       removed decision
       (and (eq? (atomic-preorder-result-status decision)
                 'invalid-countervaluation)
            (atomic-countervaluation-verifies? countervaluation)))))
  (let/ec inconclusive
    (define (need-audit proof profile)
      (define result (make-coaction-audit proof profile limit))
      (if (analysis-limit? result) (inconclusive result) result))
    (define profile (atomic-four-cycle-fixture-old-base-profile fixture))
    (define source-audit
      (need-audit (atomic-four-cycle-fixture-source fixture) profile))
    (define comb-audit
      (need-audit (atomic-four-cycle-fixture-comb fixture) profile))
    (define balanced-audit
      (need-audit (atomic-four-cycle-fixture-balanced fixture) profile))
    (define comb-certificate
      (make-target-certificate
       'comb fixture
       (atomic-four-cycle-fixture-comb fixture)
       (atomic-four-cycle-fixture-comb-leaf-addresses fixture)
       source-audit comb-audit 3))
    (define balanced-certificate
      (make-target-certificate
       'balanced fixture
       (atomic-four-cycle-fixture-balanced fixture)
       (atomic-four-cycle-fixture-balanced-leaf-addresses fixture)
       source-audit balanced-audit 4))
    (define verified?
      (and (andmap atomic-removal-certificate-verified? removals)
           (eq? (atomic-preorder-result-status
                 (atomic-four-cycle-fixture-decision fixture))
                'valid-quoted)
           (equal? (atomic-preorder-result-proof
                    (atomic-four-cycle-fixture-decision fixture))
                   (atomic-four-cycle-fixture-comb fixture))
           (atomic-coaction-audit-equal? source-audit)
           (= (material-query-result-coefficient
               (atomic-coaction-audit-result source-audit))
              16)
           (= (material-query-result-coefficient
               (atomic-coaction-audit-result comb-audit))
              23)
           (= (material-query-result-coefficient
               (atomic-coaction-audit-result balanced-audit))
              26)
           (= (length (atomic-coaction-audit-empty-contributions source-audit)) 1)
           (= (length (atomic-coaction-audit-proper-contributions source-audit)) 15)
           (null? (atomic-coaction-audit-whole-contributions source-audit))
           (= (length (atomic-coaction-audit-empty-contributions comb-audit)) 1)
           (= (length (atomic-coaction-audit-proper-contributions comb-audit)) 21)
           (= (length (atomic-coaction-audit-whole-contributions comb-audit)) 1)
           (= (length (atomic-coaction-audit-empty-contributions balanced-audit)) 1)
           (= (length (atomic-coaction-audit-proper-contributions balanced-audit)) 24)
           (= (length (atomic-coaction-audit-whole-contributions balanced-audit)) 1)
           (atomic-target-ck-certificate-verified? comb-certificate)
           (atomic-target-ck-certificate-verified? balanced-certificate)
           (= (atomic-target-ck-certificate-full-excess comb-certificate) 7)
           (= (atomic-target-ck-certificate-full-excess balanced-certificate) 10)))
    (atomic-cycle-ck-certificate
     fixture removals source-audit comb-certificate balanced-certificate
     verified?)))
