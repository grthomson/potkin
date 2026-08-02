#lang racket/base

(require racket/list
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "boundary.rkt"
         "signature.rkt"
         (for-syntax racket/base
                     racket/list
                     syntax/parse))

(provide rule-type?
         rule-type-tag
         rule-type-kind
         rule-type-arity
         rule-signature?
         rule-signature-types
         rule-signature-lookup
         rule-signature-admits?
         occurrence-matches-rule-signature?
         define-rule-signature
         define-occurrence
         define-calculus)

;; Rule types are fixed decorations, not inference schemata.  Concrete
;; occurrences still carry every fully instantiated boundary and datum.
(struct rule-type (tag kind arity)
  #:constructor-name make-rule-type/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (rule-type? right)
          (recur (rule-type-tag left) (rule-type-tag right))
          (recur (rule-type-kind left) (rule-type-kind right))
          (recur (rule-type-arity left) (rule-type-arity right))))
   (lambda (value recur)
     (recur (list (rule-type-tag value)
                  (rule-type-kind value)
                  (rule-type-arity value))))
   (lambda (value recur)
     (recur (list (rule-type-arity value)
                  (rule-type-kind value)
                  (rule-type-tag value))))))

(struct rule-signature (table)
  #:constructor-name make-rule-signature/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (rule-signature? right)
          (recur (rule-signature-table left)
                 (rule-signature-table right))))
   (lambda (value recur) (recur (rule-signature-table value)))
   (lambda (value recur) (recur (rule-signature-table value)))))

(define admitted-rule-kinds '(material logical structural))

(define (make-rule-type tag kind arity)
  (unless (and (symbol? tag) (symbol-interned? tag))
    (raise-argument-error 'define-rule-signature "interned-symbol?" tag))
  (unless (memq kind admitted-rule-kinds)
    (raise-arguments-error
     'define-rule-signature
     "rule kind must be material, logical, or structural"
     "kind" kind))
  (unless (exact-nonnegative-integer? arity)
    (raise-argument-error
     'define-rule-signature "exact-nonnegative-integer?" arity))
  (make-rule-type/internal tag kind arity))

(define (make-rule-signature types)
  (unless (and (list? types) (andmap rule-type? types))
    (raise-argument-error
     'define-rule-signature "(listof rule-type?)" types))
  (make-rule-signature/internal
   (for/fold ([table (hash)]) ([type (in-list types)])
     (define tag (rule-type-tag type))
     (when (hash-has-key? table tag)
       (raise-arguments-error
        'define-rule-signature
        "rule tags must be distinct"
        "duplicate tag" tag))
     (hash-set table tag type))))

(define (rule-signature-types signature)
  (unless (rule-signature? signature)
    (raise-argument-error
     'rule-signature-types "rule-signature?" signature))
  (sort (hash-values (rule-signature-table signature))
        string<?
        #:key (lambda (type) (symbol->string (rule-type-tag type)))))

(define (rule-signature-lookup signature tag)
  (unless (rule-signature? signature)
    (raise-argument-error
     'rule-signature-lookup "rule-signature?" signature))
  (unless (and (symbol? tag) (symbol-interned? tag))
    (raise-argument-error 'rule-signature-lookup "interned-symbol?" tag))
  (hash-ref (rule-signature-table signature) tag #f))

(define (rule-signature-admits? signature type)
  (unless (rule-signature? signature)
    (raise-argument-error
     'rule-signature-admits? "rule-signature?" signature))
  (and (rule-type? type)
       (equal? type
               (rule-signature-lookup signature (rule-type-tag type)))))

(define (occurrence-matches-rule-signature? signature occurrence)
  (unless (rule-signature? signature)
    (raise-argument-error
     'occurrence-matches-rule-signature? "rule-signature?" signature))
  (and
   (concrete-occurrence? occurrence)
   (let ([declared
          (rule-signature-lookup
           signature
           (concrete-occurrence-tag occurrence))])
     (and declared
          (eq? (rule-type-kind declared)
               (concrete-occurrence-kind occurrence))
          (= (rule-type-arity declared)
             (occurrence-arity occurrence))))))

(define (make-declared-occurrence who type id instance premises conclusion
                                  incidence)
  (unless (rule-type? type)
    (raise-argument-error who "rule-type?" type))
  (unless (list? premises)
    (raise-argument-error who "list? premises" premises))
  (unless (= (length premises) (rule-type-arity type))
    (raise-arguments-error
     who
     "the occurrence must instantiate every declared premise slot"
     "rule type" (rule-type-tag type)
     "expected arity" (rule-type-arity type)
     "actual arity" (length premises)))
  (make-concrete-occurrence
   id
   premises
   conclusion
   #:kind (rule-type-kind type)
   #:tag (rule-type-tag type)
   #:instance instance
   #:incidence incidence))

(define (make-declared-calculus who language rules occurrences)
  (unless (formula-signature? language)
    (raise-argument-error who "formula-signature?" language))
  (unless (rule-signature? rules)
    (raise-argument-error who "rule-signature?" rules))
  (unless (and (list? occurrences) (andmap concrete-occurrence? occurrences))
    (raise-argument-error who "(listof concrete-occurrence?)" occurrences))
  (for ([occurrence (in-list occurrences)])
    (unless (occurrence-matches-rule-signature? rules occurrence)
      (raise-arguments-error
       who
       "concrete occurrence does not match a declared rule profile"
       "occurrence" occurrence
       "tag" (concrete-occurrence-tag occurrence)
       "kind" (concrete-occurrence-kind occurrence)
       "arity" (occurrence-arity occurrence)))
    (for ([premise (in-vector (concrete-occurrence-premises occurrence))]
          [slot (in-naturals 1)])
      (unless (hypersequent-in-signature? language premise)
        (raise-arguments-error
         who
         "occurrence premise contains a formula outside the language"
         "occurrence ID" (concrete-occurrence-id occurrence)
         "premise slot" slot
         "premise" premise)))
    (unless (hypersequent-in-signature?
             language
             (concrete-occurrence-conclusion occurrence))
      (raise-arguments-error
       who
       "occurrence conclusion contains a formula outside the language"
       "occurrence ID" (concrete-occurrence-id occurrence)
       "conclusion" (concrete-occurrence-conclusion occurrence))))
  (make-equipped-calculus occurrences))

(begin-for-syntax
  (define-syntax-class rule-declaration
    (pattern [name:id
              #:kind kind:id
              #:arity arity]
      #:fail-unless
      (memq (syntax-e #'kind) '(material logical structural))
      "rule kind must be material, logical, or structural"
      #:fail-unless
      (exact-nonnegative-integer? (syntax-e #'arity))
      "rule arity must be a literal exact nonnegative integer"))

  (define (duplicate-name identifiers)
    (check-duplicates (map syntax-e identifiers) eq?)))

(define-syntax (define-rule-signature stx)
  (syntax-parse stx
    [(_ signature-name:id declaration:rule-declaration ...)
     (define names (syntax->list #'(declaration.name ...)))
     (define duplicate (duplicate-name names))
     (when duplicate
       (raise-syntax-error
        #f "duplicate rule declaration" stx
        (for/first ([name (in-list names)]
                    #:when (eq? (syntax-e name) duplicate))
          name)))
     (define type-definitions
       (for/list ([name (in-list names)]
                  [kind (in-list (syntax->list #'(declaration.kind ...)))]
                  [arity (in-list (syntax->list #'(declaration.arity ...)))])
         #`(define #,name
             (make-rule-type '#,(syntax-e name) '#,(syntax-e kind) #,arity))))
     #`(begin
         #,@type-definitions
         (define signature-name
           (make-rule-signature (list #,@names))))]))

(define-syntax (define-occurrence stx)
  (syntax-parse stx
    [(_ binding-name:id
        #:type type:expr
        (~optional (~seq #:id id:expr))
        #:instance instance:expr
        #:premises [premise:expr ...]
        #:conclusion conclusion:expr
        (~optional (~seq #:incidence incidence:expr)))
     (define id-expression
       (if (attribute id)
           #'id
           #`'#,(syntax-e #'binding-name)))
     (define incidence-expression
       (if (attribute incidence) #'incidence #''()))
     #`(define binding-name
         (make-declared-occurrence
          '#,(syntax-e #'binding-name)
          type
          #,id-expression
          instance
          (list premise ...)
          conclusion
          #,incidence-expression))]))

(define-syntax (define-calculus stx)
  (syntax-parse stx
    [(_ binding-name:id
        #:language language:expr
        #:rules rules:expr
        #:occurrences [occurrence:expr ...])
     #`(define binding-name
         (make-declared-calculus
          '#,(syntax-e #'binding-name)
          language
          rules
          (list occurrence ...)))]))
