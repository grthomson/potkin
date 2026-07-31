#lang racket/base

(require racket/generator
         racket/list
         racket/match
         "address.rkt"
         "boundary.rkt"
         "calculus.rkt"
         "check.rkt"
         "context.rkt"
         "syntax.rkt")

(provide proof-forest?
         make-proof-forest
         empty-proof-forest
         proof-forest-calculus
         proof-forest-empty?
         proof-forest-size
         proof-forest-count
         proof-forest-factors
         forest-union
         block-root-profile?
         block-root-profile-size
         block-root-profile-count
         block-root-profile-boundaries
         forest-block-root-profile
         forest-flattened-root
         cut-error?
         cut-error-code
         cut-error-message
         cut-error-address
         cut-error-details
         validate-ck-cut
         ck-cut-admissible?
         detached-entry?
         detached-entry-address
         detached-entry-term
         cut-witness?
         cut-witness-source
         cut-witness-addresses
         cut-witness-detached
         cut-witness-remainder
         cut-witness-forest
         make-cut-witness
         reconstruct-cut-witness
         cut-witness-reconstructs?
         in-admissible-cuts
         in-admissible-cut-witnesses)

;; Forests are commutative multisets of positive-vertex connected checked
;; terms. Registry provenance supports later operations but is excluded from
;; presentation equality, just as it is for checked terms.
(struct proof-forest (calculus counts)
  #:constructor-name make-proof-forest/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (proof-forest? right)
          (recur (proof-forest-counts left)
                 (proof-forest-counts right))))
   (lambda (value recur) (recur (proof-forest-counts value)))
   (lambda (value recur) (recur (proof-forest-counts value)))))

(define (make-proof-forest calculus factors)
  (unless (equipped-calculus? calculus)
    (raise-argument-error 'make-proof-forest "equipped-calculus?" calculus))
  (unless (and (list? factors) (andmap checked-node? factors))
    (raise-argument-error
     'make-proof-forest "(listof checked-node?)" factors))
  (define normalized-factors
    (for/list ([factor (in-list factors)])
      (unless (term-admitted-by? calculus factor)
        (raise-arguments-error
         'make-proof-forest
         "every connected factor must be admitted by the forest calculus"
         "factor" factor))
      ;; Recheck under the selected registry so extracted factors carry the
      ;; same operational provenance reported by the forest.
      (define normalized
        (validate-candidate
         calculus
         (checked-term->raw factor)
         #:expected (derivation-root-boundary factor)))
      (when (validation-error? normalized)
        (raise-arguments-error
         'make-proof-forest
         "rechecking an admitted connected factor unexpectedly failed"
         "factor" factor
         "validation error" normalized))
      normalized))
  (make-proof-forest/internal
   calculus
   (for/fold ([counts (hash)]) ([factor (in-list normalized-factors)])
     (hash-update counts factor add1 0))))

(define (empty-proof-forest calculus)
  (make-proof-forest calculus '()))

(define (proof-forest-empty? forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'proof-forest-empty? "proof-forest?" forest))
  (zero? (hash-count (proof-forest-counts forest))))

(define (proof-forest-size forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'proof-forest-size "proof-forest?" forest))
  (for/sum ([count (in-hash-values (proof-forest-counts forest))])
    count))

(define (proof-forest-count forest factor)
  (unless (proof-forest? forest)
    (raise-argument-error 'proof-forest-count "proof-forest?" forest))
  (unless (checked-node? factor)
    (raise-argument-error 'proof-forest-count "checked-node?" factor))
  (hash-ref (proof-forest-counts forest) factor 0))

;; The order of this expanded view is deliberately unspecified. It is for
;; traversal only; equality and multiplication use the multiset counts.
(define (proof-forest-factors forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'proof-forest-factors "proof-forest?" forest))
  (append-map
   (lambda (factor)
     (make-list (hash-ref (proof-forest-counts forest) factor) factor))
   (hash-keys (proof-forest-counts forest))))

(define (forest-union first-forest . remaining-forests)
  (unless (proof-forest? first-forest)
    (raise-argument-error 'forest-union "proof-forest?" first-forest))
  (for ([forest (in-list remaining-forests)])
    (unless (proof-forest? forest)
      (raise-argument-error 'forest-union "proof-forest?" forest))
    (unless (equal? (proof-forest-calculus first-forest)
                    (proof-forest-calculus forest))
      (raise-arguments-error
       'forest-union
       "forest multiplication is defined within one equipped calculus"
       "first calculus" (proof-forest-calculus first-forest)
       "other calculus" (proof-forest-calculus forest))))
  (define calculus (proof-forest-calculus first-forest))
  (make-proof-forest
   calculus
   (append-map proof-forest-factors
               (cons first-forest remaining-forests))))

(struct block-root-profile (counts)
  #:constructor-name make-block-root-profile/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (block-root-profile? right)
          (recur (block-root-profile-counts left)
                 (block-root-profile-counts right))))
   (lambda (value recur) (recur (block-root-profile-counts value)))
   (lambda (value recur) (recur (block-root-profile-counts value)))))

(define (block-root-profile-size profile)
  (unless (block-root-profile? profile)
    (raise-argument-error
     'block-root-profile-size "block-root-profile?" profile))
  (for/sum ([count (in-hash-values (block-root-profile-counts profile))])
    count))

(define (block-root-profile-count profile boundary)
  (unless (block-root-profile? profile)
    (raise-argument-error
     'block-root-profile-count "block-root-profile?" profile))
  (unless (hypersequent? boundary)
    (raise-argument-error
     'block-root-profile-count "hypersequent?" boundary))
  (hash-ref (block-root-profile-counts profile) boundary 0))

(define (block-root-profile-boundaries profile)
  (unless (block-root-profile? profile)
    (raise-argument-error
     'block-root-profile-boundaries "block-root-profile?" profile))
  (append-map
   (lambda (boundary)
     (make-list (hash-ref (block-root-profile-counts profile) boundary)
                boundary))
   (hash-keys (block-root-profile-counts profile))))

(define (forest-block-root-profile forest)
  (unless (proof-forest? forest)
    (raise-argument-error
     'forest-block-root-profile "proof-forest?" forest))
  (make-block-root-profile/internal
   (for/fold ([counts (hash)])
             ([factor (in-list (proof-forest-factors forest))])
     (hash-update counts (derivation-root-boundary factor) add1 0))))

;; HSeq excludes the empty hypersequent, so the empty forest has no flattened
;; HSeq value and returns #f. Nonempty forests flatten component multisets.
(define (forest-flattened-root forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'forest-flattened-root "proof-forest?" forest))
  (define roots
    (map derivation-root-boundary (proof-forest-factors forest)))
  (and (pair? roots) (apply hypersequent-union roots)))

(struct cut-error (code message address details)
  #:transparent)

(define (make-cut-error code message
                        #:address [address #f]
                        #:details [details (hash)])
  (cut-error code message address details))

(define (prefix-conflict sorted-addresses)
  (for*/first ([left (in-list sorted-addresses)]
               [right (in-list sorted-addresses)]
               #:when (proper-address-prefix? left right))
    (list left right)))

(define (validate-ck-cut proof addresses)
  (unless (checked-node? proof)
    (raise-argument-error 'validate-ck-cut "checked-node?" proof))
  (cond
    [(not (list? addresses))
     (make-cut-error
      'malformed-cut
      "a CK cut is a finite list of premise-slot addresses")]
    [(for/or ([address (in-list addresses)])
       (and (not (address? address)) (list address)))
     =>
     (lambda (boxed-bad-address)
       (make-cut-error
        'malformed-address
        "every cut address must be a list of positive premise slots"
        #:address (car boxed-bad-address)))]
    [(member root-address addresses)
     (make-cut-error
      'root-cut
      "the whole-tree endpoint is not an admissible CK cut"
      #:address root-address)]
    [(check-duplicates addresses equal?)
     =>
     (lambda (duplicate)
       (make-cut-error
        'duplicate-address
        "a cut is a set of distinct vertex occurrences"
        #:address duplicate))]
    [(findf (lambda (address) (not (vertex-at-address proof address)))
            addresses)
     =>
     (lambda (missing)
       (make-cut-error
        'nonvertex-address
        "every cut address must name an existing rule vertex"
        #:address missing))]
    [else
     (define sorted-addresses (sort addresses address<?))
     (define conflict (prefix-conflict sorted-addresses))
     (if conflict
         (make-cut-error
          'non-prefix-free
          "an admissible cut cannot select an ancestor and its descendant"
          #:address (second conflict)
          #:details (hash 'ancestor (first conflict)
                          'descendant (second conflict)))
         sorted-addresses)]))

(define (ck-cut-admissible? proof addresses)
  (not (cut-error? (validate-ck-cut proof addresses))))

(struct detached-entry (address term)
  #:constructor-name make-detached-entry/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (detached-entry? right)
          (recur (detached-entry-address left)
                 (detached-entry-address right))
          (recur (detached-entry-term left)
                 (detached-entry-term right))))
   (lambda (value recur)
     (recur (list (detached-entry-address value)
                  (detached-entry-term value))))
   (lambda (value recur)
     (recur (list (detached-entry-term value)
                  (detached-entry-address value))))))

(struct cut-witness (source addresses detached remainder forest)
  #:constructor-name make-cut-witness/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (cut-witness? right)
          (recur (cut-witness-source left) (cut-witness-source right))
          (recur (cut-witness-addresses left) (cut-witness-addresses right))
          (recur (cut-witness-detached left) (cut-witness-detached right))
          (recur (cut-witness-remainder left) (cut-witness-remainder right))
          (recur (cut-witness-forest left) (cut-witness-forest right))))
   (lambda (value recur)
     (recur (list (cut-witness-source value)
                  (cut-witness-addresses value)
                  (cut-witness-detached value)
                  (cut-witness-remainder value)
                  (cut-witness-forest value))))
   (lambda (value recur)
     (recur (list (cut-witness-forest value)
                  (cut-witness-remainder value)
                  (cut-witness-detached value)
                  (cut-witness-addresses value)
                  (cut-witness-source value))))))

(define (raw-puncture-at-addresses candidate selected-addresses)
  (define selected
    (for/hash ([address (in-list selected-addresses)])
      (values address #t)))
  (define (walk current prefix)
    (cond
      [(hash-has-key? selected prefix) raw-hole]
      [else
       (match current
         [(list 'app occurrence-id children ...)
          (list*
           'app
           occurrence-id
           (for/list ([child (in-list children)]
                      [slot (in-naturals 1)])
             (walk child (append prefix (list slot)))))]
         [_ current])]))
  (walk candidate root-address))

(define (make-cut-witness proof addresses)
  (unless (checked-node? proof)
    (raise-argument-error 'make-cut-witness "checked-node?" proof))
  (define validated (validate-ck-cut proof addresses))
  (cond
    [(cut-error? validated) validated]
    [else
     (define detached
       (for/list ([address (in-list validated)])
         (make-detached-entry/internal
          address
          (vertex-at-address proof address))))
     (define calculus (checked-term-calculus proof))
     (define remainder
       (validate-candidate
        calculus
        (raw-puncture-at-addresses (checked-term->raw proof) validated)
        #:expected (derivation-root-boundary proof)))
     (if (validation-error? remainder)
         (make-cut-error
          'invalid-remainder
          "puncturing an admitted proof unexpectedly failed revalidation"
          #:details (hash 'validation-error remainder))
         (make-cut-witness/internal
          proof
          validated
          detached
          remainder
          (make-proof-forest calculus
                             (map detached-entry-term detached))))]))

(define (reconstruct-cut-witness witness)
  (unless (cut-witness? witness)
    (raise-argument-error
     'reconstruct-cut-witness "cut-witness?" witness))
  ;; Fill only the newly cut addresses. A source may already have unrelated
  ;; punctures, which must remain vacant after distinguished reconstruction.
  (let loop ([current (cut-witness-remainder witness)]
             [entries (cut-witness-detached witness)])
    (cond
      [(null? entries) current]
      [else
       (define entry (car entries))
       (define result
         (context-insert current
                         (detached-entry-address entry)
                         (detached-entry-term entry)))
       (if (context-error? result)
           result
           (loop result (cdr entries)))])))

(define (cut-witness-reconstructs? witness)
  (and (cut-witness? witness)
       (equal? (reconstruct-cut-witness witness)
               (cut-witness-source witness))))

(define (in-admissible-cuts proof)
  (unless (checked-node? proof)
    (raise-argument-error 'in-admissible-cuts "checked-node?" proof))
  (in-generator
   (define (branches node prefix)
     (for/list ([child (in-list (checked-node-children node))]
                [slot (in-naturals 1)]
                #:when (checked-node? child))
       (cons child (append prefix (list slot)))))

   ;; Enumerate the Cartesian product of branch choices with earlier premise
   ;; slots varying first, matching lexicographic address/mask order without
   ;; ever constructing an inadmissible ancestor/descendant subset.
   (define (enumerate-combinations branch-list emit)
     (define (loop reversed-branches accumulated)
       (cond
         [(null? reversed-branches)
          (emit (sort accumulated address<?))]
         [else
          (define branch (car reversed-branches))
          (enumerate-subtree
           (car branch)
           (cdr branch)
           (lambda (choice)
             (loop (cdr reversed-branches)
                   (append choice accumulated))))]))
     (loop (reverse branch-list) '()))

   (define (enumerate-subtree node address emit)
     (emit '())
     (emit (list address))
     (define child-branches (branches node address))
     (when (pair? child-branches)
       (enumerate-combinations
        child-branches
        (lambda (descendant-cut)
          (unless (null? descendant-cut)
            (emit descendant-cut))))))

   (enumerate-combinations (branches proof root-address) yield)))

(define (in-admissible-cut-witnesses proof)
  (unless (checked-node? proof)
    (raise-argument-error
     'in-admissible-cut-witnesses "checked-node?" proof))
  (in-generator
   (for ([addresses (in-admissible-cuts proof)])
     (yield (make-cut-witness proof addresses)))))
