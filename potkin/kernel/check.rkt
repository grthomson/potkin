#lang racket/base

(require racket/list
         racket/match
         "boundary.rkt"
         "calculus.rkt"
         "syntax.rkt")

(provide checked-node?
         checked-node-calculus
         checked-node-occurrence
         checked-node-children
         checked-hole?
         checked-hole-calculus
         checked-hole-boundary
         checked-term?
         checked-term-calculus
         checked-term-has-exact-calculus?
         validate-candidate
         validation-error?
         validation-error-code
         validation-error-message
         validation-error-address
         validation-error-expected
         validation-error-actual
         validation-error-details
         validation-success?
         checked-term->raw
         derivation-root-boundary
         derivation-complete?
         derivation-vertex-count)

(struct checked-node (calculus occurrence children)
  #:constructor-name make-checked-node/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (checked-node? right)
          (recur (checked-node-occurrence left)
                 (checked-node-occurrence right))
          (recur (checked-node-children left)
                 (checked-node-children right))))
   (lambda (value recur)
     (recur (list (checked-node-occurrence value)
                  (checked-node-children value))))
   (lambda (value recur)
     (recur (list (checked-node-children value)
                  (checked-node-occurrence value))))))

(struct checked-hole (calculus boundary)
  #:constructor-name make-checked-hole/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (checked-hole? right)
          (recur (checked-hole-boundary left)
                 (checked-hole-boundary right))))
   (lambda (value recur)
     (recur (checked-hole-boundary value)))
   (lambda (value recur)
     (recur (checked-hole-boundary value)))))

(struct validation-error (code message address expected actual details)
  #:transparent)

(define (checked-term? value)
  (or (checked-node? value) (checked-hole? value)))

(define (checked-term-calculus term)
  (cond
    [(checked-node? term) (checked-node-calculus term)]
    [(checked-hole? term) (checked-hole-calculus term)]
    [else (raise-argument-error 'checked-term-calculus "checked-term?" term)]))

;; Presentation equality deliberately omits registry provenance. Operational
;; carrier checks use this separate recursive predicate to require one exact
;; immutable calculus snapshot throughout a checked term.
(define (checked-term-has-exact-calculus? term calculus)
  (and (checked-term? term)
       (equipped-calculus? calculus)
       (eq? (checked-term-calculus term) calculus)
       (or (checked-hole? term)
           (andmap (lambda (child)
                     (checked-term-has-exact-calculus? child calculus))
                   (checked-node-children term)))))

(define (validation-success? value)
  (checked-term? value))

(define (checked-term->raw term)
  (cond
    [(checked-hole? term) raw-hole]
    [(checked-node? term)
     (apply raw-app
            (concrete-occurrence-id (checked-node-occurrence term))
            (map checked-term->raw (checked-node-children term)))]
    [else (raise-argument-error 'checked-term->raw "checked-term?" term)]))

(define (make-error code message address
                    #:expected [expected #f]
                    #:actual [actual #f]
                    #:details [details (hash)])
  (validation-error code message address expected actual details))

(define (validate-candidate calculus candidate #:expected [expected #f])
  (unless (equipped-calculus? calculus)
    (raise-argument-error 'validate-candidate "equipped-calculus?" calculus))
  (unless (or (not expected) (hypersequent? expected))
    (raise-argument-error
     'validate-candidate "(or/c #f hypersequent?)" expected))

  (define (validate term required address)
    (cond
      [(raw-hole? term)
       (if required
           (make-checked-hole/internal calculus required)
           (make-error
            'missing-boundary
            "a nodeless puncture needs an externally supplied boundary"
            address))]
      [else
       (match term
         [(list 'app id children ...)
          (cond
            [(not (symbol? id))
             (make-error
              'malformed-candidate
              "an application occurrence key must be a symbol"
              address
              #:actual id)]
            [else
             (define occurrence (calculus-lookup calculus id))
             (cond
               [(not occurrence)
                (make-error
                 'unknown-occurrence
                 "the occurrence key is not admitted by this calculus"
                 address
                 #:actual id)]
               [(and required
                     (not (equal? required
                                  (concrete-occurrence-conclusion occurrence))))
                (make-error
                 'wrong-boundary
                 "the child conclusion does not match its whole required hypersequent"
                 address
                 #:expected required
                 #:actual (concrete-occurrence-conclusion occurrence)
                 #:details (hash 'occurrence id))]
               [(not (= (length children) (occurrence-arity occurrence)))
                (make-error
                 'wrong-arity
                 "the application does not supply exactly the registered premise slots"
                 address
                 #:expected (occurrence-arity occurrence)
                 #:actual (length children)
                 #:details (hash 'occurrence id))]
               [else
                (define checked-children
                  (for/list ([child (in-list children)]
                             [slot (in-naturals 1)])
                    (validate child
                              (occurrence-premise occurrence slot)
                              (append address (list slot)))))
                (define child-error
                  (findf validation-error? checked-children))
                (if child-error
                    child-error
                    (make-checked-node/internal
                     calculus occurrence checked-children))])])]
         [_
          (make-error
           'malformed-candidate
           "expected (puncture) or (app occurrence-key child ...)"
           address
           #:actual term)])]))

  (validate candidate expected '()))

(define (derivation-root-boundary term)
  (cond
    [(checked-node? term)
     (concrete-occurrence-conclusion (checked-node-occurrence term))]
    [(checked-hole? term) (checked-hole-boundary term)]
    [else (raise-argument-error 'derivation-root-boundary "checked-term?" term)]))

(define (derivation-complete? term)
  (cond
    [(checked-hole? term) #f]
    [(checked-node? term)
     (andmap derivation-complete? (checked-node-children term))]
    [else (raise-argument-error 'derivation-complete? "checked-term?" term)]))

(define (derivation-vertex-count term)
  (cond
    [(checked-hole? term) 0]
    [(checked-node? term)
     (add1
      (for/sum ([child (in-list (checked-node-children term))])
        (derivation-vertex-count child)))]
    [else (raise-argument-error 'derivation-vertex-count "checked-term?" term)]))
