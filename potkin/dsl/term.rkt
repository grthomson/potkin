#lang racket/base

(require racket/list
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/syntax.rkt"
         (for-syntax racket/base
                     racket/list
                     syntax/parse))

(provide check-derivation
         define-derivation
         define-proof
         define-context
         context-interface?
         context-interface-calculus
         context-interface-of
         context-input-word
         context-output-boundary
         context-in-interface?
         positive-context-operation?
         context-compose/addressed
         backward-refine
         filling-point?
         filling-point-context
         filling-point-fillers
         make-filling-point
         evaluate-filling-point
         extract-filling-point
         dsl-error?
         dsl-error-code
         dsl-error-message
         dsl-error-operation
         dsl-error-address
         dsl-error-expected
         dsl-error-actual
         dsl-error-details)

(struct dsl-error
  (code message operation address expected actual details)
  #:transparent)

(define (make-dsl-error code message operation
                        #:address [address #f]
                        #:expected [expected #f]
                        #:actual [actual #f]
                        #:details [details (hash)])
  (dsl-error code message operation address expected actual details))

(define (validation-error->dsl operation error)
  (make-dsl-error
   (validation-error-code error)
   (validation-error-message error)
   operation
   #:address (validation-error-address error)
   #:expected (validation-error-expected error)
   #:actual (validation-error-actual error)
   #:details (validation-error-details error)))

(define (context-error->dsl operation error)
  (make-dsl-error
   (context-error-code error)
   (context-error-message error)
   operation
   #:address (context-error-address error)
   #:expected (context-error-expected error)
   #:actual (context-error-actual error)
   #:details (context-error-details error)))

;; The macro compiler sees lexical occurrence bindings as values.  Exact
;; registry identity is checked before the shared raw application is emitted;
;; looking up a printed tag or accepting a structurally equal counterfeit
;; would lose the calculus-relative meaning of the term.
(define (compile-lexical-application calculus occurrence children address)
  (unless (equipped-calculus? calculus)
    (raise-argument-error
     'check-derivation "equipped-calculus?" calculus))
  (cond
    [(not (concrete-occurrence? occurrence))
     (make-dsl-error
      'not-concrete-occurrence
      "a derivation head or leaf must be a concrete-occurrence binding"
      'check-derivation
      #:address address
      #:actual occurrence)]
    [else
     (define registered
       (calculus-lookup calculus (concrete-occurrence-id occurrence)))
     (cond
       [(not (eq? occurrence registered))
        (make-dsl-error
         'foreign-occurrence
         "the cited occurrence is not the exact object admitted by this calculus"
         'check-derivation
         #:address address
         #:expected registered
         #:actual occurrence
         #:details
         (hash 'occurrence-id (concrete-occurrence-id occurrence)))]
       [(not (= (length children) (occurrence-arity occurrence)))
        (make-dsl-error
         'wrong-arity
         "the application does not supply exactly the declared premise slots"
         'check-derivation
         #:address address
         #:expected (occurrence-arity occurrence)
         #:actual (length children)
         #:details
         (hash 'occurrence (concrete-occurrence-id occurrence)))]
       [else
        (define child-error (findf dsl-error? children))
        (if child-error
            child-error
            (apply raw-app
                   (concrete-occurrence-id occurrence)
                   children))])]))

(define (check-compiled-derivation calculus root compiled)
  (unless (equipped-calculus? calculus)
    (raise-argument-error
     'check-derivation "equipped-calculus?" calculus))
  (unless (hypersequent? root)
    (raise-argument-error 'check-derivation "hypersequent?" root))
  (cond
    [(dsl-error? compiled) compiled]
    [else
     (define result
       (validate-candidate calculus compiled #:expected root))
     (if (validation-error? result)
         (validation-error->dsl 'check-derivation result)
         result)]))

(begin-for-syntax
  (define (quoted-address context address)
    (datum->syntax context `(quote ,address)))

  (define (compile-tree tree calculus address)
    (cond
      [(identifier? tree)
       (if (eq? (syntax-e tree) '_)
           #'raw-hole
           #`(compile-lexical-application
              #,calculus
              #,tree
              '()
              #,(quoted-address tree address)))]
      [else
       (syntax-parse tree
         [(head:id child ...)
          (define children (syntax->list #'(child ...)))
          (define compiled-children
            (for/list ([child (in-list children)]
                       [slot (in-naturals 1)])
              (compile-tree child calculus (append address (list slot)))))
          #`(compile-lexical-application
             #,calculus
             head
             (list #,@compiled-children)
             #,(quoted-address tree address))]
         [_
          (raise-syntax-error
           'check-derivation
           "expected _, an occurrence binding, or (occurrence-binding tree ...)"
           tree)])])))

(define-syntax (check-derivation stx)
  (syntax-parse stx
    [(_ #:in calculus:expr #:root root:expr tree)
     (define calculus-name (car (generate-temporaries '(calculus))))
     (define root-name (car (generate-temporaries '(root))))
     (define compiled
       (compile-tree #'tree calculus-name '()))
     #`(let ([#,calculus-name calculus]
             [#,root-name root])
         (check-compiled-derivation
          #,calculus-name
          #,root-name
          #,compiled))]))

(define (require-declaration-kind operation result kind)
  (cond
    [(dsl-error? result) result]
    [(eq? kind 'derivation) result]
    [(eq? kind 'proof)
     (if (complete-proof? result)
         result
         (make-dsl-error
          'not-complete-proof
          "define-proof requires a complete rule-rooted derivation"
          operation
          #:address
          (and (pair? (puncture-addresses result))
               (car (puncture-addresses result)))
          #:expected 'complete-rule-rooted
          #:actual result))]
    [(eq? kind 'context)
     (if (proof-context? result)
         result
         (make-dsl-error
          'not-punctured-context
          "define-context requires at least one typed puncture"
          operation
          #:expected 'punctured-derivation
          #:actual result))]))

(define-syntax (define-derivation stx)
  (syntax-parse stx
    [(_ binding-name:id #:in calculus:expr #:root root:expr tree)
     #'(define binding-name
         (require-declaration-kind
          'define-derivation
          (check-derivation #:in calculus #:root root tree)
          'derivation))]))

(define-syntax (define-proof stx)
  (syntax-parse stx
    [(_ binding-name:id #:in calculus:expr #:root root:expr tree)
     #'(define binding-name
         (require-declaration-kind
          'define-proof
          (check-derivation #:in calculus #:root root tree)
          'proof))]))

(define-syntax (define-context stx)
  (syntax-parse stx
    [(_ binding-name:id #:in calculus:expr #:root root:expr tree)
     #'(define binding-name
         (require-declaration-kind
          'define-context
          (check-derivation #:in calculus #:root root tree)
          'context))]))

;; The interface is derived metadata for the nonsymmetric context operation.
;; Its calculus field enforces operational provenance but it is never a proof
;; tree, puncture, forest factor, or Hopf generator.
(struct context-interface (calculus inputs output)
  #:constructor-name make-context-interface/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (context-interface? right)
          (eq? (context-interface-calculus left)
               (context-interface-calculus right))
          (recur (context-interface-inputs left)
                 (context-interface-inputs right))
          (recur (context-interface-output left)
                 (context-interface-output right))))
   (lambda (value recur)
     (bitwise-xor
      (eq-hash-code (context-interface-calculus value))
      (recur (list (context-interface-inputs value)
                   (context-interface-output value)))))
   (lambda (value recur)
     (bitwise-xor
      (eq-hash-code (context-interface-calculus value))
      (recur (list (context-interface-output value)
                   (context-interface-inputs value)))))))

(define (context-interface-of term)
  (unless (checked-term? term)
    (raise-argument-error 'context-interface-of "checked-term?" term))
  (define calculus (checked-term-calculus term))
  (unless (checked-term-has-exact-calculus? term calculus)
    (raise-arguments-error
     'context-interface-of
     "the checked term must carry one exact calculus snapshot throughout"
     "term" term))
  (make-context-interface/internal
   calculus
   (for/list ([entry (in-list (premise-telescope term))])
     (telescope-entry-requirement entry))
   (derivation-root-boundary term)))

(define (context-input-word interface)
  (unless (context-interface? interface)
    (raise-argument-error
     'context-input-word "context-interface?" interface))
  (context-interface-inputs interface))

(define (context-output-boundary interface)
  (unless (context-interface? interface)
    (raise-argument-error
     'context-output-boundary "context-interface?" interface))
  (context-interface-output interface))

(define (context-in-interface? term interface)
  (and
   (checked-term? term)
   (context-interface? interface)
   (let ([calculus (context-interface-calculus interface)])
     (and
      (checked-term-has-exact-calculus? term calculus)
      (equal?
       (for/list ([entry (in-list (premise-telescope term))])
         (telescope-entry-requirement entry))
       (context-interface-inputs interface))
      (equal? (derivation-root-boundary term)
              (context-interface-output interface))))))

(define (positive-context-operation? value)
  (checked-node? value))

(define (address-map-entry? entry)
  (and (pair? entry)
       (address? (car entry))
       (checked-term? (cdr entry))))

(define (context-compose/addressed context assignments)
  (unless (checked-term? context)
    (raise-argument-error
     'context-compose/addressed "checked-term?" context))
  (unless (list? assignments)
    (raise-argument-error
     'context-compose/addressed "list?" assignments))
  (define operation 'context-compose/addressed)
  (define malformed
    (for/first ([entry (in-list assignments)]
                #:unless (address-map-entry? entry))
      (list entry)))
  (cond
    [malformed
     (make-dsl-error
      'malformed-address-map
      "each assignment must be a pair from an address to a checked replacement"
      operation
      #:actual (car malformed))]
    [else
     (define supplied-addresses (map car assignments))
     (define duplicate (check-duplicates supplied-addresses equal?))
     (define telescope (premise-telescope context))
     (define expected-addresses (map telescope-entry-address telescope))
     (cond
       [duplicate
        (make-dsl-error
         'duplicate-address
         "an addressed composition assigns one replacement to each puncture"
         operation
         #:address duplicate)]
       [else
        (define extra
          (findf (lambda (address)
                   (not (member address expected-addresses equal?)))
                 supplied-addresses))
        (cond
          [extra
           (define selected (checked-term-at-address context extra))
           (make-dsl-error
            (if (and selected (not (checked-hole? selected)))
                'nonpuncture-address
                'extra-address)
            (if (and selected (not (checked-hole? selected)))
                "the address names a retained vertex rather than a puncture"
                "the address is not in the context's premise telescope")
            operation
            #:address extra
            #:expected expected-addresses
            #:actual supplied-addresses)]
          [else
           (define missing
             (findf (lambda (address)
                      (not (member address supplied-addresses equal?)))
                    expected-addresses))
           (cond
             [missing
              (make-dsl-error
               'missing-address
               "addressed composition needs a replacement for every puncture"
               operation
               #:address missing
               #:expected expected-addresses
               #:actual supplied-addresses)]
             [else
              (define ordered-replacements
                (for/list ([entry (in-list telescope)])
                  (cdr (assoc (telescope-entry-address entry)
                              assignments
                              equal?))))
              (define result (context-compose context ordered-replacements))
              (if (context-error? result)
                  (context-error->dsl operation result)
                  result)])])])]))

(define (backward-refine context address occurrence)
  (unless (checked-term? context)
    (raise-argument-error 'backward-refine "checked-term?" context))
  (unless (address? address)
    (raise-argument-error 'backward-refine "address?" address))
  (define operation 'backward-refine)
  (define selected (checked-term-at-address context address))
  (cond
    [(not selected)
     (make-dsl-error
      'no-such-address
      "the address does not occur in this context"
      operation
      #:address address)]
    [(not (checked-hole? selected))
     (make-dsl-error
      'not-a-puncture
      "backward refinement targets a vacant premise slot"
      operation
      #:address address
      #:actual selected)]
    [(not (concrete-occurrence? occurrence))
     (make-dsl-error
      'not-concrete-occurrence
      "backward refinement requires a concrete occurrence"
      operation
      #:address address
      #:actual occurrence)]
    [else
     (define calculus (checked-term-calculus context))
     (define registered
       (calculus-lookup calculus (concrete-occurrence-id occurrence)))
     (define requirement (puncture-requirement context address))
     (cond
       [(not (eq? occurrence registered))
        (make-dsl-error
         'foreign-occurrence
         "the refining occurrence is not the exact occurrence admitted here"
         operation
         #:address address
         #:expected registered
         #:actual occurrence)]
       [(not (equal? requirement
                     (concrete-occurrence-conclusion occurrence)))
        (make-dsl-error
         'wrong-boundary
         "the refining corolla does not conclude the selected requirement"
         operation
         #:address address
         #:expected requirement
         #:actual (concrete-occurrence-conclusion occurrence))]
       [else
        (define one-corolla (corolla calculus occurrence))
        (cond
          [(context-error? one-corolla)
           (context-error->dsl operation one-corolla)]
          [else
           (define result (context-insert context address one-corolla))
           (if (context-error? result)
               (context-error->dsl operation result)
               result)])])]))

(struct filling-point (context fillers)
  #:constructor-name make-filling-point/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (filling-point? right)
          (eq? (checked-term-calculus (filling-point-context left))
               (checked-term-calculus (filling-point-context right)))
          (recur (filling-point-context left)
                 (filling-point-context right))
          (recur (filling-point-fillers left)
                 (filling-point-fillers right))))
   (lambda (value recur)
     (bitwise-xor
      (eq-hash-code
       (checked-term-calculus (filling-point-context value)))
      (recur (list (filling-point-context value)
                   (filling-point-fillers value)))))
   (lambda (value recur)
     (bitwise-xor
      (eq-hash-code
       (checked-term-calculus (filling-point-context value)))
      (recur (list (filling-point-fillers value)
                   (filling-point-context value)))))))

(define (make-filling-point context fillers)
  (unless (checked-term? context)
    (raise-argument-error 'make-filling-point "checked-term?" context))
  (unless (list? fillers)
    (raise-argument-error 'make-filling-point "list?" fillers))
  (define operation 'make-filling-point)
  (cond
    [(not (proof-context? context))
     (make-dsl-error
      'not-context
      "a filling point is indexed by a punctured derivation"
      operation
      #:expected 'punctured-derivation
      #:actual context)]
    [else
     (define telescope (premise-telescope context))
     (cond
       [(not (= (length telescope) (length fillers)))
        (make-dsl-error
         'wrong-filler-count
         "a filling point supplies one proof per telescope entry"
         operation
         #:expected (length telescope)
         #:actual (length fillers))]
       [else
        (define calculus (checked-term-calculus context))
        (define failure
          (for/first ([entry (in-list telescope)]
                      [filler (in-list fillers)]
                      [position (in-naturals 1)]
                      #:do
                      [(define error
                         (cond
                           [(not (checked-term? filler))
                            (make-dsl-error
                             'invalid-filler
                             "a filling point contains checked derivations"
                             operation
                             #:address (telescope-entry-address entry)
                             #:actual filler
                             #:details (hash 'position position))]
                           [(not (complete-proof? filler))
                            (make-dsl-error
                             'incomplete-filler
                             "a filling point accepts only complete rule-rooted proofs"
                             operation
                             #:address (telescope-entry-address entry)
                             #:actual filler
                             #:details (hash 'position position))]
                           [(not (checked-term-has-exact-calculus?
                                  filler calculus))
                            (make-dsl-error
                             'wrong-calculus-provenance
                             "every filler must carry the context's exact calculus"
                             operation
                             #:address (telescope-entry-address entry)
                             #:expected calculus
                             #:actual (checked-term-calculus filler)
                             #:details (hash 'position position))]
                           [(not (equal?
                                  (telescope-entry-requirement entry)
                                  (derivation-root-boundary filler)))
                            (make-dsl-error
                             'wrong-boundary
                             "a filler root does not match its ordered telescope entry"
                             operation
                             #:address (telescope-entry-address entry)
                             #:expected (telescope-entry-requirement entry)
                             #:actual (derivation-root-boundary filler)
                             #:details (hash 'position position))]
                           [else #f]))]
                      #:when error)
            error))
        (if failure
            failure
            (make-filling-point/internal context (for/list ([f fillers]) f)))])]))

(define (evaluate-filling-point point)
  (unless (filling-point? point)
    (raise-argument-error
     'evaluate-filling-point "filling-point?" point))
  (define result
    (complete-fill (filling-point-context point)
                   (filling-point-fillers point)))
  (if (context-error? result)
      (context-error->dsl 'evaluate-filling-point result)
      result))

(define (extract-filling-point context candidate)
  (unless (checked-term? context)
    (raise-argument-error 'extract-filling-point "checked-term?" context))
  (unless (checked-term? candidate)
    (raise-argument-error 'extract-filling-point "checked-term?" candidate))
  (define operation 'extract-filling-point)
  (cond
    [(not (proof-context? context))
     (make-dsl-error
      'not-context
      "filling extraction requires a punctured source context"
      operation
      #:expected 'punctured-derivation
      #:actual context)]
    [(not (complete-proof? candidate))
     (make-dsl-error
      'incomplete-candidate
      "filling extraction compares the context with a complete proof"
      operation
      #:expected 'complete-rule-rooted
      #:actual candidate)]
    [else
     (define calculus (checked-term-calculus context))
     (cond
       [(not (checked-term-has-exact-calculus? context calculus))
        (make-dsl-error
         'wrong-calculus-provenance
         "the source context must carry one exact calculus throughout"
         operation
         #:expected calculus
         #:actual (checked-term-calculus context))]
       [(not (checked-term-has-exact-calculus? candidate calculus))
        (make-dsl-error
         'wrong-calculus-provenance
         "the candidate proof must carry the context's exact calculus"
         operation
         #:expected calculus
         #:actual (checked-term-calculus candidate))]
       [(not (equal? (derivation-root-boundary context)
                     (derivation-root-boundary candidate)))
        (make-dsl-error
         'wrong-boundary
         "the candidate proof has the wrong whole root boundary"
         operation
         #:address root-address
         #:expected (derivation-root-boundary context)
         #:actual (derivation-root-boundary candidate))]
       [else
        (define captures (make-hash))
        (define failure #f)
        (define (walk retained actual address)
          (cond
            [failure (void)]
            [(checked-hole? retained)
             ;; Candidate completeness makes this a complete checked node.
             (hash-set! captures address actual)]
            [(not (checked-node? actual))
             (set! failure
                   (make-dsl-error
                    'retained-shape-mismatch
                    "the candidate does not preserve a retained rule node"
                    operation
                    #:address address
                    #:expected retained
                    #:actual actual))]
            [(not (eq? (checked-node-occurrence retained)
                       (checked-node-occurrence actual)))
             (set! failure
                   (make-dsl-error
                    'retained-occurrence-mismatch
                    "the candidate changes an exact retained occurrence"
                    operation
                    #:address address
                    #:expected (checked-node-occurrence retained)
                    #:actual (checked-node-occurrence actual)))]
            [else
             (for ([retained-child
                    (in-list (checked-node-children retained))]
                   [actual-child
                    (in-list (checked-node-children actual))]
                   [slot (in-naturals 1)])
               (walk retained-child
                     actual-child
                     (append address (list slot))))]))
        (walk context candidate root-address)
        (cond
          [failure failure]
          [else
           (define fillers
             (for/list ([entry (in-list (premise-telescope context))])
               (hash-ref captures (telescope-entry-address entry))))
           (make-filling-point context fillers)])])]))
