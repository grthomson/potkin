#lang racket/base

(require racket/list
         "../kernel/boundary.rkt"
         (for-syntax racket/base
                     racket/list
                     racket/syntax
                     syntax/parse))

(provide formula-signature?
         formula-signature-atoms
         formula-signature-operators
         formula-signature-operator-arity
         formula-in-signature?
         define-formula-signature)

;; A language signature validates ordinary formula data.  It is deliberately
;; not attached to checked terms and is not a calculus-provenance token.
(struct formula-signature (atom-table operator-table)
  #:constructor-name make-formula-signature/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (formula-signature? right)
          (recur (formula-signature-atom-table left)
                 (formula-signature-atom-table right))
          (recur (formula-signature-operator-table left)
                 (formula-signature-operator-table right))))
   (lambda (value recur)
     (recur (list (formula-signature-atom-table value)
                  (formula-signature-operator-table value))))
   (lambda (value recur)
     (recur (list (formula-signature-operator-table value)
                  (formula-signature-atom-table value))))))

(define (interned-symbol? value)
  (and (symbol? value) (symbol-interned? value)))

(define (symbol<? left right)
  (string<? (symbol->string left) (symbol->string right)))

(define (make-formula-signature atoms operators)
  (unless (and (list? atoms) (andmap interned-symbol? atoms))
    (raise-argument-error
     'define-formula-signature "(listof interned-symbol?)" atoms))
  (unless (and (list? operators)
               (andmap (lambda (entry)
                         (and (pair? entry)
                              (interned-symbol? (car entry))
                              (exact-nonnegative-integer? (cdr entry))))
                       operators))
    (raise-argument-error
     'define-formula-signature
     "(listof (cons/c interned-symbol? exact-nonnegative-integer?))"
     operators))
  (define duplicate-atom (check-duplicates atoms eq?))
  (when duplicate-atom
    (raise-arguments-error
     'define-formula-signature
     "atom names must be distinct"
     "duplicate atom" duplicate-atom))
  (define operator-names (map car operators))
  (define duplicate-operator (check-duplicates operator-names eq?))
  (when duplicate-operator
    (raise-arguments-error
     'define-formula-signature
     "operator names must be distinct"
     "duplicate operator" duplicate-operator))
  (define collision
    (for/first ([atom (in-list atoms)] #:when (memq atom operator-names))
      atom))
  (when collision
    (raise-arguments-error
     'define-formula-signature
     "an atom and an operator cannot have the same name"
     "collision" collision))
  (make-formula-signature/internal
   (for/hash ([atom (in-list atoms)]) (values atom #t))
   (for/hash ([entry (in-list operators)])
     (values (car entry) (cdr entry)))))

(define (formula-signature-atoms signature)
  (unless (formula-signature? signature)
    (raise-argument-error
     'formula-signature-atoms "formula-signature?" signature))
  (sort (hash-keys (formula-signature-atom-table signature)) symbol<?))

(define (formula-signature-operators signature)
  (unless (formula-signature? signature)
    (raise-argument-error
     'formula-signature-operators "formula-signature?" signature))
  (for/list ([name (in-list
                    (sort
                     (hash-keys (formula-signature-operator-table signature))
                     symbol<?))])
    (cons name (hash-ref (formula-signature-operator-table signature) name))))

(define (formula-signature-operator-arity signature operator)
  (unless (formula-signature? signature)
    (raise-argument-error
     'formula-signature-operator-arity "formula-signature?" signature))
  (unless (interned-symbol? operator)
    (raise-argument-error
     'formula-signature-operator-arity "interned-symbol?" operator))
  (hash-ref (formula-signature-operator-table signature) operator #f))

(define (formula-in-signature? signature formula)
  (unless (formula-signature? signature)
    (raise-argument-error
     'formula-in-signature? "formula-signature?" signature))
  (define atoms (formula-signature-atom-table signature))
  (define operators (formula-signature-operator-table signature))
  (define (walk value)
    (and
     (formula-datum? value)
     (cond
       [(symbol? value) (hash-has-key? atoms value)]
       [(and (pair? value)
             (list? value)
             (symbol? (car value)))
        (define arity (hash-ref operators (car value) #f))
        (and arity
             (= arity (length (cdr value)))
             (andmap walk (cdr value)))]
       [else #f])))
  (walk formula))

(define (make-signature-formula signature operator arguments)
  (unless (formula-signature? signature)
    (raise-argument-error
     operator "formula-signature?" signature))
  (define expected
    (hash-ref (formula-signature-operator-table signature) operator #f))
  (unless expected
    (raise-arguments-error
     operator
     "operator is not declared by the formula signature"
     "operator" operator))
  (unless (= expected (length arguments))
    (raise-arguments-error
     operator
     "wrong formula-operator arity"
     "expected" expected
     "actual" (length arguments)))
  (for ([argument (in-list arguments)] [position (in-naturals 1)])
    (unless (formula-in-signature? signature argument)
      (raise-arguments-error
       operator
       "formula argument is outside the declared signature"
       "position" position
       "argument" argument)))
  (cons operator arguments))

(begin-for-syntax
  (define-syntax-class operator-declaration
    (pattern [name:id arity]
      #:fail-unless
      (exact-nonnegative-integer? (syntax-e #'arity))
      "operator arity must be a literal exact nonnegative integer"))

  (define (duplicate-name identifiers)
    (check-duplicates (map syntax-e identifiers) eq?)))

(define-syntax (define-formula-signature stx)
  (syntax-parse stx
    [(_ signature-name:id
        #:atoms [atom-name:id ...]
        operator:operator-declaration ...)
     (define atoms (syntax->list #'(atom-name ...)))
     (define operators (syntax->list #'(operator.name ...)))
     (define duplicate-atom (duplicate-name atoms))
     (when duplicate-atom
       (raise-syntax-error
        #f "duplicate atom declaration" stx
        (for/first ([atom (in-list atoms)]
                    #:when (eq? (syntax-e atom) duplicate-atom))
          atom)))
     (define duplicate-operator (duplicate-name operators))
     (when duplicate-operator
       (raise-syntax-error
        #f "duplicate operator declaration" stx
        (for/first ([operator (in-list operators)]
                    #:when (eq? (syntax-e operator) duplicate-operator))
          operator)))
     (define collision
       (for/first ([atom (in-list atoms)]
                   #:when (member (syntax-e atom)
                                  (map syntax-e operators)
                                  eq?))
         atom))
     (when collision
       (raise-syntax-error
        #f "an atom and operator cannot share a name" stx collision))
     (define atom-definitions
       (for/list ([atom (in-list atoms)])
         #`(define #,atom '#,(syntax-e atom))))
     (define operator-definitions
       (for/list ([operator-name (in-list operators)]
                  [arity-stx (in-list
                              (syntax->list #'(operator.arity ...)))])
         (define argument-names
           (generate-temporaries
            (make-list (syntax-e arity-stx) #'formula-argument)))
         #`(define (#,operator-name #,@argument-names)
             (make-signature-formula
              signature-name
              '#,(syntax-e operator-name)
              (list #,@argument-names)))))
     #`(begin
         (define signature-name
           (make-formula-signature
            '(#,@(map syntax-e atoms))
            (list
             #,@(for/list ([operator-name (in-list operators)]
                           [arity-stx (in-list
                                       (syntax->list
                                        #'(operator.arity ...)))])
                  #`(cons '#,(syntax-e operator-name) #,arity-stx)))))
         #,@atom-definitions
         #,@operator-definitions)]))
