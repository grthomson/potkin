#lang racket/base

;; Compact open-CK macro summaries over the existing checked context carrier.
;; Circuit nodes below are analysis metadata only.  They never replace checked
;; terms, typed punctures, occurrence addresses, cut witnesses, or forests.

(require racket/list
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt")

(provide macro-port?
         make-macro-port
         macro-port-name
         macro-port-boundary
         macro-port-allows-zero-use?

         macro-input?
         macro-input-address
         macro-input-port
         macro-input-boundary
         macro-endpoint?
         macro-endpoint-address
         macro-endpoint-occurrence

         macro-circuit?
         macro-circuit-hole?
         macro-circuit-hole-input
         macro-circuit-product?
         macro-circuit-product-factors
         macro-circuit-root?
         macro-circuit-root-endpoint
         macro-circuit-root-children

         macro-summary?
         macro-summary-calculus
         macro-summary-context
         macro-summary-ports
         macro-summary-inputs
         macro-summary-port-occurrences
         macro-summary-fixed-vertex-count
         macro-summary-port-use-counts
         macro-summary-circuit
         compile-macro-summary
         macro-summary-use-count
         macro-summary-occurrence-addresses
         macro-circuit-fold
         evaluate-macro-summary
         macro-summary-substitute)

;; A zero-use declaration is explicit metadata.  It authorises a declared
;; logical port to have no native puncture; it does not create a puncture.
(struct macro-port (name boundary allows-zero-use?)
  #:constructor-name make-macro-port/internal
  #:transparent)

(define (make-macro-port name boundary
                         #:allow-zero-use? [allows-zero-use? #f])
  (unless (symbol? name)
    (raise-argument-error 'make-macro-port "symbol?" name))
  (unless (hypersequent? boundary)
    (raise-argument-error 'make-macro-port "hypersequent?" boundary))
  (unless (boolean? allows-zero-use?)
    (raise-argument-error 'make-macro-port "boolean?" allows-zero-use?))
  (make-macro-port/internal name boundary allows-zero-use?))

;; A macro input is one exact native puncture occurrence.  Equal logical ports
;; at different addresses therefore remain distinct until diagonal counting.
(struct macro-input (address port boundary) #:transparent)

;; The endpoint is the separately weighted whole connected root at this
;; native vertex occurrence.  It is never represented by a root cut.
(struct macro-endpoint (address occurrence) #:transparent)

(struct macro-circuit-hole (input) #:transparent)
(struct macro-circuit-product (factors) #:transparent)
(struct macro-circuit-root (endpoint children) #:transparent)

(define (macro-circuit? value)
  (or (macro-circuit-hole? value)
      (macro-circuit-product? value)
      (macro-circuit-root? value)))

(struct macro-summary
  (calculus context ports inputs port-occurrences fixed-vertex-count
            port-use-counts circuit)
  #:constructor-name make-macro-summary/internal
  #:transparent)

(define (mapping-entry->binding who entry)
  (cond
    [(and (pair? entry)
          (address? (car entry))
          (symbol? (cdr entry)))
     (cons (car entry) (cdr entry))]
    [(and (list? entry)
          (= (length entry) 2)
          (address? (first entry))
          (symbol? (second entry)))
     (cons (first entry) (second entry))]
    [else
     (raise-arguments-error
      who
      "each input mapping must pair one native puncture address with a declared port name"
      "mapping entry" entry)]))

(define (puncture-prefix-conflict addresses)
  (for*/first ([outer (in-list addresses)]
               [inner (in-list addresses)]
               #:when (and (not (equal? outer inner))
                           (address-prefix? outer inner)))
    (list outer inner)))

(define (build-circuit term input-table [address root-address])
  (cond
    [(checked-hole? term)
     (macro-circuit-hole
      (hash-ref
       input-table
       address
       (lambda ()
         (error 'compile-macro-summary
                "internal input table lacks native puncture ~e"
                address))))]
    [else
     (macro-circuit-root
      (macro-endpoint address (checked-node-occurrence term))
      (macro-circuit-product
       (for/list ([child (in-list (checked-node-children term))]
                  [slot (in-naturals 1)])
         (build-circuit child input-table
                        (address-append address (list slot))))))]))

(define (compile-macro-summary calculus context ports input-mapping)
  (define who 'compile-macro-summary)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (checked-term? context)
    (raise-argument-error who "checked-term?" context))
  (unless (and (list? ports) (andmap macro-port? ports))
    (raise-argument-error who "(listof macro-port?)" ports))
  (unless (list? input-mapping)
    (raise-argument-error who "list?" input-mapping))
  (unless (and (eq? (checked-term-calculus context) calculus)
               (checked-term-has-exact-calculus? context calculus)
               (term-admitted-by? calculus context))
    (raise-arguments-error
     who
     "the checked macro must carry and be admitted by the exact supplied calculus snapshot"
     "supplied calculus" calculus
     "context calculus" (checked-term-calculus context)
     "context" context))

  (define port-names (map macro-port-name ports))
  (define duplicate-port (check-duplicates port-names eq?))
  (when duplicate-port
    (raise-arguments-error
     who "source-port names must be distinct"
     "duplicate port" duplicate-port))
  (define port-table
    (for/hash ([port (in-list ports)])
      (values (macro-port-name port) port)))

  (define bindings
    (sort (map (lambda (entry) (mapping-entry->binding who entry))
               input-mapping)
          address<?
          #:key car))
  (define mapped-addresses (map car bindings))
  (define duplicate-address (check-duplicates mapped-addresses equal?))
  (when duplicate-address
    (raise-arguments-error
     who "each native puncture occurrence must be mapped exactly once"
     "duplicate address" duplicate-address))

  (define native-addresses (puncture-addresses context))
  (define prefix-conflict (puncture-prefix-conflict native-addresses))
  (when prefix-conflict
    (raise-arguments-error
     who "native puncture addresses must be prefix-free"
     "outer address" (first prefix-conflict)
     "inner address" (second prefix-conflict)))
  (unless (equal? mapped-addresses native-addresses)
    (raise-arguments-error
     who
     "the mapping must cover exactly the native puncture occurrences"
     "native punctures" native-addresses
     "mapped addresses" mapped-addresses))

  (define inputs
    (for/list ([binding (in-list bindings)])
      (define address (car binding))
      (define port-name (cdr binding))
      (define port (hash-ref port-table port-name #f))
      (unless port
        (raise-arguments-error
         who "every mapped puncture must name a declared source port"
         "address" address
         "port" port-name))
      (define selected (checked-term-at-address context address))
      (unless (checked-hole? selected)
        (raise-arguments-error
         who "an input occurrence must be a native typed puncture"
         "address" address
         "selected term" selected))
      (define requirement (puncture-requirement context address))
      (unless (equal? requirement (macro-port-boundary port))
        (raise-arguments-error
         who "the puncture boundary must equal its declared port boundary"
         "address" address
         "expected" (macro-port-boundary port)
         "actual" requirement))
      (macro-input address port-name requirement)))

  (define port-occurrences
    (for/hash ([port (in-list ports)])
      (define name (macro-port-name port))
      (values name
              (filter (lambda (input)
                        (eq? name (macro-input-port input)))
                      inputs))))
  (for ([port (in-list ports)])
    (define occurrences
      (hash-ref port-occurrences (macro-port-name port)))
    (when (and (null? occurrences)
               (not (macro-port-allows-zero-use? port)))
      (raise-arguments-error
       who
       "an unused declared port requires an explicit zero-use declaration"
       "port" (macro-port-name port))))
  (define port-use-counts
    (for/hash ([(name occurrences) (in-hash port-occurrences)])
      (values name (length occurrences))))
  (define input-table
    (for/hash ([input (in-list inputs)])
      (values (macro-input-address input) input)))

  (make-macro-summary/internal
   calculus
   context
   ports
   inputs
   port-occurrences
   (derivation-vertex-count context)
   port-use-counts
   (build-circuit context input-table)))

(define (macro-summary-use-count summary port-name)
  (unless (macro-summary? summary)
    (raise-argument-error 'macro-summary-use-count "macro-summary?" summary))
  (unless (symbol? port-name)
    (raise-argument-error 'macro-summary-use-count "symbol?" port-name))
  (unless (hash-has-key? (macro-summary-port-use-counts summary) port-name)
    (raise-arguments-error
     'macro-summary-use-count "the port is not declared by this summary"
     "port" port-name))
  (hash-ref (macro-summary-port-use-counts summary) port-name))

(define (macro-summary-occurrence-addresses summary port-name)
  (unless (macro-summary? summary)
    (raise-argument-error
     'macro-summary-occurrence-addresses "macro-summary?" summary))
  (unless (symbol? port-name)
    (raise-argument-error
     'macro-summary-occurrence-addresses "symbol?" port-name))
  (unless (hash-has-key? (macro-summary-port-occurrences summary) port-name)
    (raise-arguments-error
     'macro-summary-occurrence-addresses
     "the port is not declared by this summary"
     "port" port-name))
  (map macro-input-address
       (hash-ref (macro-summary-port-occurrences summary) port-name)))

;; Generic evaluator for
;;   Phi(Box_h) = x_h
;;   Phi(F G) = Phi(F) Phi(G)
;;   Phi(B_r(C1,...,Ck)) = u_r + product_j Phi(Cj).
;; `zero` is accepted explicitly as part of the caller's target algebra even
;; though a compiled connected circuit has no empty-sum node.
(define (macro-circuit-fold circuit
                            #:add add
                            #:multiply multiply
                            #:zero zero
                            #:one one
                            #:hole hole-valuation
                            #:endpoint endpoint-valuation)
  (unless (macro-circuit? circuit)
    (raise-argument-error 'macro-circuit-fold "macro-circuit?" circuit))
  (for ([procedure (in-list
                    (list add multiply hole-valuation endpoint-valuation))])
    (unless (procedure? procedure)
      (raise-argument-error 'macro-circuit-fold "procedure?" procedure)))
  (void zero)
  (let evaluate ([current circuit])
    (cond
      [(macro-circuit-hole? current)
       (hole-valuation (macro-circuit-hole-input current))]
      [(macro-circuit-product? current)
       (for/fold ([value one])
                 ([factor (in-list
                           (macro-circuit-product-factors current))])
         (multiply value (evaluate factor)))]
      [else
       (add
        (endpoint-valuation (macro-circuit-root-endpoint current))
        (evaluate (macro-circuit-root-children current)))])))

(define (evaluate-macro-summary summary
                                #:add add
                                #:multiply multiply
                                #:zero zero
                                #:one one
                                #:hole hole-valuation
                                #:endpoint endpoint-valuation)
  (unless (macro-summary? summary)
    (raise-argument-error
     'evaluate-macro-summary "macro-summary?" summary))
  (macro-circuit-fold
   (macro-summary-circuit summary)
   #:add add
   #:multiply multiply
   #:zero zero
   #:one one
   #:hole hole-valuation
   #:endpoint endpoint-valuation))

(define (find-port ports name)
  (findf (lambda (port) (eq? (macro-port-name port) name)) ports))

(define (merge-port-declarations who outer-ports filler-ports selected-name)
  (for/fold ([merged
              (filter (lambda (port)
                        (not (eq? (macro-port-name port) selected-name)))
                      outer-ports)])
            ([candidate (in-list filler-ports)])
    (define name (macro-port-name candidate))
    (define existing (find-port merged name))
    (cond
      [(not existing) (append merged (list candidate))]
      [(not (equal? (macro-port-boundary existing)
                    (macro-port-boundary candidate)))
       (raise-arguments-error
        who "same-named retained and inserted ports must have one boundary"
        "port" name
        "outer boundary" (macro-port-boundary existing)
        "filler boundary" (macro-port-boundary candidate))]
      [else
       (define replacement
         (make-macro-port
          name
          (macro-port-boundary existing)
          #:allow-zero-use?
          (or (macro-port-allows-zero-use? existing)
              (macro-port-allows-zero-use? candidate))))
       (map (lambda (port)
              (if (eq? (macro-port-name port) name) replacement port))
            merged)])))

;; Substitute an independently rechecked copy of `filler` at every native
;; occurrence of `port-name`.  Recompilation gives every copied hole and rule
;; occurrence its flattened outer-prefix/native-relative address.
(define (macro-summary-substitute outer port-name filler)
  (define who 'macro-summary-substitute)
  (unless (macro-summary? outer)
    (raise-argument-error who "macro-summary?" outer))
  (unless (symbol? port-name)
    (raise-argument-error who "symbol?" port-name))
  (unless (macro-summary? filler)
    (raise-argument-error who "macro-summary?" filler))
  (define calculus (macro-summary-calculus outer))
  (unless (eq? calculus (macro-summary-calculus filler))
    (raise-arguments-error
     who "macro substitution requires one exact calculus snapshot"
     "outer calculus" calculus
     "filler calculus" (macro-summary-calculus filler)))
  (define selected-port (find-port (macro-summary-ports outer) port-name))
  (unless selected-port
    (raise-arguments-error
     who "the substituted port must be declared by the outer macro"
     "port" port-name))
  (define selected-inputs
    (hash-ref (macro-summary-port-occurrences outer) port-name))
  (when (null? selected-inputs)
    (raise-arguments-error
     who "substitution requires at least one native occurrence of the port"
     "port" port-name))
  (unless (equal? (macro-port-boundary selected-port)
                  (derivation-root-boundary
                   (macro-summary-context filler)))
    (raise-arguments-error
     who "the filler root must match the substituted port boundary"
     "port boundary" (macro-port-boundary selected-port)
     "filler root"
     (derivation-root-boundary (macro-summary-context filler))))

  (define filled-context
    (for/fold ([current (macro-summary-context outer)])
              ([input (in-list selected-inputs)])
      ;; Rechecking each copy prevents host-language object sharing from being
      ;; used as occurrence identity.  Native addresses remain authoritative.
      (define fresh-copy
        (validate-candidate
         calculus
         (checked-term->raw (macro-summary-context filler))
         #:expected (macro-input-boundary input)))
      (when (validation-error? fresh-copy)
        (raise-arguments-error
         who "rechecking an independent filler copy failed"
         "outer address" (macro-input-address input)
         "validation error" fresh-copy))
      (define inserted
        (context-insert current (macro-input-address input) fresh-copy))
      (when (context-error? inserted)
        (raise-arguments-error
         who "native context insertion failed"
         "outer address" (macro-input-address input)
         "context error" inserted))
      inserted))

  (define retained-bindings
    (for/list ([input (in-list (macro-summary-inputs outer))]
               #:unless (eq? (macro-input-port input) port-name))
      (cons (macro-input-address input) (macro-input-port input))))
  (define inserted-bindings
    (append-map
     (lambda (outer-input)
       (for/list ([inner-input (in-list (macro-summary-inputs filler))])
         (cons
          (address-append (macro-input-address outer-input)
                          (macro-input-address inner-input))
          (macro-input-port inner-input))))
     selected-inputs))
  (define result-ports
    (merge-port-declarations
     who
     (macro-summary-ports outer)
     (macro-summary-ports filler)
     port-name))
  (compile-macro-summary
   calculus
   filled-context
   result-ports
   (append retained-bindings inserted-bindings)))
