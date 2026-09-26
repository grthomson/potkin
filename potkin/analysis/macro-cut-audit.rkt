#lang racket/base

;; Bounded occurrence-level comparison of two ways to obtain the native CK
;; cuts of a filled open macro.  The structures in this module are audit
;; metadata only: every target cut, detached tuple, forest, remainder, and
;; reconstruction is a native POTKIN object.

(require racket/list
         "../kernel/address.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "macro-summary.rkt")

(provide macro-pointed-state?
         macro-pointed-state-kind
         macro-pointed-state-witness

         macro-copy-profile-entry?
         macro-copy-profile-entry-occurrence-address
         macro-copy-profile-entry-port
         macro-copy-profile-entry-source-state
         macro-copy-profile-entry-embedded-addresses

         macro-whole-endpoint?
         macro-whole-endpoint-target
         macro-whole-endpoint-paired-source-state

         macro-cut-audit-entry?
         macro-cut-audit-entry-sector
         macro-cut-audit-entry-witness
         macro-cut-audit-entry-addresses
         macro-cut-audit-entry-detached
         macro-cut-audit-entry-forest
         macro-cut-audit-entry-remainder
         macro-cut-audit-entry-copy-profile
         macro-cut-audit-entry-paired-source-state
         macro-cut-audit-entry-reconstruction

         macro-cut-audit?
         macro-cut-audit-summary
         macro-cut-audit-port
         macro-cut-audit-filler
         macro-cut-audit-target
         macro-cut-audit-source-states
         macro-cut-audit-entries
         macro-cut-audit-compositional-entries
         macro-cut-audit-lost-states
         macro-cut-audit-endpoint
         macro-cut-audit-completeness
         macro-cut-audit-direct=compositional?
         audit-macro-cuts
         macro-cut-audit-sector-count
         macro-cut-audit-transport-source-state)

;; `whole` always has witness #f.  In particular, it is not encoded as a
;; native root cut.  Empty and proper states retain their native witnesses.
(struct macro-pointed-state (kind witness)
  #:constructor-name make-macro-pointed-state/internal
  #:transparent)

;; Copy identity is the native macro puncture address.  The logical port name
;; remains a separate field, so repeated uses of one port never collapse.
(struct macro-copy-profile-entry
  (occurrence-address port source-state embedded-addresses)
  #:constructor-name make-macro-copy-profile-entry/internal
  #:transparent)

;; The target's algebraic whole-tree endpoint is witness-free.
(struct macro-whole-endpoint (target paired-source-state)
  #:constructor-name make-macro-whole-endpoint/internal
  #:transparent)

(struct macro-cut-audit-entry
  (sector witness addresses detached forest remainder copy-profile
          paired-source-state reconstruction)
  #:constructor-name make-macro-cut-audit-entry/internal
  #:transparent)

(struct macro-cut-audit
  (summary port filler target source-states entries compositional-entries
           lost-states endpoint completeness direct=compositional?)
  #:constructor-name make-macro-cut-audit/internal
  #:transparent)

(define (find-port summary port-name)
  (findf (lambda (port) (eq? (macro-port-name port) port-name))
         (macro-summary-ports summary)))

(define (bounded-sequence->list sequence limit)
  ;; Inspect at most one item beyond the retained prefix, solely to establish
  ;; whether the finite witness limit was exceeded.
  (define items '())
  (define truncated? #f)
  (for ([item sequence]
        [index (in-range (add1 limit))])
    (if (= index limit)
        (set! truncated? #t)
        (set! items (cons item items))))
  (values (reverse items) truncated?))

(define (fresh-copy who calculus filler expected address)
  (define copy
    (validate-candidate calculus
                        (checked-term->raw filler)
                        #:expected expected))
  (when (validation-error? copy)
    (raise-arguments-error
     who
     "rechecking an independent filler copy failed"
     "macro occurrence address" address
     "validation error" copy))
  copy)

(define (pointed-state-owner-addresses state)
  (case (macro-pointed-state-kind state)
    [(empty) '()]
    [(proper)
     (cut-witness-addresses (macro-pointed-state-witness state))]
    [(whole) (list root-address)]
    [else
     (error 'audit-macro-cuts "unknown pointed-state kind: ~e"
            (macro-pointed-state-kind state))]))

(define (prefix-free-addresses? addresses)
  (not
   (for*/or ([left (in-list addresses)]
             [right (in-list addresses)])
     (proper-address-prefix? left right))))

(define (strip-address-prefix prefix address)
  (drop address (length prefix)))

(define (native-state-table source-states)
  (for/hash ([state (in-list source-states)]
             #:unless (eq? (macro-pointed-state-kind state) 'whole))
    (values (cut-witness-addresses
             (macro-pointed-state-witness state))
            state)))

(define (classify-addresses who summary inputs source-states address-set)
  (define strict-fixed-addresses
    (if (checked-node? (macro-summary-context summary))
        (filter pair? (vertex-addresses (macro-summary-context summary)))
        '()))
  (define state-table (native-state-table source-states))
  (define whole-state
    (findf (lambda (state)
             (eq? (macro-pointed-state-kind state) 'whole))
           source-states))
  (define empty-state
    (hash-ref state-table '()
              (lambda ()
                (error who "the source empty witness is missing"))))

  ;; A target address must be either a fixed macro vertex or owned by one
  ;; exact puncture occurrence.  This check rules out accidental reliance on
  ;; rule names or on an untracked address conversion.
  (for ([address (in-list address-set)])
    (unless
        (or (member address strict-fixed-addresses equal?)
            (for/or ([input (in-list inputs)])
              (address-prefix? (macro-input-address input) address)))
      (error who "target cut address has no macro/copy owner: ~e" address)))

  (define profile
    (for/list ([input (in-list inputs)])
      (define occurrence-address (macro-input-address input))
      (define at-copy-root?
        (member occurrence-address address-set equal?))
      (define relative-addresses
        (if at-copy-root?
            #f
            (sort
             (for/list ([address (in-list address-set)]
                        #:when (proper-address-prefix?
                                occurrence-address address))
               (strip-address-prefix occurrence-address address))
             address<?)))
      (define state
        (cond
          [at-copy-root? whole-state]
          [else
           (hash-ref
            state-table relative-addresses
            (lambda ()
              (error who
                     "target cut does not strip to a native source state at ~e: ~e"
                     occurrence-address relative-addresses)))]))
      (make-macro-copy-profile-entry/internal
       occurrence-address
       (macro-input-port input)
       state
       (cond
         [at-copy-root? (list occurrence-address)]
         [else
          (map (lambda (relative)
                 (address-append occurrence-address relative))
               relative-addresses)]))))

  (define macro-internal?
    (for/or ([address (in-list address-set)])
      (member address strict-fixed-addresses equal?)))
  (define states
    (map macro-copy-profile-entry-source-state profile))
  (define saturated?
    (or (null? states)
        (andmap (lambda (state) (eq? state (car states))) (cdr states))))
  (define paired-state
    (and saturated?
         (if (null? states) empty-state (car states))))
  (cond
    [macro-internal? (values 'macro-internal profile #f)]
    [saturated? (values 'saturated profile paired-state)]
    [else
     (define owner-union
       (sort
        (remove-duplicates
         (append-map
          (lambda (state) (pointed-state-owner-addresses state))
          states)
         equal?)
        address<?))
     (values (if (prefix-free-addresses? owner-union)
                 'partial-copy
                 'cross-copy)
             profile
             #f)]))

(define (make-checked-entry who calculus target summary inputs source-states
                            witness)
  (unless (cut-witness? witness)
    (error who "native cut construction failed: ~e" witness))
  (unless (and (eq? (checked-term-calculus (cut-witness-source witness))
                    calculus)
               (checked-term-has-exact-calculus?
                (cut-witness-source witness) calculus)
               (equal? (cut-witness-source witness) target))
    (error who "native witness lost its exact target provenance"))
  (define addresses (cut-witness-addresses witness))
  (define validated (validate-ck-cut target addresses))
  (unless (equal? validated addresses)
    (error who "native witness no longer validates as its recorded cut: ~e"
           addresses))
  (define detached (cut-witness-detached witness))
  (unless (equal? (map detached-entry-address detached) addresses)
    (error who "detached tuple is not ordered and address-aligned"))
  (for ([entry (in-list detached)])
    (unless (checked-term-has-exact-calculus?
             (detached-entry-term entry) calculus)
      (error who "detached factor lost exact calculus provenance")))
  (define forest (cut-witness-forest witness))
  (unless (eq? (proof-forest-calculus forest) calculus)
    (error who "detached forest lost exact calculus provenance"))
  (define remainder (cut-witness-remainder witness))
  (unless (checked-term-has-exact-calculus? remainder calculus)
    (error who "punctured remainder lost exact calculus provenance"))
  ;; Reconstruction intentionally consumes the retained native remainder and
  ;; detached tuple; retaining them is not merely documentary.
  (define reconstruction (reconstruct-cut-witness witness))
  (unless (and (checked-term? reconstruction)
               (checked-term-has-exact-calculus? reconstruction calculus)
               (equal? reconstruction target)
               (cut-witness-reconstructs? witness))
    (error who "native witness failed exact checked-target reconstruction"))
  (define-values (sector profile paired-state)
    (classify-addresses who summary inputs source-states addresses))
  (make-macro-cut-audit-entry/internal
   sector witness addresses detached forest remainder profile paired-state
   reconstruction))

(define (entry-comparison-key entry)
  ;; This is deliberately much finer than a coefficient/count comparison.
  (list (macro-cut-audit-entry-sector entry)
        (macro-cut-audit-entry-addresses entry)
        (macro-cut-audit-entry-detached entry)
        (macro-cut-audit-entry-forest entry)
        (macro-cut-audit-entry-remainder entry)
        (macro-cut-audit-entry-copy-profile entry)
        (macro-cut-audit-entry-paired-source-state entry)
        (macro-cut-audit-entry-reconstruction entry)))

(define (entry-multiset entries)
  (for/fold ([counts (hash)]) ([entry (in-list entries)])
    (hash-update counts (entry-comparison-key entry) add1 0)))

(define (cartesian-tuples choices count)
  (if (zero? count)
      (list '())
      (for*/list ([head (in-list choices)]
                  [tail (in-list (cartesian-tuples choices (sub1 count)))])
        (cons head tail))))

(define (embedded-state-addresses occurrence-address state)
  (case (macro-pointed-state-kind state)
    [(empty) '()]
    [(proper)
     (map (lambda (address)
            (address-append occurrence-address address))
          (cut-witness-addresses (macro-pointed-state-witness state)))]
    [(whole)
     ;; #f marks the unique Pass-at-root endpoint.  It is never sent to the
     ;; native cut constructor as a fabricated root address.
     (and (pair? occurrence-address) (list occurrence-address))]
    [else
     (error 'audit-macro-cuts "unknown pointed-state kind: ~e"
            (macro-pointed-state-kind state))]))

(define (truncated-audit summary port-name filler target source-states
                         direct-entries endpoint
                         [compositional-entries '()])
  (make-macro-cut-audit/internal
   summary port-name filler target source-states direct-entries
   compositional-entries '() endpoint 'truncated #f))

(define (audit-macro-cuts summary port-name filler #:limit [limit 4096])
  (let/ec return
  (define who 'audit-macro-cuts)
  (unless (macro-summary? summary)
    (raise-argument-error who "macro-summary?" summary))
  (unless (symbol? port-name)
    (raise-argument-error who "symbol?" port-name))
  (unless (exact-positive-integer? limit)
    (raise-argument-error who "exact-positive-integer?" limit))
  (unless (complete-proof? filler)
    (raise-argument-error who "complete-proof?" filler))

  (define calculus (macro-summary-calculus summary))
  (unless (and (eq? (checked-term-calculus filler) calculus)
               (checked-term-has-exact-calculus? filler calculus)
               (term-admitted-by? calculus filler))
    (raise-arguments-error
     who
     "the filler must carry and be admitted by the exact macro calculus snapshot"
     "macro calculus" calculus
     "filler calculus" (checked-term-calculus filler)
     "filler" filler))
  (define port (find-port summary port-name))
  (unless port
    (raise-arguments-error who "the port is not declared by this summary"
                           "port" port-name))
  (unless (equal? (macro-port-boundary port)
                  (derivation-root-boundary filler))
    (raise-arguments-error
     who "the filler root must equal the selected port boundary"
     "port boundary" (macro-port-boundary port)
     "filler root" (derivation-root-boundary filler)))

  ;; This bounded auditor fills one logical port.  Every actual puncture must
  ;; therefore be one occurrence of that port; other declared zero-use ports
  ;; remain harmless metadata.
  (define inputs (macro-summary-inputs summary))
  (define foreign-input
    (findf (lambda (input) (not (eq? (macro-input-port input) port-name)))
           inputs))
  (when foreign-input
    (raise-arguments-error
     who
     "all native puncture occurrences must belong to the audited port"
     "audited port" port-name
     "other occurrence" foreign-input))

  (define copies
    (for/list ([input (in-list inputs)])
      (fresh-copy who calculus filler (macro-input-boundary input)
                  (macro-input-address input))))
  (define target (complete-fill (macro-summary-context summary) copies))
  (when (context-error? target)
    (raise-arguments-error who "native complete filling failed"
                           "context error" target))
  (unless (and (complete-proof? target)
               (checked-term-has-exact-calculus? target calculus)
               (term-admitted-by? calculus target))
    (error who "native filling did not produce an exact admitted proof"))

  (define-values (source-witnesses source-truncated?)
    (bounded-sequence->list
     (in-admissible-cut-witnesses filler) limit))
  (for ([witness (in-list source-witnesses)])
    (unless (cut-witness? witness)
      (error who "source native cut enumeration emitted an error: ~e"
             witness)))
  (define source-states
    (append
     (for/list ([witness (in-list source-witnesses)])
       (make-macro-pointed-state/internal
        (if (null? (cut-witness-addresses witness)) 'empty 'proper)
        witness))
     (list (make-macro-pointed-state/internal 'whole #f))))
  (define whole-state (last source-states))
  (define endpoint-pair
    (and (checked-hole? (macro-summary-context summary))
         (= (length inputs) 1)
         (null? (macro-input-address (car inputs)))
         whole-state))
  (define endpoint
    (make-macro-whole-endpoint/internal target endpoint-pair))
  (when source-truncated?
    (return
     (truncated-audit summary port-name filler target source-states '()
                      endpoint)))

  ;; Path A: the deliberately bounded expanded-target oracle.
  (define-values (target-witnesses target-truncated?)
    (bounded-sequence->list
     (in-admissible-cut-witnesses target) limit))
  (define direct-entries
    (for/list ([witness (in-list target-witnesses)])
      (make-checked-entry who calculus target summary inputs source-states
                          witness)))
  (when target-truncated?
    (return
     (truncated-audit summary port-name filler target source-states
                      direct-entries endpoint)))

  ;; Path B: enumerate only cuts of the unfilled macro skeleton, then combine
  ;; them with the ordered pointed state at each occurrence.  This path never
  ;; calls the filled target's all-witness enumerator.
  (define-values (outer-cuts outer-truncated?)
    (if (checked-hole? (macro-summary-context summary))
        (values (list '()) #f)
        (bounded-sequence->list
         (in-admissible-cuts (macro-summary-context summary)) limit)))
  (when outer-truncated?
    (return
     (truncated-audit summary port-name filler target source-states
                      direct-entries endpoint)))
  (define candidate-count
    (* (length outer-cuts)
       (expt (length source-states) (length inputs))))
  (when (> candidate-count limit)
    (return
     (truncated-audit summary port-name filler target source-states
                      direct-entries endpoint)))

  (define tuples (cartesian-tuples source-states (length inputs)))
  (define compositional-entries
    (reverse
     (for*/fold ([generated '()])
                ([outer-cut (in-list outer-cuts)]
                 [tuple (in-list tuples)])
       (define embedded
         (for/list ([input (in-list inputs)]
                    [state (in-list tuple)])
           (embedded-state-addresses (macro-input-address input) state)))
       (cond
         ;; Only the whole state of a root Pass reaches this case.  Its image
         ;; is the separate endpoint, never a native root-cut witness.
         [(member #f embedded) generated]
         [else
          (define target-addresses
            (sort (remove-duplicates
                   (append outer-cut (append* embedded)) equal?)
                  address<?))
          (define witness (make-cut-witness target target-addresses))
          (cond
            [(and (cut-error? witness)
                  (eq? (cut-error-code witness) 'non-prefix-free))
             generated]
            [(cut-error? witness)
             (error who "compositional native cut construction failed: ~e"
                    witness)]
            [else
             (cons
              (make-checked-entry who calculus target summary inputs
                                  source-states witness)
              generated)])]))))

  (define same-multiset?
    (equal? (entry-multiset direct-entries)
            (entry-multiset compositional-entries)))
  (define live-source-states
    (for/list ([entry (in-list direct-entries)]
               #:when (eq? (macro-cut-audit-entry-sector entry) 'saturated))
      (macro-cut-audit-entry-paired-source-state entry)))
  (define lost-states
    (for/list ([state (in-list source-states)]
               #:unless
               (or (memq state live-source-states)
                   (eq? state endpoint-pair)))
      state))
  (make-macro-cut-audit/internal
   summary port-name filler target source-states direct-entries
   compositional-entries lost-states endpoint 'complete same-multiset?)))

(define valid-sectors
  '(saturated partial-copy cross-copy macro-internal lost endpoint))

(define (macro-cut-audit-sector-count audit sector)
  (unless (macro-cut-audit? audit)
    (raise-argument-error
     'macro-cut-audit-sector-count "macro-cut-audit?" audit))
  (unless (memq sector valid-sectors)
    (raise-argument-error
     'macro-cut-audit-sector-count
     "(or/c 'saturated 'partial-copy 'cross-copy 'macro-internal 'lost 'endpoint)"
     sector))
  (case sector
    [(lost) (length (macro-cut-audit-lost-states audit))]
    [(endpoint) 1]
    [else
     (count (lambda (entry)
              (eq? (macro-cut-audit-entry-sector entry) sector))
            (macro-cut-audit-entries audit))]))

(define (macro-cut-audit-transport-source-state audit state)
  (unless (macro-cut-audit? audit)
    (raise-argument-error
     'macro-cut-audit-transport-source-state "macro-cut-audit?" audit))
  ;; Identity membership is intentional: native checked presentation equality
  ;; omits registry provenance, while transport must not cross snapshots.
  (unless (memq state (macro-cut-audit-source-states audit))
    (raise-arguments-error
     'macro-cut-audit-transport-source-state
     "the state must be one occurrence from this exact audit"
     "state" state))
  (or
   (findf
    (lambda (entry)
      (and (eq? (macro-cut-audit-entry-sector entry) 'saturated)
           (eq? (macro-cut-audit-entry-paired-source-state entry) state)))
    (macro-cut-audit-entries audit))
   (and (eq? (macro-whole-endpoint-paired-source-state
              (macro-cut-audit-endpoint audit))
             state)
        (macro-cut-audit-endpoint audit))
   #f))
