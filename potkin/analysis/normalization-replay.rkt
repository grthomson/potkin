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
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "ancestry.rkt"
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
 certify-guarded-source-cut)

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
