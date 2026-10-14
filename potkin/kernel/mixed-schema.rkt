#lang racket/base

;; Frozen unit-free MILL equipment on POTKIN's native checked carrier.
;; This admits precisely six rule-constructor schemas, NOT six extra
;; conversion equations. The four conversions are separately certified by
;; their analysis client. Every schema instance is admitted from inception;
;; requesting one only interns its deterministic exact occurrence object.
;; Premises, selected/discharged indices and every canonical exchange are
;; recorded. Indices below are 1-based positions in the native boundary's
;; canonical formula-context->list, so equal formulas have distinct indices.

(require racket/list
         racket/match
         racket/string
         racket/port
         racket/generator
         "boundary.rkt"
         "component-incidence.rkt"
         "calculus.rkt"
         "check.rkt")

(provide mixed-formula? mixed-boundary? mixed-boundary-left mixed-boundary-right
         make-mixed-schema-calculus mixed-schema-calculus?
         mixed-schema-sector
         mixed-schema-material-occurrences
         mixed-rule-occurrence mixed-apply
         in-mixed-rule-orders mixed-rule-orders
         mixed-occurrence-data mixed-occurrence-family mixed-occurrence-indices
         mixed-occurrence-order mixed-occurrence-routing)

(define schema-descriptor
  '(potkin/mixed-mill-v1 (tensor implies)
                         (cut+ cut- tensorR tensorL impliesR impliesL)))
(define id-prefix "potkin/mixed-mill-v1:")
(define mixed-snapshots (make-weak-hasheq))
(define snapshot-sectors (make-weak-hasheq))

(define (mixed-formula? formula)
  (or (and (symbol? formula) (symbol-interned? formula))
      (match formula
        [(list (or 'tensor 'implies) a b)
         (and (mixed-formula? a) (mixed-formula? b))]
        [_ #f])))

(define (mixed-boundary? boundary)
  (and (hypersequent? boundary)
       (= (hypersequent-size boundary) 1)
       (let ([sequent (car (hypersequent-sequents boundary))])
         (and (= (formula-context-size (sequent-right sequent)) 1)
              (andmap mixed-formula? (formula-context->list (sequent-left sequent)))
              (mixed-formula? (car (formula-context->list (sequent-right sequent))))))))

(define (check-boundary who boundary)
  (unless (mixed-boundary? boundary)
    (raise-argument-error who "unit-free singleton single-succedent native boundary" boundary)))

(define (mixed-boundary-left boundary)
  (check-boundary 'mixed-boundary-left boundary)
  (formula-context->list (sequent-left (car (hypersequent-sequents boundary)))))

(define (mixed-boundary-right boundary)
  (check-boundary 'mixed-boundary-right boundary)
  (car (formula-context->list (sequent-right (car (hypersequent-sequents boundary))))))

(define (boundary->datum boundary)
  (list (mixed-boundary-left boundary) (mixed-boundary-right boundary)))

(define (datum->boundary datum)
  (match datum
    [(list (? list? left) right)
     (unless (and (andmap mixed-formula? left) (mixed-formula? right)
                  (equal? left (sort left symbolic-datum<?)))
       (raise-argument-error 'mixed-schema-resolver "canonical MILL boundary datum" datum))
     (singleton-hypersequent left (list right))]
    [_ (raise-argument-error 'mixed-schema-resolver "MILL boundary datum" datum)]))

(define (mixed-schema-calculus? calculus)
  ;; A matching public tag/descriptor is not proof that this controlled
  ;; constructor supplied the resolver. Membership is exact snapshot identity.
  (and (equipped-calculus? calculus) (hash-has-key? mixed-snapshots calculus)))

(define (check-snapshot who calculus)
  (unless (mixed-schema-calculus? calculus)
    (raise-argument-error who "exact frozen mixed-schema calculus" calculus)))

(define (mixed-schema-material-occurrences calculus)
  (check-snapshot 'mixed-schema-material-occurrences calculus)
  (hash-ref mixed-snapshots calculus))

(define (mixed-schema-sector calculus)
  (check-snapshot 'mixed-schema-sector calculus)
  (hash-ref snapshot-sectors calculus))

(define (sector-admits-family? calculus family)
  (or (eq? (mixed-schema-sector calculus) 'mixed)
      (memq family '(cut+ tensorR tensorL))))

(define (rule-error family message . data)
  (apply raise-arguments-error 'mixed-rule-occurrence message "family" family data))

(define (selected left index family)
  (unless (and (exact-positive-integer? index) (<= index (length left)))
    (rule-error family "selected index is not an existing antecedent occurrence" "index" index))
  (list-ref left (sub1 index)))

(define (check-indices family indices count)
  (unless (and (list? indices) (= (length indices) count)
               (andmap exact-positive-integer? indices)
               (not (check-duplicates indices)))
    (rule-error family "wrong number of distinct selected/discharged indices" "indices" indices)))

;; Return the fixed output formula and all antecedent tokens, before their
;; recorded exchange. Tokens (slot index) name physical premise occurrences;
;; `principal` is the new packed antecedent, not a proof vertex or port.
(define (rule-shape family premises indices)
  (unless (memq family '(cut+ cut- tensorR tensorL impliesR impliesL))
    (rule-error family "constructor is outside the frozen six-rule equipment"))
  (define arity (if (memq family '(tensorL impliesR)) 1 2))
  (unless (and (list? premises) (= (length premises) arity)
               (andmap mixed-boundary? premises))
    (rule-error family "wrong complete ordered MILL premise boundaries" "premises" premises))
  (define lefts (map mixed-boundary-left premises))
  (define rights (map mixed-boundary-right premises))
  (define (tokens slot removed)
    (for/list ([f (in-list (list-ref lefts (sub1 slot)))] [i (in-naturals 1)]
               #:unless (memv i removed))
      (cons (list slot i) f)))
  (case family
    [(cut+ cut-)
     (check-indices family indices 1)
     (define consumer (if (eq? family 'cut+) 2 1))
     (define producer (if (eq? family 'cut+) 1 2))
     (define formula (list-ref rights (sub1 producer)))
     (unless (equal? formula (selected (list-ref lefts (sub1 consumer)) (car indices) family))
       (rule-error family "producer succedent differs from the selected consumer occurrence"))
     (values (append (tokens 1 (if (= consumer 1) indices '()))
                     (tokens 2 (if (= consumer 2) indices '())))
             (list-ref rights (sub1 consumer)) formula #f #f)]
    [(tensorR)
     (check-indices family indices 0)
     (define formula (list 'tensor (first rights) (second rights)))
     (values (append (tokens 1 '()) (tokens 2 '())) formula formula
             (first rights) (second rights))]
    [(tensorL)
     (check-indices family indices 2)
     (define a (selected (first lefts) (first indices) family))
     (define b (selected (first lefts) (second indices) family))
     (define formula (list 'tensor a b))
     (values (append (tokens 1 indices) (list (cons 'principal formula)))
             (first rights) formula a b)]
    [(impliesR)
     (check-indices family indices 1)
     (define a (selected (first lefts) (first indices) family))
     (define b (first rights))
     (define formula (list 'implies a b))
     (values (tokens 1 indices) formula formula a b)]
    [(impliesL)
     (check-indices family indices 1)
     (define a (first rights))
     (define b (selected (second lefts) (car indices) family))
     (define formula (list 'implies a b))
     (values (append (tokens 1 '()) (tokens 2 indices) (list (cons 'principal formula)))
             (second rights) formula a b)]))

(define (normalize-order family entries order)
  (define sorted (sort entries (lambda (a b) (symbolic-datum<? (cdr a) (cdr b)))))
  (define default (map car sorted))
  (define actual (if order order default))
  (unless (and (list? actual) (= (length actual) (length entries))
               (not (check-duplicates actual equal?))
               (andmap (lambda (token) (assoc token entries equal?)) actual)
               (equal? (map (lambda (token) (cdr (assoc token entries equal?))) actual)
                       (map cdr sorted)))
    (rule-error family "output order must be a canonical-formula-order permutation of exact antecedent tokens"
                "order" actual "tokens" (map car entries)))
  actual)

;; Yield rather than eagerly creating factorially many exchanges. Production
;; callers charge each yielded candidate against their work/deadline limits.
(define (in-mixed-rule-orders calculus family premises #:indices [indices '()])
  (check-snapshot 'in-mixed-rule-orders calculus)
  (unless (sector-admits-family? calculus family)
    (rule-error family "constructor is not admitted by this exact tensor sector"))
  (define-values (entries _right _formula _a _b) (rule-shape family premises indices))
  (define formulas (sort (map cdr entries) symbolic-datum<?))
  (in-generator
   (define (walk remaining expected reversed)
     (if (null? expected)
         (yield (reverse reversed))
         (for ([entry (in-list remaining)] #:when (equal? (cdr entry) (car expected)))
           (walk (remove entry remaining equal?) (cdr expected) (cons (car entry) reversed)))))
   (walk entries formulas '())))

(define (mixed-rule-orders calculus family premises #:indices [indices '()])
  (for/list ([order (in-mixed-rule-orders calculus family premises #:indices indices)]) order))

(define (rule-instance family premises indices order)
  (define-values (entries right formula a b) (rule-shape family premises indices))
  (define actual-order (normalize-order family entries order))
  (define output-left (map (lambda (token) (cdr (assoc token entries equal?))) actual-order))
  (define conclusion (singleton-hypersequent output-left (list right)))
  (define (output-index token)
    (define index (index-of actual-order token equal?))
    (and index (add1 index)))
  (define principal-index (output-index 'principal))
  (define (antecedent-target slot index)
    (define out (output-index (list slot index)))
    (cond
      [out (list 'left out '())]
      [(memq family '(cut+ cut-)) (list 'cut 0 '())]
      [(eq? family 'tensorL)
       (list 'left principal-index (list (if (= index (first indices)) 'left 'right)))]
      [(eq? family 'impliesR) (list 'right 1 '(domain))]
      [(eq? family 'impliesL) (list 'left principal-index '(codomain))]
      [else (rule-error family "unrouted antecedent occurrence" "slot" slot "index" index)]))
  ;; Route records: (premise-slot input-side input-index output-side
  ;;                output-index connective-path). A cut endpoint is recorded
  ;; explicitly as `cut 0 ()`, not silently forgotten. Paths retain logical
  ;; packing and discharge; component incidence alone cannot express them.
  (define antecedent-routes
    (append-map
     (lambda (slot)
       (for/list ([f (in-list (mixed-boundary-left (list-ref premises (sub1 slot))))]
                  [index (in-naturals 1)])
         (append (list slot 'left index) (antecedent-target slot index))))
     (range 1 (add1 (length premises)))))
  (define succedent-routes
    (case family
      [(cut+) '((1 right 1 cut 0 ()) (2 right 1 right 1 ()))]
      [(cut-) '((1 right 1 right 1 ()) (2 right 1 cut 0 ()))]
      [(tensorR) '((1 right 1 right 1 (left)) (2 right 1 right 1 (right)))]
      [(tensorL) '((1 right 1 right 1 ()))]
      [(impliesR) '((1 right 1 right 1 (codomain)))]
      [(impliesL) (list (list 1 'right 1 'left principal-index '(domain))
                        '(2 right 1 right 1 ()))]))
  (values conclusion actual-order
          (hash 'schema 'potkin/mixed-mill-v1 'family family
                'premises (map boundary->datum premises)
                'indices indices 'order actual-order
                'routing (append antecedent-routes succedent-routes)
                'formula formula 'A a 'B b
                'principal-output-index principal-index)))

(define (instance-id family premises indices order)
  (string->symbol
   (string-append id-prefix
                  (format "~s" (list family (map boundary->datum premises) indices order)))))

(define (resolve-schema id)
  (and (symbol? id) (symbol-interned? id)
       (string-prefix? (symbol->string id) id-prefix)
       (with-handlers ([exn:fail? (lambda (_) #f)])
         (parameterize ([read-accept-reader #f] [read-accept-lang #f]
                        [read-accept-compiled #f] [read-accept-graph #f])
           (define input (open-input-string (substring (symbol->string id) (string-length id-prefix))))
           (define data (read input))
           (unless (eof-object? (read input)) (error 'mixed-schema-resolver "trailing instance datum"))
           (match data
             [(list family (? list? premise-data) indices order)
              (define premises (map datum->boundary premise-data))
              (define-values (conclusion canonical-order instance)
                (rule-instance family premises indices order))
              (and (eq? id (instance-id family premises indices canonical-order))
                   (make-concrete-occurrence
                    id premises conclusion #:kind 'logical #:tag family #:instance instance
                    #:incidence
                    (make-component-incidence
                     premises conclusion
                     (for/list ([slot (in-range 1 (add1 (length premises)))])
                       (make-component-edge slot 1 1)))))]
             [_ #f])))))

(define (make-mixed-schema-calculus materials #:sector [sector 'mixed])
  (unless (memq sector '(mixed tensor))
    (raise-argument-error 'make-mixed-schema-calculus "'mixed or 'tensor" sector))
  (unless (and (list? materials)
               (andmap (lambda (occurrence)
                         (and (concrete-occurrence? occurrence)
                              (eq? 'material (concrete-occurrence-kind occurrence))
                              (zero? (occurrence-arity occurrence))
                              (mixed-boundary? (concrete-occurrence-conclusion occurrence))
                              (not (string-prefix? (symbol->string (concrete-occurrence-id occurrence)) id-prefix))))
                       materials))
    (raise-argument-error 'make-mixed-schema-calculus
                          "exact nullary material stock with unit-free MILL boundaries and nonreserved IDs"
                          materials))
  ;; This is an admission restriction on the SAME native equipped calculus,
  ;; not a converted tree carrier. Shared instance IDs retain their routes;
  ;; a proof crossing snapshots must still be rechecked explicitly.
  (define descriptor
    (if (eq? sector 'mixed) schema-descriptor
        '(potkin/tensor-sector-v1 (tensor implies) (cut+ tensorR tensorL))))
  (define (resolver id)
    (define occurrence (resolve-schema id))
    (and occurrence
         (or (eq? sector 'mixed)
             (memq (hash-ref (concrete-occurrence-instance occurrence) 'family)
                   '(cut+ tensorR tensorL)))
         occurrence))
  (define calculus (make-schema-equipped-calculus materials descriptor resolver))
  (hash-set! mixed-snapshots calculus (for/list ([material (in-list materials)]) material))
  (hash-set! snapshot-sectors calculus sector)
  calculus)

(define (mixed-rule-occurrence calculus family premises #:indices [indices '()] #:order [order #f])
  (check-snapshot 'mixed-rule-occurrence calculus)
  (unless (sector-admits-family? calculus family)
    (rule-error family "constructor is not admitted by this exact tensor sector"))
  (define-values (_conclusion actual-order _instance) (rule-instance family premises indices order))
  (define occurrence (calculus-lookup calculus (instance-id family premises indices actual-order)))
  (unless occurrence
    (error 'mixed-rule-occurrence "a validated frozen-schema instance was not resolved"))
  occurrence)

(define (mixed-apply calculus family children #:indices [indices '()] #:order [order #f])
  (check-snapshot 'mixed-apply calculus)
  (unless (and (list? children) (andmap checked-term? children))
    (raise-argument-error 'mixed-apply "ordered native checked children" children))
  (define occurrence
    (mixed-rule-occurrence calculus family (map derivation-root-boundary children)
                           #:indices indices #:order order))
  (assemble-checked-application calculus occurrence children))

(define (mixed-occurrence-data calculus occurrence)
  (check-snapshot 'mixed-occurrence-data calculus)
  (unless (and (concrete-occurrence? occurrence)
               (eq? occurrence (calculus-lookup calculus (concrete-occurrence-id occurrence))))
    (raise-argument-error 'mixed-occurrence-data "exact occurrence in this snapshot" occurrence))
  (cond
    [(memq occurrence (mixed-schema-material-occurrences calculus))
     (hash 'schema 'potkin/mixed-mill-v1 'family 'material 'indices '() 'order '() 'routing '())]
    [else
     ;; Its exact object was returned by the controlled full-shape resolver;
     ;; do not recognize a rule by its public name, kind, tag or instance tag.
     (concrete-occurrence-instance occurrence)]))

(define (mixed-occurrence-family calculus occurrence)
  (hash-ref (mixed-occurrence-data calculus occurrence) 'family))
(define (mixed-occurrence-indices calculus occurrence)
  (hash-ref (mixed-occurrence-data calculus occurrence) 'indices))
(define (mixed-occurrence-order calculus occurrence)
  (hash-ref (mixed-occurrence-data calculus occurrence) 'order))
(define (mixed-occurrence-routing calculus occurrence)
  (hash-ref (mixed-occurrence-data calculus occurrence) 'routing))
