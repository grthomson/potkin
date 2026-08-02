#lang racket/base

(require racket/list
         "../algebra/formal-sum.rkt"
         "../hopf/ck.rkt"
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "ancestry.rkt")

(provide typed-pointed-hole
         typed-pointed-hole?
         (struct-out pointed-input-position)
         (struct-out pointed-coaction-choice)
         (struct-out pointed-choice-tuple)
         (struct-out pointed-input-coaction-certificate)
         make-pointed-input-positions
         pointed-input-coaction-choices
         typed-pointed-input-coaction
         protected-pointed-input-coaction
         typed-graft
         (struct-out grafting-choice-certificate)
         (struct-out grafting-reverse-certificate)
         (struct-out typed-grafting-cocycle-certificate)
         typed-grafting-cocycle
         (struct-out vertex-origin)
         (struct-out protected-choice-certificate)
         (struct-out protected-cut-record)
         (struct-out protected-factorization-certificate)
         protected-context-factorization-defect
         protected-factorization-defect
         (struct-out protected-local-residue-certificate)
         protected-local-replacement-residue
         protected-local-residue
         (struct-out protected-local-residue-laws-certificate)
         protected-local-residue-laws)

;; A pointed hole is the existing typed checked puncture.  It is deliberately
;; not a new algebra basis element: it can occur only in an ordered retained
;; input tuple, and evaluation under a positive context removes the need for a
;; pointed carrier before a tensor coordinate is constructed.
(define typed-pointed-hole identity-context)
(define typed-pointed-hole? checked-hole?)

;; `index` is the stable position in the addressed telescope.  For a corolla
;; it is also the concrete occurrence's 1-indexed premise slot.  Keeping the
;; outer address is essential for contexts whose punctures are not immediate
;; children of their root.
(struct pointed-input-position
  (index outer-address boundary input)
  #:transparent)

;; Kinds are `hole`, `whole`, `empty`, `proper`, and (for an unprotected
;; input) `trivial`.  A whole choice records the formal relative root address
;; `(())`, but has no local CK witness because root cuts are not admissible.
(struct pointed-coaction-choice
  (position kind relative-addresses witness detached-forest retained-input)
  #:transparent)

(struct pointed-choice-tuple
  (choices detached-forest retained-inputs global-addresses)
  #:transparent)

(struct pointed-input-coaction-certificate
  (calculus positions protected-positions choice-families tuple-count tuples)
  #:transparent)

(struct grafting-choice-certificate
  (choice-tuple
   grafted-remainder
   global-witness
   reconstruction
   reconstructs?
   forest-agrees?
   remainder-agrees?
   tensor)
  #:transparent)

(struct grafting-reverse-certificate
  (witness
   recovered-choice-tuple
   matched-forward
   forward-addresses
   addresses-round-trip?
   choices-round-trip?)
  #:transparent)

(struct typed-grafting-cocycle-certificate
  (calculus
   occurrence
   premise-profile
   inputs
   positions
   grafted
   input-coaction
   endpoint
   forward-certificates
   reverse-certificates
   recursive-coproduct
   direct-coproduct
   forward-valid?
   reverse-valid?
   witness-bijection?
   equal?)
  #:transparent)

;; Every output vertex belongs either to the fixed context or to exactly one
;; original input region.  Formal holes contribute no vertices.
(struct vertex-origin
  (address kind position outer-address relative-address vertex)
  #:transparent)

(struct protected-choice-certificate
  (choice-tuple
   evaluated-remainder
   global-witness
   reconstruction
   reconstructs?
   forest-agrees?
   remainder-agrees?
   tensor)
  #:transparent)

;; `disposition` is one of cancelled-empty, cancelled-protected,
;; residual-fixed-context, residual-unprotected, or residual-mixed.
(struct protected-cut-record
  (witness
   addresses
   detached
   retained-context
   reconstruction
   reconstructs?
   selected-origins
   disposition
   recovered-choice-tuple
   matching-choice
   cancellation-round-trip?
   tensor)
  #:transparent)

(struct protected-factorization-certificate
  (calculus
   context
   telescope
   inputs
   protected-positions
   output
   input-coaction
   choice-certificates
   vertex-origins
   cut-records
   direct-coaction
   evaluated-input-coaction
   defect
   residual-witness-sum
   cancellation-bijection?
   support-theorem?
   collected-coefficients-agree?)
  #:transparent)

(struct protected-local-residue-certificate
  (calculus
   source-context
   target-context
   telescope
   inputs
   protected-positions
   source-defect
   target-defect
   residue
   reverse-residue
   identity-law?
   antisymmetry-law?)
  #:transparent)

(struct protected-local-residue-laws-certificate
  (first-context
   second-context
   third-context
   inputs
   protected-positions
   residue-01
   residue-12
   residue-02
   identity-law?
   antisymmetry-law?
   telescoping-law?)
  #:transparent)

(define (cocycle-error code message operation expected actual
                       [details (hash)])
  (analysis-error code message operation expected actual details))

(define (check-limit who limit)
  (unless (or (not limit) (exact-nonnegative-integer? limit))
    (raise-argument-error
     who "(or/c #f exact-nonnegative-integer?)" limit)))

(define (over-limit? value limit)
  (and limit (> value limit)))

(define (cap-add left right limit)
  (define value (+ left right))
  (if (over-limit? value limit) (add1 limit) value))

(define (cap-multiply left right limit)
  (cond
    [(or (zero? left) (zero? right)) 0]
    [(not limit) (* left right)]
    [(or (> left limit) (> right limit)) (add1 limit)]
    [(> left (quotient limit right)) (add1 limit)]
    [else (* left right)]))

(define (limit-result operation limit required metric [details (hash)])
  (analysis-limit
   'not-computed-limit
   "the exact cocycle analysis exceeds its configured finite limit"
   operation
   limit
   required
   metric
   details))

(define (canonical-protected-positions who positions count)
  (cond
    [(not (list? positions))
     (raise-argument-error who "(listof exact-positive-integer?)" positions)]
    [(findf (lambda (position)
              (not (and (exact-positive-integer? position)
                        (<= position count))))
            positions)
     =>
     (lambda (bad)
       (cocycle-error
        'invalid-protected-position
        "every protected position must name an addressed telescope entry"
        who
        (list 1 count)
        bad
        (hash 'positions positions)))]
    [(check-duplicates positions)
     =>
     (lambda (duplicate)
       (cocycle-error
        'duplicate-protected-position
        "protected input positions form a set"
        who
        'distinct-positions
        duplicate
        (hash 'positions positions)))]
    [else (sort positions <)]))

(define (exact-term-in-calculus? term calculus)
  (and (checked-term? term)
       (checked-term-has-exact-calculus? term calculus)
       (term-admitted-by? calculus term)))

(define (make-pointed-input-positions context inputs)
  (unless (checked-node? context)
    (raise-argument-error
     'make-pointed-input-positions "checked-node?" context))
  (unless (and (list? inputs) (andmap checked-term? inputs))
    (raise-argument-error
     'make-pointed-input-positions "(listof checked-term?)" inputs))
  (define operation 'make-pointed-input-positions)
  (define calculus (checked-node-calculus context))
  (define telescope (premise-telescope context))
  (cond
    [(not (checked-term-has-exact-calculus? context calculus))
     (cocycle-error
      'mixed-calculus-provenance
      "the positive context must carry one exact calculus snapshot"
      operation calculus (checked-term-calculus context)
      (hash 'context context))]
    [(not (= (length telescope) (length inputs)))
     (cocycle-error
      'wrong-input-count
      "one pointed input is required for every addressed telescope position"
      operation (length telescope) (length inputs)
      (hash 'telescope telescope))]
    [else
     (define bad
       (for/first ([entry (in-list telescope)]
                   [input (in-list inputs)]
                   [index (in-naturals 1)]
                   #:when
                   (or (not (exact-term-in-calculus? input calculus))
                       (not (equal? (telescope-entry-requirement entry)
                                    (derivation-root-boundary input)))))
         (list index entry input)))
     (cond
       [(and bad
             (not (exact-term-in-calculus? (third bad) calculus)))
        (cocycle-error
         'wrong-calculus-provenance
         "every pointed input must carry the context's exact calculus snapshot"
         operation calculus (checked-term-calculus (third bad))
         (hash 'position (first bad) 'input (third bad)))]
       [bad
        (cocycle-error
         'wrong-input-boundary
         "the pointed input root must match its entire telescope boundary"
         operation
         (telescope-entry-requirement (second bad))
         (derivation-root-boundary (third bad))
         (hash 'position (first bad)
               'outer-address (telescope-entry-address (second bad))))]
       [else
        (for/list ([entry (in-list telescope)]
                   [input (in-list inputs)]
                   [index (in-naturals 1)])
          (pointed-input-position
           index
           (telescope-entry-address entry)
           (telescope-entry-requirement entry)
           input))])]))

;; W(t), the number of ordinary CK witnesses of a positive term, is computed
;; from the root constructor: independently choose a pointed option in every
;; positive child region.  C(t)=1+W(t) adds the special pointed whole choice.
;; A hole has one retained choice and no CK vertex.  Saturation makes this a
;; genuine preflight rather than an exhaustive count after enumeration.
(define (ordinary-witness-count/capped term limit)
  (unless (checked-node? term)
    (raise-argument-error
     'ordinary-witness-count/capped "checked-node?" term))
  (for/fold ([product 1]) ([child (in-list (checked-node-children term))])
    (cap-multiply product (pointed-choice-count/capped child limit) limit)))

(define (pointed-choice-count/capped term limit)
  (cond
    [(checked-hole? term) 1]
    [else
     (cap-add 1 (ordinary-witness-count/capped term limit) limit)]))

(define (validate-position position operation)
  (unless (pointed-input-position? position)
    (raise-argument-error operation "pointed-input-position?" position))
  (define input (pointed-input-position-input position))
  (cond
    [(not (and (exact-positive-integer?
                (pointed-input-position-index position))
               (address? (pointed-input-position-outer-address position))
               (hypersequent? (pointed-input-position-boundary position))
               (checked-term? input)))
     (cocycle-error
      'malformed-pointed-position
      "a pointed position needs a positive index, address, boundary and checked input"
      operation 'well-formed-pointed-position position)]
    [(not (equal? (pointed-input-position-boundary position)
                  (derivation-root-boundary input)))
     (cocycle-error
      'wrong-input-boundary
      "the pointed input root does not match its recorded position boundary"
      operation
      (pointed-input-position-boundary position)
      (derivation-root-boundary input)
      (hash 'position (pointed-input-position-index position)))]
    [else #f]))

(define (pointed-input-coaction-choices/internal position)
  (define input (pointed-input-position-input position))
  (define calculus (checked-term-calculus input))
  (define empty-forest (empty-proof-forest calculus))
  (cond
    [(checked-hole? input)
     (list
      (pointed-coaction-choice
       position 'hole '() #f empty-forest input))]
    [else
     (define whole-hole
       (typed-pointed-hole calculus (derivation-root-boundary input)))
     (define whole
       (pointed-coaction-choice
        position
        'whole
        (list root-address)
        #f
        (make-proof-forest calculus (list input))
        whole-hole))
     (define witness-choices
       (for/list ([witness (in-admissible-cut-witnesses input)])
         (pointed-coaction-choice
          position
          (if (null? (cut-witness-addresses witness)) 'empty 'proper)
          (cut-witness-addresses witness)
          witness
          (cut-witness-forest witness)
          (cut-witness-remainder witness))))
     (cons whole witness-choices)]))

(define (pointed-input-coaction-choices
         position #:limit [limit analysis-default-limit])
  (check-limit 'pointed-input-coaction-choices limit)
  (define malformed
    (validate-position position 'pointed-input-coaction-choices))
  (cond
    [malformed malformed]
    [else
     (define input (pointed-input-position-input position))
     (define calculus (checked-term-calculus input))
     (cond
       [(not (exact-term-in-calculus? input calculus))
        (cocycle-error
         'mixed-calculus-provenance
         "a pointed input must carry one exact calculus snapshot"
         'pointed-input-coaction-choices
         calculus
         (checked-term-calculus input)
         (hash 'position (pointed-input-position-index position)))]
       [else
        (define count (pointed-choice-count/capped input limit))
        (if (over-limit? count limit)
            (limit-result
             'pointed-input-coaction-choices limit (add1 limit)
             'pointed-choice-count
             (hash 'position (pointed-input-position-index position)
                   'required-at-least (add1 limit)))
            (pointed-input-coaction-choices/internal position))])]))

(define (choice-global-addresses choice)
  (define prefix
    (pointed-input-position-outer-address
     (pointed-coaction-choice-position choice)))
  (for/list ([relative
              (in-list (pointed-coaction-choice-relative-addresses choice))])
    (address-append prefix relative)))

(define (make-choice-tuple calculus choices)
  (define detached
    (for/fold ([forest (empty-proof-forest calculus)])
              ([choice (in-list choices)])
      (forest-union forest
                    (pointed-coaction-choice-detached-forest choice))))
  (pointed-choice-tuple
   choices
   detached
   (map pointed-coaction-choice-retained-input choices)
   (sort (append-map choice-global-addresses choices) address<?)))

(define (cartesian-choice-tuples calculus choice-families)
  (define (walk remaining reversed)
    (cond
      [(null? remaining)
       (list (make-choice-tuple calculus (reverse reversed)))]
      [else
       (append-map
        (lambda (choice)
          (walk (cdr remaining) (cons choice reversed)))
        (car remaining))]))
  (walk choice-families '()))

(define (coaction-choice-count/capped positions protected-positions limit)
  (for/fold ([product 1]) ([position (in-list positions)])
    (define factor
      (if (member (pointed-input-position-index position)
                  protected-positions)
          (pointed-choice-count/capped
           (pointed-input-position-input position) limit)
          1))
    (cap-multiply product factor limit)))

(define (trivial-choice position)
  (define input (pointed-input-position-input position))
  (pointed-coaction-choice
   position
   'trivial
   '()
   #f
   (empty-proof-forest (checked-term-calculus input))
   input))

(define (build-input-coaction/with-calculus
         calculus positions protected-positions)
  (define families
    (for/list ([position (in-list positions)])
      (if (member (pointed-input-position-index position)
                  protected-positions)
          (pointed-input-coaction-choices/internal position)
          (list (trivial-choice position)))))
  (define tuples (cartesian-choice-tuples calculus families))
  (pointed-input-coaction-certificate
   calculus
   positions
   protected-positions
   families
   (length tuples)
   tuples))

(define (typed-pointed-input-coaction
         context inputs #:limit [limit analysis-default-limit])
  (check-limit 'typed-pointed-input-coaction limit)
  (define positions (make-pointed-input-positions context inputs))
  (cond
    [(analysis-error? positions) positions]
    [else
     (define protected
       (for/list ([position (in-list positions)])
         (pointed-input-position-index position)))
     (define count
       (coaction-choice-count/capped positions protected limit))
     (if (over-limit? count limit)
         (limit-result
          'typed-pointed-input-coaction limit (add1 limit)
          'input-choice-tuple-count
          (hash 'required-at-least (add1 limit)))
         (build-input-coaction/with-calculus
          (checked-node-calculus context) positions protected))]))

(define (validate-protected-input-kinds
         positions protected-positions operation)
  (for/first ([position (in-list positions)]
              #:do
              [(define index (pointed-input-position-index position))
               (define input (pointed-input-position-input position))]
              #:when
              (if (member index protected-positions)
                  (not (or (complete-proof? input) (checked-hole? input)))
                  (not (complete-proof? input))))
    (define protected? (and (member index protected-positions) #t))
    (cocycle-error
     (if protected? 'invalid-protected-input 'incomplete-unprotected-input)
     (if protected?
         "a protected input must be a complete proof or a formal pointed hole"
         "an unprotected input must be a complete proof")
     operation
     (if protected?
         '(or complete-proof formal-pointed-hole)
         'complete-proof)
     input
     (hash 'position index))))

(define (protected-pointed-input-coaction
         context inputs protected-positions
         #:limit [limit analysis-default-limit])
  (check-limit 'protected-pointed-input-coaction limit)
  (define positions (make-pointed-input-positions context inputs))
  (cond
    [(analysis-error? positions) positions]
    [else
     (define protected
       (canonical-protected-positions
        'protected-pointed-input-coaction
        protected-positions
        (length positions)))
     (cond
       [(analysis-error? protected) protected]
       [(validate-protected-input-kinds
         positions protected 'protected-pointed-input-coaction)
        => values]
       [else
        (define count
          (coaction-choice-count/capped positions protected limit))
        (if (over-limit? count limit)
            (limit-result
             'protected-pointed-input-coaction limit (add1 limit)
             'protected-input-choice-tuple-count
             (hash 'required-at-least (add1 limit)))
            (build-input-coaction/with-calculus
             (checked-node-calculus context) positions protected))])]))

(define (resolve-occurrence calculus occurrence-or-id operation)
  (unless (equipped-calculus? calculus)
    (raise-argument-error operation "equipped-calculus?" calculus))
  (cond
    [(symbol? occurrence-or-id)
     (or (calculus-lookup calculus occurrence-or-id)
         (cocycle-error
          'unadmitted-occurrence
          "the occurrence ID is not admitted by the exact calculus"
          operation 'admitted-occurrence occurrence-or-id))]
    [(concrete-occurrence? occurrence-or-id)
     (define registered
       (calculus-lookup
        calculus (concrete-occurrence-id occurrence-or-id)))
     (if (and registered (equal? registered occurrence-or-id))
         registered
         (cocycle-error
          'unadmitted-occurrence
          "the concrete occurrence is not admitted by the exact calculus"
          operation 'admitted-occurrence occurrence-or-id))]
    [else
     (raise-argument-error
      operation "(or/c symbol? concrete-occurrence?)" occurrence-or-id)]))

(define (typed-graft calculus occurrence-or-id inputs)
  (unless (and (list? inputs) (andmap checked-term? inputs))
    (raise-argument-error 'typed-graft "(listof checked-term?)" inputs))
  (define occurrence
    (resolve-occurrence calculus occurrence-or-id 'typed-graft))
  (cond
    [(analysis-error? occurrence) occurrence]
    [else
     (define open-corolla (corolla calculus occurrence))
     (cond
       [(context-error? open-corolla)
        (cocycle-error
         'corolla-construction-failed
         "constructing the exact admitted corolla failed"
         'typed-graft 'checked-corolla open-corolla)]
       [else
        (define positions
          (make-pointed-input-positions open-corolla inputs))
        (cond
          [(analysis-error? positions) positions]
          [else
           (define result (context-compose open-corolla inputs))
           (if (context-error? result)
               (cocycle-error
                'grafting-failed
                "rechecking the typed ordered graft failed"
                'typed-graft 'checked-node result
                (hash 'context-error result))
               result)])])]))

(define (singleton-forest term)
  (make-proof-forest (checked-term-calculus term) (list term)))

(define (cut-witness-tensor witness)
  (define source (cut-witness-source witness))
  (define calculus (checked-term-calculus source))
  (pure-tensor
   calculus
   (vector
    (cut-witness-forest witness)
    (singleton-forest (cut-witness-remainder witness)))))

(define (choice-tensor calculus choice-tuple evaluated)
  (pure-tensor
   calculus
   (vector
    (pointed-choice-tuple-detached-forest choice-tuple)
    (singleton-forest evaluated))))

(define (choice-tuple-key tuple)
  (for/list ([choice (in-list (pointed-choice-tuple-choices tuple))])
    (list
     (pointed-input-position-index
      (pointed-coaction-choice-position choice))
     (pointed-coaction-choice-kind choice)
     (pointed-coaction-choice-relative-addresses choice))))

(define (address-family-unique? certificates address-accessor)
  (not
   (check-duplicates
    (map address-accessor certificates)
    equal?)))

(define (forward-choice-certificate open-corolla source tuple constructor)
  (define calculus (checked-node-calculus source))
  (define evaluated
    (context-compose
     open-corolla
     (pointed-choice-tuple-retained-inputs tuple)))
  (cond
    [(context-error? evaluated)
     (cocycle-error
      'retained-grafting-failed
      "evaluating the retained pointed tuple failed"
      constructor 'checked-node evaluated
      (hash 'choice-tuple tuple))]
    [else
     (define witness
       (make-cut-witness
        source (pointed-choice-tuple-global-addresses tuple)))
     (cond
       [(cut-error? witness)
        (cocycle-error
         'invalid-prefixed-cut
         "prefixing the independent input choices did not form a CK cut"
         constructor 'admissible-ck-cut witness
         (hash 'choice-tuple tuple))]
       [else
        (define reconstruction (reconstruct-cut-witness witness))
        (define reconstructs?
          (and (checked-term? reconstruction)
               (checked-term-has-exact-calculus? reconstruction calculus)
               (equal? reconstruction source)))
        (define forest-agrees?
          (equal? (cut-witness-forest witness)
                  (pointed-choice-tuple-detached-forest tuple)))
        (define remainder-agrees?
          (and (checked-term-has-exact-calculus? evaluated calculus)
               (equal? (cut-witness-remainder witness) evaluated)))
        (define tensor (choice-tensor calculus tuple evaluated))
        (if (eq? constructor 'typed-grafting-cocycle)
            (grafting-choice-certificate
             tuple evaluated witness reconstruction reconstructs?
             forest-agrees? remainder-agrees? tensor)
            (protected-choice-certificate
             tuple evaluated witness reconstruction reconstructs?
             forest-agrees? remainder-agrees? tensor))])]))

(define (choice-for-region position relevant protected?)
  (define input (pointed-input-position-input position))
  (define calculus (checked-term-calculus input))
  (define empty-forest (empty-proof-forest calculus))
  (cond
    [(not protected?)
     (if (null? relevant)
         (trivial-choice position)
         (cocycle-error
          'cut-enters-unprotected-region
          "a cancellation inverse cannot absorb a cut in an unprotected input"
          'choice-for-region 'no-selected-root relevant
          (hash 'position (pointed-input-position-index position))))]
    [(checked-hole? input)
     (if (null? relevant)
         (pointed-coaction-choice
          position 'hole '() #f empty-forest input)
         (cocycle-error
          'cut-enters-formal-hole
          "a formal pointed hole has no CK vertex"
          'choice-for-region 'no-selected-root relevant
          (hash 'position (pointed-input-position-index position))))]
    [(null? relevant)
     (define witness (make-cut-witness input '()))
     (pointed-coaction-choice
      position 'empty '() witness
      (cut-witness-forest witness)
      (cut-witness-remainder witness))]
    [(member root-address relevant equal?)
     (if (= (length relevant) 1)
         (pointed-coaction-choice
          position 'whole (list root-address) #f
          (make-proof-forest calculus (list input))
          (typed-pointed-hole calculus (derivation-root-boundary input)))
         (cocycle-error
          'non-prefix-free-local-choice
          "a whole-input choice cannot also select a descendant"
          'choice-for-region 'prefix-free-local-choice relevant
          (hash 'position (pointed-input-position-index position))))]
    [else
     (define witness (make-cut-witness input relevant))
     (if (cut-error? witness)
         (cocycle-error
          'invalid-local-cut
          "the partitioned global cut did not induce a proper local CK cut"
          'choice-for-region 'proper-local-ck-cut witness
          (hash 'position (pointed-input-position-index position)
                'relative-addresses relevant))
         (pointed-coaction-choice
          position 'proper relevant witness
          (cut-witness-forest witness)
          (cut-witness-remainder witness)))]))

(define (inverse-choice-tuple calculus positions protected-positions addresses)
  (define choices-or-errors
    (for/list ([position (in-list positions)])
      (define prefix (pointed-input-position-outer-address position))
      (define relevant-global
        (filter (lambda (address) (address-prefix? prefix address))
                addresses))
      (define relevant-relative
        (for/list ([address (in-list relevant-global)])
          (drop address (length prefix))))
      (choice-for-region
       position
       relevant-relative
       (and (member (pointed-input-position-index position)
                    protected-positions)
            #t))))
  (define choice-error (findf analysis-error? choices-or-errors))
  (cond
    [choice-error choice-error]
    [else
     (define covered
       (append-map
        (lambda (position)
          (define prefix (pointed-input-position-outer-address position))
          (filter (lambda (address) (address-prefix? prefix address))
                  addresses))
        positions))
     (if (not (= (length covered) (length addresses)))
         (cocycle-error
          'cut-outside-input-regions
          "the cut has a selected root outside the invertible input regions"
          'inverse-choice-tuple
          'input-region-cut
          addresses
          (hash 'covered covered))
         (make-choice-tuple calculus choices-or-errors))]))

(define (formal-sum-from-choice-certificates calculus certificates accessor)
  (make-formal-sum
   calculus
   2
   (for/list ([certificate (in-list certificates)])
     (define tensor (accessor certificate))
     (define entry (car (formal-sum-terms tensor)))
     (cons (car entry) (cdr entry)))))

(define (typed-grafting-cocycle
         calculus occurrence-or-id inputs
         #:limit [limit analysis-default-limit])
  (check-limit 'typed-grafting-cocycle limit)
  (unless (and (list? inputs) (andmap checked-term? inputs))
    (raise-argument-error
     'typed-grafting-cocycle "(listof checked-term?)" inputs))
  (define occurrence
    (resolve-occurrence calculus occurrence-or-id 'typed-grafting-cocycle))
  (cond
    [(analysis-error? occurrence) occurrence]
    [else
     (define open-corolla (corolla calculus occurrence))
     (define positions
       (make-pointed-input-positions open-corolla inputs))
     (cond
       [(analysis-error? positions) positions]
       [else
        (define protected
          (for/list ([position (in-list positions)])
            (pointed-input-position-index position)))
        (define choice-count
          (coaction-choice-count/capped positions protected limit))
        (cond
          [(over-limit? choice-count limit)
           (limit-result
            'typed-grafting-cocycle limit (add1 limit)
            'grafting-cut-witness-count
            (hash 'required-at-least (add1 limit)
                  'occurrence-id (concrete-occurrence-id occurrence)))]
          [else
           (define grafted (context-compose open-corolla inputs))
           (cond
             [(context-error? grafted)
              (cocycle-error
               'grafting-failed
               "rechecking the typed ordered graft failed"
               'typed-grafting-cocycle 'checked-node grafted
               (hash 'context-error grafted))]
             [else
              (define input-coaction
                (build-input-coaction/with-calculus
                 calculus positions protected))
              (define forward-or-errors
                (for/list
                    ([tuple
                      (in-list
                       (pointed-input-coaction-certificate-tuples
                        input-coaction))])
                  (forward-choice-certificate
                   open-corolla grafted tuple 'typed-grafting-cocycle)))
              (define forward-error
                (findf analysis-error? forward-or-errors))
              (cond
                [forward-error forward-error]
                [else
                 (define forward forward-or-errors)
                 (define forward-by-address
                   (for/hash ([certificate (in-list forward)])
                     (values
                      (cut-witness-addresses
                       (grafting-choice-certificate-global-witness
                        certificate))
                      certificate)))
                 (define direct-witnesses
                   (for/list
                       ([witness (in-admissible-cut-witnesses grafted)])
                     witness))
                 (define reverse-or-errors
                   (for/list ([witness (in-list direct-witnesses)])
                     (define recovered
                       (inverse-choice-tuple
                        calculus positions protected
                        (cut-witness-addresses witness)))
                     (cond
                       [(analysis-error? recovered) recovered]
                       [else
                        (define matched
                          (hash-ref
                           forward-by-address
                           (cut-witness-addresses witness)
                           #f))
                        (define forward-addresses
                          (and matched
                               (pointed-choice-tuple-global-addresses
                                (grafting-choice-certificate-choice-tuple
                                 matched))))
                        (grafting-reverse-certificate
                         witness
                         recovered
                         matched
                         forward-addresses
                         (and forward-addresses
                              (equal? forward-addresses
                                      (cut-witness-addresses witness)))
                         (and matched
                              (equal?
                               (choice-tuple-key recovered)
                               (choice-tuple-key
                                (grafting-choice-certificate-choice-tuple
                                 matched)))))])))
                 (define reverse-error
                   (findf analysis-error? reverse-or-errors))
                 (cond
                   [reverse-error reverse-error]
                   [else
                    (define reverse reverse-or-errors)
                    (define endpoint
                      (pure-tensor
                       calculus
                       (vector
                        (singleton-forest grafted)
                        (empty-proof-forest calculus))))
                    (define choice-sum
                      (formal-sum-from-choice-certificates
                       calculus forward
                       grafting-choice-certificate-tensor))
                    (define recursive
                      (formal-sum-add endpoint choice-sum))
                    (define direct (connected-coproduct grafted))
                    (define forward-valid?
                      (and
                       (address-family-unique?
                        forward
                        (lambda (certificate)
                          (cut-witness-addresses
                           (grafting-choice-certificate-global-witness
                            certificate))))
                       (andmap
                        (lambda (certificate)
                          (and
                           (grafting-choice-certificate-reconstructs?
                            certificate)
                           (grafting-choice-certificate-forest-agrees?
                            certificate)
                           (grafting-choice-certificate-remainder-agrees?
                            certificate)))
                        forward)))
                    (define reverse-valid?
                      (andmap
                       (lambda (certificate)
                         (and
                          (grafting-reverse-certificate-matched-forward
                           certificate)
                          (grafting-reverse-certificate-addresses-round-trip?
                           certificate)
                          (grafting-reverse-certificate-choices-round-trip?
                           certificate)))
                       reverse))
                    (define bijection?
                      (and forward-valid?
                           reverse-valid?
                           (= (length forward) (length reverse))))
                    (typed-grafting-cocycle-certificate
                     calculus
                     occurrence
                     (vector->list
                      (concrete-occurrence-premises occurrence))
                     inputs
                     positions
                     grafted
                     input-coaction
                     endpoint
                     forward
                     reverse
                     recursive
                     direct
                     forward-valid?
                     reverse-valid?
                     bijection?
                     (and (formal-sum? direct)
                          (equal? direct recursive)))])])])])])]))

(define (output-vertex-origins output positions protected-positions)
  (for/list ([address (in-list (vertex-addresses output))])
    (define region
      (for/first ([position (in-list positions)]
                  #:when
                  (address-prefix?
                   (pointed-input-position-outer-address position)
                   address))
        position))
    (cond
      [region
       (define index (pointed-input-position-index region))
       (define prefix (pointed-input-position-outer-address region))
       (vertex-origin
        address
        (if (member index protected-positions)
            'protected-input
            'unprotected-input)
        index
        prefix
        (drop address (length prefix))
        (vertex-at-address output address))]
      [else
       (vertex-origin
        address
        'fixed-context
        #f
        #f
        address
        (vertex-at-address output address))])))

(define (cut-disposition addresses origins)
  (cond
    [(null? addresses) 'cancelled-empty]
    [(andmap
      (lambda (origin)
        (eq? (vertex-origin-kind origin) 'protected-input))
      origins)
     'cancelled-protected]
    [(andmap
      (lambda (origin)
        (eq? (vertex-origin-kind origin) 'fixed-context))
      origins)
     'residual-fixed-context]
    [(and (pair? origins)
          (andmap
           (lambda (origin)
             (eq? (vertex-origin-kind origin) 'unprotected-input))
           origins)
          (= 1
             (length
              (remove-duplicates
               (map vertex-origin-position origins)))))
     'residual-unprotected]
    [else 'residual-mixed]))

(define (cancelled-disposition? disposition)
  (memq disposition '(cancelled-empty cancelled-protected)))

(define (residual-disposition? disposition)
  (memq disposition
        '(residual-fixed-context residual-unprotected residual-mixed)))

(define (protected-choice-forward context output tuple)
  (forward-choice-certificate
   context output tuple 'protected-context-factorization-defect))

(define (same-address-family? left right address-accessor)
  (define right-addresses
    (for/hash ([item (in-list right)])
      (values (address-accessor item) #t)))
  (and (= (length left) (length right))
       (= (hash-count right-addresses) (length right))
       (for/and ([item (in-list left)])
         (hash-has-key? right-addresses (address-accessor item)))))

(define (protected-context-factorization-defect
         context inputs protected-positions
         #:limit [limit analysis-default-limit])
  (check-limit 'protected-context-factorization-defect limit)
  (unless (checked-node? context)
    (raise-argument-error
     'protected-context-factorization-defect "checked-node?" context))
  (unless (and (list? inputs) (andmap checked-term? inputs))
    (raise-argument-error
     'protected-context-factorization-defect
     "(listof checked-term?)"
     inputs))
  (let/ec stop
    (define calculus (checked-node-calculus context))
    (define positions (make-pointed-input-positions context inputs))
    (when (analysis-error? positions) (stop positions))
    (define protected
      (canonical-protected-positions
       'protected-context-factorization-defect
       protected-positions
       (length positions)))
    (when (analysis-error? protected) (stop protected))
    (define kind-error
      (validate-protected-input-kinds
       positions protected 'protected-context-factorization-defect))
    (when kind-error (stop kind-error))
    (define output (context-compose context inputs))
    (when (context-error? output)
      (stop
       (cocycle-error
        'context-evaluation-failed
        "evaluating the protected input tuple failed"
        'protected-context-factorization-defect
        'positive-checked-context
        output
        (hash 'context-error output))))

    ;; Preflight both finite witness families before materialising either.
    (define choice-count
      (coaction-choice-count/capped positions protected limit))
    (define direct-count
      (ordinary-witness-count/capped output limit))
    (when (or (over-limit? choice-count limit)
              (over-limit? direct-count limit))
      (stop
       (limit-result
        'protected-context-factorization-defect
        limit
        (add1 limit)
        'protected-factorization-witness-count
        (hash 'required-at-least (add1 limit)
              'protected-choice-count choice-count
              'direct-cut-count direct-count))))

    (define input-coaction
      (build-input-coaction/with-calculus calculus positions protected))
    (define choice-or-errors
      (for/list
          ([tuple
            (in-list
             (pointed-input-coaction-certificate-tuples input-coaction))])
        (protected-choice-forward context output tuple)))
    (define choice-error (findf analysis-error? choice-or-errors))
    (when choice-error (stop choice-error))
    (define choice-certificates choice-or-errors)
    (define choice-by-address
      (for/hash ([certificate (in-list choice-certificates)])
        (values
         (cut-witness-addresses
          (protected-choice-certificate-global-witness certificate))
         certificate)))
    (define origins
      (output-vertex-origins output positions protected))
    (define origin-by-address
      (for/hash ([origin (in-list origins)])
        (values (vertex-origin-address origin) origin)))
    (define cut-records-or-errors
      (for/list ([witness (in-admissible-cut-witnesses output)])
        (define addresses (cut-witness-addresses witness))
        (define selected-origins
          (for/list ([address (in-list addresses)])
            (hash-ref origin-by-address address)))
        (define disposition
          (cut-disposition addresses selected-origins))
        (define reconstruction (reconstruct-cut-witness witness))
        (define cancelled? (cancelled-disposition? disposition))
        (define recovered
          (and cancelled?
               (inverse-choice-tuple
                calculus positions protected addresses)))
        (define matching
          (and cancelled?
               (hash-ref choice-by-address addresses #f)))
        (cond
          [(analysis-error? recovered) recovered]
          [else
           (protected-cut-record
            witness
            addresses
            (cut-witness-detached witness)
            (cut-witness-remainder witness)
            reconstruction
            (and (checked-term? reconstruction)
                 (checked-term-has-exact-calculus? reconstruction calculus)
                 (equal? reconstruction output))
            selected-origins
            disposition
            recovered
            matching
            (and
             cancelled?
             recovered
             matching
             (equal? (pointed-choice-tuple-global-addresses recovered)
                     addresses)
             (equal?
              (choice-tuple-key recovered)
              (choice-tuple-key
               (protected-choice-certificate-choice-tuple matching))))
            (cut-witness-tensor witness))])))
    (define cut-record-error
      (findf analysis-error? cut-records-or-errors))
    (when cut-record-error (stop cut-record-error))
    (define cut-records cut-records-or-errors)

    (define direct (root-coaction output))
    (define recursive
      (formal-sum-from-choice-certificates
       calculus choice-certificates protected-choice-certificate-tensor))
    (define defect
      (and (formal-sum? direct)
           (formal-sum-subtract direct recursive)))
    (define residual-records
      (filter
       (lambda (record)
         (residual-disposition?
          (protected-cut-record-disposition record)))
       cut-records))
    (define residual-sum
      (make-formal-sum
       calculus
       2
       (for/list ([record (in-list residual-records)])
         (define entry
           (car
            (formal-sum-terms
             (protected-cut-record-tensor record))))
         (cons (car entry) (cdr entry)))))
    (define cancelled-records
      (filter
       (lambda (record)
         (cancelled-disposition?
          (protected-cut-record-disposition record)))
       cut-records))
    (define cancellation-bijection?
      (and
       (address-family-unique?
        choice-certificates
        (lambda (certificate)
          (cut-witness-addresses
           (protected-choice-certificate-global-witness certificate))))
       (same-address-family?
        choice-certificates
        cancelled-records
        (lambda (item)
          (cond
            [(protected-choice-certificate? item)
             (cut-witness-addresses
              (protected-choice-certificate-global-witness item))]
            [else (protected-cut-record-addresses item)])))
       (andmap
        (lambda (certificate)
          (and
           (protected-choice-certificate-reconstructs? certificate)
           (protected-choice-certificate-forest-agrees? certificate)
           (protected-choice-certificate-remainder-agrees? certificate)))
        choice-certificates)
       (andmap
        (lambda (record)
          (and
           (protected-cut-record-recovered-choice-tuple record)
           (protected-cut-record-matching-choice record)
           (protected-cut-record-cancellation-round-trip? record)
           (equal?
            (protected-cut-record-addresses record)
            (cut-witness-addresses
             (protected-choice-certificate-global-witness
              (protected-cut-record-matching-choice record))))))
        cancelled-records)))
    (define support-theorem?
      (and
       (andmap protected-cut-record-reconstructs? cut-records)
       (andmap
        (lambda (record)
          (define addresses (protected-cut-record-addresses record))
          (define selected
            (protected-cut-record-selected-origins record))
          (define wholly-protected?
            (and (pair? addresses)
                 (andmap
                  (lambda (origin)
                    (eq? (vertex-origin-kind origin) 'protected-input))
                  selected)))
          (if (residual-disposition?
               (protected-cut-record-disposition record))
              (and (pair? addresses) (not wholly-protected?))
              (or (null? addresses) wholly-protected?)))
        cut-records)))
    (protected-factorization-certificate
     calculus
     context
     (premise-telescope context)
     inputs
     protected
     output
     input-coaction
     choice-certificates
     origins
     cut-records
     direct
     recursive
     defect
     residual-sum
     cancellation-bijection?
     support-theorem?
     (and (formal-sum? defect) (equal? defect residual-sum)))))

(define protected-factorization-defect
  protected-context-factorization-defect)

(define (compatible-local-contexts-error source target operation)
  (define source-calculus (checked-node-calculus source))
  (cond
    [(not (eq? source-calculus (checked-node-calculus target)))
     (cocycle-error
      'calculus-mismatch
      "local replacement residues require one exact calculus snapshot"
      operation source-calculus (checked-node-calculus target))]
    [(not (equal? (derivation-root-boundary source)
                  (derivation-root-boundary target)))
     (cocycle-error
      'root-boundary-mismatch
      "local replacement contexts must have the same whole root boundary"
      operation
      (derivation-root-boundary source)
      (derivation-root-boundary target))]
    [(not (equal? (premise-telescope source)
                  (premise-telescope target)))
     (cocycle-error
      'addressed-telescope-mismatch
      "local replacement contexts must have the same addressed telescope"
      operation
      (premise-telescope source)
      (premise-telescope target))]
    [else #f]))

(define (protected-local-replacement-residue
         source-context target-context inputs protected-positions
         #:limit [limit analysis-default-limit])
  (check-limit 'protected-local-replacement-residue limit)
  (unless (checked-node? source-context)
    (raise-argument-error
     'protected-local-replacement-residue
     "checked-node?"
     source-context))
  (unless (checked-node? target-context)
    (raise-argument-error
     'protected-local-replacement-residue
     "checked-node?"
     target-context))
  (define compatibility
    (compatible-local-contexts-error
     source-context target-context
     'protected-local-replacement-residue))
  (cond
    [compatibility compatibility]
    [else
     (define source-defect
       (protected-context-factorization-defect
        source-context inputs protected-positions #:limit limit))
     (cond
       [(or (analysis-error? source-defect)
            (analysis-limit? source-defect))
        source-defect]
       [else
        (define target-defect
          (protected-context-factorization-defect
           target-context inputs protected-positions #:limit limit))
        (cond
          [(or (analysis-error? target-defect)
               (analysis-limit? target-defect))
           target-defect]
          [else
           (define source-sum
             (protected-factorization-certificate-defect source-defect))
           (define target-sum
             (protected-factorization-certificate-defect target-defect))
           (define residue
             (formal-sum-subtract target-sum source-sum))
           (define reverse-residue
             (formal-sum-subtract source-sum target-sum))
           (define identity-source
             (formal-sum-subtract source-sum source-sum))
           (define identity-target
             (formal-sum-subtract target-sum target-sum))
           (define antisymmetry
             (formal-sum-add residue reverse-residue))
           (protected-local-residue-certificate
            (checked-node-calculus source-context)
            source-context
            target-context
            (premise-telescope source-context)
            inputs
            (protected-factorization-certificate-protected-positions
             source-defect)
            source-defect
            target-defect
            residue
            reverse-residue
            (and (formal-zero? identity-source)
                 (formal-zero? identity-target))
            (formal-zero? antisymmetry))])])]))

(define protected-local-residue protected-local-replacement-residue)

(define (protected-local-residue-laws
         first-context second-context third-context inputs protected-positions
         #:limit [limit analysis-default-limit])
  (check-limit 'protected-local-residue-laws limit)
  (define residue-01
    (protected-local-replacement-residue
     first-context second-context inputs protected-positions #:limit limit))
  (cond
    [(or (analysis-error? residue-01) (analysis-limit? residue-01))
     residue-01]
    [else
     (define residue-12
       (protected-local-replacement-residue
        second-context third-context inputs protected-positions #:limit limit))
     (cond
       [(or (analysis-error? residue-12) (analysis-limit? residue-12))
        residue-12]
       [else
        (define residue-02
          (protected-local-replacement-residue
           first-context third-context inputs protected-positions
           #:limit limit))
        (cond
          [(or (analysis-error? residue-02) (analysis-limit? residue-02))
           residue-02]
          [else
           (define sum-01
             (protected-local-residue-certificate-residue residue-01))
           (define sum-12
             (protected-local-residue-certificate-residue residue-12))
           (define sum-02
             (protected-local-residue-certificate-residue residue-02))
           (protected-local-residue-laws-certificate
            first-context
            second-context
            third-context
            inputs
            (protected-local-residue-certificate-protected-positions
             residue-01)
            residue-01
            residue-12
            residue-02
            (and
             (protected-local-residue-certificate-identity-law? residue-01)
             (protected-local-residue-certificate-identity-law? residue-12)
             (protected-local-residue-certificate-identity-law? residue-02))
            (and
             (protected-local-residue-certificate-antisymmetry-law?
              residue-01)
             (protected-local-residue-certificate-antisymmetry-law?
              residue-12)
             (protected-local-residue-certificate-antisymmetry-law?
              residue-02))
            (equal? (formal-sum-add sum-01 sum-12) sum-02))])])]))
