#lang racket/base

(require racket/list
         racket/match
         "address.rkt"
         "boundary.rkt"
         "calculus.rkt"
         "check.rkt"
         "syntax.rkt")

(provide complete-proof?
         proof-context?
         identity-context
         corolla
         puncture-addresses
         puncture-requirement
         telescope-entry?
         telescope-entry-address
         telescope-entry-requirement
         premise-telescope
         term-admitted-by?
         context-insert
         context-compose
         complete-fill
         context-error?
         context-error-code
         context-error-message
         context-error-address
         context-error-expected
         context-error-actual
         context-error-details)

(struct telescope-entry (address requirement)
  #:constructor-name make-telescope-entry/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (telescope-entry? right)
          (recur (telescope-entry-address left)
                 (telescope-entry-address right))
          (recur (telescope-entry-requirement left)
                 (telescope-entry-requirement right))))
   (lambda (value recur)
     (recur (list (telescope-entry-address value)
                  (telescope-entry-requirement value))))
   (lambda (value recur)
     (recur (list (telescope-entry-requirement value)
                  (telescope-entry-address value))))))

(struct context-error (code message address expected actual details)
  #:transparent)

(define (make-context-error code message
                            #:address [address #f]
                            #:expected [expected #f]
                            #:actual [actual #f]
                            #:details [details (hash)])
  (context-error code message address expected actual details))

(define (complete-proof? term)
  (and (checked-node? term) (derivation-complete? term)))

(define (proof-context? term)
  (and (checked-term? term) (not (derivation-complete? term))))

(define (identity-context calculus boundary)
  (unless (equipped-calculus? calculus)
    (raise-argument-error 'identity-context "equipped-calculus?" calculus))
  (unless (hypersequent? boundary)
    (raise-argument-error 'identity-context "hypersequent?" boundary))
  (validate-candidate calculus raw-hole #:expected boundary))

(define (corolla calculus occurrence-or-id)
  (unless (equipped-calculus? calculus)
    (raise-argument-error 'corolla "equipped-calculus?" calculus))
  (define occurrence
    (cond
      [(symbol? occurrence-or-id)
       (calculus-lookup calculus occurrence-or-id)]
      [(and (concrete-occurrence? occurrence-or-id)
            (calculus-admits? calculus occurrence-or-id))
       occurrence-or-id]
      [else #f]))
  (define candidate-or-error
    (if occurrence
        (apply raw-app
               (concrete-occurrence-id occurrence)
               (make-list (occurrence-arity occurrence) raw-hole))
        (make-context-error
         'unadmitted-occurrence
         "a corolla must use an exact occurrence admitted by the calculus"
         #:actual occurrence-or-id)))
  (if (context-error? candidate-or-error)
      candidate-or-error
      (validate-candidate calculus candidate-or-error)))

(define (puncture-addresses term)
  (unless (checked-term? term)
    (raise-argument-error 'puncture-addresses "checked-term?" term))
  (define (walk current prefix)
    (cond
      [(checked-hole? current) (list prefix)]
      [else
       (append-map
        (lambda (slot+child)
          (walk (cdr slot+child)
                (append prefix (list (car slot+child)))))
        (for/list ([child (in-list (checked-node-children current))]
                   [slot (in-naturals 1)])
          (cons slot child)))]))
  (sort (walk term root-address) address<?))

(define (puncture-requirement term address)
  (unless (checked-term? term)
    (raise-argument-error 'puncture-requirement "checked-term?" term))
  (unless (address? address)
    (raise-argument-error 'puncture-requirement "address?" address))
  (define selected (checked-term-at-address term address))
  (cond
    [(not (checked-hole? selected)) #f]
    [(null? address) (checked-hole-boundary selected)]
    [else
     (define parent-address (drop-right address 1))
     (define slot (last address))
     (define parent (vertex-at-address term parent-address))
     (and parent
          (<= slot (length (checked-node-children parent)))
          ;; The stored hole colour was created by the checker; returning the
          ;; retained occurrence's premise makes the inference explicit.
          (occurrence-premise (checked-node-occurrence parent) slot))]))

(define (premise-telescope term)
  (for/list ([address (in-list (puncture-addresses term))])
    (make-telescope-entry/internal
     address
     (puncture-requirement term address))))

(define (term-admitted-by? calculus term)
  (and (equipped-calculus? calculus)
       (checked-term? term)
       (cond
         [(checked-hole? term) #t]
         [else
          (define occurrence (checked-node-occurrence term))
          (and (equal? occurrence
                       (calculus-lookup
                        calculus
                        (concrete-occurrence-id occurrence)))
               (andmap (lambda (child) (term-admitted-by? calculus child))
                       (checked-node-children term)))])))

(define (raw-replace-at candidate address replacement)
  (cond
    [(null? address) replacement]
    [else
     (match candidate
       [(list 'app occurrence-id children ...)
        (define selected-slot (car address))
        (list*
         'app
         occurrence-id
         (for/list ([child (in-list children)]
                    [slot (in-naturals 1)])
           (if (= slot selected-slot)
               (raw-replace-at child (cdr address) replacement)
               child)))]
       [_ candidate])]))

(define (context-insert context address replacement)
  (unless (checked-term? context)
    (raise-argument-error 'context-insert "checked-term?" context))
  (unless (address? address)
    (raise-argument-error 'context-insert "address?" address))
  (unless (checked-term? replacement)
    (raise-argument-error 'context-insert "checked-term?" replacement))
  (define selected (checked-term-at-address context address))
  (cond
    [(not selected)
     (make-context-error
      'no-such-address
      "the address does not occur in this context"
      #:address address)]
    [(not (checked-hole? selected))
     (make-context-error
      'not-a-puncture
      "context insertion targets a vacant premise, not a vertex"
      #:address address
      #:actual selected)]
    [else
     (define expected (puncture-requirement context address))
     (define actual (derivation-root-boundary replacement))
     (define calculus (checked-term-calculus context))
     (cond
       [(not (equal? expected actual))
        (make-context-error
         'wrong-boundary
         "the replacement root does not match the puncture requirement"
         #:address address
         #:expected expected
         #:actual actual)]
       [(not (term-admitted-by? calculus replacement))
        (make-context-error
         'unadmitted-replacement
         "every replacement occurrence must belong to the context's registry"
         #:address address
         #:actual replacement)]
       [else
        (define candidate
          (raw-replace-at (checked-term->raw context)
                          address
                          (checked-term->raw replacement)))
        (define result
          (validate-candidate
           calculus
           candidate
           #:expected (derivation-root-boundary context)))
        (if (validation-error? result)
            (make-context-error
             'invalid-composition
             "rechecking the composed candidate failed"
             #:address address
             #:details (hash 'validation-error result))
            result)])]))

(define (context-compose context replacements)
  (unless (checked-term? context)
    (raise-argument-error 'context-compose "checked-term?" context))
  (unless (and (list? replacements) (andmap checked-term? replacements))
    (raise-argument-error
     'context-compose "(listof checked-term?)" replacements))
  (define telescope (premise-telescope context))
  (cond
    [(not (= (length telescope) (length replacements)))
     (make-context-error
      'wrong-filler-count
      "composition needs one replacement for each telescope entry"
      #:expected (length telescope)
      #:actual (length replacements))]
    [else
     (let loop ([current context]
                [entries telescope]
                [remaining replacements])
       (cond
         [(null? entries) current]
         [else
          (define result
            (context-insert
             current
             (telescope-entry-address (car entries))
             (car remaining)))
          (if (context-error? result)
              result
              (loop result (cdr entries) (cdr remaining)))]))]))

(define (complete-fill context fillers)
  (unless (checked-term? context)
    (raise-argument-error 'complete-fill "checked-term?" context))
  (unless (and (list? fillers) (andmap checked-term? fillers))
    (raise-argument-error 'complete-fill "(listof checked-term?)" fillers))
  (define expected-count (length (premise-telescope context)))
  (cond
    [(not (= expected-count (length fillers)))
     (make-context-error
      'wrong-filler-count
      "complete filling needs one proof for each telescope entry"
      #:expected expected-count
      #:actual (length fillers))]
    [(findf (lambda (filler) (not (complete-proof? filler))) fillers)
     =>
     (lambda (incomplete)
     (make-context-error
      'incomplete-filler
      "complete filling accepts only complete rule-rooted proofs"
      #:actual incomplete))]
    [else
     (define result (context-compose context fillers))
     (cond
       [(context-error? result) result]
       [(complete-proof? result) result]
       [else
        (make-context-error
         'incomplete-result
         "complete filling left a puncture unresolved"
         #:actual result)])]))
