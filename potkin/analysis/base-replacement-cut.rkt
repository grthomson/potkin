#lang racket/base

;; Simultaneous base-replacement CK interaction, on POTKIN's native checked
;; proofs and cuts.
;;
;; Paper theorem.  Fix one exact material profile B and replace k distinct
;; physical holes from B-impure nullary primitives e_i to same-boundary,
;; connected B-pure proofs Q_i.  Every hybrid T_S is rechecked.  For a proper
;; cut c of T_all, let R(c) be the set of physical replacement regions met by
;; its detached subtrees.  A selected subtree contributes in hybrid T_S
;; exactly when every changed region it meets belongs to S: an enclosing
;; subtree otherwise contains the impure e_i, while a selected vertex inside
;; Q_i otherwise does not exist.  Cuts disjoint from a region differ only in
;; their right remainder, which zeta sends to 1.  Therefore
;;
;;   sum_S (-1)^(k-|S|)
;;     ((id tensor zeta)(pi_B tensor id) Delta_CK(T_S) - pi_B(T_S))
;;
;; selects precisely the proper B-pure cuts of T_all with R(c) equal to all
;; k regions.  The subtraction removes the witness-free whole endpoint.  The
;; unit/empty-cut term cancels for k>0 and is omitted by the proper recurrence.
;; This argument does not identify the typed right remainders of different
;; hybrids and does not assert equality of their full tensor coactions.
;; Nullarity of e_i is essential; an impure unary old proof can have surviving
;; descendant cuts and is deliberately outside the theorem and API contract.
;;
;; The production recurrence never enumerates a hybrid cut family or the cuts
;; of T_all.  At a nonroot node it adds one selection term iff that exact
;; checked subtree is B-pure; otherwise it multiplies the ordered child
;; recurrences.  Keys are (region bitmask, detached-factor count).  Masks are
;; combined by UNION, so selecting two incomparable roots in one Q_i retains
;; both factors while the repeated marker satisfies x_i^2=x_i.  One canonical
;; address representative is retained only to ask the native cut constructor
;; for an inspectable witness after a positive selective query.

(require racket/list
         "../algebra/formal-sum.rkt"
         "../kernel/address.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "ancestry.rkt"
         "material-hopf-selector.rkt"
         "material-stock.rkt")

(provide (struct-out base-replacement)
         make-base-replacement
         (struct-out replacement-region)
         (struct-out replacement-hybrid)
         (struct-out replacement-factor-overlap)
         (struct-out simultaneous-base-cut-failure)
         (struct-out simultaneous-base-cut-certificate)
         simultaneous-base-cut-certificate-positive?
         certify-simultaneous-base-cuts)

;; `hole-address` is physical identity.  `port-label` is caller metadata and
;; may repeat; it is never used to merge occurrences or infer an address.
(struct base-replacement (hole-address port-label old new)
  #:transparent)

(define (make-base-replacement hole-address port-label old new)
  (unless (address? hole-address)
    (raise-argument-error 'make-base-replacement "address?" hole-address))
  (unless (and (symbol? port-label) (symbol-interned? port-label))
    (raise-argument-error
     'make-base-replacement "interned-symbol?" port-label))
  (unless (checked-node? old)
    (raise-argument-error 'make-base-replacement "checked-node? old" old))
  (unless (checked-node? new)
    (raise-argument-error 'make-base-replacement "checked-node? new" new))
  (base-replacement hole-address port-label old new))

;; Indices are zero-based only for bit arithmetic; native premise addresses
;; remain positive and 1-indexed.
(struct replacement-region
  (index mask hole-address port-label old new)
  #:transparent)

;; `whole-endpoint` is pi_B(T_S), a native rank-one formal sum.  It has no cut
;; witness and is retained separately from the proper recurrence.
(struct replacement-hybrid (mask proof whole-endpoint)
  #:transparent)

;; A detached factor may intersect several regions, or several factors may
;; carry the same region mask.  Both physical addresses and logical labels are
;; reported; duplicate logical labels are retained.
(struct replacement-factor-overlap
  (factor-address region-mask hole-addresses port-labels)
  #:transparent)

(struct simultaneous-base-cut-failure (code message details)
  #:transparent)

(struct simultaneous-base-cut-certificate
  (calculus context profile regions hybrids all-old all-new
   full-region-mask requested-region-mask requested-factor-count
   polynomial coefficient witness detached forest remainder refill
   factor-overlaps overlap-kind whole-endpoint work verified?)
  #:transparent)

;; Internal coefficient plus one canonical native address representative.
(struct interaction-entry (coefficient addresses)
  #:transparent)

(struct node-recurrence (polynomial pure?)
  #:transparent)

(define (failure code message [details (hash)])
  (simultaneous-base-cut-failure code message details))

(define (simultaneous-base-cut-certificate-positive? certificate)
  (unless (simultaneous-base-cut-certificate? certificate)
    (raise-argument-error
     'simultaneous-base-cut-certificate-positive?
     "simultaneous-base-cut-certificate?"
     certificate))
  (positive? (simultaneous-base-cut-certificate-coefficient certificate)))

(define (singleton-forest calculus proof)
  (make-proof-forest calculus (list proof)))

(define (exact-term-in-calculus? calculus term)
  (and (checked-term? term)
       (checked-term-has-exact-calculus? term calculus)
       (term-admitted-by? calculus term)))

(define (exact-registry-occurrence? calculus occurrence)
  (and (concrete-occurrence? occurrence)
       (eq? occurrence
            (calculus-lookup calculus
                             (concrete-occurrence-id occurrence)))))

(define (bit-set? mask index)
  (not (zero? (bitwise-and mask (arithmetic-shift 1 index)))))

(define (mask-size mask)
  (let loop ([remaining mask] [count 0])
    (if (zero? remaining)
        count
        (loop (arithmetic-shift remaining -1)
              (+ count (bitwise-and remaining 1))))))

(define (single-bit? mask)
  (and (positive? mask)
       (zero? (bitwise-and mask (sub1 mask)))))

(define (address-family<? left right)
  (cond
    [(null? left) (pair? right)]
    [(null? right) #f]
    [(equal? (car left) (car right))
     (address-family<? (cdr left) (cdr right))]
    [else (address<? (car left) (car right))]))

(define (polynomial-add-entry polynomial key coefficient addresses)
  (define prior (hash-ref polynomial key #f))
  (cond
    [prior
     (hash-set
      polynomial key
      (interaction-entry
       (+ (interaction-entry-coefficient prior) coefficient)
       (if (address-family<? addresses
                            (interaction-entry-addresses prior))
           addresses
           (interaction-entry-addresses prior))))]
    [else
     (hash-set polynomial key (interaction-entry coefficient addresses))]))

(define (factor-region-mask regions address)
  (for/fold ([mask 0]) ([region (in-list regions)]
                        #:when
                        (or (address-prefix?
                             address
                             (replacement-region-hole-address region))
                            (address-prefix?
                             (replacement-region-hole-address region)
                             address)))
    (bitwise-ior mask (replacement-region-mask region))))

(define (factor-overlap regions address)
  (define mask (factor-region-mask regions address))
  (define touched
    (filter (lambda (region)
              (not (zero? (bitwise-and
                           mask (replacement-region-mask region)))))
            regions))
  (replacement-factor-overlap
   address mask
   (map replacement-region-hole-address touched)
   (map replacement-region-port-label touched)))

(define (classify-overlap requested-mask overlaps)
  (define masks (map replacement-factor-overlap-region-mask overlaps))
  (cond
    [(and (= (length masks) 1)
          (> (mask-size (car masks)) 1))
     'one-factor-enclosing-multiple-regions]
    [(and (= (length masks) (mask-size requested-mask))
          (andmap single-bit? masks)
          (not (check-duplicates masks =))
          (= (for/fold ([mask 0]) ([part (in-list masks)])
               (bitwise-ior mask part))
             requested-mask))
     'separate-region-factors]
    [else 'general-overlap]))

(define (canonical-regions context replacements)
  (define telescope (premise-telescope context))
  (for/list ([entry (in-list telescope)]
             [index (in-naturals 0)])
    (define address (telescope-entry-address entry))
    (define replacement
      (findf (lambda (candidate)
               (equal? address (base-replacement-hole-address candidate)))
             replacements))
    (replacement-region
     index (arithmetic-shift 1 index) address
     (base-replacement-port-label replacement)
     (base-replacement-old replacement)
     (base-replacement-new replacement))))

(define (validate-replacement who calculus selector context region)
  (define address (replacement-region-hole-address region))
  (define old (replacement-region-old region))
  (define new (replacement-region-new region))
  (define expected (puncture-requirement context address))
  (cond
    [(not (and (complete-proof? old)
               (exact-term-in-calculus? calculus old)))
     (failure
      'invalid-old-proof
      "the old primitive must be a complete proof in the exact context calculus"
      (hash 'region (replacement-region-index region) 'old old))]
    [(not (and (complete-proof? new)
               (exact-term-in-calculus? calculus new)))
     (failure
      'invalid-new-proof
      "the replacement must be a complete proof in the exact context calculus"
      (hash 'region (replacement-region-index region) 'new new))]
    [(not (and (null? (checked-node-children old))
               (zero? (occurrence-arity
                       (checked-node-occurrence old)))
               (= (derivation-vertex-count old) 1)))
     (failure
      'old-not-nullary
      "the positive finite-difference theorem requires a nullary old primitive"
      (hash 'region (replacement-region-index region) 'old old))]
    [(not (equal? (derivation-root-boundary old) expected))
     (failure
      'old-boundary-mismatch
      "the old primitive does not match its exact typed hole boundary"
      (hash 'address address 'expected expected
            'actual (derivation-root-boundary old)))]
    [(not (equal? (derivation-root-boundary new) expected))
     (failure
      'new-boundary-mismatch
      "the replacement does not match its exact typed hole boundary"
      (hash 'address address 'expected expected
            'actual (derivation-root-boundary new)))]
    [(material-hopf-selector-forest-pure?
      selector (singleton-forest calculus old))
     (failure
      'old-not-impure
      "the old nullary primitive must be outside the exact material profile"
      (hash 'region (replacement-region-index region) 'old old))]
    [(not (material-hopf-selector-forest-pure?
           selector (singleton-forest calculus new)))
     (failure
      'new-not-pure
      "the connected replacement proof must be pure for the exact material profile"
      (hash 'region (replacement-region-index region) 'new new))]
    [else #f]))

(define (certify-simultaneous-base-cuts
         context replacements profile requested-region-mask factor-count
         #:limit [limit analysis-default-limit])
  (define who 'certify-simultaneous-base-cuts)
  (unless (checked-term? context)
    (raise-argument-error who "checked-term?" context))
  (unless (and (list? replacements) (andmap base-replacement? replacements))
    (raise-argument-error who "(listof base-replacement?)" replacements))
  (unless (material-profile? profile)
    (raise-argument-error who "material-profile?" profile))
  (unless (exact-nonnegative-integer? requested-region-mask)
    (raise-argument-error
     who "exact-nonnegative-integer? requested-region-mask"
     requested-region-mask))
  (unless (exact-positive-integer? factor-count)
    (raise-argument-error who "exact-positive-integer? factor-count"
                          factor-count))
  (unless (exact-nonnegative-integer? limit)
    (raise-argument-error who "exact-nonnegative-integer? limit" limit))

  (let/ec return
    (define calculus (checked-term-calculus context))
    (define holes (puncture-addresses context))
    (define addresses (map base-replacement-hole-address replacements))
    (define duplicate-address (check-duplicates addresses equal?))
    (when (not (proof-context? context))
      (return
       (failure 'not-a-context
                "base replacement requires a native checked open context")))
    (when (or (not (checked-term-has-exact-calculus? context calculus))
              (not (term-admitted-by? calculus context)))
      (return
       (failure
        'invalid-context-provenance
        "the context must be admitted throughout by one exact calculus")))
    (when (not (eq? calculus (material-profile-calculus profile)))
      (return
       (failure
        'foreign-profile
        "the material profile belongs to a different calculus snapshot"
        (hash 'context-calculus calculus
              'profile-calculus (material-profile-calculus profile)))))
    (when (null? holes)
      (return
       (failure 'no-replacement-regions
                "at least one physical hole occurrence is required")))
    (when duplicate-address
      (return
       (failure
        'duplicate-hole-address
        "each replacement must identify a distinct physical hole occurrence"
        (hash 'duplicate duplicate-address))))
    (when (not (equal? (sort addresses address<?) holes))
      (return
       (failure
        'hole-set-mismatch
        "the replacements must cover exactly the context's physical punctures"
        (hash 'context-holes holes
              'replacement-addresses (sort addresses address<?)))))

    (define selector (prepare-material-hopf-selector profile))
    (define regions (canonical-regions context replacements))
    (for ([region (in-list regions)])
      (define invalid
        (validate-replacement who calculus selector context region))
      (when invalid (return invalid)))

    (define full-mask (sub1 (arithmetic-shift 1 (length regions))))
    (when (> requested-region-mask full-mask)
      (return
       (failure
        'invalid-region-mask
        "the requested mask contains no such physical replacement region"
        (hash 'requested requested-region-mask 'full-mask full-mask))))

    (define work 0)
    (define (charge! [amount 1])
      (set! work (+ work amount))
      (when (> work limit)
        (return
         (analysis-limit
          'not-computed-limit
          "the simultaneous base-replacement recurrence exceeded its work limit"
          who limit work 'union-mask-recurrence-work
          (hash 'requested-region-mask requested-region-mask
                'requested-factor-count factor-count)))))

    ;; Recheck every hybrid proof required by the finite-difference contract.
    ;; This is 2^k checked filling, not 2^k cut-family enumeration.
    (define hybrid-count (arithmetic-shift 1 (length regions)))
    (define hybrids
      (for/list ([mask (in-range hybrid-count)])
        (charge!)
        (define fillers
          (for/list ([region (in-list regions)])
            (if (bit-set? mask (replacement-region-index region))
                (replacement-region-new region)
                (replacement-region-old region))))
        (define proof (complete-fill context fillers))
        (when (context-error? proof)
          (return
           (failure
            'hybrid-filling-failed
            "one finite-difference hybrid failed native checked filling"
            (hash 'hybrid-mask mask 'context-error proof))))
        (unless (and (complete-proof? proof)
                     (exact-term-in-calculus? calculus proof))
          (return
           (failure
            'invalid-hybrid-proof
            "a hybrid filling did not remain a complete exact checked proof"
            (hash 'hybrid-mask mask 'proof proof))))
        (replacement-hybrid
         mask proof
         (material-hopf-selector-project-forest
          selector (singleton-forest calculus proof)))))

    (define all-old (replacement-hybrid-proof (car hybrids)))
    (define all-new
      (replacement-hybrid-proof
       (list-ref hybrids full-mask)))

    (define polynomial-one
      (hash (list 0 0) (interaction-entry 1 '())))

    (define (multiply left right)
      (for*/fold ([result (hash)])
                 ([(left-key left-entry) (in-hash left)]
                  [(right-key right-entry) (in-hash right)])
        (charge!)
        (define key
          (list (bitwise-ior (first left-key) (first right-key))
                (+ (second left-key) (second right-key))))
        (polynomial-add-entry
         result key
         (* (interaction-entry-coefficient left-entry)
            (interaction-entry-coefficient right-entry))
         (sort
          (append (interaction-entry-addresses left-entry)
                  (interaction-entry-addresses right-entry))
          address<?))))

    (define (evaluate node address root?)
      (charge!)
      (unless (and (checked-node? node)
                   (eq? (checked-node-calculus node) calculus)
                   (exact-registry-occurrence?
                    calculus (checked-node-occurrence node)))
        (error who
               "the checked all-new proof lost exact registered provenance at ~e"
               address))
      (define child-results
        (for/list ([child (in-list (checked-node-children node))]
                   [slot (in-naturals 1)])
          (evaluate child (append address (list slot)) #f)))
      (define child-product
        (for/fold ([product polynomial-one])
                  ([child-result (in-list child-results)])
          (multiply product (node-recurrence-polynomial child-result))))
      (define pure?
        (and (material-profile-designates?
              profile (checked-node-occurrence node))
             (andmap node-recurrence-pure? child-results)))
      (define polynomial
        (if (and pure? (not root?))
            (begin
              (charge!)
              (polynomial-add-entry
               child-product
               (list (factor-region-mask regions address) 1)
               1
               (list address)))
            child-product))
      (node-recurrence polynomial pure?))

    (define with-empty
      (node-recurrence-polynomial
       (evaluate all-new root-address #t)))
    (define proper-entries (hash-remove with-empty (list 0 0)))
    (define polynomial
      (for/hash ([(key entry) (in-hash proper-entries)])
        (values key (interaction-entry-coefficient entry))))
    (define requested-key (list requested-region-mask factor-count))
    (define selected-entry (hash-ref proper-entries requested-key #f))
    (define coefficient
      (if selected-entry (interaction-entry-coefficient selected-entry) 0))
    (define witness
      (and selected-entry
           (make-cut-witness
            all-new (interaction-entry-addresses selected-entry))))
    (when (cut-error? witness)
      (error who "the union-mask recurrence produced an invalid native cut: ~e"
             witness))

    (define detached (and witness (cut-witness-detached witness)))
    (define forest (and witness (cut-witness-forest witness)))
    (define remainder (and witness (cut-witness-remainder witness)))
    (define refill
      (and witness
           (complete-fill
            remainder (map detached-entry-term detached))))
    (define overlaps
      (if witness
          (map (lambda (address) (factor-overlap regions address))
               (cut-witness-addresses witness))
          '()))
    (define overlap-kind
      (and witness (classify-overlap requested-region-mask overlaps)))
    (define overlap-union
      (for/fold ([mask 0]) ([overlap (in-list overlaps)])
        (bitwise-ior
         mask (replacement-factor-overlap-region-mask overlap))))
    (define whole-endpoint
      (replacement-hybrid-whole-endpoint
       (list-ref hybrids full-mask)))
    (define witness-valid?
      (or
       (not witness)
       (and
        (pair? (cut-witness-addresses witness))
        (not (member root-address (cut-witness-addresses witness) equal?))
        (= (length detached) factor-count)
        (= (proof-forest-size forest) factor-count)
        (= overlap-union requested-region-mask)
        (material-hopf-selector-forest-pure? selector forest)
        (equal? (map detached-entry-address detached)
                (cut-witness-addresses witness))
        (equal? (puncture-addresses remainder)
                (cut-witness-addresses witness))
        (checked-term-has-exact-calculus? remainder calculus)
        (cut-witness-reconstructs? witness)
        (checked-node? refill)
        (checked-term-has-exact-calculus? refill calculus)
        (equal? refill all-new)
        (equal? (reconstruct-cut-witness witness) all-new))))
    (define verified?
      (and
       (= (length hybrids) hybrid-count)
       (for/and ([hybrid (in-list hybrids)])
         (and (complete-proof? (replacement-hybrid-proof hybrid))
              (checked-term-has-exact-calculus?
               (replacement-hybrid-proof hybrid) calculus)))
       (if (positive? coefficient) witness #t)
       witness-valid?))

    (simultaneous-base-cut-certificate
     calculus context profile regions hybrids all-old all-new
     full-mask requested-region-mask factor-count polynomial coefficient
     witness detached forest remainder refill overlaps overlap-kind
     whole-endpoint work verified?)))
