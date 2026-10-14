#lang racket/base

;; Source-relative protected ORDERED CK expressions.  No semantic quotient,
;; inverse proof, provider swap, or normalization operation is introduced.
;; The universal laws invoked here are paper laws for the frozen four cells;
;; returned records are independently checkable finite instance evidence.
(require racket/list racket/match racket/vector
         "ck-boundary-certification.rkt"
         "../kernel/address.rkt" "../kernel/calculus.rkt"
         "../kernel/check.rkt" "../kernel/context.rkt" "../kernel/cut.rkt"
         "../kernel/mixed-schema.rkt" "../hopf/ordered-ck.rkt")

(provide (struct-out ck-structured-certificate)
         (struct-out ck-protection-evidence) (struct-out ck-protection-result)
         (struct-out ck-protected-observables) (struct-out ck-occurrence-term)
         (struct-out ck-heredity-entry) (struct-out ck-protected-flag)
         (struct-out ck-flag-result) (struct-out ck-comparison-certificate)
         (struct-out ck-iterated-result) protected-ck-iterated-coproduct
         certify-structured-ck-protection verify-structured-ck-certificate
         prepare-ck-protection verify-ck-protection-evidence
         protected-ck-observables verify-protected-ck-observables full-protected-fidelity
         verify-ck-heredity protected-ck-flags
         certify-tensor-mixed-comparison verify-tensor-mixed-comparison
         ck-live-material-spectrum ck-pure-material-selector)

(struct ck-structured-certificate
  (source policy family partition providers history hypotheses conversion-version)
  #:transparent)
(struct ck-protection-evidence (source policy partition certificate) #:transparent)
(struct ck-protection-result (status evidence reason details) #:transparent)
(struct ck-occurrence-term (kind witness left right coefficient transports) #:transparent)
(struct ck-protected-observables
  (status selector coaction core occurrence-terms historical-spectrum live-eligible? details)
  #:transparent)
(struct ck-heredity-entry (kind source local-to-source restricted recomputed status) #:transparent)
(struct ck-protected-flag (coordinates witnesses transports) #:transparent)
(struct ck-flag-result (status flags reason details) #:transparent)
(struct ck-iterated-result (status sum terms reason details) #:transparent)
(struct ck-comparison-certificate
  (source policy old-evidence mixed-evidence profiles ambient-maps observations)
  #:transparent)
(struct exn:protected-limit exn:fail () #:transparent)
(struct exn:protected-heredity exn:fail (details) #:transparent)

(define (family K q)
  (and (checked-node? q) (mixed-occurrence-family K (checked-node-occurrence q))))
(define (child q i) (list-ref (checked-node-children q) (sub1 i)))
(define (material? K q)
  (and (eq? (family K q) 'material) (null? (checked-node-children q))))
(define (initial q)
  (define vs (vertex-addresses q))
  (ck-marked-state q (vector->immutable-vector (list->vector (range (length vs))))
                   (for/hash ([a (in-list vs)] [i (in-naturals)]) (values a i))))
(define (partition-for q groups)
  (define vs (vertex-addresses q))
  (vector->immutable-vector
   (for/vector ([a (in-list vs)] [i (in-naturals)])
     (or (for/first ([g (in-list groups)] #:when (member a g equal?))
           (index-of vs (car (sort g address<?)))) i))))
(define (primitive-addresses q)
  (define K (checked-term-calculus q))
  (filter (lambda (a) (material? K (vertex-at-address q a))) (vertex-addresses q)))
(define (distinct-primitives? q)
  (define K (checked-term-calculus q))
  (define ps (primitive-addresses q))
  (and (derivation-complete? q)
       (for/and ([a (in-list (vertex-addresses q))])
         (define p (vertex-at-address q a))
         (if (null? (checked-node-children p)) (material? K p) #t))
       (not (check-duplicates
             (map (lambda (a) (concrete-occurrence-id
                              (checked-node-occurrence (vertex-at-address q a)))) ps)))))

;; Strict templates.  Actual occurrence selections/exchanges are checked by
;; native schema admission and the independently replayed merge history, not
;; inferred from constructor names or equal-looking formula occurrences.
(define (tensor-producer? K p)
  (or (material? K p)
      (and (eq? (family K p) 'tensorR)
           (tensor-producer? K (child p 1)) (tensor-producer? K (child p 2)))))
(define (tensor-consumer? K p)
  (or (material? K p)
      (and (eq? (family K p) 'tensorL) (tensor-consumer? K (child p 1)))))
(define (bundle? K q)
  (and (eq? (family K q) 'cut+)
       (tensor-producer? K (child q 1)) (tensor-consumer? K (child q 2))
       ;; The cut selects the packed principal, not a passive consumer input.
       (or (material? K (child q 2))
           (eq? 'principal
                (list-ref (mixed-occurrence-order K (checked-node-occurrence (child q 2)))
                          (sub1 (car (mixed-occurrence-indices K (checked-node-occurrence q)))))))))
(define (curried? K q)
  (and (eq? (family K q) 'cut+)
       (let loop ([p (child q 1)] [r (child q 2)] [m 0])
         (cond
           [(and (material? K p) (material? K r)) (positive? m)]
           [(and (eq? (family K p) 'impliesR) (eq? (family K r) 'impliesL)
                 (material? K (child r 1)))
            (loop (child p 1) (child r 2) (add1 m))]
           [else #f]))))

(define (context-hypotheses K q)
  (and (eq? (family K q) 'cut+) (material? K (child q 1))
       (bundle? K (child q 2))
       (let* ([s (child q 1)] [b (child q 2)]
              [ps (filter (lambda (a) (address-prefix? '(1) a)) (primitive-addresses b))]
              [r (last (primitive-addresses b))]
              [d (mixed-boundary-right (derivation-root-boundary s))]
              [c (mixed-boundary-right (derivation-root-boundary b))]
              [atoms (map (lambda (a) (mixed-boundary-right
                                      (derivation-root-boundary (vertex-at-address b a)))) ps)]
              [dependent (for/list ([a (in-list ps)] [i (in-naturals 1)]
                                     #:when (equal? (mixed-boundary-left
                                                    (derivation-root-boundary (vertex-at-address b a)))
                                                   (list d))) i)])
         (and (null? (mixed-boundary-left (derivation-root-boundary s)))
              (symbol? d) (symbol? c) (andmap symbol? atoms)
              (not (check-duplicates (append atoms (list d c))))
              (= (length dependent) 1)
              (for/and ([a (in-list ps)] [i (in-naturals 1)])
                (equal? (mixed-boundary-left (derivation-root-boundary (vertex-at-address b a)))
                        (if (= i (car dependent)) (list d) '())))
              (equal? (sort atoms symbol<?)
                      (mixed-boundary-left (derivation-root-boundary (vertex-at-address b r))))
              (equal? (mixed-boundary-left (derivation-root-boundary b)) (list d))
              (hash 'position (car dependent) 'arity (length atoms) 'atoms atoms 'd d 'c c)))))

(define (recognize q policy)
  (and (checked-node? q) (memq policy '(forward bidirectional))
       (mixed-schema-calculus? (checked-term-calculus q)) (distinct-primitives? q)
       (let* ([K (checked-term-calculus q)] [ctx (context-hypotheses K q)]
              [ps (primitive-addresses q)]
              [logical (filter (lambda (a) (not (member a ps equal?))) (vertex-addresses q))])
         (cond
           [ctx
            (define separated? (or (eq? policy 'forward) (= (hash-ref ctx 'position) 1)))
            (list 'ordered-context ps
                  (partition-for q (if separated? (list (remove '() logical equal?)) (list logical))) ctx)]
           [(bundle? K q) (list 'tensor-bundle ps (partition-for q (list logical)) (hash))]
           [(curried? K q) (list 'curried-application ps (partition-for q (list logical)) (hash))]
           [else #f]))))

;; The lower bound is an ACTUAL native history; greedy generation may fail to
;; find it under the cap, in which case this path is UNKNOWN, never SAFE.
(define (merge-history q desired policy cap gen ms)
  (let loop ([s (initial q)] [history '()] [fuel cap])
    (cond
      [(equal? desired (ck-marked-state-partition s)) (reverse history)]
      [(zero? fuel) #f]
      [else
       (define-values (moves complete? reason)
         (enumerate-ck-schema-moves (ck-marked-state-endpoint s) #:policy 'forward
                                   #:generation-limit gen #:time-limit-ms ms))
       (define m (and (pair? moves) (car moves)))
       (unless m
         (when (eq? policy 'bidirectional)
           (define-values (all done? why)
             (enumerate-ck-schema-moves (ck-marked-state-endpoint s) #:policy policy
                                       #:generation-limit gen #:time-limit-ms ms))
           (set! m (findf (lambda (v)
                           (equal? desired (ck-marked-state-partition (ck-marked-successor s v)))) all))))
       (and m (loop (ck-marked-successor s m) (cons m history) (sub1 fuel)))])))

(define (certify-structured-ck-protection source #:policy [policy 'bidirectional]
                                        #:generation-limit [gen 20000] #:time-limit-ms [ms 30000])
  (define template (recognize source policy))
  (cond
    [(not template) (ck-protection-result 'UNKNOWN #f 'not-a-strict-structured-family (hash))]
    [else
     (define history (merge-history source (third template) policy
                                    (+ 1 (* 4 (derivation-vertex-count source) (derivation-vertex-count source))) gen ms))
     (cond
       [(not history) (ck-protection-result 'UNKNOWN #f 'constructive-history-incomplete (hash))]
       [else
        (define c (ck-structured-certificate source policy (first template) (third template)
                                            (second template) history (fourth template) ck-conversion-version))
        (define v (verify-structured-ck-certificate c #:generation-limit gen #:time-limit-ms ms))
        (if (ck-closure-report-valid? v)
            (ck-protection-result 'SAFE
              (ck-protection-evidence source policy (third template) c)
              'verified-structured-template (hash 'family (first template) 'history-length (length history)))
            (ck-protection-result 'UNKNOWN #f 'structured-verification-incomplete (hash 'verification v)))])]))

(define (verify-structured-ck-certificate c #:generation-limit [gen 20000] #:time-limit-ms [ms 30000])
  (with-handlers ([exn:fail? (lambda (e) (ck-closure-report #f 'UNKNOWN 'malformed-structured-certificate
                                                         (hash 'message (exn-message e))))])
    (let/ec reject
      (define (bad why) (reject (ck-closure-report #f 'UNKNOWN why (hash))))
      (unless (ck-structured-certificate? c) (bad 'wrong-certificate-type))
      (unless (and (vector? (ck-structured-certificate-partition c))
                   (immutable? (ck-structured-certificate-partition c))
                   (hash? (ck-structured-certificate-hypotheses c))
                   (immutable? (ck-structured-certificate-hypotheses c)))
        (bad 'mutable-or-malformed-structured-evidence))
      (define template (recognize (ck-structured-certificate-source c) (ck-structured-certificate-policy c)))
      (unless (and template (equal? ck-conversion-version (ck-structured-certificate-conversion-version c))
                   (equal? (list (ck-structured-certificate-family c) (ck-structured-certificate-providers c)
                                 (ck-structured-certificate-partition c) (ck-structured-certificate-hypotheses c))
                           template)) (bad 'template-hypotheses-not-met))
      (define s (initial (ck-structured-certificate-source c)))
      (define K (checked-term-calculus (ck-structured-certificate-source c)))
      (for ([m (in-list (ck-structured-certificate-history c))])
        ;; Presentation equality deliberately omits registry identity for
        ;; checked trees. Membership in freshly enumerated moves therefore
        ;; cannot by itself certify a supplied target's exact provenance.
        (unless (and (ck-schema-move? m) (checked-term? (ck-schema-move-target m))
                     (checked-term-has-exact-calculus? (ck-schema-move-target m) K)
                     (checked-term-has-exact-calculus? (ck-marked-state-endpoint s) K))
          (bad 'foreign-history-target-provenance))
        (define-values (moves complete? why)
          (enumerate-ck-schema-moves (ck-marked-state-endpoint s) #:policy (ck-structured-certificate-policy c)
                                    #:generation-limit gen #:time-limit-ms ms))
        (unless (member m moves equal?) (bad (if complete? 'invalid-history-cell 'history-generation-incomplete)))
        (set! s (ck-marked-successor s m)))
      (unless (equal? (ck-marked-state-partition s) (ck-structured-certificate-partition c))
        (bad 'history-does-not-establish-exact-lower-bound))
      ;; Upper bound: all four rigid shells contain only logical constructors;
      ;; immutable nullary material IDs remain separate under EVERY zigzag.
      ;; The sole two-block context case additionally uses the strict atom and
      ;; unique-input/first-provider exclusion hypotheses of Context Thm 3.1,
      ;; or the atomic outer-interface forward exclusion of Corollary 4.2.
      (ck-closure-report #t 'SAFE 'strict-template-and-checked-history
                         (hash 'status 'CODE-CHECKED 'universal-law 'paper-template-upper-bound)))))

(define (prepare-ck-protection source #:policy [policy 'bidirectional]
                               #:state-limit [cap 4096] #:generation-limit [gen 20000]
                               #:time-limit-ms [ms 30000])
  (define structured (certify-structured-ck-protection source #:policy policy
                          #:generation-limit gen #:time-limit-ms ms))
  (if (eq? 'SAFE (ck-protection-result-status structured)) structured
      (let* ([w (and (checked-node? source) (make-cut-witness source '()))]
             [r (certify-native-ck-boundary source (or w '()) #:policy policy
                    #:state-limit cap #:generation-limit gen #:time-limit-ms ms)])
        (if (eq? (ck-boundary-result-status r) 'SAFE)
            (ck-protection-result 'SAFE
              (ck-protection-evidence source policy (ck-certificate-protection (ck-boundary-result-certificate r))
                                      (ck-boundary-result-certificate r))
              'verified-complete-closure (ck-boundary-result-details r))
            (ck-protection-result 'UNKNOWN #f (ck-boundary-result-reason r) (ck-boundary-result-details r))))))

(define (verify-ck-protection-evidence e)
  (cond
    [(not (ck-protection-evidence? e)) (ck-closure-report #f 'UNKNOWN 'wrong-evidence-type (hash))]
    [else
     (define c (ck-protection-evidence-certificate e))
     (define report (if (ck-structured-certificate? c) (verify-structured-ck-certificate c)
                       (verify-ck-boundary-certificate c #:source (ck-protection-evidence-source e)
                                                      #:policy (ck-protection-evidence-policy e))))
     (define pi (and (ck-closure-report-valid? report)
                     (if (ck-structured-certificate? c) (ck-structured-certificate-partition c)
                         (ck-certificate-protection c))))
     (if (and pi (vector? (ck-protection-evidence-partition e))
              (immutable? (ck-protection-evidence-partition e))
              (equal? pi (ck-protection-evidence-partition e))
              (or (not (ck-structured-certificate? c))
                  (and (eq? (ck-protection-evidence-source e) (ck-structured-certificate-source c))
                       (eq? (ck-protection-evidence-policy e) (ck-structured-certificate-policy c))))) report
         (ck-closure-report #f 'UNKNOWN 'stale-or-altered-protection (hash)))]))

(define (check-profile p)
  (unless (and (list? p) (andmap symbol? p) (not (check-duplicates p)))
    (raise-argument-error 'ck-profile "list of distinct exact material IDs" p)))
(define (ck-live-material-spectrum source profile)
  (check-profile profile)
  (define K (checked-term-calculus source))
  (for/list ([a (in-list (vertex-addresses source))]
             #:when (eq? (family K (vertex-at-address source a)) 'material))
    (define id (concrete-occurrence-id (checked-node-occurrence (vertex-at-address source a))))
    (list a id (and (memq id profile) #t))))
(define (pure? forest profile)
  (for/and ([q (in-list (ordered-forest-factors forest))])
    (andmap third (ck-live-material-spectrum q profile))))
(define (ck-pure-material-selector sum profile)
  (check-profile profile)
  (unless (= (ordered-sum-rank sum) 1)
    (raise-argument-error 'ck-pure-material-selector "rank-one ordered sum" sum))
  (make-ordered-sum (ordered-sum-calculus sum) 1
    (filter (lambda (t) (pure? (vector-ref (car t) 0) profile)) (ordered-sum-terms sum))))

;; Restriction transports vertex identities; holes are not vertices.  Local
;; remainder addresses are literally unchanged, factors are prefix-translated.
(define (restrict-partition source pi q prefix)
  (define vs (vertex-addresses source))
  (define labels (for/list ([a (in-list (vertex-addresses q))])
                   (vector-ref pi (index-of vs (append prefix a)))))
  (vector->immutable-vector
   (list->vector (map (lambda (x) (index-of labels x)) labels))))
(define (transports q prefix)
  (for/list ([a (in-list (vertex-addresses q))]) (list a (append prefix a))))
(define (budget-tick! b)
  (when (<= (unbox b) 0)
    (raise (exn:protected-limit "protected output materialization cap reached" (current-continuation-marks))))
  (set-box! b (sub1 (unbox b))))
(define (budget-charge! b n)
  (when (> n (unbox b))
    (raise (exn:protected-limit "protected additive expansion cap reached" (current-continuation-marks))))
  (set-box! b (- (unbox b) n)))
(define (sector source pi budget)
  (for/list ([w (in-admissible-cut-witnesses source)]
             #:do [(budget-tick! budget)]
             #:when (ck-protection-retains-cut? source pi w)) w))

(define (restriction-checker evidence budget)
  (define memo (make-hash
                (list (cons (list (ck-protection-evidence-source evidence)
                                  (ck-protection-evidence-partition evidence)) #t))))
  (lambda (q p)
    (unless (hash-ref memo (list q p) #f)
      (budget-tick! budget)
      (define r (prepare-ck-protection q #:policy (ck-protection-evidence-policy evidence)
                                      #:state-limit 256 #:generation-limit 5000 #:time-limit-ms 1000))
      (unless (and (ck-protection-result-evidence r)
                   (equal? p (ck-protection-evidence-partition (ck-protection-result-evidence r))))
        (raise (exn:protected-heredity "flag restriction not independently certified"
                                     (current-continuation-marks) (hash 'term q 'partition p 'result r))))
      (hash-set! memo (list q p) #t))))

(define (protected-ck-observables evidence profile #:cut-limit [cap 4096]
                                 #:heredity-state-limit [heredity-cap 256])
  (check-profile profile)
  (unless (exact-nonnegative-integer? cap) (raise-argument-error 'protected-ck-observables "nonnegative cap" cap))
  (define v (verify-ck-protection-evidence evidence))
  (cond
    [(not (ck-closure-report-valid? v))
     (ck-protected-observables 'UNKNOWN #f #f #f '() '() #f (hash 'verification v))]
    [else
     (define source (ck-protection-evidence-source evidence))
     (define spectrum (ck-live-material-spectrum source profile))
     (define budget (box cap))
     (with-handlers ([exn:protected-heredity?
                     (lambda (e) (ck-protected-observables 'UNKNOWN #f #f #f '() spectrum
                                    (andmap third spectrum) (hash 'reason 'heredity-not-certified
                                                                 'obligation (exn:protected-heredity-details e))))]
                    [exn:protected-limit?
                     (lambda (e) (ck-protected-observables 'UNKNOWN #f #f #f '() spectrum
                                    (andmap third spectrum) (hash 'reason 'materialization-limit 'cap cap)))])
       (unless (checked-node? source)
         (raise-argument-error 'protected-ck-observables "positive native generator (not Box)" source))
       (define K (checked-term-calculus source))
       (define pi (ck-protection-evidence-partition evidence))
       (define unit (empty-ordered-forest K))
       (define whole (make-ordered-forest K (list source)))
       (define heredity-cache (make-hash (list (cons (list source pi) #t))))
       (define heredity-obligations '())
       (define (ensure-restriction! q restricted)
         (unless (hash-ref heredity-cache (list q restricted) #f)
           (budget-tick! budget)
           (define r (prepare-ck-protection q #:policy (ck-protection-evidence-policy evidence)
                       #:state-limit heredity-cap #:generation-limit 5000 #:time-limit-ms 1000))
           (define e (ck-protection-result-evidence r))
           (unless (and e (equal? restricted (ck-protection-evidence-partition e)))
             (raise (exn:protected-heredity "restriction not independently certified"
                      (current-continuation-marks)
                      (hash 'term q 'restricted restricted 'result r))))
           (hash-set! heredity-cache (list q restricted) #t)
           (set! heredity-obligations (cons (list q restricted e) heredity-obligations))))
       (define (checked-sector q p)
         (define ws (sector q p budget))
         (for ([w (in-list ws)])
           (for ([d (in-list (cut-witness-detached w))])
             (define f (detached-entry-term d))
             (ensure-restriction! f (restrict-partition q p f (detached-entry-address d))))
           (define r (cut-witness-remainder w))
           (ensure-restriction! r (restrict-partition q p r '())))
         ws)
       (define kept (checked-sector source pi))
       (define terms
         (cons (ck-occurrence-term 'whole #f whole unit 1 (transports source '()))
               (for/list ([w (in-list kept)])
                 (ck-occurrence-term 'cut w (ordered-cut-forest w)
                   (make-ordered-forest K (list (cut-witness-remainder w))) 1
                   (list (for/list ([d (in-list (cut-witness-detached w))])
                           (transports (detached-entry-term d) (detached-entry-address d)))
                         (transports (cut-witness-remainder w) '()))))))
       (define coaction
         (make-ordered-sum K 2
           (for/list ([t (in-list terms)] #:when (pure? (ck-occurrence-term-left t) profile))
             (cons (vector (ck-occurrence-term-left t) (ck-occurrence-term-right t)) 1))))
       (define memo (make-hash))
       (define (bounded-product a b)
         ;; Charge uncollected cartesian summands BEFORE allocating them;
         ;; collection/cancellation must not conceal exponential work.
         (budget-charge! budget (* (ordered-sum-support-size a) (ordered-sum-support-size b)))
         (ordered-sum-multiply a b))
       (define (antinode q p)
         (hash-ref! memo (list q p)
           (lambda ()
             (for/fold ([s (ordered-sum-negate (ordered-node-basis q))])
                       ([w (in-list (checked-sector q p))] #:unless (null? (cut-witness-addresses w)))
               (define left (antiforest q p (cut-witness-detached w)))
               (ordered-sum-subtract s (bounded-product left
                                          (ordered-node-basis (cut-witness-remainder w))))))))
       (define (antiforest q p detached)
         (for/fold ([s (ordered-unit K)]) ([d (in-list (reverse detached))])
           (define t (detached-entry-term d))
           (bounded-product s (antinode t (restrict-partition q p t (detached-entry-address d))))))
       (define core
         (for/fold ([s (ordered-zero K)]) ([t (in-list terms)] #:when (pure? (ck-occurrence-term-left t) profile))
           (define left
             (if (eq? 'whole (ck-occurrence-term-kind t)) (antinode source pi)
                 (antiforest source pi (cut-witness-detached (ck-occurrence-term-witness t)))))
           (budget-tick! budget)
           (ordered-sum-add s (bounded-product left (ordered-forest-basis (ck-occurrence-term-right t))))))
       (ck-protected-observables 'SAFE (ck-pure-material-selector (ordered-node-basis source) profile)
         coaction core terms spectrum (andmap third spectrum)
         (hash 'carrier 'native-ordered-protected 'profile profile 'cap cap 'work (- cap (unbox budget))
               'source source 'calculus K
               'core-is 'signed-forest-concatenation-not-a-proof
               'heredity 'independently-recomputed
               'heredity-obligations (reverse heredity-obligations))))]))

(define (verify-protected-ck-observables evidence profile proposed #:cut-limit [cap 4096])
  (with-handlers ([exn:fail?
                   (lambda (e) (ck-closure-report #f 'UNKNOWN 'malformed-observable-evidence
                                                  (hash 'message (exn-message e))))])
    (let/ec reject
      (define (bad why [details (hash)]) (reject (ck-closure-report #f 'UNKNOWN why details)))
      (unless (and (ck-protection-evidence? evidence) (ck-protected-observables? proposed))
        (bad 'wrong-observable-evidence-type))
      (define fresh (protected-ck-observables evidence profile #:cut-limit cap))
      (unless (and (eq? (ck-protected-observables-status proposed) 'SAFE)
                   (eq? (ck-protected-observables-status fresh) 'SAFE))
        (bad 'full-observable-recomputation-incomplete
             (hash 'proposed-status (ck-protected-observables-status proposed)
                   'recomputed-status (ck-protected-observables-status fresh)
                   'recomputed-details (ck-protected-observables-details fresh))))
      (define source (ck-protection-evidence-source evidence))
      (define K (checked-term-calculus source))
      (define details (ck-protected-observables-details proposed))
      (unless (and (hash? details) (immutable? details)
                   (eq? source (hash-ref details 'source #f))
                   (eq? K (hash-ref details 'calculus #f))
                   (equal? profile (hash-ref details 'profile #f)))
        (bad 'stale-source-calculus-or-profile))
      (for ([s (in-list (list (ck-protected-observables-selector proposed)
                             (ck-protected-observables-coaction proposed)
                             (ck-protected-observables-core proposed)))])
        (unless (and (ordered-sum? s) (eq? K (ordered-sum-calculus s)))
          (bad 'foreign-observable-sum-provenance)))
      (for ([t (in-list (ck-protected-observables-occurrence-terms proposed))])
        (unless (and (ck-occurrence-term? t)
                     (ordered-forest? (ck-occurrence-term-left t))
                     (ordered-forest? (ck-occurrence-term-right t))
                     (eq? K (ordered-forest-calculus (ck-occurrence-term-left t)))
                     (eq? K (ordered-forest-calculus (ck-occurrence-term-right t))))
          (bad 'foreign-occurrence-term-provenance))
        (define w (ck-occurrence-term-witness t))
        (when w
          (unless (and (cut-witness? w) (eq? source (cut-witness-source w))
                       (checked-term-has-exact-calculus? (cut-witness-source w) K))
            (bad 'foreign-occurrence-witness-source))))
      (define accessors
        (list ck-protected-observables-status ck-protected-observables-selector
              ck-protected-observables-coaction ck-protected-observables-core
              ck-protected-observables-occurrence-terms ck-protected-observables-historical-spectrum
              ck-protected-observables-live-eligible?))
      (for ([get (in-list accessors)]
            [name (in-list '(status selector coaction core occurrence-attachments historical-spectrum live-eligibility))])
        (unless (equal? (get proposed) (get fresh))
          (bad 'altered-complete-observable (hash 'field name 'proposed (get proposed) 'recomputed (get fresh)))))
      (ck-closure-report #t 'SAFE 'independently-recomputed-complete-observables
                         (hash 'source source 'profile profile 'cap cap)))))

(define (full-protected-fidelity old new)
  (cond
    [(not (and (ck-protected-observables? old) (ck-protected-observables? new)
               (eq? (ck-protected-observables-status old) 'SAFE)
               (eq? (ck-protected-observables-status new) 'SAFE)))
     (ck-closure-report #f 'UNKNOWN 'incomplete-represented-observables (hash))]
    [else
     (define names '(selector coaction core occurrence-attachments historical-spectrum))
     (define (objects o)
       (list (ck-protected-observables-selector o) (ck-protected-observables-coaction o)
             (ck-protected-observables-core o) (ck-protected-observables-occurrence-terms o)
             (map (lambda (e) (take e 2)) (ck-protected-observables-historical-spectrum o))))
     (define mismatch (for/first ([name (in-list names)] [a (in-list (objects old))] [b (in-list (objects new))]
                                  #:unless (equal? a b)) (hash 'observable name 'old a 'new b)))
     (if mismatch (ck-closure-report #t 'UNSAFE 'represented-object-difference mismatch)
         (ck-closure-report #t 'SAFE 'full-represented-object-equality (hash)))]))

(define (verify-ck-heredity evidence witness #:state-limit [cap 4096])
  (define v (verify-ck-protection-evidence evidence))
  (cond
    [(not (ck-closure-report-valid? v)) (ck-closure-report #f 'UNKNOWN 'invalid-source-protection (hash))]
    [else
     (define source (ck-protection-evidence-source evidence))
     (define pi (ck-protection-evidence-partition evidence))
     (cond
       [(not (ck-protection-retains-cut? source pi witness))
        (ck-closure-report #f 'UNSAFE 'not-a-protected-source-cut (hash))]
       [else
        (define compartments
          (append (for/list ([d (in-list (cut-witness-detached witness))])
                    (list 'factor (detached-entry-term d) (detached-entry-address d)))
                  (list (list 'remainder (cut-witness-remainder witness) '()))))
        (define entries
          (for/list ([entry (in-list compartments)])
            (match-define (list kind q prefix) entry)
            (define restricted (restrict-partition source pi q prefix))
            (define r (prepare-ck-protection q #:policy (ck-protection-evidence-policy evidence) #:state-limit cap))
            (define recomputed (and (ck-protection-result-evidence r)
                                    (ck-protection-evidence-partition (ck-protection-result-evidence r))))
            (ck-heredity-entry kind q (transports q prefix) restricted recomputed
              (cond [(not recomputed) 'UNKNOWN] [(equal? restricted recomputed) 'SAFE] [else 'UNSAFE]))))
        (define status (cond [(ormap (lambda (e) (eq? 'UNSAFE (ck-heredity-entry-status e))) entries) 'UNSAFE]
                             [(ormap (lambda (e) (eq? 'UNKNOWN (ck-heredity-entry-status e))) entries) 'UNKNOWN]
                             [else 'SAFE]))
        (ck-closure-report (not (eq? status 'UNKNOWN)) status 'recomputed-compartment-protection
                           (hash 'entries entries))])]))

;; Right-iterated uncollected native flags (Delta repeatedly in the last
;; coordinate).  Whole endpoints are explicit; no root cut is manufactured.
(define (protected-ck-flags evidence depth #:cut-limit [cap 4096])
  (unless (exact-positive-integer? depth) (raise-argument-error 'protected-ck-flags "positive depth" depth))
  (define v (verify-ck-protection-evidence evidence))
  (if (not (ck-closure-report-valid? v)) (ck-flag-result 'UNKNOWN '() 'invalid-protection (hash))
      (with-handlers ([exn:protected-heredity?
                      (lambda (e) (ck-flag-result 'UNKNOWN '() 'heredity-not-certified
                                                 (exn:protected-heredity-details e)))]
                     [exn:protected-limit? (lambda (e) (ck-flag-result 'UNKNOWN '() 'materialization-limit (hash 'cap cap)))])
        (define source (ck-protection-evidence-source evidence))
        (define K (checked-term-calculus source))
        (define unit (empty-ordered-forest K))
        (define budget (box cap))
        (define ensure! (restriction-checker evidence budget))
        (define (walk q pi n ws ts)
          (budget-tick! budget)
          (ensure! q pi)
          (cond
            [(= n 1) (list (ck-protected-flag (list (make-ordered-forest K (list q))) (reverse ws) (reverse ts)))]
            [else
             (append
              (list (ck-protected-flag (cons (make-ordered-forest K (list q)) (make-list (sub1 n) unit))
                                       (reverse (cons 'whole ws)) (reverse ts)))
              (append-map
               (lambda (w)
                 (for ([d (in-list (cut-witness-detached w))])
                   (define f (detached-entry-term d))
                   (ensure! f (restrict-partition q pi f (detached-entry-address d))))
                 (define r (cut-witness-remainder w))
                 (define rp (restrict-partition q pi r '()))
                 (for/list ([f (in-list (walk r rp (sub1 n) (cons w ws) (cons (transports r '()) ts)))])
                   (ck-protected-flag (cons (ordered-cut-forest w) (ck-protected-flag-coordinates f))
                                      (ck-protected-flag-witnesses f) (ck-protected-flag-transports f))))
               (sector q pi budget))) ]))
        (ck-flag-result 'SAFE (walk source (ck-protection-evidence-partition evidence) depth '() '())
                        'complete-right-iterated-native-flags (hash 'cap cap 'work (- cap (unbox budget)))))))

;; Two independent separations of the same native stratified flags. Located
;; factors carry their own exact partition and local-to-original prefix.
;; Coordinates and factors are ordered throughout, even at equal labels.
(define (protected-ck-iterated-coproduct evidence rank #:side [side 'right] #:cut-limit [cap 4096])
  (unless (and (exact-positive-integer? rank) (memq side '(left right)))
    (raise-argument-error 'protected-ck-iterated-coproduct "positive rank and left/right side" (list rank side)))
  (define v (verify-ck-protection-evidence evidence))
  (if (not (ck-closure-report-valid? v)) (ck-iterated-result 'UNKNOWN #f '() 'invalid-protection (hash))
      (with-handlers ([exn:protected-heredity?
                      (lambda (e) (ck-iterated-result 'UNKNOWN #f '() 'heredity-not-certified
                                                     (exn:protected-heredity-details e)))]
                     [exn:protected-limit?
                      (lambda (e) (ck-iterated-result 'UNKNOWN #f '() 'materialization-limit (hash 'cap cap)))])
        (define q (ck-protection-evidence-source evidence))
        (define K (checked-term-calculus q))
        (define budget (box cap))
        (define ensure! (restriction-checker evidence budget))
        (define (node-split loc)
          (match-define (list t p prefix) loc)
          (ensure! t p)
          (cons (list (list loc) '() 'whole)
            (for/list ([w (in-list (sector t p budget))])
              (define r (cut-witness-remainder w))
              (for ([d (in-list (cut-witness-detached w))])
                (define f (detached-entry-term d))
                (ensure! f (restrict-partition t p f (detached-entry-address d))))
              (ensure! r (restrict-partition t p r '()))
              (list (for/list ([d (in-list (cut-witness-detached w))])
                      (define f (detached-entry-term d))
                      (list f (restrict-partition t p f (detached-entry-address d))
                            (append prefix (detached-entry-address d))))
                    (list (list r (restrict-partition t p r '()) prefix)) w))))
        (define (word-split word)
          (for/fold ([choices (list (list '() '() '()))]) ([loc (in-list word)])
            (for*/list ([prior (in-list choices)] [next (in-list (node-split loc))])
              (budget-tick! budget)
              (list (append (first prior) (first next)) (append (second prior) (second next))
                    (append (third prior) (list (third next)))))))
        (define terms (list (list (list q (ck-protection-evidence-partition evidence) '()))))
        ;; `terms` initially is a list of ONE coordinate-word; wrap the full
        ;; tensor into the outer collection explicitly to retain empty words.
        (set! terms (list terms))
        (for ([degree (in-range 1 rank)])
          (define index (if (eq? side 'left) 0 (sub1 degree)))
          (set! terms
            (append-map
             (lambda (coords)
               (for/list ([split (in-list (word-split (list-ref coords index)))])
                 (append (take coords index) (list (first split) (second split))
                         (drop coords (add1 index))))) terms)))
        (define sum
          (make-ordered-sum K rank
            (for/list ([coords (in-list terms)])
              (cons (for/vector ([word (in-list coords)])
                      (make-ordered-forest K (map first word))) 1))))
        (ck-iterated-result 'SAFE sum terms 'complete-protected-stratified-flags
                            (hash 'side side 'work (- cap (unbox budget)) 'cap cap)))))

;; Actual old-tensor inclusion is identity on the checked carrier in this
;; frozen snapshot, not an orientation erasure or replacement operation.
;; Old closure is independently obtained by deleting arrow moves from fresh
;; enumeration; zero conserved charge proves there are none to delete.
(define (certify-tensor-mixed-comparison source profiles ambient-maps #:target target #:policy [policy 'bidirectional]
                                        #:cut-limit [cap 4096])
  (unless (and (list? profiles) (andmap list? profiles) (hash? ambient-maps) (immutable? ambient-maps))
    (raise-argument-error 'certify-tensor-mixed-comparison "profiles and immutable ambient map assignment" (list profiles ambient-maps)))
  (for-each check-profile profiles)
  (define transported (and (mixed-schema-calculus? target)
                           (eq? (mixed-schema-sector target) 'mixed)
                           (validate-candidate target (checked-term->raw source))))
  (define r (prepare-ck-protection source #:policy policy))
  (cond
    [(or (not (eq? (mixed-schema-sector (checked-term-calculus source)) 'tensor))
         (not (checked-node? transported))
         (not (eq? 'SAFE (ck-protection-result-status r)))
         (not (zero? (hash-ref (mixed-proof-invariants source) 'arrow-charge))))
     (ck-closure-report #f 'UNKNOWN 'not-a-certified-old-tensor-source (hash))]
    [else
     (define e (ck-protection-result-evidence r))
     (define mr (prepare-ck-protection transported #:policy policy))
     (define me (ck-protection-result-evidence mr))
     (define os (map (lambda (p) (protected-ck-observables e p #:cut-limit cap)) profiles))
     (define c (ck-comparison-certificate source policy e me profiles ambient-maps os))
     (define report (verify-tensor-mixed-comparison c #:cut-limit cap))
     (if (ck-closure-report-valid? report) c report)]))

(define (verify-tensor-mixed-comparison c #:cut-limit [cap 4096])
  (with-handlers ([exn:fail? (lambda (e) (ck-closure-report #f 'UNKNOWN 'invalid-comparison (hash 'message (exn-message e))))])
    (let/ec reject
      (define (bad why) (reject (ck-closure-report #f 'UNKNOWN why (hash))))
      (unless (ck-comparison-certificate? c) (bad 'wrong-comparison-type))
      (define q (ck-comparison-certificate-source c))
      (unless (zero? (hash-ref (mixed-proof-invariants q) 'arrow-charge)) (bad 'nonzero-arrow-charge))
      (define es (list (ck-comparison-certificate-old-evidence c) (ck-comparison-certificate-mixed-evidence c)))
      (unless (andmap ck-protection-evidence? es) (bad 'missing-comparison-evidence))
      (define mq (ck-protection-evidence-source (second es)))
      (define target (checked-term-calculus mq))
      (unless (and (eq? 'tensor (mixed-schema-sector (checked-term-calculus q)))
                   (eq? 'mixed (mixed-schema-sector target))
                   (eq? q (ck-protection-evidence-source (first es)))
                   (equal? mq (validate-candidate target (checked-term->raw q))))
        (bad 'not-the-explicit-native-sector-inclusion))
      (for ([e (in-list es)])
        (unless (and (eq? (ck-comparison-certificate-policy c) (ck-protection-evidence-policy e))
                     (ck-closure-report-valid? (verify-ck-protection-evidence e))) (bad 'stale-comparison-evidence)))
      (unless (equal? (ck-protection-evidence-partition (first es)) (ck-protection-evidence-partition (second es)))
        (bad 'protection-not-transported))
      (define profiles (ck-comparison-certificate-profiles c))
      (for-each check-profile profiles)
      (for ([a (in-list profiles)] [b (in-list (if (null? profiles) '() (cdr profiles)))])
        (unless (andmap (lambda (id) (and (memq id b) #t)) a) (bad 'profiles-not-nested)))
      (define maps (ck-comparison-certificate-ambient-maps c))
      (unless (and (hash? maps) (immutable? maps)) (bad 'ambient-map-assignment-not-immutable))
      (for ([a (in-list (primitive-addresses q))])
        (define occurrence (checked-node-occurrence (vertex-at-address q a)))
        (unless (equal? occurrence (checked-node-occurrence (vertex-at-address mq a)))
          (bad 'material-occurrence-interface-or-id-changed))
        (unless (hash-has-key? maps (concrete-occurrence-id occurrence))
          (bad 'missing-ambient-material-map)))
      (unless (= (length profiles) (length (ck-comparison-certificate-observations c))) (bad 'missing-profile-observation))
      (for ([p (in-list profiles)] [stored (in-list (ck-comparison-certificate-observations c))])
        (define old (protected-ck-observables (first es) p #:cut-limit cap))
        (define mixed (protected-ck-observables (second es) p #:cut-limit cap))
        (unless (and (eq? 'SAFE (ck-closure-report-status (full-protected-fidelity (transport-observables old target) mixed)))
                     (eq? 'SAFE (ck-closure-report-status (full-protected-fidelity stored old))))
          (bad 'full-profile-comparison-incomplete-or-different)))
      ;; pi_small pi_large = pi_small is the justified vertical composition.
      ;; Coactions/cores at DISTINCT profiles need not be equal. Horizontal
      ;; transport is identity on every actual occurrence, typed attachment,
      ;; selector/coaction/core term; ambient IDs/maps do not change.
      (ck-closure-report #t 'SAFE 'tensor-mixed-identity-inclusion-and-profile-composition
        (hash 'arrow-charge 0 'horizontal-map 'explicit-raw-revalidation-in-extended-native-sector
              'vertical-law 'pi-small-compose-pi-large-equals-pi-small
              'not-claimed 'different-profile-coactions-equal
              'admission-base-extension 'separate-from-trust-profile-growth)))))

;; Cross-snapshot equality is checked AFTER explicit transport through the
;; shared raw syntax. Structural presentation equality is never a provenance
;; cast. Reconstructed witnesses retain the same source addresses/interfaces.
(define (transport-observables o target)
  (define (node q)
    (define t (validate-candidate target (checked-term->raw q)))
    (unless (checked-node? t) (error 'transport-observables "native inclusion recheck failed")) t)
  (define (forest f) (make-ordered-forest target (map node (ordered-forest-factors f))))
  (define (sum s)
    (make-ordered-sum target (ordered-sum-rank s)
      (for/list ([t (in-list (ordered-sum-terms s))])
        (cons (for/vector ([f (in-vector (car t))]) (forest f)) (cdr t)))))
  (if (not (eq? 'SAFE (ck-protected-observables-status o))) o
      (struct-copy ck-protected-observables o
        [selector (sum (ck-protected-observables-selector o))]
        [coaction (sum (ck-protected-observables-coaction o))]
        [core (sum (ck-protected-observables-core o))]
        [occurrence-terms
         (for/list ([t (in-list (ck-protected-observables-occurrence-terms o))])
           (define w (ck-occurrence-term-witness t))
           (ck-occurrence-term (ck-occurrence-term-kind t)
             (and w (make-cut-witness (node (cut-witness-source w)) (cut-witness-addresses w)))
             (forest (ck-occurrence-term-left t)) (forest (ck-occurrence-term-right t))
             (ck-occurrence-term-coefficient t) (ck-occurrence-term-transports t)))])))
