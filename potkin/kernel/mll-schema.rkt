#lang racket/base

;; A separately declared one-sided, unit-free MLL+binary-Mix equipment.
;; Its frozen resolver admits schemas, not a growing finite material stock.
(require racket/list racket/match racket/string
         "boundary.rkt" "calculus.rkt" "check.rkt" "component-incidence.rkt")
(provide mll-formula? mll-literal? mll-dual mll-rank
         mll-boundary mll-boundary? mll-boundary-formulas
         make-mll-schema-calculus mll-schema-calculus? mll-schema-sector
         mll-rule-occurrence mll-apply mll-id mll-expanded-id
         mll-occurrence-data mll-occurrence-family mll-occurrence-indices
         mll-occurrence-order mll-occurrence-routing)

(define prefix "potkin/mll-v1:")
(define snapshots (make-weak-hasheq))
(define (mll-literal? x)
  (or (and (symbol? x) (symbol-interned? x))
      (match x [(list 'neg (? symbol? a)) (symbol-interned? a)] [_ #f])))
(define (mll-formula? x)
  (or (mll-literal? x)
      (match x [(list (or 'tensor 'par) a b) (and (mll-formula? a) (mll-formula? b))]
        [_ #f])))
(define (mll-dual x)
  (match x
    [(? symbol?) (list 'neg x)] [(list 'neg a) a]
    [(list 'tensor a b) (list 'par (mll-dual a) (mll-dual b))]
    [(list 'par a b) (list 'tensor (mll-dual a) (mll-dual b))]
    [_ (raise-argument-error 'mll-dual "mll-formula?" x)]))
(define (mll-rank x)
  (unless (mll-formula? x) (raise-argument-error 'mll-rank "mll-formula?" x))
  (if (mll-literal? x) 0 (+ 1 (mll-rank (cadr x)) (mll-rank (caddr x)))))
(define (mll-boundary formulas)
  (unless (and (list? formulas) (andmap mll-formula? formulas))
    (raise-argument-error 'mll-boundary "list of MLL formulas" formulas))
  (singleton-hypersequent '() formulas))
(define (mll-boundary? b)
  (and (hypersequent? b) (= (hypersequent-size b) 1)
       (let ([s (car (hypersequent-sequents b))])
         (and (zero? (formula-context-size (sequent-left s)))
              (andmap mll-formula? (formula-context->list (sequent-right s)))))))
(define (mll-boundary-formulas b)
  (unless (mll-boundary? b) (raise-argument-error 'mll-boundary-formulas "one-sided MLL boundary" b))
  (formula-context->list (sequent-right (car (hypersequent-sequents b)))))
(define (mll-schema-calculus? k) (and (equipped-calculus? k) (hash-has-key? snapshots k)))
(define (mll-schema-sector k)
  (unless (mll-schema-calculus? k) (raise-argument-error 'mll-schema-sector "exact MLL snapshot" k))
  (hash-ref snapshots k))

;; Exact tokens name every physical premise occurrence; principal tokens
;; preserve the two ordered logical children. Canonical exchange never merges
;; equal formulas. Id's two ports are positive then negative, independently
;; of their canonical displayed order.
(define (shape family premises indices atom)
  (define arity (case family [(id) 0] [(par) 1] [(tensor mix cut) 2] [else -1]))
  (unless (and (list? premises) (= (length premises) arity) (andmap mll-boundary? premises))
    (error 'mll-rule-occurrence "invalid family or complete premise arity: ~s" family))
  (define fs (map mll-boundary-formulas premises))
  (define (at slot index)
    (unless (and (exact-positive-integer? index) (<= index (length (list-ref fs (sub1 slot)))))
      (error 'mll-rule-occurrence "principal is not an existing indexed root"))
    (list-ref (list-ref fs (sub1 slot)) (sub1 index)))
  (define count (case family [(tensor par cut) 2] [else 0]))
  (unless (and (list? indices) (= (length indices) count) (andmap exact-positive-integer? indices))
    (error 'mll-rule-occurrence "wrong principal indices"))
  (when (and (eq? family 'par) (= (car indices) (cadr indices)))
    (error 'mll-rule-occurrence "Par consumes distinct root occurrences"))
  (define principal
    (case family
      [(tensor) (list 'tensor (at 1 (car indices)) (at 2 (cadr indices)))]
      [(par) (list 'par (at 1 (car indices)) (at 1 (cadr indices)))]
      [(cut)
       (unless (equal? (mll-dual (at 1 (car indices))) (at 2 (cadr indices)))
         (error 'mll-rule-occurrence "Cut principals are not dual"))
       (at 1 (car indices))]
      [else #f]))
  (define selected
    (case family [(tensor cut) (list (list 1 (car indices)) (list 2 (cadr indices)))]
      [(par) (map (lambda (i) (list 1 i)) indices)] [else '()]))
  (define entries
    (case family
      [(id)
       (unless (and (symbol? atom) (symbol-interned? atom)) (error 'mll-rule-occurrence "identity is atomic"))
       (list (cons '(axiom 1) atom) (cons '(axiom 2) (mll-dual atom)))]
      [else
       (append
        (append-map
         (lambda (slot)
           (for/list ([f (in-list (list-ref fs (sub1 slot)))] [i (in-naturals 1)]
                      #:unless (member (list slot i) selected equal?))
             (cons (list slot i) f))) (range 1 (add1 arity)))
        (if (memq family '(tensor par)) (list (cons 'principal principal)) '()))]))
  (values entries selected principal))

(define (instance family premises indices order atom)
  (define-values (entries selected principal) (shape family premises indices atom))
  (define sorted (sort entries (lambda (a b) (symbolic-datum<? (cdr a) (cdr b)))))
  (define actual (or order (map car sorted)))
  (unless (and (list? actual) (= (length actual) (length entries))
               (not (check-duplicates actual equal?))
               (andmap (lambda (t) (assoc t entries equal?)) actual)
               (equal? (map (lambda (t) (cdr (assoc t entries equal?))) actual) (map cdr sorted)))
    (error 'mll-rule-occurrence "exchange omits, duplicates or changes an output occurrence"))
  (define routes
    (for*/list ([slot (in-range 1 (add1 (length premises)))]
                [i (in-range 1 (add1 (length (mll-boundary-formulas (list-ref premises (sub1 slot))))))])
      (define token (list slot i))
      (define pos (index-of actual token equal?))
      (define child (index-of selected token equal?))
      (list slot i (cond [pos (list 'output (add1 pos) '())]
                         [(eq? family 'cut) (list 'cut (add1 child) '())]
                         [else (list 'output (add1 (index-of actual 'principal)) (list (add1 child)))]))))
  (values (mll-boundary (map cdr sorted)) actual
          (hash 'schema 'potkin/mll-v1 'family family 'indices indices 'order actual
                'atom atom 'formula principal 'routing routes)))
(define (key family premises indices order atom)
  (string->symbol (string-append prefix (format "~s" (list family (map mll-boundary-formulas premises) indices order atom)))))
(define (make-mll-schema-calculus #:sector [sector 'full])
  (unless (memq sector '(full F0 F1)) (raise-argument-error 'make-mll-schema-calculus "full/F0/F1" sector))
  (define (resolver id)
    (and (symbol? id) (string-prefix? (symbol->string id) prefix)
         (with-handlers ([exn:fail? (lambda (_) #f)])
           (parameterize ([read-accept-reader #f] [read-accept-lang #f] [read-accept-compiled #f] [read-accept-graph #f])
             (define in (open-input-string (substring (symbol->string id) (string-length prefix))))
             (define datum (read in))
             (unless (eof-object? (read in)) (error 'mll-resolver "trailing data"))
             (match datum
               [(list family boundaries indices order atom)
                (define premises (map mll-boundary boundaries))
                (define-values (conclusion actual data) (instance family premises indices order atom))
                (and (equal? boundaries (map mll-boundary-formulas premises))
                     (eq? id (key family premises indices actual atom))
                     (or (not (eq? family 'cut)) (eq? sector 'full)
                         (<= (mll-rank (hash-ref data 'formula)) (if (eq? sector 'F0) 0 1)))
                     (make-concrete-occurrence id premises conclusion #:tag family #:instance data
                       #:incidence (make-component-incidence premises conclusion
                                     (for/list ([s (in-range 1 (add1 (length premises)))]) (make-component-edge s 1 1)))))]
               [_ #f])))))
  (define k (make-schema-equipped-calculus '() (list 'potkin/mll-v1 sector '(id tensor par mix cut)) resolver))
  (hash-set! snapshots k sector) k)
(define (mll-rule-occurrence k family premises #:indices [indices '()] #:order [order #f] #:atom [atom #f])
  (mll-schema-sector k)
  (define-values (_b actual _data) (instance family premises indices order atom))
  (or (calculus-lookup k (key family premises indices actual atom))
      (error 'mll-rule-occurrence "schema admission rejects this instance (~a)" (mll-schema-sector k))))
(define (mll-apply k family children #:indices [indices '()] #:order [order #f] #:atom [atom #f])
  (define occurrence (mll-rule-occurrence k family (map derivation-root-boundary children) #:indices indices #:order order #:atom atom))
  (define result (assemble-checked-application k occurrence children))
  (when (validation-error? result) (error 'mll-apply "native checker rejected assembly: ~a" (validation-error-message result)))
  result)
(define (mll-id k atom) (mll-apply k 'id '() #:atom atom))
(define (mll-occurrence-data k o)
  (mll-schema-sector k)
  (unless (eq? o (calculus-lookup k (concrete-occurrence-id o))) (error 'mll-occurrence-data "wrong exact occurrence"))
  (concrete-occurrence-instance o))
(define (mll-occurrence-family k o) (hash-ref (mll-occurrence-data k o) 'family))
(define (mll-occurrence-indices k o) (hash-ref (mll-occurrence-data k o) 'indices))
(define (mll-occurrence-order k o) (hash-ref (mll-occurrence-data k o) 'order))
(define (mll-occurrence-routing k o) (hash-ref (mll-occurrence-data k o) 'routing))

;; Expanded ordinary compound identity; never a compound primitive axiom.
(define (mll-expanded-id k formula)
  (cond
    [(symbol? formula) (mll-id k formula)]
    [(mll-literal? formula) (mll-id k (cadr formula))]
    [else
     (define a (cadr formula)) (define b (caddr formula))
     (define p (mll-expanded-id k a)) (define q (mll-expanded-id k b))
     (define connective (car formula))
     (define tensor-a (if (eq? connective 'tensor) a (mll-dual a)))
     (define tensor-b (if (eq? connective 'tensor) b (mll-dual b)))
     (define t (mll-apply k 'tensor (list p q)
                        #:indices (list (add1 (index-of (mll-boundary-formulas (derivation-root-boundary p)) tensor-a equal?))
                                        (add1 (index-of (mll-boundary-formulas (derivation-root-boundary q)) tensor-b equal?)))))
     (define fs (mll-boundary-formulas (derivation-root-boundary t)))
     (define pa (mll-dual tensor-a)) (define pb (mll-dual tensor-b))
     (define ia (index-of fs pa equal?))
     (define ib (for/first ([f (in-list fs)] [i (in-naturals)] #:when (and (equal? f pb) (not (= i ia)))) i))
     (mll-apply k 'par (list t) #:indices (list (add1 ia) (add1 ib)))]))
