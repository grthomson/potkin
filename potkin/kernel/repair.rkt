#lang racket/base

(require racket/list
         "address.rkt"
         "calculus.rkt"
         "check.rkt"
         "context.rkt"
         "cut.rkt"
         "revision.rkt")

(provide plan-ground-repair
         ground-repair-plan?
         ground-repair-plan-revision
         ground-repair-plan-source
         ground-repair-plan-target-context
         ground-repair-plan-telescope
         ground-repair-plan-addresses
         nonroot-ground-repair-plan?
         nonroot-ground-repair-plan-revision
         nonroot-ground-repair-plan-source-witness
         nonroot-ground-repair-plan-target-remainder
         whole-ground-replacement-plan?
         whole-ground-replacement-plan-revision
         whole-ground-replacement-plan-detached-source
         whole-ground-replacement-plan-target-identity-context
         apply-repair-plan
         extract-fillers
         repair-error?
         repair-error-phase
         repair-error-code
         repair-error-message
         repair-error-address
         repair-error-expected
         repair-error-actual
         repair-error-details
         repair-scope-error?
         repair-application-error?
         repair-extraction-error?
         repair-scope-issue?
         repair-scope-issue-address
         repair-scope-issue-occurrence
         repair-scope-issue-reason
         repair-scope-issue-details)

;; A nonroot repair is a CK factorisation retained in its historical source
;; calculus together with a separately checked lift of only its punctured
;; remainder. The source witness is never retroactively rebased.
(struct nonroot-ground-repair-plan (revision source-witness target-remainder)
  #:constructor-name make-nonroot-ground-repair-plan/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (nonroot-ground-repair-plan? right)
          (recur (nonroot-ground-repair-plan-revision left)
                 (nonroot-ground-repair-plan-revision right))
          (recur (nonroot-ground-repair-plan-source-witness left)
                 (nonroot-ground-repair-plan-source-witness right))
          (recur (nonroot-ground-repair-plan-target-remainder left)
                 (nonroot-ground-repair-plan-target-remainder right))))
   (lambda (value recur)
     (recur
      (list (nonroot-ground-repair-plan-revision value)
            (nonroot-ground-repair-plan-source-witness value)
            (nonroot-ground-repair-plan-target-remainder value))))
   (lambda (value recur)
     (recur
      (list (nonroot-ground-repair-plan-target-remainder value)
            (nonroot-ground-repair-plan-source-witness value)
            (nonroot-ground-repair-plan-revision value))))))

;; The manuscript's one-vertex exception is adjacent to ground repair but is
;; not a CK root cut. It stores the detached whole source and target Box^G.
(struct whole-ground-replacement-plan
  (revision detached-source target-identity-context)
  #:constructor-name make-whole-ground-replacement-plan/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (whole-ground-replacement-plan? right)
          (recur (whole-ground-replacement-plan-revision left)
                 (whole-ground-replacement-plan-revision right))
          (recur (whole-ground-replacement-plan-detached-source left)
                 (whole-ground-replacement-plan-detached-source right))
          (recur
           (whole-ground-replacement-plan-target-identity-context left)
           (whole-ground-replacement-plan-target-identity-context right))))
   (lambda (value recur)
     (recur
      (list (whole-ground-replacement-plan-revision value)
            (whole-ground-replacement-plan-detached-source value)
            (whole-ground-replacement-plan-target-identity-context value))))
   (lambda (value recur)
     (recur
      (list (whole-ground-replacement-plan-target-identity-context value)
            (whole-ground-replacement-plan-detached-source value)
            (whole-ground-replacement-plan-revision value))))))

(struct repair-error (phase code message address expected actual details)
  #:constructor-name make-repair-error/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (repair-error? right)
          (recur (repair-error-phase left) (repair-error-phase right))
          (recur (repair-error-code left) (repair-error-code right))
          (recur (repair-error-message left) (repair-error-message right))
          (recur (repair-error-address left) (repair-error-address right))
          (recur (repair-error-expected left) (repair-error-expected right))
          (recur (repair-error-actual left) (repair-error-actual right))
          (recur (repair-error-details left) (repair-error-details right))))
   (lambda (value recur)
     (recur
      (list (repair-error-phase value)
            (repair-error-code value)
            (repair-error-message value)
            (repair-error-address value)
            (repair-error-expected value)
            (repair-error-actual value)
            (repair-error-details value))))
   (lambda (value recur)
     (recur
      (list (repair-error-details value)
            (repair-error-actual value)
            (repair-error-expected value)
            (repair-error-address value)
            (repair-error-message value)
            (repair-error-code value)
            (repair-error-phase value))))))

(struct repair-scope-issue (address occurrence reason details)
  #:constructor-name make-repair-scope-issue/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (repair-scope-issue? right)
          (recur (repair-scope-issue-address left)
                 (repair-scope-issue-address right))
          (recur (repair-scope-issue-occurrence left)
                 (repair-scope-issue-occurrence right))
          (recur (repair-scope-issue-reason left)
                 (repair-scope-issue-reason right))
          (recur (repair-scope-issue-details left)
                 (repair-scope-issue-details right))))
   (lambda (value recur)
     (recur
      (list (repair-scope-issue-address value)
            (repair-scope-issue-occurrence value)
            (repair-scope-issue-reason value)
            (repair-scope-issue-details value))))
   (lambda (value recur)
     (recur
      (list (repair-scope-issue-details value)
            (repair-scope-issue-reason value)
            (repair-scope-issue-occurrence value)
            (repair-scope-issue-address value))))))

(define (make-repair-error phase code message
                           #:address [address #f]
                           #:expected [expected #f]
                           #:actual [actual #f]
                           #:details [details (hash)])
  (make-repair-error/internal
   phase code message address expected actual details))

(define (repair-scope-error? value)
  (and (repair-error? value) (eq? (repair-error-phase value) 'scope)))

(define (repair-application-error? value)
  (and (repair-error? value)
       (eq? (repair-error-phase value) 'application)))

(define (repair-extraction-error? value)
  (and (repair-error? value)
       (eq? (repair-error-phase value) 'extraction)))

(define (ground-repair-plan? value)
  (or (nonroot-ground-repair-plan? value)
      (whole-ground-replacement-plan? value)))

(define (check-plan who plan)
  (unless (ground-repair-plan? plan)
    (raise-argument-error who "ground-repair-plan?" plan)))

(define (ground-repair-plan-revision plan)
  (check-plan 'ground-repair-plan-revision plan)
  (if (nonroot-ground-repair-plan? plan)
      (nonroot-ground-repair-plan-revision plan)
      (whole-ground-replacement-plan-revision plan)))

(define (ground-repair-plan-source plan)
  (check-plan 'ground-repair-plan-source plan)
  (if (nonroot-ground-repair-plan? plan)
      (cut-witness-source
       (nonroot-ground-repair-plan-source-witness plan))
      (whole-ground-replacement-plan-detached-source plan)))

(define (ground-repair-plan-target-context plan)
  (check-plan 'ground-repair-plan-target-context plan)
  (if (nonroot-ground-repair-plan? plan)
      (nonroot-ground-repair-plan-target-remainder plan)
      (whole-ground-replacement-plan-target-identity-context plan)))

(define (ground-repair-plan-telescope plan)
  (check-plan 'ground-repair-plan-telescope plan)
  (premise-telescope (ground-repair-plan-target-context plan)))

(define (ground-repair-plan-addresses plan)
  (check-plan 'ground-repair-plan-addresses plan)
  (if (nonroot-ground-repair-plan? plan)
      (cut-witness-addresses
       (nonroot-ground-repair-plan-source-witness plan))
      (list root-address)))

(define (scope-issue address occurrence reason [details (hash)])
  (make-repair-scope-issue/internal address occurrence reason details))

(define (diagnostic-scope-issues revision diagnostic)
  (define occurrence (liveness-diagnostic-occurrence diagnostic))
  (define address (liveness-diagnostic-address diagnostic))
  (define id (concrete-occurrence-id occurrence))
  (define classification (liveness-diagnostic-classification diagnostic))
  (define withdrawn? (memq id (calculus-revision-withdrawn-ids revision)))
  (append
   (cond
     [(eq? classification 'unknown)
      (list (scope-issue address occurrence 'unknown
                         (hash 'classification classification)))]
     [(eq? classification 'incompatible/redefined)
      (list
       (scope-issue
        address occurrence 'incompatible/redefined
        (hash 'classification classification
              'target-occurrence
              (liveness-diagnostic-target-occurrence diagnostic))))]
     [(not withdrawn?)
      (list (scope-issue address occurrence 'not-explicitly-withdrawn
                         (hash 'classification classification)))]
     [else '()])
   (case (concrete-occurrence-kind occurrence)
     [(material) '()]
     [(logical) (list (scope-issue address occurrence 'logical))]
     [(structural) (list (scope-issue address occurrence 'structural))]
     [else
      (list (scope-issue address occurrence 'not-explicitly-withdrawn))])
   (if (positive? (occurrence-arity occurrence))
       (list (scope-issue address occurrence 'positive-arity
                          (hash 'arity (occurrence-arity occurrence))))
       '())))

(define (frontier-conflict-issues diagnostics)
  (append-map
   (lambda (ancestor-diagnostic)
     (define ancestor
       (liveness-diagnostic-address ancestor-diagnostic))
     (for/list ([descendant-diagnostic (in-list diagnostics)]
                #:when
                (proper-address-prefix?
                 ancestor
                 (liveness-diagnostic-address descendant-diagnostic)))
       (define descendant
         (liveness-diagnostic-address descendant-diagnostic))
       (scope-issue
        descendant
        (liveness-diagnostic-occurrence descendant-diagnostic)
        'ancestor-descendant
        (hash 'ancestor ancestor 'descendant descendant))))
   diagnostics))

(define (plan-ground-repair revision source)
  (unless (calculus-revision? revision)
    (raise-argument-error
     'plan-ground-repair "calculus-revision?" revision))
  (unless (checked-term? source)
    (raise-argument-error 'plan-ground-repair "checked-term?" source))

  (define source-calculus (calculus-revision-source revision))
  (define target-calculus (calculus-revision-target revision))
  (cond
    [(not (eq? (checked-term-calculus source) source-calculus))
     (make-repair-error
      'scope
      'wrong-source-calculus
      "repair planning requires the exact historical source registry"
      #:expected source-calculus
      #:actual (checked-term-calculus source)
      #:details
      (hash
       'liveness-diagnostics
       (term-liveness-diagnostics
        target-calculus
        source
        #:retired-ids (calculus-revision-withdrawn-ids revision))))]
    [(not (term-historically-valid? source))
     (make-repair-error
      'scope
      'historically-invalid
      "the source no longer replays under its stored historical registry"
      #:actual source)]
    [(not (complete-proof? source))
     (make-repair-error
      'scope
      'incomplete-source
      "automatic ground repair accepts only complete historical proofs"
      #:actual source)]
    [else
     (define diagnostics
       (sort (revision-liveness-diagnostics revision source)
             address<?
             #:key liveness-diagnostic-address))
     (cond
       [(null? diagnostics)
        (make-repair-error
         'scope
         'no-inactive-occurrences
         "an unaffected proof should be lifted, not represented as a repair"
         #:actual source
         #:details (hash 'liveness-diagnostics diagnostics))]
       [else
        (define issues
          (append
           (append-map
            (lambda (diagnostic)
              (diagnostic-scope-issues revision diagnostic))
            diagnostics)
           (frontier-conflict-issues diagnostics)))
        (cond
          [(pair? issues)
           (make-repair-error
            'scope
            'unsupported-repair-scope
            "automatic repair is restricted to a prefix-free frontier of explicitly withdrawn nullary material grounds"
            #:actual source
            #:details
            (hash 'liveness-diagnostics diagnostics
                  'scope-issues issues))]
          [else
           (define addresses
             (map liveness-diagnostic-address diagnostics))
           (cond
             [(equal? addresses (list root-address))
              (make-whole-ground-replacement-plan/internal
               revision
               source
               (identity-context
                target-calculus
                (derivation-root-boundary source)))]
             [else
              (define witness (make-cut-witness source addresses))
              (cond
                [(cut-error? witness)
                 (make-repair-error
                  'scope
                  'invalid-repair-frontier
                  "the selected ground frontier is not an admissible nonroot CK cut"
                  #:address (cut-error-address witness)
                  #:actual addresses
                  #:details
                  (hash 'cut-error witness
                        'liveness-diagnostics diagnostics
                        'scope-issues '()))]
                [else
                 (define target-remainder
                   (lift-context revision (cut-witness-remainder witness)))
                 (if (revision-error? target-remainder)
                     (make-repair-error
                      'scope
                      'remainder-lift-failed
                      "the retained punctured remainder did not lift into the target"
                      #:actual (cut-witness-remainder witness)
                      #:details (hash 'revision-error target-remainder))
                     (make-nonroot-ground-repair-plan/internal
                      revision witness target-remainder))])])])])]))

(define (filler-error plan entry filler)
  (define address (telescope-entry-address entry))
  (define requirement (telescope-entry-requirement entry))
  (define revision (ground-repair-plan-revision plan))
  (define target (calculus-revision-target revision))
  (cond
    [(not (checked-term? filler))
     (make-repair-error
      'application 'incomplete-filler
      "each repair filler must be a checked complete proof"
      #:address address #:expected requirement #:actual filler)]
    [(not (complete-proof? filler))
     (make-repair-error
      'application 'incomplete-filler
      "each repair filler must be a complete rule-rooted proof"
      #:address address #:expected requirement #:actual filler)]
    [(not (equal? requirement (derivation-root-boundary filler)))
     (make-repair-error
      'application 'wrong-filler-boundary
      "the filler root does not equal the telescope requirement"
      #:address address
      #:expected requirement
      #:actual (derivation-root-boundary filler))]
    [(not (term-historically-valid? filler))
     (make-repair-error
      'application 'historically-invalid-filler
      "the filler is not valid under its own checked provenance"
      #:address address #:expected requirement #:actual filler)]
    [else
     (define diagnostics
       (term-liveness-diagnostics
        target filler
        #:retired-ids (calculus-revision-withdrawn-ids revision)))
     (cond
       [(pair? diagnostics)
        (make-repair-error
         'application 'inactive-filler
         "the right-boundary filler contains target-inactive evidence"
         #:address address
         #:expected requirement
         #:actual (derivation-root-boundary filler)
         #:details (hash 'liveness-diagnostics diagnostics))]
       [(not (eq? (checked-term-calculus filler) target))
        (make-repair-error
         'application 'wrong-target-calculus
         "the filler must carry the exact target registry provenance"
         #:address address #:expected target
         #:actual (checked-term-calculus filler))]
       [else #f])]))

(define (apply-repair-plan plan fillers)
  (check-plan 'apply-repair-plan plan)
  (unless (list? fillers)
    (raise-argument-error 'apply-repair-plan "list?" fillers))
  (define telescope (ground-repair-plan-telescope plan))
  (cond
    [(not (= (length fillers) (length telescope)))
     (make-repair-error
      'application 'wrong-filler-count
      "repair needs one explicit proof for each telescope entry"
      #:expected (length telescope)
      #:actual (length fillers))]
    [else
     (define problem
       (for/or ([entry (in-list telescope)]
                [filler (in-list fillers)])
         (filler-error plan entry filler)))
     (cond
       [problem problem]
       [else
        (define result
          (complete-fill (ground-repair-plan-target-context plan) fillers))
        (cond
          [(context-error? result)
           (make-repair-error
            'application 'fill-failed
            "checked filling of the target repair context failed"
            #:address (context-error-address result)
            #:expected (context-error-expected result)
            #:actual (context-error-actual result)
            #:details (hash 'context-error result))]
          [(and
            (complete-proof? result)
            (eq? (checked-term-calculus result)
                 (calculus-revision-target
                  (ground-repair-plan-revision plan))))
           result]
          [else
           (make-repair-error
            'application 'fill-failed
            "repair filling did not produce a complete target proof"
            #:actual result)])])]))

(define (candidate-preflight-error plan candidate)
  (define target
    (calculus-revision-target (ground-repair-plan-revision plan)))
  (define expected
    (derivation-root-boundary (ground-repair-plan-target-context plan)))
  (cond
    [(not (checked-term? candidate))
     (make-repair-error
      'extraction 'incomplete-candidate
      "extraction requires a checked complete target proof"
      #:expected expected #:actual candidate)]
    [(not (complete-proof? candidate))
     (make-repair-error
      'extraction 'incomplete-candidate
      "extraction requires a complete rule-rooted target proof"
      #:expected expected #:actual candidate)]
    [(not (equal? expected (derivation-root-boundary candidate)))
     (make-repair-error
      'extraction 'wrong-candidate-boundary
      "the candidate root differs from the repair context root"
      #:expected expected #:actual (derivation-root-boundary candidate))]
    [(not (term-historically-valid? candidate))
     (make-repair-error
      'extraction 'historically-invalid-candidate
      "the candidate is not valid under its checked provenance"
      #:expected expected #:actual candidate)]
    [else
     (define diagnostics
       (term-liveness-diagnostics
        target candidate
        #:retired-ids
        (calculus-revision-withdrawn-ids
         (ground-repair-plan-revision plan))))
     (cond
       [(pair? diagnostics)
        (make-repair-error
         'extraction 'inactive-candidate
         "the candidate contains target-inactive evidence"
         #:expected expected
         #:actual (derivation-root-boundary candidate)
         #:details (hash 'liveness-diagnostics diagnostics))]
       [(not (eq? (checked-term-calculus candidate) target))
        (make-repair-error
         'extraction 'wrong-target-calculus
         "the candidate must carry the exact target registry provenance"
         #:expected target #:actual (checked-term-calculus candidate))]
       [else #f])]))

;; Return (address expected actual) for the first retained presentation
;; mismatch. Both inputs are already checked remainders under the same target.
(define (first-retained-mismatch expected actual [address root-address])
  (cond
    [(and (checked-hole? expected) (checked-hole? actual)) #f]
    [(and (checked-node? expected) (checked-node? actual))
     (cond
       [(not (equal? (checked-node-occurrence expected)
                     (checked-node-occurrence actual)))
        (list address
              (checked-node-occurrence expected)
              (checked-node-occurrence actual))]
       [(not (= (length (checked-node-children expected))
                (length (checked-node-children actual))))
        (list address
              (checked-node-occurrence expected)
              (checked-node-occurrence actual))]
       [else
        (for/or ([expected-child
                  (in-list (checked-node-children expected))]
                 [actual-child
                  (in-list (checked-node-children actual))]
                 [slot (in-naturals 1)])
          (first-retained-mismatch
           expected-child actual-child (append address (list slot))))])]
    [else (list address expected actual)]))

(define (extract-fillers plan candidate)
  (check-plan 'extract-fillers plan)
  (define preflight (candidate-preflight-error plan candidate))
  (cond
    [preflight preflight]
    [else
     (define fillers-or-error
       (cond
         [(whole-ground-replacement-plan? plan) (list candidate)]
         [else
          (define candidate-witness
            (make-cut-witness candidate
                              (ground-repair-plan-addresses plan)))
          (cond
            [(cut-error? candidate-witness)
             (make-repair-error
              'extraction 'candidate-shape-mismatch
              "the plan addresses do not form the same cut in the candidate"
              #:address (cut-error-address candidate-witness)
              #:actual candidate
              #:details (hash 'cut-error candidate-witness))]
            [else
             (define expected-remainder
               (nonroot-ground-repair-plan-target-remainder plan))
             (define actual-remainder
               (cut-witness-remainder candidate-witness))
             (define mismatch
               (first-retained-mismatch expected-remainder actual-remainder))
             (if mismatch
                 (make-repair-error
                  'extraction 'retained-context-mismatch
                  "the candidate changes a retained constructor or ordered premise"
                  #:address (first mismatch)
                  #:expected (second mismatch)
                  #:actual (third mismatch)
                  #:details
                  (hash 'expected-remainder expected-remainder
                        'actual-remainder actual-remainder))
                 (map detached-entry-term
                      (cut-witness-detached candidate-witness)))])]))
     (cond
       [(repair-error? fillers-or-error) fillers-or-error]
       [else
        (define rebuilt (apply-repair-plan plan fillers-or-error))
        (cond
          [(repair-error? rebuilt)
           (make-repair-error
            'extraction 'roundtrip-failed
            "extracted fillers unexpectedly failed checked repair filling"
            #:actual candidate
            #:details (hash 'application-error rebuilt))]
          [(not (equal? rebuilt candidate))
           (make-repair-error
            'extraction 'roundtrip-failed
            "extracted fillers do not rebuild the candidate presentation"
            #:expected candidate #:actual rebuilt)]
          [else fillers-or-error])])]))
