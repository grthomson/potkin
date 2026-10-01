#lang racket/base

;; Native normalization/replay certificates.
;;
;; This module implements the finite algorithms of
;; CK_SEQUENT_NORMALIZATION_REUSE_PROOFS_2026-10-01.md.  Its cells and
;; certificates are immutable analysis metadata around POTKIN's existing
;; checked proofs, typed holes, CK witnesses, detached tuples and remainders.
;; They are not a second proof, context, cut, forest, or tensor carrier.
;;
;; Paper status.  Same-cell lifting, least exposure, read-partition guarding,
;; the union-find/LCA eligibility criterion, the stop/continue fold, integer
;; potential descent and maximal opaque replay are PROVED in the cited note.
;; The executable layer below checks concrete registered histories; a finite
;; test is not a mechanized proof of those universal statements.

(require racket/list
         racket/match
         racket/set
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/component-incidence.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "ancestry.rkt"
         "macro-summary.rkt"
         "material-hopf-selector.rkt"
         "material-stock.rkt")

(provide
 (struct-out normalization-signature)
 make-normalization-signature
 (struct-out formula-occurrence-position)
 boundary-formula-occurrences
 (struct-out exact-boundary-routing)
 make-exact-boundary-routing
 identity-boundary-routing
 (struct-out normalization-port-routing)
 make-normalization-port-routing
 (struct-out normalization-cell)
 register-normalization-cell
 register-principal-tensor-par-cell
 register-left-identity-cut-cell
 register-right-identity-cut-cell
 register-atomic-root-pair-quote-cell
 (struct-out normalization-cell-registry)
 make-normalization-cell-registry
 (struct-out normalization-event-request)
 make-normalization-event-request
 (struct-out normalization-potential)
 proof-normalization-potential
 forest-normalization-potential
 context-cut-ancestor-counts
 (struct-out replay-cache-handle)
 (struct-out normalization-crossing)
 (struct-out normalization-exposure)
 (struct-out replay-input-move)
 (struct-out normalization-event-certificate)
 (struct-out replay-read-class)
 (struct-out guarded-node-fold)
 (struct-out guarded-cut-fold)
 (struct-out projected-replay-state)
 (struct-out compiled-normalization-history)
 (struct-out base-purity-claim)
 (struct-out zipper-baseline-result)
 (struct-out normalization-replay-certificate)
 (struct-out normalization-replay-failure)
 (struct-out normalization-check-report)
 (struct-out normalization-replay-result)
 (struct-out guarded-source-cut-certificate)
 compile-normalization-replay
 check-normalization-replay-certificate
 replay-compiled-normalization
 run-normalization-zipper-baseline
 normalization-frontier-guarded?
 certify-guarded-source-cut

 ;; Checked contextual routing.  Formula and component occurrence transport
 ;; are deliberately separate pieces of registered equipment.
 (struct-out exact-component-routing)
 make-exact-component-routing
 identity-component-routing
 (struct-out equipped-formula-edge)
 make-equipped-formula-edge
 (struct-out normalization-principal-mark)
 make-normalization-principal-mark
 (struct-out normalization-rule-equipment)
 make-normalization-rule-equipment
 (struct-out normalization-ancestor-lift)
 register-normalization-ancestor-lift
 (struct-out normalization-routing-registry)
 make-normalization-routing-registry
 (struct-out contextual-routing-certificate)
 certify-contextual-normalization-event
 check-contextual-routing-certificate

 ;; Authentic finite causal interfaces and sequential pushout composition.
 (struct-out normalization-causal-interface)
 normalization-certificate-causal-interface
 normalization-causal-interface-authentic?
 compose-normalization-causal-interfaces
 normalization-causal-interface-equivalent?

 ;; Positive native elaboration, pulled causal constraints, and the integrated
 ;; elaborate/normalize/replay certificate.
 (struct-out normalization-macro-interpretation)
 make-normalization-macro-interpretation
 (struct-out interpreted-rule-potential-summary)
 (struct-out positive-normalization-elaboration)
 compile-positive-normalization-elaboration
 pullback-normalization-potential
 (struct-out normalization-collapse-analysis)
 analyze-normalization-collapse
 (struct-out source-aligned-frontier-certificate)
 certify-source-aligned-frontier
 (struct-out compositional-normalization-certificate)
 certify-compositional-normalization
 check-compositional-normalization-certificate)

;; Exact occurrence membership is supplied, never inferred from names, tags,
;; rule kinds or tree shape.  M is the common atomic-quotation macro bound.
(struct normalization-signature
  (calculus cut-occurrences tensor-occurrences par-occurrences macro-bound)
  #:transparent)

(struct formula-occurrence-position
  (component-index side formula local-index)
  #:transparent)

;; `pairs` is a total, type-preserving bijection between the formula
;; occurrences of two complete native boundaries.  Local indices distinguish
;; repeated equal-looking formula occurrences.
(struct exact-boundary-routing (source target pairs) #:transparent)

(struct normalization-port-routing (port-label routing) #:transparent)

;; LHS and RHS are native checked open terms (or positive complete terms in a
;; zero-port quotation).  Port labels are aligned with each native premise
;; telescope.  RHS labels are a permutation of LHS labels, enforcing one use.
(struct normalization-cell
  (id calculus role lhs rhs lhs-port-labels rhs-port-labels
      external-routing port-routings)
  #:transparent)

(struct normalization-cell-registry (signature cells table) #:transparent)
(struct normalization-event-request (id cell address) #:transparent)

(struct normalization-potential (N A H M L psi) #:transparent)

(struct replay-cache-handle
  (source-address current-address initial-cache-address boundary term
                  base-pure?)
  #:transparent)

(struct normalization-crossing
  (event-index event-id shell-addresses owners crossed-cache-addresses)
  #:transparent)

(struct normalization-exposure
  (event-index event-id old-cache-handles exposed-addresses
               retained-cache-handles refined-addresses native-witness
               reconstruction-ok?)
  #:transparent)

(struct replay-input-move
  (port-label before-address after-address term)
  #:transparent)

(struct normalization-event-certificate
  (index request cell before after shell-addresses read-node-identities
         read-source-origins input-moves fresh-node-identities
         external-routing potential-before potential-after inspections
         before-node-identities after-node-identities
         before-origin-representatives after-origin-representatives)
  #:transparent)

(struct replay-read-class (representative members ever-read?) #:transparent)

(struct guarded-node-fold
  (address eligible? polynomial scalar-count children)
  #:transparent)

;; The polynomial includes the empty cut and all guarded proper cuts.  The
;; witness-free whole endpoint is deliberately a separate scalar weight.
(struct guarded-cut-fold
  (polynomial empty-and-proper-count proper-count whole-weight
              eligible-addresses eligibility-table node-folds term-cap)
  #:transparent)

(struct projected-replay-state
  (index term survivor-addresses survivor-source-addresses native-witness
         endpoint-capture? cut-ancestor-counts)
  #:transparent)

(struct compiled-normalization-history
  (calculus registry source target states requests survivor-source-addresses
            survivor-boundaries output-routing survivor-routings
            endpoint-capture?)
  #:transparent)

(struct base-purity-claim
  (kind source-address native-witness forest pure?)
  #:transparent)

(struct zipper-baseline-result
  (target output-routing survivor-source-addresses survivor-target-addresses
          constructor-inspections opaque-interior-inspections valid?)
  #:transparent)

(struct normalization-replay-certificate
  (source target registry initial-frontier events first-crossing exposures
          initial-cache-handles survivor-source-addresses
          survivor-target-addresses read-partition ever-read-source-addresses
          guarded-fold compiled-history potentials material-profile
          base-purity-claims
          preparation-inspections replay-inspections
          opaque-interior-inspections zipper-baseline)
  #:transparent)

(struct normalization-replay-failure (code message details) #:transparent)

(struct normalization-check-report
  (valid? checks constructor-inspections opaque-interior-inspections details)
  #:transparent)

(struct normalization-replay-result
  (target states output-routing admission-inspections replay-inspections
          opaque-interior-inspections valid?)
  #:transparent)

(struct guarded-source-cut-certificate
  (source addresses witness detached forest remainder refill guarded?
          base-pure? whole-endpoint?)
  #:transparent)

;; Internal records.
(struct cell-binding (label term address) #:transparent)
(struct cell-match (bindings shell-addresses inspections) #:transparent)
(struct cell-application
  (target match input-moves fresh-relative-addresses inspections)
  #:transparent)
(struct rhs-instantiation (term fresh-relative-addresses inspections)
  #:transparent)
(struct native-replacement (term inspections) #:transparent)
(struct opaque-fill-result (term inspections) #:transparent)
(struct active-state
  (proof node-identities origin-representatives frontier parent ever-read)
  #:transparent)
(struct history-state
  (proof node-identities origin-representatives frontier)
  #:transparent)
(struct zipper-crumb (occurrence left right) #:transparent)

(define (failure code message [details (hash)])
  (normalization-replay-failure code message details))

(define (exact-registry-occurrence? calculus occurrence)
  (and (concrete-occurrence? occurrence)
       (eq? occurrence
            (calculus-lookup calculus
                             (concrete-occurrence-id occurrence)))))

(define (exact-term-in-calculus? calculus term)
  (and (checked-term? term)
       (checked-term-has-exact-calculus? term calculus)
       (term-admitted-by? calculus term)))

(define (check-occurrence-family who calculus name values)
  (unless (and (list? values) (andmap concrete-occurrence? values))
    (raise-argument-error who "(listof concrete-occurrence?)" values))
  (when (check-duplicates values eq?)
    (raise-arguments-error who "an occurrence family cannot repeat an exact object"
                           "family" name "occurrences" values))
  (for ([occurrence (in-list values)])
    (unless (exact-registry-occurrence? calculus occurrence)
      (raise-arguments-error
       who
       "every classified occurrence must be the exact object stored in the supplied calculus"
       "family" name "occurrence" occurrence))))

(define (make-normalization-signature calculus cuts tensors pars macro-bound)
  (define who 'make-normalization-signature)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (exact-nonnegative-integer? macro-bound)
    (raise-argument-error who "exact-nonnegative-integer?" macro-bound))
  (check-occurrence-family who calculus 'Cut cuts)
  (check-occurrence-family who calculus 'tensor tensors)
  (check-occurrence-family who calculus 'par pars)
  (define combined (append cuts tensors pars))
  (when (check-duplicates combined eq?)
    (raise-arguments-error
     who "Cut, tensor and par classifications must be disjoint exact objects"
     "occurrences" combined))
  (normalization-signature
   calculus
   (for/list ([occurrence (in-list cuts)]) occurrence)
   (for/list ([occurrence (in-list tensors)]) occurrence)
   (for/list ([occurrence (in-list pars)]) occurrence)
   macro-bound))

(define (occurrence-in-family? occurrence family)
  (and (memq occurrence family) #t))

(define (position-list component-index side context)
  (define-values (reversed _counts)
    (for/fold ([positions '()] [counts (hash)])
              ([formula (in-list (formula-context->list context))])
      (define index (add1 (hash-ref counts formula 0)))
      (values
       (cons (formula-occurrence-position
              component-index side formula index)
             positions)
       (hash-set counts formula index))))
  (reverse reversed))

(define (boundary-formula-occurrences boundary)
  (unless (hypersequent? boundary)
    (raise-argument-error
     'boundary-formula-occurrences "hypersequent?" boundary))
  (append-map
   (lambda (component)
     (define index (component-occurrence-index component))
     (define sequent (component-occurrence-sequent component))
     (append (position-list index 'left (sequent-left sequent))
             (position-list index 'right (sequent-right sequent))))
   (hypersequent-components boundary)))

(define (formula-position-compatible? source target)
  (and (eq? (formula-occurrence-position-side source)
            (formula-occurrence-position-side target))
       (equal? (formula-occurrence-position-formula source)
               (formula-occurrence-position-formula target))))

(define (make-exact-boundary-routing source target pairs)
  (define who 'make-exact-boundary-routing)
  (unless (hypersequent? source)
    (raise-argument-error who "hypersequent? source" source))
  (unless (hypersequent? target)
    (raise-argument-error who "hypersequent? target" target))
  (unless (and (list? pairs)
               (andmap (lambda (entry)
                         (and (pair? entry)
                              (formula-occurrence-position? (car entry))
                              (formula-occurrence-position? (cdr entry))))
                       pairs))
    (raise-argument-error
     who "(listof (cons/c formula-occurrence-position? formula-occurrence-position?))"
     pairs))
  (define source-positions (boundary-formula-occurrences source))
  (define target-positions (boundary-formula-occurrences target))
  (define routed-sources (map car pairs))
  (define routed-targets (map cdr pairs))
  (unless (and (= (length pairs) (length source-positions))
               (not (check-duplicates routed-sources equal?))
               (not (check-duplicates routed-targets equal?))
               (andmap (lambda (position)
                         (member position routed-sources equal?))
                       source-positions)
               (andmap (lambda (position)
                         (member position routed-targets equal?))
                       target-positions))
    (raise-arguments-error
     who
     "routing must be a total bijection on exact source and target formula occurrences"
     "source occurrences" source-positions
     "target occurrences" target-positions
     "pairs" pairs))
  (for ([entry (in-list pairs)])
    (unless (formula-position-compatible? (car entry) (cdr entry))
      (raise-arguments-error
       who "routing cannot relabel or move a formula between sequent sides"
       "source position" (car entry) "target position" (cdr entry))))
  (exact-boundary-routing
   source target (for/list ([entry (in-list pairs)]) entry)))

(define (identity-boundary-routing boundary)
  (unless (hypersequent? boundary)
    (raise-argument-error 'identity-boundary-routing "hypersequent?" boundary))
  (define positions (boundary-formula-occurrences boundary))
  (make-exact-boundary-routing
   boundary boundary (map cons positions positions)))

(define (make-normalization-port-routing port-label routing)
  (unless (and (symbol? port-label) (symbol-interned? port-label))
    (raise-argument-error
     'make-normalization-port-routing "interned-symbol?" port-label))
  (unless (exact-boundary-routing? routing)
    (raise-argument-error
     'make-normalization-port-routing "exact-boundary-routing?" routing))
  (normalization-port-routing port-label routing))

(define (valid-port-labels? labels count)
  (and (list? labels)
       (= (length labels) count)
       (andmap (lambda (label)
                 (and (symbol? label) (symbol-interned? label)))
               labels)
       (not (check-duplicates labels eq?))))

(define (telescope-boundary-by-label term labels)
  (for/hash ([entry (in-list (premise-telescope term))]
             [label (in-list labels)])
    (values label (telescope-entry-requirement entry))))

(define (register-normalization-cell
         id signature role lhs rhs lhs-port-labels rhs-port-labels routing
         #:port-routings [port-routings '()])
  (define who 'register-normalization-cell)
  (unless (and (symbol? id) (symbol-interned? id))
    (raise-argument-error who "interned-symbol? id" id))
  (unless (normalization-signature? signature)
    (raise-argument-error who "normalization-signature?" signature))
  (unless (and (symbol? role) (symbol-interned? role))
    (raise-argument-error who "interned-symbol? role" role))
  (define calculus (normalization-signature-calculus signature))
  (unless (and (checked-node? lhs)
               (exact-term-in-calculus? calculus lhs))
    (raise-argument-error
     who "positive exact checked LHS" lhs))
  (unless (and (checked-term? rhs)
               (exact-term-in-calculus? calculus rhs))
    (raise-argument-error who "exact checked RHS" rhs))
  (define lhs-telescope (premise-telescope lhs))
  (define rhs-telescope (premise-telescope rhs))
  (unless (valid-port-labels? lhs-port-labels (length lhs-telescope))
    (raise-argument-error who "distinct labels for every LHS physical port"
                          lhs-port-labels))
  (unless (valid-port-labels? rhs-port-labels (length rhs-telescope))
    (raise-argument-error who "distinct labels for every RHS physical port"
                          rhs-port-labels))
  (unless (and (= (length lhs-port-labels) (length rhs-port-labels))
               (andmap (lambda (label) (memq label rhs-port-labels))
                       lhs-port-labels))
    (raise-arguments-error
     who "every physical input must occur exactly once on each side"
     "LHS labels" lhs-port-labels "RHS labels" rhs-port-labels))
  (define lhs-boundaries (telescope-boundary-by-label lhs lhs-port-labels))
  (define rhs-boundaries (telescope-boundary-by-label rhs rhs-port-labels))
  (for ([label (in-list lhs-port-labels)])
    (unless (equal? (hash-ref lhs-boundaries label)
                    (hash-ref rhs-boundaries label))
      (raise-arguments-error
       who "a routed physical input must retain its entire typed boundary"
       "port" label
       "LHS boundary" (hash-ref lhs-boundaries label)
       "RHS boundary" (hash-ref rhs-boundaries label))))
  (unless (equal? (derivation-root-boundary lhs)
                  (derivation-root-boundary rhs))
    (raise-arguments-error
     who "a normalization cell must preserve its complete external boundary"
     "LHS boundary" (derivation-root-boundary lhs)
     "RHS boundary" (derivation-root-boundary rhs)))
  (unless (and (exact-boundary-routing? routing)
               (equal? (exact-boundary-routing-source routing)
                       (derivation-root-boundary lhs))
               (equal? (exact-boundary-routing-target routing)
                       (derivation-root-boundary rhs)))
    (raise-argument-error
     who "exact routing for the cell's complete external boundary" routing))
  (unless (and (list? port-routings)
               (andmap normalization-port-routing? port-routings)
               (not (check-duplicates
                     (map normalization-port-routing-port-label port-routings)
                     eq?)))
    (raise-argument-error
     who "distinct (listof normalization-port-routing?)" port-routings))
  (for ([entry (in-list port-routings)])
    (define label (normalization-port-routing-port-label entry))
    (define port-route (normalization-port-routing-routing entry))
    (unless (and (hash-has-key? lhs-boundaries label)
                 (equal? (exact-boundary-routing-source port-route)
                         (hash-ref lhs-boundaries label))
                 (equal? (exact-boundary-routing-target port-route)
                         (derivation-root-boundary rhs)))
      (raise-arguments-error
       who "a passive-port route must run from that exact input to the cell output"
       "port" label "routing" port-route)))
  (normalization-cell
   id calculus role lhs rhs
   (for/list ([label (in-list lhs-port-labels)]) label)
   (for/list ([label (in-list rhs-port-labels)]) label)
   routing (for/list ([entry (in-list port-routings)]) entry)))

(define (cell-root-cut? signature cell)
  (occurrence-in-family?
   (checked-node-occurrence (normalization-cell-lhs cell))
   (normalization-signature-cut-occurrences signature)))

(define (register-principal-tensor-par-cell
         id signature lhs rhs lhs-port-labels rhs-port-labels routing
         #:port-routings [port-routings '()])
  (define cell
    (register-normalization-cell
     id signature 'principal-tensor-par lhs rhs
     lhs-port-labels rhs-port-labels routing
     #:port-routings port-routings))
  (define root (normalization-cell-lhs cell))
  (define children (checked-node-children root))
  (unless (and (cell-root-cut? signature cell)
               (= (length children) 2)
               (checked-node? (first children))
               (checked-node? (second children))
               (occurrence-in-family?
                (checked-node-occurrence (first children))
                (normalization-signature-tensor-occurrences signature))
               (occurrence-in-family?
                (checked-node-occurrence (second children))
                (normalization-signature-par-occurrences signature)))
    (raise-arguments-error
     'register-principal-tensor-par-cell
     "the exact LHS shell must be Cut(tensor(...), par(...))"
     "LHS" root))
  cell)

(define (register-identity-cell
         who role rigid-slot id signature lhs rhs
         lhs-port-labels rhs-port-labels routing port-routings)
  (define cell
    (register-normalization-cell
     id signature role lhs rhs lhs-port-labels rhs-port-labels routing
     #:port-routings port-routings))
  (define children (checked-node-children lhs))
  (unless (and (cell-root-cut? signature cell)
               (= (length children) 2)
               (checked-node? (list-ref children (sub1 rigid-slot)))
               (checked-hole? rhs)
               (= (length (premise-telescope lhs)) 1)
               (= (length (premise-telescope rhs)) 1))
    (raise-arguments-error
     who "identity-Cut cell must read Cut and the declared rigid identity root, then return its sole input"
     "LHS" lhs "RHS" rhs))
  cell)

(define (register-left-identity-cut-cell
         id signature lhs rhs lhs-port-labels rhs-port-labels routing
         #:port-routings [port-routings '()])
  (register-identity-cell
   'register-left-identity-cut-cell 'left-identity-cut 1
   id signature lhs rhs lhs-port-labels rhs-port-labels routing port-routings))

(define (register-right-identity-cut-cell
         id signature lhs rhs lhs-port-labels rhs-port-labels routing
         #:port-routings [port-routings '()])
  (register-identity-cell
   'register-right-identity-cut-cell 'right-identity-cut 2
   id signature lhs rhs lhs-port-labels rhs-port-labels routing port-routings))

(define (register-atomic-root-pair-quote-cell
         id signature lhs rhs routing)
  (define cell
    (register-normalization-cell
     id signature 'atomic-root-pair-quote lhs rhs '() '() routing))
  (define children (checked-node-children lhs))
  (unless (and (cell-root-cut? signature cell)
               (= (length children) 2)
               (andmap checked-node? children)
               (andmap (lambda (child)
                         (null? (checked-node-children child)))
                       children)
               (checked-node? rhs)
               (null? (checked-node-children rhs)))
    (raise-arguments-error
     'register-atomic-root-pair-quote-cell
     "an atomic quote reads the Cut and both exact nullary roots and returns one exact nullary quote"
     "LHS" lhs "RHS" rhs))
  cell)

(define (make-normalization-cell-registry signature cells)
  (define who 'make-normalization-cell-registry)
  (unless (normalization-signature? signature)
    (raise-argument-error who "normalization-signature?" signature))
  (unless (and (list? cells) (andmap normalization-cell? cells))
    (raise-argument-error who "(listof normalization-cell?)" cells))
  (define calculus (normalization-signature-calculus signature))
  (define table
    (for/fold ([table (hasheq)]) ([cell (in-list cells)])
      (unless (eq? (normalization-cell-calculus cell) calculus)
        (raise-arguments-error
         who "every cell must belong to the signature's exact calculus snapshot"
         "cell" cell))
      (unless (cell-root-cut? signature cell)
        (raise-arguments-error
         who "this milestone admits only Cut-rooted registered cells"
         "cell" cell))
      (define id (normalization-cell-id cell))
      (when (hash-has-key? table id)
        (raise-arguments-error who "cell IDs must be unique" "duplicate" id))
      (hash-set table id cell)))
  (normalization-cell-registry
   signature (for/list ([cell (in-list cells)]) cell) table))

(define (make-normalization-event-request registry id cell-id address)
  (define who 'make-normalization-event-request)
  (unless (normalization-cell-registry? registry)
    (raise-argument-error who "normalization-cell-registry?" registry))
  (unless (and (symbol? id) (symbol-interned? id))
    (raise-argument-error who "interned-symbol? id" id))
  (unless (and (symbol? cell-id) (symbol-interned? cell-id))
    (raise-argument-error who "interned-symbol? cell-id" cell-id))
  (unless (address? address)
    (raise-argument-error who "address?" address))
  (define cell
    (hash-ref (normalization-cell-registry-table registry) cell-id #f))
  (unless cell
    (raise-arguments-error who "the event must name a cell in the exact registry"
                           "cell ID" cell-id))
  (normalization-event-request id cell address))

(define (node-count term)
  (if (checked-hole? term)
      0
      (add1 (for/sum ([child (in-list (checked-node-children term))])
              (node-count child)))))

(define (proof-normalization-potential term signature)
  (unless (checked-term? term)
    (raise-argument-error
     'proof-normalization-potential "checked-term?" term))
  (unless (normalization-signature? signature)
    (raise-argument-error
     'proof-normalization-potential "normalization-signature?" signature))
  (define calculus (normalization-signature-calculus signature))
  (unless (exact-term-in-calculus? calculus term)
    (raise-arguments-error
     'proof-normalization-potential
     "the term must carry the signature's exact calculus throughout"
     "term" term))
  (define cuts (normalization-signature-cut-occurrences signature))
  (define tensors (normalization-signature-tensor-occurrences signature))
  (define pars (normalization-signature-par-occurrences signature))
  (define-values (N A H)
    (let walk ([current term])
      (cond
        [(checked-hole? current) (values 0 0 0)]
        [else
         (define child-values
           (for/list ([child (in-list (checked-node-children current))])
             (call-with-values (lambda () (walk child)) list)))
         (define occurrence (checked-node-occurrence current))
         (define cut? (occurrence-in-family? occurrence cuts))
         (define active?
           (or cut?
               (occurrence-in-family? occurrence tensors)
               (occurrence-in-family? occurrence pars)))
         (values
          (add1 (for/sum ([entry (in-list child-values)]) (first entry)))
          (+ (if active? 1 0)
             (for/sum ([entry (in-list child-values)]) (second entry)))
          (+ (if cut?
                 (for/sum ([child (in-list (checked-node-children current))])
                   (node-count child))
                 0)
             (for/sum ([entry (in-list child-values)]) (third entry))))])))
  (define M (normalization-signature-macro-bound signature))
  (define L (+ N (* M A)))
  (normalization-potential N A H M L (+ (* A (+ 1 (* L L))) H)))

(define (forest-normalization-potential forest signature)
  (unless (proof-forest? forest)
    (raise-argument-error
     'forest-normalization-potential "proof-forest?" forest))
  (unless (normalization-signature? signature)
    (raise-argument-error
     'forest-normalization-potential "normalization-signature?" signature))
  (unless (eq? (proof-forest-calculus forest)
               (normalization-signature-calculus signature))
    (raise-arguments-error
     'forest-normalization-potential
     "forest potential requires one exact calculus snapshot"
     "forest" forest))
  ;; The forest value is additive by definition; never apply the connected
  ;; polynomial to aggregate forest statistics.
  (for/sum ([factor (in-list (proof-forest-factors forest))])
    (normalization-potential-psi
     (proof-normalization-potential factor signature))))

(define (context-cut-ancestor-counts context signature)
  (unless (checked-term? context)
    (raise-argument-error
     'context-cut-ancestor-counts "checked-term?" context))
  (unless (normalization-signature? signature)
    (raise-argument-error
     'context-cut-ancestor-counts "normalization-signature?" signature))
  (define cuts (normalization-signature-cut-occurrences signature))
  (for/list ([hole (in-list (puncture-addresses context))])
    (cons
     hole
     (for/sum ([depth (in-range (length hole))])
       (define ancestor (take hole depth))
       (define node (vertex-at-address context ancestor))
       (if (and node
                (occurrence-in-family?
                 (checked-node-occurrence node) cuts))
           1 0)))))

;; -------------------------------------------------------------------------
;; Opaque native matching, instantiation and tree surgery

(define (address-rebase old-root new-root address)
  (and (address-prefix? old-root address)
       (address-append new-root (drop address (length old-root)))))

(define (pattern-label-table term labels)
  (for/hash ([entry (in-list (premise-telescope term))]
             [label (in-list labels)])
    (values (telescope-entry-address entry) label)))

(define (match-cell-at term address cell)
  (define focus (checked-term-at-address term address))
  (cond
    [(not focus)
     (failure 'no-such-redex-address
              "the event address does not occur in the checked term"
              (hash 'address address))]
    [else
     (define lhs (normalization-cell-lhs cell))
     (define labels
       (pattern-label-table lhs (normalization-cell-lhs-port-labels cell)))
     (let/ec abort
       (define bindings '())
       (define shell '())
       (define inspections 0)
       (define (walk pattern candidate relative)
         (cond
           [(checked-hole? pattern)
            (unless (and (checked-term? candidate)
                         (eq? (checked-term-calculus candidate)
                              (normalization-cell-calculus cell))
                         (equal? (derivation-root-boundary candidate)
                                 (checked-hole-boundary pattern)))
              (abort
               (failure
                'input-interface-mismatch
                "a cell input does not match its exact physical interface"
                (hash 'address (address-append address relative)
                      'expected (checked-hole-boundary pattern)
                      'actual (and (checked-term? candidate)
                                   (derivation-root-boundary candidate))))))
            (set! bindings
                  (cons (cell-binding
                         (hash-ref labels relative)
                         candidate
                         (address-append address relative))
                        bindings))]
           [else
            (unless (checked-node? candidate)
              (abort
               (failure
                'rigid-shell-hidden
                "a rigid cell constructor cannot match a typed vacancy"
                (hash 'address (address-append address relative)))))
            (set! inspections (add1 inspections))
            (unless (eq? (checked-node-occurrence candidate)
                         (checked-node-occurrence pattern))
              (abort
               (failure
                'wrong-rigid-occurrence
                "the concrete event does not match the registered exact read shell"
                (hash 'address (address-append address relative)
                      'expected (checked-node-occurrence pattern)
                      'actual (checked-node-occurrence candidate)))))
            (define pattern-children (checked-node-children pattern))
            (define candidate-children (checked-node-children candidate))
            (unless (= (length pattern-children) (length candidate-children))
              (abort
               (failure 'wrong-rigid-arity
                        "a matched rigid node has the wrong child count"
                        (hash 'address (address-append address relative)))))
            (set! shell (cons (address-append address relative) shell))
            (for ([pattern-child (in-list pattern-children)]
                  [candidate-child (in-list candidate-children)]
                  [slot (in-naturals 1)])
              (walk pattern-child candidate-child
                    (address-append relative (list slot))))]))
       (walk lhs focus root-address)
       (cell-match
        (sort bindings address<? #:key cell-binding-address)
        (sort shell address<?)
        inspections))]))

(define (binding-by-label bindings label)
  (findf (lambda (binding) (eq? (cell-binding-label binding) label))
         bindings))

(define (instantiate-cell-rhs cell bindings)
  (define rhs (normalization-cell-rhs cell))
  (define labels
    (pattern-label-table rhs (normalization-cell-rhs-port-labels cell)))
  (let/ec abort
    (define constructions 0)
    (define fresh-relative '())
    (define (walk current relative)
      (cond
        [(checked-hole? current)
         (define binding
           (binding-by-label bindings (hash-ref labels relative)))
         (unless binding
           (abort
            (failure 'missing-routed-input
                     "the RHS names no corresponding exact LHS input"
                     (hash 'address relative))))
         (cell-binding-term binding)]
        [else
         (define children
           (for/list ([child (in-list (checked-node-children current))]
                      [slot (in-naturals 1)])
             (walk child (address-append relative (list slot)))))
         (define assembled
           (assemble-checked-application
            (normalization-cell-calculus cell)
            (checked-node-occurrence current)
            children
            #:expected (derivation-root-boundary current)))
         (when (validation-error? assembled)
           (abort
            (failure
             'rhs-native-assembly-failed
             "the registered RHS failed native checked-child assembly"
             (hash 'address relative 'validation-error assembled))))
         (set! constructions (add1 constructions))
         (set! fresh-relative (cons relative fresh-relative))
         assembled]))
    (define term (walk rhs root-address))
    (rhs-instantiation
     term (sort fresh-relative address<?) constructions)))

(define (replace-at-address/opaque term address replacement)
  (let/ec abort
    (define inspections 0)
    (define (walk current remaining)
      (cond
        [(null? remaining) replacement]
        [(checked-hole? current)
         (abort
          (failure 'replacement-through-hole
                   "native local replacement cannot descend through a vacancy"
                   (hash 'remaining remaining)))]
        [else
         (set! inspections (add1 inspections))
         (define slot (car remaining))
         (define children (checked-node-children current))
         (unless (<= slot (length children))
           (abort
            (failure 'no-such-redex-address
                     "the local replacement path names no ordered child"
                     (hash 'remaining remaining))))
         (define rebuilt-children
           (for/list ([child (in-list children)]
                      [index (in-naturals 1)])
             (if (= index slot)
                 (walk child (cdr remaining))
                 child)))
         (define assembled
           (assemble-checked-application
            (checked-term-calculus current)
            (checked-node-occurrence current)
            rebuilt-children
            #:expected (derivation-root-boundary current)))
         (when (validation-error? assembled)
           (abort
            (failure
             'ancestor-native-assembly-failed
             "rebuilding the checked ancestor spine failed"
             (hash 'remaining remaining 'validation-error assembled))))
         assembled]))
    (define result (walk term address))
    (native-replacement result inspections)))

(define (apply-cell-at term request)
  (define cell (normalization-event-request-cell request))
  (define address (normalization-event-request-address request))
  (let/ec abort
    (define matched (match-cell-at term address cell))
    (when (normalization-replay-failure? matched) (abort matched))
    (define instantiation
      (instantiate-cell-rhs cell (cell-match-bindings matched)))
    (when (normalization-replay-failure? instantiation)
      (abort instantiation))
    (define replacement
      (replace-at-address/opaque
       term address (rhs-instantiation-term instantiation)))
    (when (normalization-replay-failure? replacement)
      (abort replacement))
    (define rhs-address-by-label
      (for/hash ([entry
                  (in-list
                   (premise-telescope (normalization-cell-rhs cell)))]
                 [label
                  (in-list (normalization-cell-rhs-port-labels cell))])
        (values label
                (address-append address
                                (telescope-entry-address entry)))))
    (define moves
      (for/list ([binding (in-list (cell-match-bindings matched))])
        (replay-input-move
         (cell-binding-label binding)
         (cell-binding-address binding)
         (hash-ref rhs-address-by-label (cell-binding-label binding))
         (cell-binding-term binding))))
    (cell-application
     (native-replacement-term replacement) matched moves
     (rhs-instantiation-fresh-relative-addresses instantiation)
     (+ (cell-match-inspections matched)
        (rhs-instantiation-inspections instantiation)
        (native-replacement-inspections replacement)))))

(define (opaque-fill-context context source-port-order fillers)
  (define telescope (premise-telescope context))
  (unless (= (length telescope) (length source-port-order))
    (error 'opaque-fill-context "internal survivor/telescope mismatch"))
  (define filler-by-source
    (for/hash ([source (in-list source-port-order)]
               [filler (in-list fillers)])
      (values source filler)))
  (define source-by-hole
    (for/hash ([entry (in-list telescope)]
               [source (in-list source-port-order)])
      (values (telescope-entry-address entry) source)))
  (let/ec abort
    (define inspections 0)
    (define (walk current relative)
      (cond
        [(checked-hole? current)
         (define filler
           (hash-ref filler-by-source (hash-ref source-by-hole relative)))
         (unless (and (checked-node? filler)
                      (eq? (checked-node-calculus filler)
                           (checked-term-calculus context))
                      (equal? (derivation-root-boundary filler)
                              (checked-hole-boundary current)))
           (abort
            (failure 'replay-filler-interface-mismatch
                     "an opaque filler has the wrong exact calculus or boundary"
                     (hash 'address relative 'filler filler))))
         filler]
        [else
         (set! inspections (add1 inspections))
         (define children
           (for/list ([child (in-list (checked-node-children current))]
                      [slot (in-naturals 1)])
             (walk child (address-append relative (list slot)))))
         (define result
           (assemble-checked-application
            (checked-node-calculus current)
            (checked-node-occurrence current)
            children
            #:expected (derivation-root-boundary current)))
         (when (validation-error? result)
           (abort
            (failure 'opaque-fill-native-assembly-failed
                     "native opaque context filling failed"
                     (hash 'address relative 'validation-error result))))
         result]))
    (define result (walk context root-address))
    (opaque-fill-result result inspections)))

(define (routing-compose first-route second-route)
  (unless (equal? (exact-boundary-routing-target first-route)
                  (exact-boundary-routing-source second-route))
    (error 'routing-compose "incompatible exact boundary routes"))
  (define second-table
    (for/hash ([entry
                (in-list (exact-boundary-routing-pairs second-route))])
      (values (car entry) (cdr entry))))
  (make-exact-boundary-routing
   (exact-boundary-routing-source first-route)
   (exact-boundary-routing-target second-route)
   (for/list ([entry
               (in-list (exact-boundary-routing-pairs first-route))])
     (cons (car entry) (hash-ref second-table (cdr entry))))))

;; -------------------------------------------------------------------------
;; Node identities, origins and exact read partitions

(define (source-node-identity address)
  (list 'source address))

(define (fresh-node-identity event-id relative-address)
  (list 'event event-id relative-address))

(define (source-node-identity-address identity)
  (and (list? identity)
       (= (length identity) 2)
       (eq? (first identity) 'source)
       (address? (second identity))
       (second identity)))

(define (initial-node-map source)
  (for/hash ([address (in-list (vertex-addresses source))])
    (values address (source-node-identity address))))

(define (initial-origin-map source)
  (for/hash ([address (in-list (vertex-addresses source))])
    (values address address)))

(define (initial-parent source)
  (for/hash ([address (in-list (vertex-addresses source))])
    (values address address)))

(define (uf-find parent item)
  (define next (hash-ref parent item item))
  (if (equal? next item) item (uf-find parent next)))

(define (uf-union parent items)
  (define roots
    (sort (remove-duplicates
           (map (lambda (item) (uf-find parent item)) items)
           equal?)
          address<?))
  (cond
    [(null? roots) (values parent #f)]
    [else
     (define representative (car roots))
     (values
      (for/fold ([updated parent]) ([root (in-list (cdr roots))])
        (hash-set updated root representative))
      representative)]))

(define (class-members parent source-addresses representative)
  (sort
   (for/list ([address (in-list source-addresses)]
              #:when (equal? (uf-find parent address)
                             (uf-find parent representative)))
     address)
   address<?))

(define (copy-map-outside-subtree table root)
  (for/hash ([(address value) (in-hash table)]
             #:unless (address-prefix? root address))
    (values address value)))

(define (copy-input-subtrees table moves)
  (for*/fold ([copied (hash)])
             ([move (in-list moves)]
              [(address value) (in-hash table)]
              #:when (address-prefix?
                      (replay-input-move-before-address move) address))
    (hash-set copied
              (address-rebase
               (replay-input-move-before-address move)
               (replay-input-move-after-address move)
               address)
              value)))

(define (hash-union/right left right)
  (for/fold ([result left]) ([(key value) (in-hash right)])
    (hash-set result key value)))

(define (transition-identities+origins
         source-addresses state request application)
  (define redex (normalization-event-request-address request))
  (define event-id (normalization-event-request-id request))
  (define shell (cell-match-shell-addresses
                 (cell-application-match application)))
  (define before-origins (active-state-origin-representatives state))
  (define before-identities (active-state-node-identities state))
  (define parent0 (active-state-parent state))
  (define shell-representatives
    (for/list ([address (in-list shell)])
      (uf-find parent0 (hash-ref before-origins address))))
  (define read-before
    (sort
     (remove-duplicates
      (append-map
       (lambda (representative)
         (class-members parent0 source-addresses representative))
       shell-representatives)
      equal?)
     address<?))
  (define-values (parent1 fresh-representative)
    (uf-union parent0 shell-representatives))
  (define read-after
    (if fresh-representative
        (class-members parent1 source-addresses fresh-representative)
        '()))
  (define ever-read
    (set-union (active-state-ever-read state)
               (list->set read-after)))
  (define moves (cell-application-input-moves application))
  (define identities-outside
    (copy-map-outside-subtree before-identities redex))
  (define origins-outside
    (copy-map-outside-subtree before-origins redex))
  (define moved-identities (copy-input-subtrees before-identities moves))
  (define moved-origins (copy-input-subtrees before-origins moves))
  (define base-identities
    (hash-union/right identities-outside moved-identities))
  (define base-origins
    (hash-union/right origins-outside moved-origins))
  (define fresh-relative (cell-application-fresh-relative-addresses application))
  (define after-identities
    (for/fold ([table base-identities])
              ([relative (in-list fresh-relative)])
      (hash-set table
                (address-append redex relative)
                (fresh-node-identity event-id relative))))
  (define after-origins
    (for/fold ([table base-origins])
              ([relative (in-list fresh-relative)])
      (hash-set table
                (address-append redex relative)
                fresh-representative)))
  (values after-identities after-origins parent1 ever-read
          (map (lambda (address) (hash-ref before-identities address)) shell)
          read-after
          (map (lambda (relative)
                 (fresh-node-identity event-id relative))
               fresh-relative)))

(define (partition-from-parent parent source-addresses ever-read)
  (define grouped
    (for/fold ([table (hash)]) ([address (in-list source-addresses)])
      (define representative (uf-find parent address))
      (hash-update table representative
                   (lambda (members) (cons address members)) '())))
  (for/list ([representative (in-list (sort (hash-keys grouped) address<?))])
    (define members (sort (hash-ref grouped representative) address<?))
    (replay-read-class
     representative members
     (for/or ([member (in-list members)]) (set-member? ever-read member)))))

;; -------------------------------------------------------------------------
;; Native cache frontiers and least prefix exposure

(define (term-cut-free?/count term signature)
  (define cuts (normalization-signature-cut-occurrences signature))
  (let walk ([current term])
    (cond
      [(checked-hole? current) (values #t 0)]
      [else
       (define child-results
         (for/list ([child (in-list (checked-node-children current))])
           (call-with-values (lambda () (walk child)) list)))
       (values
        (and (not (occurrence-in-family?
                   (checked-node-occurrence current) cuts))
             (andmap first child-results))
        (add1 (for/sum ([result (in-list child-results)])
                (second result))))])))

(define (initial-cache-handles source witness signature selector)
  (let/ec abort
    (define inspections 0)
    (define handles
      (for/list ([entry (in-list (cut-witness-detached witness))])
        (define term (detached-entry-term entry))
        (define-values (cut-free? inspected)
          (term-cut-free?/count term signature))
        (set! inspections (+ inspections inspected))
        (unless cut-free?
          (abort
           (failure
            'cache-not-cut-free
            "every admitted opaque cache must be certified Gentzen-Cut-free"
            (hash 'address (detached-entry-address entry)))))
        (define pure?
          (and selector
               (material-hopf-selector-forest-pure?
                selector
                (make-proof-forest
                 (checked-node-calculus source) (list term)))))
        (replay-cache-handle
         (detached-entry-address entry)
         (detached-entry-address entry)
         (detached-entry-address entry)
         (derivation-root-boundary term)
         term pure?)))
    (values handles inspections)))

(define (frontier-owner frontier address)
  (define found
    (findf (lambda (handle)
             (address-prefix?
              (replay-cache-handle-current-address handle) address))
           frontier))
  (if found (replay-cache-handle-source-address found) 'remainder))

(define (cell-shell-addresses request)
  (define root (normalization-event-request-address request))
  (for/list ([relative
              (in-list
               (vertex-addresses
                (normalization-cell-lhs
                 (normalization-event-request-cell request))))])
    (address-append root relative)))

(define (prefix-path root descendant)
  (for/list ([depth (in-range (length root)
                              (add1 (length descendant)))])
    (take descendant depth)))

(define (canonical-addresses addresses)
  (sort (remove-duplicates addresses equal?) address<?))

(define (frontier-native-witness proof addresses)
  (cond
    [(and (= (length addresses) 1)
          (equal? (car addresses) root-address))
     #f]
    [else (make-cut-witness proof addresses)]))

(define (compute-least-exposure state request event-index selector)
  (define proof (active-state-proof state))
  (define frontier (active-state-frontier state))
  (define shell (cell-shell-addresses request))
  (define owners (map (lambda (address) (frontier-owner frontier address)) shell))
  (define distinct-owners (remove-duplicates owners equal?))
  (cond
    [(<= (length distinct-owners) 1)
     (values #f #f frontier)]
    [(not (eq? (frontier-owner frontier
                               (normalization-event-request-address request))
               'remainder))
     (values
      (failure
       'crossing-root-inside-cache
       "a mixed shell cannot escape from a redex rooted inside an opaque cache"
       (hash 'event (normalization-event-request-id request)
             'owners owners))
      #f frontier)]
    [else
     (define touched
       (filter
        (lambda (handle)
          (for/or ([address (in-list shell)])
            (address-prefix?
             (replay-cache-handle-current-address handle) address)))
        frontier))
     (define exposed
       (canonical-addresses
        (append-map
         (lambda (handle)
           (define root (replay-cache-handle-current-address handle))
           (append-map
            (lambda (address) (prefix-path root address))
            (filter (lambda (address) (address-prefix? root address)) shell)))
         touched)))
     (define exposed-set (list->set exposed))
     (define retained-addresses
       (canonical-addresses
        (append-map
         (lambda (address)
           (define node (vertex-at-address proof address))
           (if node
               (for/list ([child (in-list (checked-node-children node))]
                          [slot (in-naturals 1)]
                          #:when
                          (let ([child-address
                                 (address-append address (list slot))])
                            (and (checked-node? child)
                                 (not (set-member? exposed-set child-address)))))
                 (address-append address (list slot)))
               '()))
         exposed)))
     (define untouched
       (filter (lambda (handle) (not (memq handle touched))) frontier))
     (define retained
       (for/list ([address (in-list retained-addresses)])
         (define identity
           (hash-ref (active-state-node-identities state) address #f))
         (define source-address (and identity
                                     (source-node-identity-address identity)))
         (unless source-address
           (error 'compute-least-exposure
                  "least exposure attempted to re-hide a fresh constructor"))
         (define term (vertex-at-address proof address))
         (define parent-cache
           (findf
            (lambda (handle)
              (address-prefix?
               (replay-cache-handle-current-address handle) address))
            touched))
         (replay-cache-handle
          source-address address
          (replay-cache-handle-initial-cache-address parent-cache)
          (derivation-root-boundary term) term
          (replay-cache-handle-base-pure? parent-cache))))
     (define refined
       (sort (append untouched retained)
             address<? #:key replay-cache-handle-current-address))
     (define refined-addresses
       (map replay-cache-handle-current-address refined))
     (define witness (frontier-native-witness proof refined-addresses))
     (when (cut-error? witness)
       (error 'compute-least-exposure
              "least exposure did not form a native CK frontier: ~e" witness))
     (define exposure
       (normalization-exposure
        event-index (normalization-event-request-id request)
        touched exposed retained refined-addresses witness
        (or (not witness) (cut-witness-reconstructs? witness))))
     (define crossing
       (normalization-crossing
        event-index (normalization-event-request-id request)
        shell owners
        (map replay-cache-handle-source-address touched)))
     (values crossing exposure refined)]))

(define (route-frontier-after-application frontier application target)
  (define moves (cell-application-input-moves application))
  (define routed
    (for/list ([handle (in-list frontier)])
      (define old (replay-cache-handle-current-address handle))
      (define move
        (findf (lambda (candidate)
                 (address-prefix?
                  (replay-input-move-before-address candidate) old))
               moves))
      (define new
        (if move
            (address-rebase
             (replay-input-move-before-address move)
             (replay-input-move-after-address move)
             old)
            old))
      (define term (vertex-at-address target new))
      (unless term
        (error 'route-frontier-after-application
               "an opaque survivor was not routed as a complete subtree"))
      (struct-copy replay-cache-handle handle
                   [current-address new]
                   [term term])))
  (define ordered
    (sort routed address<? #:key replay-cache-handle-current-address))
  (for* ([left (in-list ordered)] [right (in-list ordered)]
         #:unless (eq? left right))
    (when (address-prefix?
           (replay-cache-handle-current-address left)
           (replay-cache-handle-current-address right))
      (error 'route-frontier-after-application
             "routed survivor handles ceased to be a CK antichain")))
  ordered)

;; -------------------------------------------------------------------------
;; LCA saturation and guarded stop/continue folding

(define (longest-common-prefix addresses)
  (cond
    [(null? addresses) root-address]
    [else
     (let loop ([prefix (car addresses)] [remaining (cdr addresses)])
       (cond
         [(null? remaining) prefix]
         [else
          (define next (car remaining))
          (define common-length
            (let compare ([left prefix] [right next] [count 0])
              (if (and (pair? left) (pair? right)
                       (= (car left) (car right)))
                  (compare (cdr left) (cdr right) (add1 count))
                  count)))
          (loop (take prefix common-length) (cdr remaining))]))]))

(define (eligibility-from-partition source partition)
  (define vertices (vertex-addresses source))
  (define marks
    (for/fold ([table
                (for/hash ([address (in-list vertices)])
                  (values address 1))])
              ([class (in-list partition)])
      (define members (replay-read-class-members class))
      (define lca (longest-common-prefix members))
      (hash-update table lca
                   (lambda (value) (- value (length members))) 0)))
  (define sums (make-hash))
  (define (walk node address)
    (define subtotal
      (+ (hash-ref marks address 0)
         (for/sum ([child (in-list (checked-node-children node))]
                   [slot (in-naturals 1)])
           (walk child (address-append address (list slot))))))
    (hash-set! sums address subtotal)
    subtotal)
  (walk source root-address)
  (for/hash ([address (in-list vertices)])
    (values address (zero? (hash-ref sums address)))))

(define (poly-one) (hash 0 1))

(define (poly-multiply/cap left right cap)
  (cond
    [(analysis-limit? left) left]
    [(analysis-limit? right) right]
    [else
     (let/ec abort
       (for*/fold ([result (hash)])
                  ([(left-degree left-coefficient) (in-hash left)]
                   [(right-degree right-coefficient) (in-hash right)])
         (define updated
           (hash-update result (+ left-degree right-degree)
                        (lambda (coefficient)
                          (+ coefficient
                             (* left-coefficient right-coefficient)))
                        0))
         (if (> (hash-count updated) cap)
             (abort
              (analysis-limit
               'not-computed-limit
               "the guarded factor polynomial exceeded its term cap"
               'guarded-cut-fold cap (hash-count updated)
               'expanded-polynomial-terms (hash)))
             updated)))]))

(define (poly-add-stop polynomial)
  (if (analysis-limit? polynomial)
      polynomial
      (hash-update polynomial 1 add1 0)))

(define (compute-guarded-fold source partition term-cap)
  (define eligibility (eligibility-from-partition source partition))
  (define node-folds '())
  (define (walk node address root?)
    (define child-results
      (for/list ([child (in-list (checked-node-children node))]
                 [slot (in-naturals 1)])
        (walk child (address-append address (list slot)) #f)))
    (define continue-polynomial
      (for/fold ([polynomial (poly-one)])
                ([result (in-list child-results)])
        (poly-multiply/cap
         polynomial (guarded-node-fold-polynomial result) term-cap)))
    (define continue-count
      (for/product ([result (in-list child-results)])
        (guarded-node-fold-scalar-count result)))
    (define eligible? (hash-ref eligibility address))
    (define polynomial
      (if (and eligible? (not root?))
          (poly-add-stop continue-polynomial)
          continue-polynomial))
    (define scalar-count
      (+ continue-count (if (and eligible? (not root?)) 1 0)))
    (define result
      (guarded-node-fold
       address eligible? polynomial scalar-count child-results))
    (set! node-folds (cons result node-folds))
    result)
  (define root-result (walk source root-address #t))
  (guarded-cut-fold
   (guarded-node-fold-polynomial root-result)
   (guarded-node-fold-scalar-count root-result)
   (sub1 (guarded-node-fold-scalar-count root-result))
   1
   (sort
    (for/list ([(address eligible?) (in-hash eligibility)] #:when eligible?)
      address)
    address<?)
   eligibility
   (sort node-folds address<? #:key guarded-node-fold-address)
   term-cap))

(define (read-classes-equal? left right)
  (equal?
   (map replay-read-class-members left)
   (map replay-read-class-members right)))

;; -------------------------------------------------------------------------
;; Source projection and compiled open histories

(define (addresses-for-source-survivors node-identities survivors)
  (define wanted (map source-node-identity survivors))
  (define pairs
    (for/list ([(address identity) (in-hash node-identities)]
               #:when (member identity wanted equal?))
      (cons address (source-node-identity-address identity))))
  (sort pairs address<? #:key car))

(define (project-history-state state index survivors signature)
  (define proof (history-state-proof state))
  (define pairs
    (addresses-for-source-survivors
     (history-state-node-identities state) survivors))
  (unless (= (length pairs) (length survivors))
    (error 'project-history-state
           "a final opaque source survivor was not present in every state"))
  (define addresses (map car pairs))
  (define sources (map cdr pairs))
  (cond
    [(null? addresses)
     (projected-replay-state
      index proof '() '() #f #f (context-cut-ancestor-counts proof signature))]
    [(and (= (length addresses) 1)
          (equal? (car addresses) root-address))
     (define context
       (identity-context (checked-term-calculus proof)
                         (derivation-root-boundary proof)))
     (projected-replay-state
      index context addresses sources #f #t
      (context-cut-ancestor-counts context signature))]
    [else
     (define witness (make-cut-witness proof addresses))
     (when (cut-error? witness)
       (error 'project-history-state
              "the survivor projection is not a native CK cut: ~e" witness))
     (projected-replay-state
      index (cut-witness-remainder witness) addresses sources witness #f
      (context-cut-ancestor-counts (cut-witness-remainder witness)
                                   signature))]))

(define (cell-port-route cell label)
  (define entry
    (findf (lambda (candidate)
             (eq? label
                  (normalization-port-routing-port-label candidate)))
           (normalization-cell-port-routings cell)))
  (and entry (normalization-port-routing-routing entry)))

(define (compiled-output-routing source events)
  (define route (identity-boundary-routing (derivation-root-boundary source)))
  (let/ec abort
    (for ([event (in-list events)])
      (define next
        (normalization-cell-external-routing
         (normalization-event-certificate-cell event)))
      ;; POTKIN presently has component incidence but no general native
      ;; formula-occurrence lifting through an arbitrary surrounding context.
      ;; Exact replay therefore accepts cells whose local complete boundary is
      ;; the history's complete boundary; otherwise it reports the gate.
      (unless (and (equal? (exact-boundary-routing-source next)
                           (exact-boundary-routing-target route))
                   (equal? (exact-boundary-routing-target next)
                           (derivation-root-boundary
                            (normalization-event-certificate-after event))))
        (abort
         (failure
          'routing-lift-unavailable
          "native formula routing cannot yet be lifted through this nonidentity surrounding boundary"
          (hash 'event
                (normalization-event-request-id
                 (normalization-event-certificate-request event))))))
      (set! route (routing-compose route next)))
    route))

(define (compiled-survivor-routings survivors states events target)
  (let/ec abort
    (for/hash ([source-address (in-list survivors)])
      (define route #f)
      (for ([event (in-list events)])
        (define before-map
          (normalization-event-certificate-before-node-identities event))
        (define current-pair
          (for/first ([(address identity) (in-hash before-map)]
                      #:when
                      (equal? identity (source-node-identity source-address)))
            (cons address identity)))
        (when current-pair
          (define current-address (car current-pair))
          (define move
            (findf
             (lambda (candidate)
               (equal? current-address
                       (replay-input-move-before-address candidate)))
             (normalization-event-certificate-input-moves event)))
          (when move
            (define declared
              (cell-port-route
               (normalization-event-certificate-cell event)
               (replay-input-move-port-label move)))
            (unless declared
              (abort
               (failure
                'missing-survivor-routing
                "a replayed opaque survivor lacks a registered exact passive route"
                (hash 'source-address source-address
                      'event
                      (normalization-event-request-id
                       (normalization-event-certificate-request event))))))
            (set! route declared))))
      (unless route
        (define source-state (car states))
        (define source-pair
          (findf (lambda (entry) (equal? (cdr entry) source-address))
                 (map cons
                      (projected-replay-state-survivor-addresses source-state)
                      (projected-replay-state-survivor-source-addresses
                       source-state))))
        (define source-term
          (and source-pair (pair? events)
               (vertex-at-address
                (normalization-event-certificate-before (car events))
                (car source-pair))))
        (when (and source-term
                   (equal? (derivation-root-boundary source-term)
                           (derivation-root-boundary target)))
          (set! route
                (identity-boundary-routing
                 (derivation-root-boundary source-term)))))
      (unless route
        (abort
         (failure
          'survivor-routing-unavailable
          "the registered history does not expose an exact route from a survivor interface to the output"
          (hash 'source-address source-address))))
      (values source-address route))))

(define (compile-open-history source target registry requests events states
                              survivors signature)
  (define projected
    (for/list ([state (in-list states)] [index (in-naturals 0)])
      (project-history-state state index survivors signature)))
  (let/ec abort
    ;; Recheck the projected history using the same registered cells on native
    ;; open contexts.  No survivor interior is present to inspect.
    (for ([before-state (in-list projected)]
          [after-state (in-list (cdr projected))]
          [request (in-list requests)])
      (define application
        (apply-cell-at (projected-replay-state-term before-state) request))
      (when (normalization-replay-failure? application)
        (abort application))
      (unless (equal? (cell-application-target application)
                      (projected-replay-state-term after-state))
        (abort
         (failure
          'projected-history-mismatch
          "puncturing final survivors did not project the same registered history"
          (hash 'event (normalization-event-request-id request))))))
    (define output-routing (compiled-output-routing source events))
    (when (normalization-replay-failure? output-routing)
      (abort output-routing))
    (define survivor-routings
      (if (null? survivors)
          (hash)
          (compiled-survivor-routings
           survivors projected events target)))
    (when (normalization-replay-failure? survivor-routings)
      (abort survivor-routings))
    (define source-terms
      (for/list ([source-address (in-list survivors)])
        (vertex-at-address source source-address)))
    (compiled-normalization-history
     (normalization-signature-calculus signature)
     registry
     (projected-replay-state-term (car projected))
     (projected-replay-state-term (last projected))
     projected requests survivors
     (map derivation-root-boundary source-terms)
     output-routing survivor-routings
     (and (= (length survivors) 1)
          (projected-replay-state-endpoint-capture? (last projected))))))

;; -------------------------------------------------------------------------
;; Concrete history compilation

(define (validate-history-input source initial-frontier registry requests profile)
  (define signature (normalization-cell-registry-signature registry))
  (define calculus (normalization-signature-calculus signature))
  (cond
    [(not (and (complete-proof? source)
               (exact-term-in-calculus? calculus source)))
     (failure 'invalid-source
              "normalization replay requires one complete proof in the exact cell calculus")]
    [(not (cut-witness? initial-frontier))
     (failure 'invalid-initial-frontier
              "the initial cache frontier must be an existing native CK witness")]
    [(not (eq? (cut-witness-source initial-frontier) source))
     (failure 'foreign-initial-frontier
              "the initial frontier must witness this exact source proof object")]
    [(not (cut-witness-reconstructs? initial-frontier))
     (failure 'invalid-initial-reconstruction
              "the initial native CK frontier does not reconstruct its source")]
    [(not (and (list? requests)
               (andmap normalization-event-request? requests)))
     (failure 'invalid-history "the concrete history must be a list of event requests")]
    [(check-duplicates (map normalization-event-request-id requests) eq?)
     => (lambda (duplicate)
          (failure 'duplicate-event-identity
                   "fresh event namespaces must be fixed and pairwise distinct"
                   (hash 'duplicate duplicate)))]
    [(for/or ([request (in-list requests)])
       (define cell (normalization-event-request-cell request))
       (not (eq? cell
                 (hash-ref (normalization-cell-registry-table registry)
                           (normalization-cell-id cell) #f))))
     (failure 'foreign-cell
              "every event must retain the exact cell object stored in this registry")]
    [(and profile
          (or (not (material-profile? profile))
              (not (eq? (material-profile-calculus profile) calculus))))
     (failure 'foreign-material-profile
              "base-purity claims require one exact calculus snapshot")]
    [else #f]))

(define (state-frontier-addresses frontier)
  (map replay-cache-handle-current-address frontier))

(define (frontier-proper-or-endpoint-valid? proof frontier)
  (define addresses (state-frontier-addresses frontier))
  (cond
    [(and (= (length addresses) 1)
          (equal? (car addresses) root-address)) #t]
    [else
     (define witness (make-cut-witness proof addresses))
     (and (cut-witness? witness) (cut-witness-reconstructs? witness))]))

(define (source-base-claims source initial-frontier survivors selector)
  (define initial
    (for/list ([entry (in-list (cut-witness-detached initial-frontier))])
      (define witness
        (make-cut-witness source (list (detached-entry-address entry))))
      (define forest (cut-witness-forest witness))
      (base-purity-claim
       'initial-cache (detached-entry-address entry) witness forest
       (and selector
            (material-hopf-selector-forest-pure? selector forest)))))
  (define survivor-claims
    (for/list ([address (in-list survivors)])
      (define witness (make-cut-witness source (list address)))
      (define forest (cut-witness-forest witness))
      (base-purity-claim
       'opaque-survivor address witness forest
       (and selector
            (material-hopf-selector-forest-pure? selector forest)))))
  (append initial survivor-claims))

(define (compile-normalization-replay
         source initial-frontier registry requests
         #:material-profile [profile #f]
         #:polynomial-term-cap [term-cap analysis-default-limit])
  (define who 'compile-normalization-replay)
  (unless (normalization-cell-registry? registry)
    (raise-argument-error who "normalization-cell-registry?" registry))
  (unless (exact-positive-integer? term-cap)
    (raise-argument-error who "exact-positive-integer?" term-cap))
  (define input-failure
    (validate-history-input source initial-frontier registry requests profile))
  (if input-failure
      input-failure
      (let/ec abort
        (define signature (normalization-cell-registry-signature registry))
        (define calculus (normalization-signature-calculus signature))
        (define selector (and profile (prepare-material-hopf-selector profile)))
        (define admission-values
          (call-with-values
           (lambda ()
             (initial-cache-handles
              source initial-frontier signature selector))
           list))
        (when (and (= (length admission-values) 1)
                   (normalization-replay-failure? (car admission-values)))
          (abort (car admission-values)))
        (define initial-handles (first admission-values))
        (define cache-admission-inspections (second admission-values))
        (define source-addresses (vertex-addresses source))
        (define initial-potential
          (proof-normalization-potential source signature))
        (define current
          (active-state
           source (initial-node-map source) (initial-origin-map source)
           initial-handles (initial-parent source) (set)))
        (define event-certificates '())
        (define exposures '())
        (define first-crossing #f)
        (define states
          (list (history-state
                 source
                 (active-state-node-identities current)
                 (active-state-origin-representatives current)
                 initial-handles)))
        (define potentials (list initial-potential))
        (define replay-inspections 0)

        (for ([request (in-list requests)] [index (in-naturals 1)])
          (define-values (crossing exposure refined-frontier)
            (compute-least-exposure current request index selector))
          (when (normalization-replay-failure? crossing) (abort crossing))
          (when crossing
            (unless first-crossing (set! first-crossing crossing))
            (set! exposures (append exposures (list exposure))))
          (when (and (not crossing)
                     (let ([owner
                            (frontier-owner
                             (active-state-frontier current)
                             (normalization-event-request-address request))])
                       (not (eq? owner 'remainder))))
            (abort
             (failure
              'step-inside-opaque-cache
              "a Cut-rooted step cannot execute inside an admitted Cut-free opaque cache"
              (hash 'event (normalization-event-request-id request)))))
          (define before-proof (active-state-proof current))
          (define before-potential
            (proof-normalization-potential before-proof signature))
          (define application (apply-cell-at before-proof request))
          (when (normalization-replay-failure? application)
            (abort application))
          (define after-proof (cell-application-target application))
          (define after-potential
            (proof-normalization-potential after-proof signature))
          (unless (< (normalization-potential-psi after-potential)
                     (normalization-potential-psi before-potential))
            (abort
             (failure
              'nondecreasing-potential
              "the concrete registered event does not strictly decrease Psi"
              (hash 'event (normalization-event-request-id request)
                    'before before-potential 'after after-potential))))
          (define-values
            (after-identities after-origins after-parent after-ever-read
                              read-identities read-source fresh-identities)
            (transition-identities+origins
             source-addresses current request application))
          (define routed-frontier
            (route-frontier-after-application
             refined-frontier application after-proof))
          (unless (frontier-proper-or-endpoint-valid?
                   after-proof routed-frontier)
            (abort
             (failure 'invalid-routed-frontier
                      "routed survivor handles are not a native CK frontier or pointed endpoint"
                      (hash 'event
                            (normalization-event-request-id request)))))
          (define event
            (normalization-event-certificate
             index request (normalization-event-request-cell request)
             before-proof after-proof
             (cell-match-shell-addresses (cell-application-match application))
             read-identities read-source
             (cell-application-input-moves application)
             fresh-identities
             (normalization-cell-external-routing
              (normalization-event-request-cell request))
             before-potential after-potential
             (cell-application-inspections application)
             (active-state-node-identities current) after-identities
             (active-state-origin-representatives current) after-origins))
          (set! event-certificates
                (append event-certificates (list event)))
          (set! replay-inspections
                (+ replay-inspections
                   (cell-application-inspections application)))
          (set! current
                (active-state
                 after-proof after-identities after-origins routed-frontier
                 after-parent after-ever-read))
          (set! states
                (append states
                        (list (history-state
                               after-proof after-identities after-origins
                               routed-frontier))))
          (set! potentials (append potentials (list after-potential))))

        (define target (active-state-proof current))
        (define partition
          (partition-from-parent
           (active-state-parent current) source-addresses
           (active-state-ever-read current)))
        (define guarded-fold
          (compute-guarded-fold source partition term-cap))
        (define survivor-handles (active-state-frontier current))
        (define survivors
          (sort (map replay-cache-handle-source-address survivor-handles)
                address<?))
        (define survivor-targets
          (for/list ([source-address (in-list survivors)])
            (define pair
              (findf
               (lambda (entry)
                 (equal? (cdr entry)
                         (source-node-identity source-address)))
               (for/list ([(address identity)
                           (in-hash (active-state-node-identities current))])
                 (cons address identity))))
            (unless pair
              (abort
               (failure 'lost-survivor-identity
                        "a maximal opaque source handle disappeared"
                        (hash 'source-address source-address))))
            (car pair)))
        (define compiled
          (compile-open-history
           source target registry requests event-certificates states
           survivors signature))
        (when (normalization-replay-failure? compiled) (abort compiled))
        (define claims
          (source-base-claims
           source initial-frontier survivors selector))
        (define baseline
          (run-normalization-zipper-baseline
           source initial-frontier registry requests))
        (when (normalization-replay-failure? baseline) (abort baseline))
        (unless (and (equal? (zipper-baseline-result-target baseline) target)
                     (equal?
                      (zipper-baseline-result-output-routing baseline)
                      (compiled-normalization-history-output-routing compiled))
                     (equal?
                      (zipper-baseline-result-survivor-source-addresses baseline)
                      survivors)
                     (equal?
                      (zipper-baseline-result-survivor-target-addresses baseline)
                      survivor-targets))
          (abort
           (failure
            'zipper-disagreement
            "the independent typed zipper disagrees on target, routing, or survivors"
            (hash 'baseline baseline))))
        (normalization-replay-certificate
         source target registry initial-frontier event-certificates
         first-crossing exposures initial-handles survivors survivor-targets
         partition (sort (set->list (active-state-ever-read current)) address<?)
         guarded-fold compiled potentials profile claims
         (+ (node-count source) cache-admission-inspections
            (for/sum ([event (in-list event-certificates)])
              (+ (node-count (normalization-event-certificate-before event))
                 (node-count (normalization-event-certificate-after event)))))
         replay-inspections 0 baseline))))

;; -------------------------------------------------------------------------
;; Independent typed zipper baseline

(define (zipper-replace/opaque term address replacement)
  (let/ec abort
    (define inspections 0)
    (define (descend current remaining crumbs)
      (cond
        [(null? remaining) (values current crumbs)]
        [(checked-hole? current)
         (abort
          (failure 'zipper-through-hole
                   "the zipper cannot descend through a typed vacancy"))]
        [else
         (set! inspections (add1 inspections))
         (define slot (car remaining))
         (define children (checked-node-children current))
         (unless (<= slot (length children))
           (abort
            (failure 'zipper-no-such-address
                     "the zipper path names no ordered child"
                     (hash 'address address))))
         (descend
          (list-ref children (sub1 slot)) (cdr remaining)
          (cons
           (zipper-crumb
            (checked-node-occurrence current)
            (take children (sub1 slot))
            (drop children slot))
           crumbs))]))
    (define-values (_focus crumbs) (descend term address '()))
    (define rebuilt
      (for/fold ([current replacement]) ([crumb (in-list crumbs)])
        (define assembled
          (assemble-checked-application
           (checked-term-calculus term)
           (zipper-crumb-occurrence crumb)
           (append (zipper-crumb-left crumb)
                   (list current)
                   (zipper-crumb-right crumb))))
        (when (validation-error? assembled)
          (abort
           (failure 'zipper-native-assembly-failed
                    "the independent zipper failed native ancestor assembly"
                    (hash 'validation-error assembled))))
        assembled))
    (native-replacement rebuilt inspections)))

(define (zipper-apply-cell term request)
  (define matched
    (match-cell-at term (normalization-event-request-address request)
                   (normalization-event-request-cell request)))
  (if (normalization-replay-failure? matched)
      matched
      (let ([instantiation
             (instantiate-cell-rhs
              (normalization-event-request-cell request)
              (cell-match-bindings matched))])
        (if (normalization-replay-failure? instantiation)
            instantiation
            (let ([replacement
                   (zipper-replace/opaque
                    term (normalization-event-request-address request)
                    (rhs-instantiation-term instantiation))])
              (if (normalization-replay-failure? replacement)
                  replacement
                  (let* ([address (normalization-event-request-address request)]
                         [cell (normalization-event-request-cell request)]
                         [rhs-addresses
                          (for/hash
                              ([entry
                                (in-list
                                 (premise-telescope
                                  (normalization-cell-rhs cell)))]
                               [label
                                (in-list
                                 (normalization-cell-rhs-port-labels cell))])
                            (values label
                                    (address-append
                                     address
                                     (telescope-entry-address entry))))]
                         [moves
                          (for/list ([binding
                                      (in-list (cell-match-bindings matched))])
                            (replay-input-move
                             (cell-binding-label binding)
                             (cell-binding-address binding)
                             (hash-ref rhs-addresses
                                       (cell-binding-label binding))
                             (cell-binding-term binding)))])
                    (cell-application
                     (native-replacement-term replacement)
                     matched moves
                     (rhs-instantiation-fresh-relative-addresses instantiation)
                     (+ (cell-match-inspections matched)
                        (rhs-instantiation-inspections instantiation)
                        (native-replacement-inspections replacement))))))))))

(define (subtree-has-read? root ever-read)
  (for/or ([address (in-set ever-read)])
    (address-prefix? root address)))

(define (maximal-unread-descendants source root ever-read)
  (cond
    [(not (subtree-has-read? root ever-read)) (list root)]
    [else
     (define node (vertex-at-address source root))
     (if node
         (append-map
          (lambda (slot+child)
            (if (checked-node? (cdr slot+child))
                (maximal-unread-descendants
                 source
                 (address-append root (list (car slot+child)))
                 ever-read)
                '()))
          (for/list ([child (in-list (checked-node-children node))]
                     [slot (in-naturals 1)])
            (cons slot child)))
         '())]))

(define (routing-for-requests source requests)
  (let/ec abort
    (define route (identity-boundary-routing (derivation-root-boundary source)))
    (for ([request (in-list requests)])
      (define next
        (normalization-cell-external-routing
         (normalization-event-request-cell request)))
      (unless (equal? (exact-boundary-routing-target route)
                      (exact-boundary-routing-source next))
        (abort
         (failure 'zipper-routing-lift-unavailable
                  "the zipper baseline cannot lift this local routing")))
      (set! route (routing-compose route next)))
    route))

(define (run-normalization-zipper-baseline
         source initial-frontier registry requests)
  (define input-failure
    (validate-history-input source initial-frontier registry requests #f))
  (if input-failure
      input-failure
      (let/ec abort
        (define source-addresses (vertex-addresses source))
        (define state
          (active-state
           source (initial-node-map source) (initial-origin-map source)
           '() (initial-parent source) (set)))
        (define inspections 0)
        (for ([request (in-list requests)])
          (define application
            (zipper-apply-cell (active-state-proof state) request))
          (when (normalization-replay-failure? application)
            (abort application))
          (define-values
            (after-identities after-origins after-parent after-ever-read
                              _read-identities _read-source _fresh-identities)
            (transition-identities+origins
             source-addresses state request application))
          (set! inspections
                (+ inspections (cell-application-inspections application)))
          (set! state
                (active-state
                 (cell-application-target application)
                 after-identities after-origins '()
                 after-parent after-ever-read)))
        (define initial-roots (cut-witness-addresses initial-frontier))
        (define survivors
          (sort
           (append-map
            (lambda (root)
              (maximal-unread-descendants
               source root (active-state-ever-read state)))
            initial-roots)
           address<?))
        (define targets
          (for/list ([source-address (in-list survivors)])
            (define found
              (for/first ([(address identity)
                           (in-hash (active-state-node-identities state))]
                          #:when
                          (equal? identity
                                  (source-node-identity source-address)))
                address))
            (unless found
              (abort
               (failure 'zipper-lost-survivor
                        "the zipper lost an unread source cache descendant"
                        (hash 'source-address source-address))))
            found))
        (define routing (routing-for-requests source requests))
        (when (normalization-replay-failure? routing) (abort routing))
        (zipper-baseline-result
         (active-state-proof state) routing survivors targets inspections 0 #t))))

;; -------------------------------------------------------------------------
;; Replay, direct owner-colouring and native guarded witnesses

(define (fillers-for-state state canonical-survivors fillers)
  (define table
    (for/hash ([source (in-list canonical-survivors)]
               [filler (in-list fillers)])
      (values source filler)))
  (for/list ([source
              (in-list
               (projected-replay-state-survivor-source-addresses state))])
    (hash-ref table source)))

(define (replay-compiled-normalization compiled fillers)
  (define who 'replay-compiled-normalization)
  (unless (compiled-normalization-history? compiled)
    (raise-argument-error who "compiled-normalization-history?" compiled))
  (unless (and (list? fillers) (andmap checked-node? fillers))
    (raise-argument-error who "(listof checked-node?)" fillers))
  (define survivors
    (compiled-normalization-history-survivor-source-addresses compiled))
  (unless (= (length fillers) (length survivors))
    (raise-arguments-error
     who "one checked filler is required for every physical survivor port"
     "expected" (length survivors) "actual" (length fillers)))
  (define calculus (compiled-normalization-history-calculus compiled))
  (define signature
    (normalization-cell-registry-signature
     (compiled-normalization-history-registry compiled)))
  (let/ec abort
    (define admission-inspections 0)
    (for ([filler (in-list fillers)]
          [boundary
           (in-list
            (compiled-normalization-history-survivor-boundaries compiled))])
      (unless (and (complete-proof? filler)
                   (exact-term-in-calculus? calculus filler)
                   (equal? (derivation-root-boundary filler) boundary))
        (abort
         (failure 'invalid-replay-filler
                  "a replay filler is not a complete exact proof at its physical interface"
                  (hash 'filler filler 'expected boundary))))
      (define-values (cut-free? inspected)
        (term-cut-free?/count filler signature))
      (set! admission-inspections (+ admission-inspections inspected))
      (unless cut-free?
        (abort
         (failure 'replay-filler-not-cut-free
                  "maximal opaque replay accepts only Cut-free fillers"
                  (hash 'filler filler)))))
    (define projected
      (compiled-normalization-history-states compiled))
    (define filled-states '())
    (define fill-inspections 0)
    (for ([state (in-list projected)])
      (define ordered-fillers
        (fillers-for-state state survivors fillers))
      (define result
        (opaque-fill-context
         (projected-replay-state-term state)
         (projected-replay-state-survivor-source-addresses state)
         ordered-fillers))
      (when (normalization-replay-failure? result) (abort result))
      (set! fill-inspections
            (+ fill-inspections (opaque-fill-result-inspections result)))
      (set! filled-states
            (append filled-states (list (opaque-fill-result-term result)))))
    (define event-inspections 0)
    (for ([before (in-list filled-states)]
          [after (in-list (cdr filled-states))]
          [request
           (in-list (compiled-normalization-history-requests compiled))])
      (define application (apply-cell-at before request))
      (when (normalization-replay-failure? application) (abort application))
      (set! event-inspections
            (+ event-inspections (cell-application-inspections application)))
      (unless (equal? (cell-application-target application) after)
        (abort
         (failure 'compiled-replay-mismatch
                  "the registered open history did not replay on a new exact filler"
                  (hash 'event (normalization-event-request-id request))))))
    (normalization-replay-result
     (last filled-states) filled-states
     (compiled-normalization-history-output-routing compiled)
     admission-inspections (+ fill-inspections event-inspections) 0 #t)))

(define (initial-owner-map source cut-addresses)
  (for/hash ([address (in-list (vertex-addresses source))])
    (define owner
      (for/first ([root (in-list cut-addresses)]
                  [index (in-naturals 1)]
                  #:when (address-prefix? root address))
        index))
    (values address (or owner 0))))

(define (transition-owner-map owner-map event)
  (define request (normalization-event-certificate-request event))
  (define redex (normalization-event-request-address request))
  (define shell (normalization-event-certificate-shell-addresses event))
  (define shell-owners
    (remove-duplicates
     (map (lambda (address) (hash-ref owner-map address)) shell) =))
  (cond
    [(not (= (length shell-owners) 1)) #f]
    [else
     (define shell-owner (car shell-owners))
     (define outside (copy-map-outside-subtree owner-map redex))
     (define moved
       (copy-input-subtrees
        owner-map (normalization-event-certificate-input-moves event)))
     (define base (hash-union/right outside moved))
     (for/fold ([result base])
               ([identity
                 (in-list
                  (normalization-event-certificate-fresh-node-identities
                   event))])
       (define relative (third identity))
       (hash-set result (address-append redex relative) shell-owner))]))

(define (normalization-frontier-guarded? certificate witness)
  (unless (normalization-replay-certificate? certificate)
    (raise-argument-error
     'normalization-frontier-guarded?
     "normalization-replay-certificate?" certificate))
  (unless (cut-witness? witness)
    (raise-argument-error
     'normalization-frontier-guarded? "cut-witness?" witness))
  (define source (normalization-replay-certificate-source certificate))
  (and
   (eq? (cut-witness-source witness) source)
   (let loop ([owners
               (initial-owner-map source (cut-witness-addresses witness))]
              [events (normalization-replay-certificate-events certificate)])
     (cond
       [(null? events) #t]
       [else
        (define next (transition-owner-map owners (car events)))
        (and next (loop next (cdr events)))]))))

(define (certify-guarded-source-cut certificate addresses
                                    #:material-profile [profile #f])
  (define who 'certify-guarded-source-cut)
  (unless (normalization-replay-certificate? certificate)
    (raise-argument-error who "normalization-replay-certificate?" certificate))
  (unless (and (list? addresses) (andmap address? addresses))
    (raise-argument-error who "(listof address?)" addresses))
  (define source (normalization-replay-certificate-source certificate))
  (define witness (make-cut-witness source addresses))
  (cond
    [(cut-error? witness)
     (failure 'invalid-guarded-cut
              "the request is not an existing native proper/empty CK witness"
              (hash 'cut-error witness))]
    [else
     (define guarded?
       (normalization-frontier-guarded? certificate witness))
     (define forest (cut-witness-forest witness))
     (define base-pure?
       (cond
         [(not profile) #f]
         [(not (and (material-profile? profile)
                    (eq? (material-profile-calculus profile)
                         (checked-node-calculus source))))
          (raise-arguments-error
           who "the optional material profile must use the exact source calculus"
           "profile" profile)]
         [else
          (material-hopf-selector-forest-pure?
           (prepare-material-hopf-selector profile) forest)]))
     (define refill
       (complete-fill
        (cut-witness-remainder witness)
        (map detached-entry-term (cut-witness-detached witness))))
     (guarded-source-cut-certificate
      source addresses witness (cut-witness-detached witness) forest
      (cut-witness-remainder witness) refill guarded? base-pure? #f)]))

;; -------------------------------------------------------------------------
;; Independent certificate checker

(define (check-normalization-replay-certificate certificate)
  (define who 'check-normalization-replay-certificate)
  (unless (normalization-replay-certificate? certificate)
    (raise-argument-error who "normalization-replay-certificate?" certificate))
  (let/ec finish
    (define checks '())
    (define inspections 0)
    (define (record! name value [details #f])
      (set! checks (append checks (list (cons name (and value #t)))))
      (unless value
        (finish
         (normalization-check-report
          #f checks inspections 0
          (hash 'failed-check name 'details details)))))
    (define source (normalization-replay-certificate-source certificate))
    (define registry (normalization-replay-certificate-registry certificate))
    (define signature (normalization-cell-registry-signature registry))
    (define profile
      (normalization-replay-certificate-material-profile certificate))
    (define selector (and profile (prepare-material-hopf-selector profile)))
    (define initial
      (normalization-replay-certificate-initial-frontier certificate))
    (record! 'native-initial-frontier
             (and (cut-witness? initial)
                  (eq? (cut-witness-source initial) source)
                  (cut-witness-reconstructs? initial)))
    (define admission-values
      (call-with-values
       (lambda () (initial-cache-handles source initial signature selector))
       list))
    (record! 'cache-admission
             (and (= (length admission-values) 2)
                  (equal? (first admission-values)
                          (normalization-replay-certificate-initial-cache-handles
                           certificate)))
             admission-values)
    (define source-addresses (vertex-addresses source))
    (define current
      (active-state
       source (initial-node-map source) (initial-origin-map source)
       (first admission-values) (initial-parent source) (set)))
    (define recomputed-states
      (list (history-state
             source (active-state-node-identities current)
             (active-state-origin-representatives current)
             (active-state-frontier current))))
    (define recomputed-crossing #f)
    (define recomputed-exposures '())
    (define recomputed-potentials
      (list (proof-normalization-potential source signature)))
    (for ([recorded
           (in-list (normalization-replay-certificate-events certificate))]
          [index (in-naturals 1)])
      (define request (normalization-event-certificate-request recorded))
      (record! 'exact-cell-identity
               (eq? (normalization-event-request-cell request)
                    (hash-ref (normalization-cell-registry-table registry)
                              (normalization-cell-id
                               (normalization-event-request-cell request))
                              #f)))
      (define-values (crossing exposure refined)
        (compute-least-exposure current request index selector))
      (record! 'least-exposure-computed
               (not (normalization-replay-failure? crossing)) crossing)
      (when crossing
        (unless recomputed-crossing (set! recomputed-crossing crossing))
        (set! recomputed-exposures
              (append recomputed-exposures (list exposure))))
      (define application (apply-cell-at (active-state-proof current) request))
      (record! 'native-cell-match
               (cell-application? application) application)
      (set! inspections
            (+ inspections (cell-application-inspections application)))
      (record! 'recorded-target
               (equal? (cell-application-target application)
                       (normalization-event-certificate-after recorded)))
      (record! 'recorded-shell
               (equal? (cell-match-shell-addresses
                        (cell-application-match application))
                       (normalization-event-certificate-shell-addresses
                        recorded)))
      (record! 'recorded-routing
               (and
                (equal? (normalization-cell-external-routing
                         (normalization-event-request-cell request))
                        (normalization-event-certificate-external-routing
                         recorded))
                (equal? (cell-application-input-moves application)
                        (normalization-event-certificate-input-moves
                         recorded))))
      (define before-potential
        (proof-normalization-potential (active-state-proof current) signature))
      (define after-potential
        (proof-normalization-potential
         (cell-application-target application) signature))
      (record! 'strict-potential-descent
               (and (equal? before-potential
                            (normalization-event-certificate-potential-before
                             recorded))
                    (equal? after-potential
                            (normalization-event-certificate-potential-after
                             recorded))
                    (< (normalization-potential-psi after-potential)
                       (normalization-potential-psi before-potential))))
      (define-values
        (after-identities after-origins after-parent after-ever-read
                          read-identities read-source fresh-identities)
        (transition-identities+origins
         source-addresses current request application))
      (record! 'read-origin-ledger
               (and (equal? read-identities
                            (normalization-event-certificate-read-node-identities
                             recorded))
                    (equal? read-source
                            (normalization-event-certificate-read-source-origins
                             recorded))
                    (equal? fresh-identities
                            (normalization-event-certificate-fresh-node-identities
                             recorded))
                    (equal? after-identities
                            (normalization-event-certificate-after-node-identities
                             recorded))
                    (equal? after-origins
                            (normalization-event-certificate-after-origin-representatives
                             recorded))))
      (define routed
        (route-frontier-after-application
         refined application (cell-application-target application)))
      (set! current
            (active-state
             (cell-application-target application)
             after-identities after-origins routed after-parent after-ever-read))
      (set! recomputed-states
            (append recomputed-states
                    (list (history-state
                           (active-state-proof current) after-identities
                           after-origins routed))))
      (set! recomputed-potentials
            (append recomputed-potentials (list after-potential))))
    (record! 'first-crossing
             (equal? recomputed-crossing
                     (normalization-replay-certificate-first-crossing
                      certificate)))
    (record! 'all-least-exposures
             (equal? recomputed-exposures
                     (normalization-replay-certificate-exposures certificate)))
    (record! 'checked-target
             (equal? (active-state-proof current)
                     (normalization-replay-certificate-target certificate)))
    (define partition
      (partition-from-parent
       (active-state-parent current) source-addresses
       (active-state-ever-read current)))
    (record! 'read-partition
             (equal? partition
                     (normalization-replay-certificate-read-partition
                      certificate)))
    (record! 'ever-read-ledger
             (equal?
              (sort (set->list (active-state-ever-read current)) address<?)
              (normalization-replay-certificate-ever-read-source-addresses
               certificate)))
    (define survivors
      (sort (map replay-cache-handle-source-address
                 (active-state-frontier current)) address<?))
    (record! 'maximal-opaque-survivors
             (equal? survivors
                     (normalization-replay-certificate-survivor-source-addresses
                      certificate)))
    (define expected-fold
      (compute-guarded-fold
       source partition
       (guarded-cut-fold-term-cap
        (normalization-replay-certificate-guarded-fold certificate))))
    (record! 'guarded-stop-continue-fold
             (equal? expected-fold
                     (normalization-replay-certificate-guarded-fold
                      certificate)))
    (define compiled
      (compile-open-history
       source (active-state-proof current) registry
       (map normalization-event-certificate-request
            (normalization-replay-certificate-events certificate))
       (normalization-replay-certificate-events certificate)
       recomputed-states survivors signature))
    (record! 'compiled-open-history
             (and (compiled-normalization-history? compiled)
                  (equal? compiled
                          (normalization-replay-certificate-compiled-history
                           certificate)))
             compiled)
    (for ([claim
           (in-list
            (normalization-replay-certificate-base-purity-claims certificate))])
      (record! 'native-base-purity-witness
               (and (cut-witness? (base-purity-claim-native-witness claim))
                    (cut-witness-reconstructs?
                     (base-purity-claim-native-witness claim))
                    (or (not selector)
                        (equal?
                         (base-purity-claim-pure? claim)
                         (material-hopf-selector-forest-pure?
                          selector (base-purity-claim-forest claim)))))))
    (define baseline
      (run-normalization-zipper-baseline
       source initial registry
       (map normalization-event-certificate-request
            (normalization-replay-certificate-events certificate))))
    (record! 'independent-zipper
             (and (zipper-baseline-result? baseline)
                  (equal? baseline
                          (normalization-replay-certificate-zipper-baseline
                           certificate)))
             baseline)
    (normalization-check-report #t checks inspections 0 (hash))))

;; -------------------------------------------------------------------------
;; Registered contextual routing
;;
;; A concrete occurrence already owns its ordered boundaries, native
;; component incidence and immutable instance evidence.  The records below
;; add only the formula-occurrence equipment which the kernel intentionally
;; does not infer.  They are checked metadata for rebuilding native parents;
;; they are never accepted as proof nodes.

(struct exact-component-routing (source target pairs) #:transparent)
(struct equipped-formula-edge (premise-slot source target) #:transparent)
(struct normalization-principal-mark (kind position) #:transparent)
(struct normalization-rule-equipment
  (occurrence formula-incidence principal-marks side-condition-evidence)
  #:transparent)
(struct normalization-ancestor-lift
  (id calculus before after active-before-slot port-permutation
      input-formula-routings output-formula-routing
      input-component-routings output-component-routing)
  #:transparent)
(struct normalization-routing-registry (calculus lifts search-limit)
  #:transparent)
(struct contextual-routing-certificate
  (source target cell address registry local-formula-routing
          local-component-routing ancestor-chain output-formula-routing
          output-component-routing examined-candidates)
  #:transparent)

(define (boundary-component-sequent boundary index)
  (and (exact-positive-integer? index)
       (<= index (hypersequent-size boundary))
       (component-occurrence-sequent
        (list-ref (hypersequent-components boundary) (sub1 index)))))

(define (make-exact-component-routing source target pairs)
  (define who 'make-exact-component-routing)
  (unless (hypersequent? source)
    (raise-argument-error who "hypersequent? source" source))
  (unless (hypersequent? target)
    (raise-argument-error who "hypersequent? target" target))
  (unless (and (list? pairs)
               (andmap (lambda (entry)
                         (and (pair? entry)
                              (exact-positive-integer? (car entry))
                              (exact-positive-integer? (cdr entry))))
                       pairs))
    (raise-argument-error
     who "(listof (cons/c exact-positive-integer? exact-positive-integer?))"
     pairs))
  (define sources (map car pairs))
  (define targets (map cdr pairs))
  (unless (and (= (length pairs) (hypersequent-size source))
               (= (length pairs) (hypersequent-size target))
               (equal? (sort sources <)
                       (range 1 (add1 (hypersequent-size source))))
               (equal? (sort targets <)
                       (range 1 (add1 (hypersequent-size target)))))
    (raise-arguments-error
     who "routing must be a total bijection on component occurrences"
     "source components" (hypersequent-size source)
     "target components" (hypersequent-size target)
     "pairs" pairs))
  (for ([entry (in-list pairs)])
    (unless (equal? (boundary-component-sequent source (car entry))
                    (boundary-component-sequent target (cdr entry)))
      (raise-arguments-error
       who "component routing must preserve the complete displayed sequent"
       "source component" (car entry)
       "target component" (cdr entry))))
  (exact-component-routing
   source target (for/list ([entry (in-list pairs)]) entry)))

(define (identity-component-routing boundary)
  (unless (hypersequent? boundary)
    (raise-argument-error 'identity-component-routing "hypersequent?" boundary))
  (make-exact-component-routing
   boundary boundary
   (for/list ([index (in-range 1 (add1 (hypersequent-size boundary)))])
     (cons index index))))

(define (validated-formula-routing? routing)
  (and (exact-boundary-routing? routing)
       (with-handlers ([exn:fail? (lambda (_) #f)])
         (equal?
          routing
          (make-exact-boundary-routing
           (exact-boundary-routing-source routing)
           (exact-boundary-routing-target routing)
           (exact-boundary-routing-pairs routing))))))

(define (validated-component-routing? routing)
  (and (exact-component-routing? routing)
       (with-handlers ([exn:fail? (lambda (_) #f)])
         (equal?
          routing
          (make-exact-component-routing
           (exact-component-routing-source routing)
           (exact-component-routing-target routing)
           (exact-component-routing-pairs routing))))))

(define (formula-routing-image routing position)
  (define entry
    (findf (lambda (candidate) (equal? (car candidate) position))
           (exact-boundary-routing-pairs routing)))
  (and entry (cdr entry)))

(define (component-routing-image routing index)
  (define entry
    (findf (lambda (candidate) (= (car candidate) index))
           (exact-component-routing-pairs routing)))
  (and entry (cdr entry)))

(define (identity-formula-routing? routing)
  (and (equal? (exact-boundary-routing-source routing)
               (exact-boundary-routing-target routing))
       (for/and ([entry (in-list (exact-boundary-routing-pairs routing))])
         (equal? (car entry) (cdr entry)))))

(define (identity-component-routing? routing)
  (and (equal? (exact-component-routing-source routing)
               (exact-component-routing-target routing))
       (for/and ([entry (in-list (exact-component-routing-pairs routing))])
         (= (car entry) (cdr entry)))))

(define (make-equipped-formula-edge occurrence premise-slot source target)
  (define who 'make-equipped-formula-edge)
  (unless (concrete-occurrence? occurrence)
    (raise-argument-error who "concrete-occurrence?" occurrence))
  (unless (and (exact-positive-integer? premise-slot)
               (<= premise-slot (occurrence-arity occurrence)))
    (raise-argument-error who "existing positive premise slot" premise-slot))
  (unless (and (formula-occurrence-position? source)
               (member source
                       (boundary-formula-occurrences
                        (occurrence-premise occurrence premise-slot))
                       equal?))
    (raise-argument-error who "formula occurrence in the named premise" source))
  (unless (and (formula-occurrence-position? target)
               (member target
                       (boundary-formula-occurrences
                        (concrete-occurrence-conclusion occurrence))
                       equal?))
    (raise-argument-error who "formula occurrence in the conclusion" target))
  (equipped-formula-edge premise-slot source target))

(define (make-normalization-principal-mark occurrence kind position)
  (unless (concrete-occurrence? occurrence)
    (raise-argument-error
     'make-normalization-principal-mark "concrete-occurrence?" occurrence))
  (unless (and (symbol? kind) (symbol-interned? kind))
    (raise-argument-error
     'make-normalization-principal-mark "interned-symbol? kind" kind))
  (unless (and (formula-occurrence-position? position)
               (member position
                       (boundary-formula-occurrences
                        (concrete-occurrence-conclusion occurrence))
                       equal?))
    (raise-argument-error
     'make-normalization-principal-mark
     "formula occurrence in the conclusion" position))
  (normalization-principal-mark kind position))

(define (make-normalization-rule-equipment
         calculus occurrence formula-incidence principal-marks)
  (define who 'make-normalization-rule-equipment)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (exact-registry-occurrence? calculus occurrence)
    (raise-argument-error who "exact registered concrete occurrence" occurrence))
  (unless (component-incidence? (concrete-occurrence-incidence occurrence))
    (raise-arguments-error
     who "contextual routing requires explicit sealed component incidence"
     "occurrence" occurrence
     "incidence" (concrete-occurrence-incidence occurrence)))
  (unless (and (list? formula-incidence)
               (andmap equipped-formula-edge? formula-incidence))
    (raise-argument-error who "(listof equipped-formula-edge?)"
                          formula-incidence))
  (for ([edge (in-list formula-incidence)])
    ;; Reconstructing through the controlled maker proves all endpoints belong
    ;; to this exact occurrence profile, even if a transparent struct was forged.
    (unless (equal?
             edge
             (make-equipped-formula-edge
              occurrence
              (equipped-formula-edge-premise-slot edge)
              (equipped-formula-edge-source edge)
              (equipped-formula-edge-target edge)))
      (raise-arguments-error who "invalid formula-incidence endpoint"
                             "edge" edge)))
  (unless (and (list? principal-marks)
               (andmap normalization-principal-mark? principal-marks))
    (raise-argument-error who "(listof normalization-principal-mark?)"
                          principal-marks))
  (for ([mark (in-list principal-marks)])
    (unless (equal?
             mark
             (make-normalization-principal-mark
              occurrence
              (normalization-principal-mark-kind mark)
              (normalization-principal-mark-position mark)))
      (raise-arguments-error who "invalid principal-mark endpoint"
                             "mark" mark)))
  (normalization-rule-equipment
   occurrence
   (remove-duplicates formula-incidence equal?)
   (remove-duplicates principal-marks equal?)
   (concrete-occurrence-instance occurrence)))

(define (validated-rule-equipment? calculus equipment)
  (and
   (normalization-rule-equipment? equipment)
   (with-handlers ([exn:fail? (lambda (_) #f)])
     (equal?
      equipment
      (make-normalization-rule-equipment
       calculus
       (normalization-rule-equipment-occurrence equipment)
       (normalization-rule-equipment-formula-incidence equipment)
       (normalization-rule-equipment-principal-marks equipment))))))

(define (relation-set=? left right)
  (and (= (length left) (length right))
       (andmap (lambda (item) (member item right equal?)) left)))

(define (register-normalization-ancestor-lift
         id calculus before after active-before-slot port-permutation
         input-formula-routings output-formula-routing
         input-component-routings output-component-routing)
  (define who 'register-normalization-ancestor-lift)
  (unless (and (symbol? id) (symbol-interned? id))
    (raise-argument-error who "interned-symbol? id" id))
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (and (validated-rule-equipment? calculus before)
               (validated-rule-equipment? calculus after))
    (raise-arguments-error who "expected two validated exact rule-equipment values"
                           "before" before "after" after))
  (define before-occurrence (normalization-rule-equipment-occurrence before))
  (define after-occurrence (normalization-rule-equipment-occurrence after))
  (unless (and (exact-registry-occurrence? calculus before-occurrence)
               (exact-registry-occurrence? calculus after-occurrence))
    (raise-arguments-error who "both occurrences must be exact objects in one registry"
                           "before" before-occurrence "after" after-occurrence))
  (define arity (occurrence-arity before-occurrence))
  (unless (= arity (occurrence-arity after-occurrence))
    (raise-arguments-error who "ancestor replacement must preserve physical arity"
                           "before arity" arity
                           "after arity" (occurrence-arity after-occurrence)))
  (unless (and (exact-positive-integer? active-before-slot)
               (<= active-before-slot arity))
    (raise-argument-error who "existing positive active premise slot"
                          active-before-slot))
  (unless (and (list? port-permutation)
               (= (length port-permutation) arity)
               (equal? (sort port-permutation <)
                       (range 1 (add1 arity))))
    (raise-argument-error who "permutation of ordered 1-based premise slots"
                          port-permutation))
  (unless (and (list? input-formula-routings)
               (= (length input-formula-routings) arity)
               (andmap validated-formula-routing? input-formula-routings))
    (raise-argument-error who "one checked formula routing per old premise slot"
                          input-formula-routings))
  (unless (and (list? input-component-routings)
               (= (length input-component-routings) arity)
               (andmap validated-component-routing? input-component-routings))
    (raise-argument-error who "one checked component routing per old premise slot"
                          input-component-routings))
  (unless (validated-formula-routing? output-formula-routing)
    (raise-argument-error who "validated exact output formula routing"
                          output-formula-routing))
  (unless (validated-component-routing? output-component-routing)
    (raise-argument-error who "validated exact output component routing"
                          output-component-routing))
  (for ([old-slot (in-range 1 (add1 arity))]
        [new-slot (in-list port-permutation)]
        [formula-route (in-list input-formula-routings)]
        [component-route (in-list input-component-routings)])
    (unless (and
             (equal? (exact-boundary-routing-source formula-route)
                     (occurrence-premise before-occurrence old-slot))
             (equal? (exact-boundary-routing-target formula-route)
                     (occurrence-premise after-occurrence new-slot))
             (equal? (exact-component-routing-source component-route)
                     (occurrence-premise before-occurrence old-slot))
             (equal? (exact-component-routing-target component-route)
                     (occurrence-premise after-occurrence new-slot)))
      (raise-arguments-error
       who "premise routing endpoints must follow the declared physical slot alignment"
       "old slot" old-slot "new slot" new-slot))
    (unless (or (= old-slot active-before-slot)
                (and (identity-formula-routing? formula-route)
                     (identity-component-routing? component-route)))
      (raise-arguments-error
       who "inactive siblings must retain identity formula and component routes"
       "old slot" old-slot)))
  (unless (and
           (equal? (exact-boundary-routing-source output-formula-routing)
                   (concrete-occurrence-conclusion before-occurrence))
           (equal? (exact-boundary-routing-target output-formula-routing)
                   (concrete-occurrence-conclusion after-occurrence))
           (equal? (exact-component-routing-source output-component-routing)
                   (concrete-occurrence-conclusion before-occurrence))
           (equal? (exact-component-routing-target output-component-routing)
                   (concrete-occurrence-conclusion after-occurrence)))
    (raise-arguments-error who "output routings must span the two exact conclusions"
                           "formula routing" output-formula-routing
                           "component routing" output-component-routing))
  (unless (and
           (eq? (concrete-occurrence-kind before-occurrence)
                (concrete-occurrence-kind after-occurrence))
           (eq? (concrete-occurrence-tag before-occurrence)
                (concrete-occurrence-tag after-occurrence))
           (equal? (normalization-rule-equipment-side-condition-evidence before)
                   (normalization-rule-equipment-side-condition-evidence after)))
    (raise-arguments-error
     who "ancestor replacement must preserve kind, tag, and complete side-condition evidence"
     "before" before-occurrence "after" after-occurrence))
  (define transported-formula-incidence
    (for/list ([edge
                (in-list
                 (normalization-rule-equipment-formula-incidence before))])
      (define old-slot (equipped-formula-edge-premise-slot edge))
      (define new-slot (list-ref port-permutation (sub1 old-slot)))
      (equipped-formula-edge
       new-slot
       (formula-routing-image
        (list-ref input-formula-routings (sub1 old-slot))
        (equipped-formula-edge-source edge))
       (formula-routing-image output-formula-routing
                              (equipped-formula-edge-target edge)))))
  (unless (relation-set=?
           transported-formula-incidence
           (normalization-rule-equipment-formula-incidence after))
    (raise-arguments-error
     who "formula incidence is not the exact conjugate of the registered parent"
     "required" transported-formula-incidence
     "registered" (normalization-rule-equipment-formula-incidence after)))
  (define transported-marks
    (for/list ([mark
                (in-list
                 (normalization-rule-equipment-principal-marks before))])
      (normalization-principal-mark
       (normalization-principal-mark-kind mark)
       (formula-routing-image
        output-formula-routing
        (normalization-principal-mark-position mark)))))
  (unless (relation-set=? transported-marks
                          (normalization-rule-equipment-principal-marks after))
    (raise-arguments-error
     who "principal marks are not preserved by the output occurrence route"
     "required" transported-marks
     "registered" (normalization-rule-equipment-principal-marks after)))
  (define before-incidence (concrete-occurrence-incidence before-occurrence))
  (define after-incidence (concrete-occurrence-incidence after-occurrence))
  (define transported-component-edges
    (for/list ([edge (in-list (component-incidence-edges before-incidence))])
      (define old-slot (component-edge-premise-slot edge))
      (make-component-edge
       (list-ref port-permutation (sub1 old-slot))
       (component-routing-image
        (list-ref input-component-routings (sub1 old-slot))
        (component-edge-source-index edge))
       (component-routing-image output-component-routing
                                (component-edge-target-index edge)))))
  (unless (equal? (make-component-incidence
                   (vector->list (concrete-occurrence-premises after-occurrence))
                   (concrete-occurrence-conclusion after-occurrence)
                   transported-component-edges)
                  after-incidence)
    (raise-arguments-error
     who "component incidence is not the exact conjugate of the registered parent"
     "required edges" transported-component-edges
     "registered incidence" after-incidence))
  (normalization-ancestor-lift
   id calculus before after active-before-slot
   (for/list ([slot (in-list port-permutation)]) slot)
   (for/list ([route (in-list input-formula-routings)]) route)
   output-formula-routing
   (for/list ([route (in-list input-component-routings)]) route)
   output-component-routing))

(define (validated-ancestor-lift? calculus lift)
  (and
   (normalization-ancestor-lift? lift)
   (eq? (normalization-ancestor-lift-calculus lift) calculus)
   (with-handlers ([exn:fail? (lambda (_) #f)])
     (equal?
      lift
      (register-normalization-ancestor-lift
       (normalization-ancestor-lift-id lift)
       calculus
       (normalization-ancestor-lift-before lift)
       (normalization-ancestor-lift-after lift)
       (normalization-ancestor-lift-active-before-slot lift)
       (normalization-ancestor-lift-port-permutation lift)
       (normalization-ancestor-lift-input-formula-routings lift)
       (normalization-ancestor-lift-output-formula-routing lift)
       (normalization-ancestor-lift-input-component-routings lift)
       (normalization-ancestor-lift-output-component-routing lift))))))

(define (make-normalization-routing-registry calculus lifts
                                             #:search-limit [search-limit 64])
  (define who 'make-normalization-routing-registry)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (and (list? lifts) (andmap normalization-ancestor-lift? lifts))
    (raise-argument-error who "(listof normalization-ancestor-lift?)" lifts))
  (unless (exact-positive-integer? search-limit)
    (raise-argument-error who "exact-positive-integer? search-limit"
                          search-limit))
  (when (check-duplicates (map normalization-ancestor-lift-id lifts) eq?)
    (raise-arguments-error who "ancestor-lift IDs must be distinct"
                           "lifts" lifts))
  (for ([lift (in-list lifts)])
    (unless (validated-ancestor-lift? calculus lift)
      (raise-arguments-error who "every lift must be validated in the exact registry snapshot"
                             "lift" lift)))
  (normalization-routing-registry
   calculus (for/list ([lift (in-list lifts)]) lift) search-limit))

(define (contextual-ancestor-frames source address)
  (for/list ([depth (in-range (sub1 (length address)) -1 -1)])
    (list (take address depth)
          (list-ref address depth)
          (vertex-at-address source (take address depth)))))

(define (lift-matches-input? lift occurrence active-slot formula-route component-route)
  (and (eq? occurrence
            (normalization-rule-equipment-occurrence
             (normalization-ancestor-lift-before lift)))
       (= active-slot (normalization-ancestor-lift-active-before-slot lift))
       (equal? formula-route
               (list-ref
                (normalization-ancestor-lift-input-formula-routings lift)
                (sub1 active-slot)))
       (equal? component-route
               (list-ref
                (normalization-ancestor-lift-input-component-routings lift)
                (sub1 active-slot)))))

(define (apply-one-ancestor-lift parent replacement lift)
  (define before-occurrence (checked-node-occurrence parent))
  (define after-occurrence
    (normalization-rule-equipment-occurrence
     (normalization-ancestor-lift-after lift)))
  (define active-slot (normalization-ancestor-lift-active-before-slot lift))
  (define old-children (checked-node-children parent))
  (define placed (make-vector (length old-children) #f))
  (for ([old-child (in-list old-children)]
        [old-slot (in-naturals 1)]
        [new-slot
         (in-list (normalization-ancestor-lift-port-permutation lift))])
    (vector-set! placed (sub1 new-slot)
                 (if (= old-slot active-slot) replacement old-child)))
  (assemble-checked-application
   (normalization-ancestor-lift-calculus lift)
   after-occurrence
   (vector->list placed)
   #:expected (concrete-occurrence-conclusion after-occurrence)))

(define (certify-contextual-normalization-event
         source cell address routing-registry local-component-routing)
  (define who 'certify-contextual-normalization-event)
  (unless (and (complete-proof? source) (checked-node? source))
    (raise-argument-error who "complete checked proof" source))
  (unless (normalization-cell? cell)
    (raise-argument-error who "normalization-cell?" cell))
  (unless (address? address)
    (raise-argument-error who "address?" address))
  (unless (normalization-routing-registry? routing-registry)
    (raise-argument-error who "normalization-routing-registry?"
                          routing-registry))
  (unless (validated-component-routing? local-component-routing)
    (raise-argument-error who "validated exact component routing"
                          local-component-routing))
  (define calculus (normalization-routing-registry-calculus routing-registry))
  (cond
    [(not (and (eq? (checked-node-calculus source) calculus)
               (eq? (normalization-cell-calculus cell) calculus)))
     (failure 'foreign-contextual-routing
              "source, cell, and ancestor lifts require one exact calculus snapshot")]
    [else
     (let/ec abort
       (define matched (match-cell-at source address cell))
       (when (normalization-replay-failure? matched) (abort matched))
       (define instantiated
         (instantiate-cell-rhs cell (cell-match-bindings matched)))
       (when (normalization-replay-failure? instantiated) (abort instantiated))
       (define replacement (rhs-instantiation-term instantiated))
       (define local-formula-routing
         (normalization-cell-external-routing cell))
       (define focus (checked-term-at-address source address))
       (unless (and focus
                    (equal? (exact-boundary-routing-source local-formula-routing)
                            (derivation-root-boundary focus))
                    (equal? (exact-boundary-routing-target local-formula-routing)
                            (derivation-root-boundary replacement))
                    (equal? (exact-component-routing-source
                             local-component-routing)
                            (derivation-root-boundary focus))
                    (equal? (exact-component-routing-target
                             local-component-routing)
                            (derivation-root-boundary replacement)))
         (abort
          (failure 'invalid-local-routing
                   "local formula/component routes do not span the checked event endpoints"
                   (hash 'address address))))
       (define frames (contextual-ancestor-frames source address))
       (define examined 0)
       (define limit
         (normalization-routing-registry-search-limit routing-registry))
       (define limit-failure #f)
       (define deepest-missing-depth -1)
       (define deepest-missing #f)
       (define (record-missing! depth frame formula-route component-route
                                [candidate #f] [validation #f])
         (when (> depth deepest-missing-depth)
           (set! deepest-missing-depth depth)
           (set! deepest-missing
                 (failure
                  'routing-lift-unavailable
                  "no complete compatible registered ancestor-routing chain exists"
                  (hash
                   'cell (normalization-cell-id cell)
                   'redex-address address
                   'missing-ancestor-address (first frame)
                   'missing-occurrence
                   (checked-node-occurrence (third frame))
                   'required-formula-routing formula-route
                   'required-component-routing component-route
                   'rejected-candidate candidate
                   'validation-error validation)))))
       (define (search remaining current formula-route component-route chain depth)
         (cond
           [(null? remaining)
            (list current formula-route component-route (reverse chain))]
           [else
            (define frame (car remaining))
            (define active-slot (second frame))
            (define parent (third frame))
            (define candidates
              (filter
               (lambda (lift)
                 (lift-matches-input?
                  lift (checked-node-occurrence parent) active-slot
                  formula-route component-route))
               (normalization-routing-registry-lifts routing-registry)))
             (when (null? candidates)
               (record-missing! depth frame formula-route component-route))
            (for/or ([lift (in-list candidates)])
              (set! examined (add1 examined))
              (cond
                [(> examined limit)
                 (set! limit-failure
                       (failure
                        'routing-lift-inconclusive
                        "bounded ancestor-routing search exhausted its candidate limit"
                        (hash 'limit limit
                              'ancestor-address (first frame)
                              'required-formula-routing formula-route
                              'required-component-routing component-route)))
                 #f]
                [else
                 (define assembled
                   (apply-one-ancestor-lift parent current lift))
                  (cond
                    [(validation-error? assembled)
                     (record-missing! depth frame formula-route component-route
                                      (normalization-ancestor-lift-id lift)
                                      assembled)
                     #f]
                    [else
                     (search
                      (cdr remaining) assembled
                      (normalization-ancestor-lift-output-formula-routing lift)
                      (normalization-ancestor-lift-output-component-routing lift)
                      (cons lift chain) (add1 depth))])]))]))
       (define found
         (if (null? frames)
             (list replacement local-formula-routing
                   local-component-routing '())
              (search frames replacement local-formula-routing
                      local-component-routing '() 0)))
       (cond
         [found
          (contextual-routing-certificate
           source (first found) cell address routing-registry
           local-formula-routing local-component-routing
           (fourth found) (second found) (third found) examined)]
         [limit-failure limit-failure]
          [else deepest-missing]))]))

(define (check-contextual-routing-certificate certificate)
  (unless (contextual-routing-certificate? certificate)
    (raise-argument-error
     'check-contextual-routing-certificate
     "contextual-routing-certificate?" certificate))
  (define recomputed
    (certify-contextual-normalization-event
     (contextual-routing-certificate-source certificate)
     (contextual-routing-certificate-cell certificate)
     (contextual-routing-certificate-address certificate)
     (contextual-routing-certificate-registry certificate)
     (contextual-routing-certificate-local-component-routing certificate)))
  (and (contextual-routing-certificate? recomputed)
       (equal? recomputed certificate)))

;; -------------------------------------------------------------------------
;; Marked causal interfaces and sequential composition

(struct normalization-causal-interface
  (source target calculus source-classes source-quotient live-origins
          marked-classes evidence-kind evidence)
  #:transparent)

(define (canonical-certificate-classes certificate)
  (for/list ([class
              (in-list
               (normalization-replay-certificate-read-partition certificate))])
    (define members (sort (replay-read-class-members class) address<?))
    (replay-read-class
     (car members) members (replay-read-class-ever-read? class))))

(define (classes->quotient classes)
  (for*/hash ([class (in-list classes)]
              [member (in-list (replay-read-class-members class))])
    (values member (replay-read-class-representative class))))

(define (certificate-final-raw-origins certificate)
  (define events (normalization-replay-certificate-events certificate))
  (if (null? events)
      (initial-origin-map (normalization-replay-certificate-source certificate))
      (normalization-event-certificate-after-origin-representatives
       (last events))))

(define (normalization-certificate-causal-interface certificate)
  (unless (normalization-replay-certificate? certificate)
    (raise-argument-error
     'normalization-certificate-causal-interface
     "normalization-replay-certificate?" certificate))
  (define source (normalization-replay-certificate-source certificate))
  (define target (normalization-replay-certificate-target certificate))
  (define classes (canonical-certificate-classes certificate))
  (define quotient (classes->quotient classes))
  (define raw-live (certificate-final-raw-origins certificate))
  (define live
    ;; The verified event ledger is the retained live-address lens.  Iterating
    ;; it avoids reopening an admitted opaque target merely to rediscover the
    ;; same addresses.
    (for/hash ([(address origin) (in-hash raw-live)])
      (values
       address
       (hash-ref
        quotient origin
        (lambda ()
          (error 'normalization-certificate-causal-interface
                 "live origin ~e is outside the admitted source index" origin))))))
  (define marked
    (sort
     (for/list ([class (in-list classes)]
                #:when (replay-read-class-ever-read? class))
       (replay-read-class-representative class))
     address<?))
  (normalization-causal-interface
   source target (checked-term-calculus source) classes quotient live marked
   'native certificate))

(define (causal-interface-semantic=? left right)
  (and (eq? (normalization-causal-interface-source left)
            (normalization-causal-interface-source right))
       (eq? (normalization-causal-interface-target left)
            (normalization-causal-interface-target right))
       (eq? (normalization-causal-interface-calculus left)
            (normalization-causal-interface-calculus right))
       (equal? (normalization-causal-interface-source-classes left)
               (normalization-causal-interface-source-classes right))
       (equal? (normalization-causal-interface-source-quotient left)
               (normalization-causal-interface-source-quotient right))
       (equal? (normalization-causal-interface-live-origins left)
               (normalization-causal-interface-live-origins right))
       (equal? (normalization-causal-interface-marked-classes left)
               (normalization-causal-interface-marked-classes right))))

(define (classes-from-parent+marks parent source-addresses marked)
  (define grouped
    (for/fold ([table (hash)]) ([address (in-list source-addresses)])
      (define representative (uf-find parent address))
      (hash-update table representative
                   (lambda (members) (cons address members)) '())))
  (for/list ([representative (in-list (sort (hash-keys grouped) address<?))])
    (define members (sort (hash-ref grouped representative) address<?))
    (replay-read-class
     (car members) members
     (for/or ([member (in-list members)]) (set-member? marked member)))))

(define (compose-causal-interfaces/internal prefix suffix evidence-kind evidence)
  (define source (normalization-causal-interface-source prefix))
  (define intermediate (normalization-causal-interface-target prefix))
  (define target (normalization-causal-interface-target suffix))
  ;; `source-quotient` is the admitted finite source index; composition does
  ;; not traverse proof interiors to rebuild that index.
  (define source-addresses
    (sort
     (hash-keys (normalization-causal-interface-source-quotient prefix))
     address<?))
  ;; First install the prefix quotient on its original source.  Then translate
  ;; every suffix source class through the prefix live leg, which is exactly
  ;; the finite pushout presentation of equation (4.3).
  (define parent0 (initial-parent source))
  (define parent1
    (for/fold ([parent parent0])
              ([class
                (in-list
                 (normalization-causal-interface-source-classes prefix))])
      (define-values (next _representative)
        (uf-union parent (replay-read-class-members class)))
      next))
  (define prefix-live (normalization-causal-interface-live-origins prefix))
  (define parent2
    (for/fold ([parent parent1])
              ([class
                (in-list
                 (normalization-causal-interface-source-classes suffix))])
      (define translated
        (for/list ([address (in-list (replay-read-class-members class))])
          (hash-ref
           prefix-live address
           (lambda ()
             (error 'compose-normalization-causal-interfaces
                    "prefix live leg lacks intermediate vertex ~e" address)))))
      (define-values (next _representative) (uf-union parent translated))
      next))
  (define suffix-class-table
    (for/hash ([class
                (in-list
                 (normalization-causal-interface-source-classes suffix))])
      (values (replay-read-class-representative class)
              (replay-read-class-members class))))
  (define marked-source-addresses
    (for/fold
        ([marked (set)])
        ([representative
          (in-list
           (normalization-causal-interface-marked-classes prefix))])
      (set-add marked representative)))
  (define marked-all
    (for/fold
        ([marked marked-source-addresses])
        ([suffix-representative
          (in-list
           (normalization-causal-interface-marked-classes suffix))])
      (define members (hash-ref suffix-class-table suffix-representative))
      (for/fold ([next marked]) ([address (in-list members)])
        (set-add next (hash-ref prefix-live address)))))
  (define classes
    (classes-from-parent+marks parent2 source-addresses marked-all))
  (define quotient (classes->quotient classes))
  (define suffix-live (normalization-causal-interface-live-origins suffix))
  (define live
    (for/hash ([(target-address suffix-representative)
                (in-hash suffix-live)])
      (define members (hash-ref suffix-class-table suffix-representative))
      (define prefix-representative (hash-ref prefix-live (car members)))
      (values target-address (hash-ref quotient prefix-representative))))
  (define marked
    (sort
     (for/list ([class (in-list classes)]
                #:when (replay-read-class-ever-read? class))
       (replay-read-class-representative class))
     address<?))
  (normalization-causal-interface
   source target (normalization-causal-interface-calculus prefix)
   classes quotient live marked evidence-kind evidence))

(define (normalization-causal-interface-authentic? interface)
  (and
   (normalization-causal-interface? interface)
   (case (normalization-causal-interface-evidence-kind interface)
     [(native)
      (define certificate (normalization-causal-interface-evidence interface))
      (and (normalization-replay-certificate? certificate)
           (normalization-check-report-valid?
            (check-normalization-replay-certificate certificate))
           (causal-interface-semantic=?
            interface
            (normalization-certificate-causal-interface certificate)))]
     [(composition)
      (define evidence (normalization-causal-interface-evidence interface))
      (and (list? evidence)
           (= (length evidence) 2)
           (normalization-causal-interface-authentic? (first evidence))
           (normalization-causal-interface-authentic? (second evidence))
           (let ([recomputed
                  (compose-causal-interfaces/internal
                   (first evidence) (second evidence)
                   'composition evidence)])
             (causal-interface-semantic=? interface recomputed)))]
     [else #f])))

(define (compose-normalization-causal-interfaces prefix suffix)
  (define who 'compose-normalization-causal-interfaces)
  (unless (normalization-causal-interface? prefix)
    (raise-argument-error who "normalization-causal-interface? prefix" prefix))
  (unless (normalization-causal-interface? suffix)
    (raise-argument-error who "normalization-causal-interface? suffix" suffix))
  (cond
    [(not (normalization-causal-interface-authentic? prefix))
     (failure 'forged-prefix-causal-interface
              "the prefix interface is not derivable from its retained native evidence")]
    [(not (normalization-causal-interface-authentic? suffix))
     (failure 'forged-suffix-causal-interface
              "the suffix interface is not derivable from its retained native evidence")]
    [(not (eq? (normalization-causal-interface-calculus prefix)
               (normalization-causal-interface-calculus suffix)))
     (failure 'foreign-causal-interface
              "causal interfaces require one exact calculus snapshot")]
    [(not (eq? (normalization-causal-interface-target prefix)
               (normalization-causal-interface-source suffix)))
     (failure 'wrong-causal-intermediate
              "sequential composition requires the exact shared intermediate proof object"
              (hash 'prefix-target
                    (normalization-causal-interface-target prefix)
                    'suffix-source
                    (normalization-causal-interface-source suffix)))]
    [else
     (compose-causal-interfaces/internal
      prefix suffix 'composition (list prefix suffix))]))

(define (normalization-causal-interface-equivalent? left right)
  (unless (normalization-causal-interface? left)
    (raise-argument-error
     'normalization-causal-interface-equivalent?
     "normalization-causal-interface? left" left))
  (unless (normalization-causal-interface? right)
    (raise-argument-error
     'normalization-causal-interface-equivalent?
     "normalization-causal-interface? right" right))
  (and (normalization-causal-interface-authentic? left)
       (normalization-causal-interface-authentic? right)
       (causal-interface-semantic=? left right)))

;; -------------------------------------------------------------------------
;; Positive macro elaboration and source pullback

(struct normalization-macro-interpretation
  (source-occurrence summary ordered-port-labels)
  #:transparent)
(struct interpreted-rule-potential-summary
  (source-occurrence N A H cut-ancestor-counts)
  #:transparent)
(struct positive-normalization-elaboration
  (source expanded calculus interpretations target-signature collapse anchors
          blocks interpreted-summaries source-profile target-profile
          local-base-fidelity? positive-provenance-reclassification-addresses
          admission-inspections)
  #:transparent)
(struct expansion-result (term collapse anchors inspections) #:transparent)
(struct normalization-collapse-analysis
  (pulled-classes projected-marked-source-addresses kernel-join-classes
                  inverse-image-classes join-equal? guarded-fold)
  #:transparent)
(struct source-aligned-frontier-certificate
  (source addresses source-witness source-detached source-remainder
          source-refill expanded-addresses expanded-witness expanded-detached
          expanded-remainder expanded-refill guarded? opaque? whole-endpoint?)
  #:transparent)
(struct compositional-normalization-certificate
  (elaboration principal-phase identity-phase direct-history
               principal-interface identity-interface composed-interface
               direct-interface interface-agreement? collapse-analysis
               pullback-potential direct-initial-potential
               empty-proper-convention whole-endpoint-weight
               opaque-interior-inspections)
  #:transparent)

(define (find-macro-port summary label)
  (findf (lambda (port) (eq? label (macro-port-name port)))
         (macro-summary-ports summary)))

(define (make-normalization-macro-interpretation
         calculus source-occurrence summary ordered-port-labels)
  (define who 'make-normalization-macro-interpretation)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (exact-registry-occurrence? calculus source-occurrence)
    (raise-argument-error who "exact registered source occurrence"
                          source-occurrence))
  (unless (and (macro-summary? summary)
               (eq? (macro-summary-calculus summary) calculus))
    (raise-argument-error who "macro-summary in the exact calculus" summary))
  (define arity (occurrence-arity source-occurrence))
  (unless (and (list? ordered-port-labels)
               (= (length ordered-port-labels) arity)
               (andmap (lambda (label)
                         (and (symbol? label) (symbol-interned? label)))
                       ordered-port-labels)
               (not (check-duplicates ordered-port-labels eq?)))
    (raise-argument-error
     who "one distinct interned port label per ordered source premise"
     ordered-port-labels))
  (define declared-labels (map macro-port-name (macro-summary-ports summary)))
  (unless (and (= (length declared-labels) arity)
               (andmap (lambda (label) (memq label declared-labels))
                       ordered-port-labels))
    (raise-arguments-error
     who "the positive macro may have no missing or additional physical ports"
     "source labels" ordered-port-labels
     "macro labels" declared-labels))
  (unless (and (checked-node? (macro-summary-context summary))
               (positive? (macro-summary-fixed-vertex-count summary))
               (equal? (derivation-root-boundary
                        (macro-summary-context summary))
                       (concrete-occurrence-conclusion source-occurrence)))
    (raise-arguments-error
     who "the interpretation must be a connected positive macro at the exact output boundary"
     "source occurrence" source-occurrence
     "macro context" (macro-summary-context summary)))
  (for ([label (in-list ordered-port-labels)]
        [slot (in-naturals 1)])
    (define port (find-macro-port summary label))
    (unless (and port
                 (= (macro-summary-use-count summary label) 1)
                 (equal? (macro-port-boundary port)
                         (occurrence-premise source-occurrence slot)))
      (raise-arguments-error
       who "each ordered physical source port must occur exactly once at its exact boundary"
       "slot" slot "label" label "port" port)))
  (normalization-macro-interpretation
   source-occurrence summary
   (for/list ([label (in-list ordered-port-labels)]) label)))

(define (validated-macro-interpretation? calculus interpretation)
  (and
   (normalization-macro-interpretation? interpretation)
   (with-handlers ([exn:fail? (lambda (_) #f)])
     (equal?
      interpretation
      (make-normalization-macro-interpretation
       calculus
       (normalization-macro-interpretation-source-occurrence interpretation)
       (normalization-macro-interpretation-summary interpretation)
       (normalization-macro-interpretation-ordered-port-labels
        interpretation))))))

(define (interpretation-potential-summary interpretation target-signature)
  (define macro
    (macro-summary-context
     (normalization-macro-interpretation-summary interpretation)))
  (define potential (proof-normalization-potential macro target-signature))
  (define counts (context-cut-ancestor-counts macro target-signature))
  (define summary
    (normalization-macro-interpretation-summary interpretation))
  (define count-by-label
    (for/hash ([input (in-list (macro-summary-inputs summary))])
      (values
       (macro-input-port input)
       (cdr (assoc (macro-input-address input) counts equal?)))))
  (interpreted-rule-potential-summary
   (normalization-macro-interpretation-source-occurrence interpretation)
   (normalization-potential-N potential)
   (normalization-potential-A potential)
   (normalization-potential-H potential)
   (for/list
       ([label
         (in-list
          (normalization-macro-interpretation-ordered-port-labels
           interpretation))])
     (hash-ref count-by-label label))))

(define (interpretation-table interpretations)
  (for/fold ([table (hasheq)]) ([interpretation (in-list interpretations)])
    (define occurrence
      (normalization-macro-interpretation-source-occurrence interpretation))
    (when (hash-has-key? table occurrence)
      (raise-arguments-error
       'compile-positive-normalization-elaboration
       "each exact source occurrence has at most one macro interpretation"
       "occurrence" occurrence))
    (hash-set table occurrence interpretation)))

(define (prefix-hash-addresses table key-prefix value-prefix)
  (for/hash ([(key value) (in-hash table)])
    (values (address-append key-prefix key)
            (address-append value-prefix value))))

(define (expand-source-with-interpretations source table)
  (let/ec abort
    (define (walk node)
      (define occurrence (checked-node-occurrence node))
      (define interpretation (hash-ref table occurrence #f))
      (unless interpretation
        (abort
         (failure
          'missing-macro-interpretation
          "the elaboration table lacks an exact source occurrence"
          (hash 'occurrence occurrence))))
      (define child-results
        (for/list ([child (in-list (checked-node-children node))])
          (walk child)))
      (when (ormap normalization-replay-failure? child-results)
        (abort (findf normalization-replay-failure? child-results)))
      (define summary
        (normalization-macro-interpretation-summary interpretation))
      (define labels
        (normalization-macro-interpretation-ordered-port-labels interpretation))
      (define result-by-label
        (for/hash ([label (in-list labels)]
                   [result (in-list child-results)])
          (values label result)))
      (define fillers
        (for/list ([input (in-list (macro-summary-inputs summary))])
          (expansion-result-term
           (hash-ref result-by-label (macro-input-port input)))))
      (define filled
        (complete-fill (macro-summary-context summary) fillers))
      (when (context-error? filled)
        (abort
         (failure 'macro-elaboration-fill-failed
                  "native macro filling rejected an interpreted source node"
                  (hash 'occurrence occurrence 'context-error filled))))
      (define rigid-collapse
        (for/hash ([address
                    (in-list
                     (vertex-addresses (macro-summary-context summary)))])
          (values address root-address)))
      (define collapse rigid-collapse)
      (define anchors (hash root-address root-address))
      (for ([input (in-list (macro-summary-inputs summary))])
        (define label (macro-input-port input))
        (define source-slot
          (add1
           (index-of labels label eq?)))
        (define child-result (hash-ref result-by-label label))
        (define hole (macro-input-address input))
        (set! collapse
              (hash-union/right
               collapse
               (prefix-hash-addresses
                (expansion-result-collapse child-result)
                hole (list source-slot))))
        (set! anchors
              (hash-union/right
               anchors
               (prefix-hash-addresses
                (expansion-result-anchors child-result)
                (list source-slot) hole))))
      (expansion-result
       filled collapse anchors
       (+ (macro-summary-fixed-vertex-count summary)
          (for/sum ([result (in-list child-results)])
            (expansion-result-inspections result)))))
    (walk source)))

(define (macro-rigid-base-pure? interpretation profile)
  (for/and ([address
             (in-list
              (vertex-addresses
               (macro-summary-context
                (normalization-macro-interpretation-summary
                 interpretation))))])
    (material-profile-designates?
     profile
     (checked-node-occurrence
      (vertex-at-address
       (macro-summary-context
        (normalization-macro-interpretation-summary interpretation))
       address)))))

(define (compile-positive-normalization-elaboration
         source expanded interpretations target-signature
         #:source-profile [source-profile #f]
         #:target-profile [target-profile #f])
  (define who 'compile-positive-normalization-elaboration)
  (unless (and (complete-proof? source) (checked-node? source))
    (raise-argument-error who "complete checked source proof" source))
  (unless (and (complete-proof? expanded) (checked-node? expanded))
    (raise-argument-error who "complete checked expanded proof" expanded))
  (unless (and (list? interpretations)
               (andmap normalization-macro-interpretation? interpretations))
    (raise-argument-error
     who "(listof normalization-macro-interpretation?)" interpretations))
  (unless (normalization-signature? target-signature)
    (raise-argument-error who "normalization-signature?" target-signature))
  (define calculus (checked-node-calculus source))
  (cond
    [(not (and (eq? (checked-node-calculus expanded) calculus)
               (eq? (normalization-signature-calculus target-signature)
                    calculus)
               (exact-term-in-calculus? calculus source)
               (exact-term-in-calculus? calculus expanded)))
     (failure 'foreign-elaboration
              "source, expansion, interpretations, and target rank require one exact calculus snapshot")]
    [(not (and (or (not source-profile)
                   (and (material-profile? source-profile)
                        (eq? (material-profile-calculus source-profile)
                             calculus)))
               (or (not target-profile)
                   (and (material-profile? target-profile)
                        (eq? (material-profile-calculus target-profile)
                             calculus)))
               (equal? (and source-profile #t) (and target-profile #t))))
     (failure 'invalid-elaboration-base-profiles
              "base comparison requires two exact profiles in the same registry, or neither")]
    [else
     (let/ec abort
       (for ([interpretation (in-list interpretations)])
         (unless (validated-macro-interpretation? calculus interpretation)
           (abort
            (failure
             'invalid-macro-interpretation
             "every macro interpretation must be maker-validated in the exact elaboration calculus"))))
       (define table (interpretation-table interpretations))
       (define result (expand-source-with-interpretations source table))
       (when (normalization-replay-failure? result) (abort result))
       (unless (equal? (expansion-result-term result) expanded)
         (abort
          (failure
           'wrong-elaboration-target
           "recursive native macro filling does not reconstruct the supplied expanded proof"
           (hash 'reconstructed (expansion-result-term result)
                 'supplied expanded))))
       (define collapse (expansion-result-collapse result))
       (define anchors (expansion-result-anchors result))
       (unless (and
                (equal? (sort (hash-keys collapse) address<?)
                        (vertex-addresses expanded))
                (andmap (lambda (address)
                          (member address (vertex-addresses source) equal?))
                        (hash-values collapse))
                (not
                 (for/or ([source-address (in-list (vertex-addresses source))])
                   (not (member source-address
                                (hash-values collapse) equal?)))))
         (abort
          (failure 'invalid-macro-collapse
                   "the derived collapse is not a total surjection onto source vertices")))
       (define blocks
         (for/hash ([source-address (in-list (vertex-addresses source))])
           (values
            source-address
            (sort
             (for/list ([(expanded-address owner) (in-hash collapse)]
                        #:when (equal? owner source-address))
               expanded-address)
             address<?))))
       ;; The anchor cone must be exactly the expansion of the corresponding
       ;; source cone.  This is the concrete positive block/substitution law.
       (for ([source-address (in-list (vertex-addresses source))])
         (define anchor (hash-ref anchors source-address))
         (define anchor-cone
           (filter (lambda (address) (address-prefix? anchor address))
                   (vertex-addresses expanded)))
         (define collapsed-source-cone
           (sort
            (for/list ([(expanded-address owner) (in-hash collapse)]
                       #:when (address-prefix? source-address owner))
              expanded-address)
            address<?))
         (unless (equal? anchor-cone collapsed-source-cone)
           (abort
            (failure
             'macro-anchor-law-failed
             "a positive macro anchor does not delimit exactly one expanded source cone"
             (hash 'source-address source-address 'anchor anchor)))))
       (define interpreted-summaries
         (for/list ([interpretation (in-list interpretations)])
           (interpretation-potential-summary interpretation target-signature)))
       (define fidelity?
         (and source-profile target-profile
              (for/and ([interpretation (in-list interpretations)])
                (equal?
                 (material-profile-designates?
                  source-profile
                  (normalization-macro-interpretation-source-occurrence
                   interpretation))
                 (macro-rigid-base-pure? interpretation target-profile)))))
       (define positive-reclassification
         (if (and source-profile target-profile)
             (sort
              (for/list ([address (in-list (vertex-addresses source))]
                         #:do
                         [(define occurrence
                            (checked-node-occurrence
                             (vertex-at-address source address)))
                          (define interpretation (hash-ref table occurrence))]
                         #:when
                         (and (not (material-profile-designates?
                                    source-profile occurrence))
                              (macro-rigid-base-pure?
                               interpretation target-profile)))
                address)
              address<?)
             '()))
       (positive-normalization-elaboration
        source expanded calculus interpretations target-signature collapse
        anchors blocks interpreted-summaries source-profile target-profile
        (and fidelity? #t) positive-reclassification
        (expansion-result-inspections result)))]))

(define (pullback-normalization-potential source elaboration)
  (define who 'pullback-normalization-potential)
  (unless (checked-term? source)
    (raise-argument-error who "checked-term?" source))
  (unless (positive-normalization-elaboration? elaboration)
    (raise-argument-error who "positive-normalization-elaboration?"
                          elaboration))
  (define calculus (positive-normalization-elaboration-calculus elaboration))
  (unless (and (eq? (checked-term-calculus source) calculus)
               (exact-term-in-calculus? calculus source))
    (raise-arguments-error who "source must use the exact elaboration calculus"
                           "source" source))
  (define table
    (for/hasheq
        ([summary
          (in-list
           (positive-normalization-elaboration-interpreted-summaries
            elaboration))])
      (values (interpreted-rule-potential-summary-source-occurrence summary)
              summary)))
  (define totals
    (let/ec abort
      (define (walk current)
        (cond
          [(checked-hole? current) (values 0 0 0)]
          [else
           (define summary
             (hash-ref table (checked-node-occurrence current) #f))
           (unless summary
             (abort
              (failure
               'missing-potential-summary
               "the source contains an occurrence with no interpreted macro summary"
               (hash 'occurrence (checked-node-occurrence current)))))
           (define child-values
             (for/list ([child (in-list (checked-node-children current))])
               (call-with-values (lambda () (walk child)) list)))
           (values
            (+ (interpreted-rule-potential-summary-N summary)
               (for/sum ([entry (in-list child-values)]) (first entry)))
            (+ (interpreted-rule-potential-summary-A summary)
               (for/sum ([entry (in-list child-values)]) (second entry)))
            (+ (interpreted-rule-potential-summary-H summary)
               (for/sum ([entry (in-list child-values)]) (third entry))
               (for/sum
                   ([ancestor-count
                     (in-list
                      (interpreted-rule-potential-summary-cut-ancestor-counts
                       summary))]
                    [entry (in-list child-values)])
                 (* ancestor-count (first entry)))))]))
       (call-with-values (lambda () (walk source)) list)))
  (if (normalization-replay-failure? totals)
      totals
      (match-let ([(list N A H) totals])
        (define M
          (normalization-signature-macro-bound
           (positive-normalization-elaboration-target-signature elaboration)))
        (define L (+ N (* M A)))
        (normalization-potential N A H M L (+ (* A (+ 1 (* L L))) H)))))

(define (union-class-list parent classes)
  (for/fold ([current parent]) ([class (in-list classes)])
    (define members
      (if (replay-read-class? class)
          (replay-read-class-members class)
          class))
    (define-values (next _representative) (uf-union current members))
    next))

(define (partition-members classes)
  (map replay-read-class-members classes))

(define (analyze-normalization-collapse elaboration history)
  (define who 'analyze-normalization-collapse)
  (unless (positive-normalization-elaboration? elaboration)
    (raise-argument-error who "positive-normalization-elaboration?"
                          elaboration))
  (unless (normalization-replay-certificate? history)
    (raise-argument-error who "normalization-replay-certificate?" history))
  (define expanded (positive-normalization-elaboration-expanded elaboration))
  (cond
    [(not (eq? expanded (normalization-replay-certificate-source history)))
     (failure 'wrong-collapse-history-source
              "collapse analysis requires the exact elaborated proof used by the history")]
    [else
     (define source (positive-normalization-elaboration-source elaboration))
     (define collapse (positive-normalization-elaboration-collapse elaboration))
     (define target-classes
       (normalization-replay-certificate-read-partition history))
     (define source-addresses (vertex-addresses source))
     (define source-parent0 (initial-parent source))
     (define source-parent
       (for/fold ([parent source-parent0]) ([class (in-list target-classes)])
         (define images
           (remove-duplicates
            (map (lambda (address) (hash-ref collapse address))
                 (replay-read-class-members class))
            equal?))
         (define-values (next _representative) (uf-union parent images))
         next))
     (define projected-marks
       (for*/set ([class (in-list target-classes)]
                  #:when (replay-read-class-ever-read? class)
                  [address (in-list (replay-read-class-members class))])
         (hash-ref collapse address)))
     (define pulled
       (classes-from-parent+marks
        source-parent source-addresses projected-marks))
     (define expanded-addresses (vertex-addresses expanded))
     (define expanded-parent0 (initial-parent expanded))
     (define kernel-parent
       (union-class-list
        expanded-parent0
        (hash-values (positive-normalization-elaboration-blocks elaboration))))
     (define kernel-join-parent
       (union-class-list kernel-parent target-classes))
     (define kernel-join
       (classes-from-parent+marks kernel-join-parent expanded-addresses (set)))
     (define inverse-parent
       (for/fold ([parent expanded-parent0]) ([class (in-list pulled)])
         (define source-members (replay-read-class-members class))
         (define expanded-members
           (for/list ([(address owner) (in-hash collapse)]
                      #:when (member owner source-members equal?))
             address))
         (define-values (next _representative)
           (uf-union parent expanded-members))
         next))
     (define inverse-image
       (classes-from-parent+marks inverse-parent expanded-addresses (set)))
     (define join-equal?
       (equal? (partition-members kernel-join)
               (partition-members inverse-image)))
     (normalization-collapse-analysis
      pulled
      (sort (set->list projected-marks) address<?)
      kernel-join inverse-image join-equal?
      (compute-guarded-fold source pulled
                            (guarded-cut-fold-term-cap
                             (normalization-replay-certificate-guarded-fold
                              history))))]))

(define (partition-guards-witness? classes witness)
  (define owners
    (initial-owner-map (cut-witness-source witness)
                       (cut-witness-addresses witness)))
  (for/and ([class (in-list classes)])
    (= (length
        (remove-duplicates
         (map (lambda (address) (hash-ref owners address))
              (replay-read-class-members class))
         =))
       1)))

(define (certify-source-aligned-frontier certificate addresses)
  (define who 'certify-source-aligned-frontier)
  (unless (compositional-normalization-certificate? certificate)
    (raise-argument-error who "compositional-normalization-certificate?"
                          certificate))
  (unless (and (list? addresses) (andmap address? addresses))
    (raise-argument-error who "(listof address?)" addresses))
  (define elaboration
    (compositional-normalization-certificate-elaboration certificate))
  (define source (positive-normalization-elaboration-source elaboration))
  (define source-witness (make-cut-witness source addresses))
  (cond
    [(cut-error? source-witness)
     (failure 'invalid-source-aligned-frontier
              "the source request is not an empty/proper native CK witness"
              (hash 'cut-error source-witness))]
    [else
     (define anchors (positive-normalization-elaboration-anchors elaboration))
     (define expanded-addresses
       (for/list ([address (in-list (cut-witness-addresses source-witness))])
         (hash-ref anchors address)))
     (define expanded-witness
       (make-cut-witness
        (positive-normalization-elaboration-expanded elaboration)
        expanded-addresses))
     (if (cut-error? expanded-witness)
         (failure 'invalid-anchor-lift
                  "the positive macro anchors did not form a native target CK witness"
                  (hash 'cut-error expanded-witness))
         (let* ([analysis
                 (compositional-normalization-certificate-collapse-analysis
                  certificate)]
                [guarded?
                 (partition-guards-witness?
                  (normalization-collapse-analysis-pulled-classes analysis)
                  source-witness)]
                [marked
                 (normalization-collapse-analysis-projected-marked-source-addresses
                  analysis)]
                [opaque?
                 (for/and ([root (in-list (cut-witness-addresses source-witness))])
                   (not (for/or ([address (in-list marked)])
                          (address-prefix? root address))))]
                [source-refill
                 (complete-fill
                  (cut-witness-remainder source-witness)
                  (map detached-entry-term
                       (cut-witness-detached source-witness)))]
                [expanded-refill
                 (complete-fill
                  (cut-witness-remainder expanded-witness)
                  (map detached-entry-term
                       (cut-witness-detached expanded-witness)))])
           (source-aligned-frontier-certificate
            source addresses source-witness
            (cut-witness-detached source-witness)
            (cut-witness-remainder source-witness) source-refill
            expanded-addresses expanded-witness
            (cut-witness-detached expanded-witness)
            (cut-witness-remainder expanded-witness) expanded-refill
            guarded? opaque? #f)))]))

(define (history-shape certificate)
  (for/list ([event
              (in-list
               (normalization-replay-certificate-events certificate))])
    (list (normalization-event-certificate-cell event)
          (normalization-event-request-address
           (normalization-event-certificate-request event)))))

(define (history-shapes-concatenate? prefix suffix direct)
  (define expected (append (history-shape prefix) (history-shape suffix)))
  (define actual (history-shape direct))
  (and (= (length expected) (length actual))
       (for/and ([left (in-list expected)] [right (in-list actual)])
         (and (eq? (first left) (first right))
              (equal? (second left) (second right))))))

(define (certificate-valid? certificate)
  (and (normalization-replay-certificate? certificate)
       (normalization-check-report-valid?
        (check-normalization-replay-certificate certificate))))

(define (certify-compositional-normalization
         elaboration principal-phase identity-phase direct-history)
  (define who 'certify-compositional-normalization)
  (unless (positive-normalization-elaboration? elaboration)
    (raise-argument-error who "positive-normalization-elaboration?"
                          elaboration))
  (unless (and (normalization-replay-certificate? principal-phase)
               (normalization-replay-certificate? identity-phase)
               (normalization-replay-certificate? direct-history))
    (raise-arguments-error who "expected three native normalization certificates"
                           "principal" principal-phase
                           "identity" identity-phase
                           "direct" direct-history))
  (cond
    [(not (and (certificate-valid? principal-phase)
               (certificate-valid? identity-phase)
               (certificate-valid? direct-history)))
     (failure 'invalid-compositional-history
              "every staged and direct history must pass the independent native checker")]
    [(not (and
           (eq? (positive-normalization-elaboration-expanded elaboration)
                (normalization-replay-certificate-source principal-phase))
           (eq? (normalization-replay-certificate-target principal-phase)
                (normalization-replay-certificate-source identity-phase))
           (eq? (positive-normalization-elaboration-expanded elaboration)
                (normalization-replay-certificate-source direct-history))
           (eq? (normalization-replay-certificate-target identity-phase)
                (normalization-replay-certificate-target direct-history))))
     (failure 'wrong-compositional-endpoints
              "elaboration and histories do not share their exact native endpoint objects")]
    [(not (history-shapes-concatenate?
           principal-phase identity-phase direct-history))
     (failure 'wrong-direct-history
              "the independently compiled direct history is not the staged event concatenation")]
    [(not (and
           (eq? (normalization-replay-certificate-material-profile principal-phase)
                (normalization-replay-certificate-material-profile identity-phase))
           (eq? (normalization-replay-certificate-material-profile principal-phase)
                (normalization-replay-certificate-material-profile direct-history))))
     (failure 'foreign-staged-base-profile
              "staged comparison requires one exact material profile B")]
    [else
     (let/ec abort
       (define principal-interface
         (normalization-certificate-causal-interface principal-phase))
       (define identity-interface
         (normalization-certificate-causal-interface identity-phase))
       (define composed
         (compose-normalization-causal-interfaces
          principal-interface identity-interface))
       (when (normalization-replay-failure? composed) (abort composed))
       (define direct-interface
         (normalization-certificate-causal-interface direct-history))
       (define agreement?
         (normalization-causal-interface-equivalent?
          composed direct-interface))
       (unless agreement?
         (abort
          (failure 'causal-composition-disagreement
                   "staged causal pushout disagrees with the independently checked direct history")))
       (define collapse-analysis
         (analyze-normalization-collapse elaboration direct-history))
       (when (normalization-replay-failure? collapse-analysis)
         (abort collapse-analysis))
       (unless (normalization-collapse-analysis-join-equal?
                collapse-analysis)
         (abort
          (failure 'collapse-join-law-failed
                   "kernel(collapse) join target reads differs from the pulled inverse image")))
       (define pullback
         (pullback-normalization-potential
          (positive-normalization-elaboration-source elaboration)
          elaboration))
       (when (normalization-replay-failure? pullback) (abort pullback))
       (define direct-initial
         (first
          (normalization-replay-certificate-potentials direct-history)))
       (unless (equal? pullback direct-initial)
         (abort
          (failure
           'pullback-potential-disagreement
           "macro/filler summaries do not recover the fixed target potential"
           (hash 'pullback pullback 'direct direct-initial))))
       (define opaque-inspections
         (+ (normalization-replay-certificate-opaque-interior-inspections
             principal-phase)
            (normalization-replay-certificate-opaque-interior-inspections
             identity-phase)
            (normalization-replay-certificate-opaque-interior-inspections
             direct-history)))
       (unless (zero? opaque-inspections)
         (abort
          (failure 'opaque-interior-read
                   "admitted opaque providers were inspected during normalization")))
       (compositional-normalization-certificate
        elaboration principal-phase identity-phase direct-history
        principal-interface identity-interface composed direct-interface
        agreement? collapse-analysis pullback direct-initial
        'empty+proper 1 opaque-inspections))]))

(define (check-compositional-normalization-certificate certificate)
  (unless (compositional-normalization-certificate? certificate)
    (raise-argument-error
     'check-compositional-normalization-certificate
     "compositional-normalization-certificate?" certificate))
  (define elaboration
    (compositional-normalization-certificate-elaboration certificate))
  (define rebuilt-elaboration
    (compile-positive-normalization-elaboration
     (positive-normalization-elaboration-source elaboration)
     (positive-normalization-elaboration-expanded elaboration)
     (positive-normalization-elaboration-interpretations elaboration)
     (positive-normalization-elaboration-target-signature elaboration)
     #:source-profile
     (positive-normalization-elaboration-source-profile elaboration)
     #:target-profile
     (positive-normalization-elaboration-target-profile elaboration)))
  (cond
    [(normalization-replay-failure? rebuilt-elaboration)
     (normalization-check-report
      #f '((positive-elaboration . #f)) 0 0
      (hash 'failure rebuilt-elaboration))]
    [(not (equal? rebuilt-elaboration elaboration))
     (normalization-check-report
      #f '((positive-elaboration . #f)) 0 0
      (hash 'failure 'elaboration-metadata-mismatch))]
    [else
     (define recomputed
       (certify-compositional-normalization
        rebuilt-elaboration
        (compositional-normalization-certificate-principal-phase certificate)
        (compositional-normalization-certificate-identity-phase certificate)
        (compositional-normalization-certificate-direct-history certificate)))
     (if (and (compositional-normalization-certificate? recomputed)
              (equal? recomputed certificate))
         (normalization-check-report
          #t
          '((positive-elaboration . #t)
            (native-phases . #t)
            (causal-pushout . #t)
            (collapse-join . #t)
            (pullback-potential . #t)
            (opaque-replay . #t))
          0 0 (hash))
         (normalization-check-report
          #f '((integrated-recomputation . #f)) 0 0
          (hash 'failure recomputed)))]))
