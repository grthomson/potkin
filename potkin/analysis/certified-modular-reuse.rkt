#lang racket/base

;; Separate semantic, operational and provenance contracts on native CK cuts.
;; These records are analysis evidence, never an alternative proof carrier.
(require racket/list racket/match
         "../kernel/address.rkt" "../kernel/calculus.rkt"
         "../kernel/check.rkt" "../kernel/context.rkt" "../kernel/cut.rkt"
         "../kernel/mixed-schema.rkt"
         "ck-boundary-certification.rkt" "ck-rational-semantics.rkt"
         "ck-protected-reuse.rkt")

(provide (struct-out reuse-contract) (struct-out reuse-preparation)
         (struct-out reuse-update) (struct-out reuse-verification)
         (struct-out opaque-replay-step) (struct-out opaque-replay-certificate)
         prepare-reuse apply-reuse-update verify-reuse-update
         project-opaque-history verify-opaque-replay opaque-fill
         reuse-update-contracts reuse-contract-certified?)

(struct reuse-contract (status evidence reason details) #:transparent)
(struct reuse-preparation
  (source frontier remainder providers compiled summaries model observation
          policy profile requested boundary protection observables replay dependencies stats)
  #:transparent)
(struct reuse-update
  (preparation replacements model profile filled replayed boundary behavior replay
               material fidelity plan accepted?) #:transparent)
(struct reuse-verification (valid? reason details) #:transparent)
(struct opaque-replay-step (move before-holes after-holes) #:transparent)
(struct opaque-replay-certificate
  (source frontier policy history initial steps terminal terminal-holes) #:transparent)

(define contract-statuses
  (hash 'behavior '(EQUAL DIFFERENT UNKNOWN) 'boundary '(SAFE UNSAFE UNKNOWN MALFORMED)
        'replay '(ELIGIBLE INELIGIBLE UNKNOWN) 'profile '(ELIGIBLE INELIGIBLE UNKNOWN)
        'fidelity '(SAFE UNSAFE UNKNOWN)))
(define (reuse-contract-certified? c name)
  (and (reuse-contract? c)
       (eq? (reuse-contract-status c)
            (hash-ref (hash 'behavior 'EQUAL 'boundary 'SAFE 'replay 'ELIGIBLE
                            'profile 'ELIGIBLE 'fidelity 'SAFE) name #f))))
(define (reuse-update-contracts u)
  (hash 'boundary (reuse-update-boundary u) 'behavior (reuse-update-behavior u)
        'replay (reuse-update-replay u) 'profile (reuse-update-material u)
        'fidelity (reuse-update-fidelity u)))
(define (unknown why [details (hash)]) (reuse-contract 'UNKNOWN #f why details))
(define (timed thunk)
  (define start (current-inexact-milliseconds))
  (define value (thunk))
  (values value (- (current-inexact-milliseconds) start)))
(define (native! who p)
  (unless (checked-term? p) (raise-argument-error who "native checked term" p)) p)

;; Traverse ONLY rigid remainder vertices. Every provider is a checker-sealed
;; handle; assembly checks its root interface and exact registry, not its body.
(define (opaque-fill remainder providers)
  (native! 'opaque-fill remainder)
  (unless (and (list? providers) (andmap complete-proof? providers)
               (= (length providers) (length (puncture-addresses remainder))))
    (raise-argument-error 'opaque-fill "one complete provider per physical hole" providers))
  (define remaining providers)
  (define K (checked-term-calculus remainder))
  (define (walk p)
    (if (checked-hole? p)
        (let ([q (car remaining)])
          (set! remaining (cdr remaining))
          (unless (and (eq? K (checked-term-calculus q))
                       (equal? (derivation-root-boundary p) (derivation-root-boundary q)))
            (raise-arguments-error 'opaque-fill "provider provenance or entire interface mismatch" "provider" q))
          q)
        (let ([q (assemble-checked-application K (checked-node-occurrence p)
                                              (map walk (checked-node-children p)))])
          (unless (checked-node? q) (error 'opaque-fill "native checker rejected assembly: ~e" q))
          q)))
  (walk remainder))

(define (move-key m)
  (list (ck-schema-move-schema m) (ck-schema-move-direction m)
        (ck-schema-move-address m) (ck-schema-move-read-shell m)
        (ck-schema-move-replacement-shell m) (ck-schema-move-providers m)))
(define (transport-hole m a)
  (define root (ck-schema-move-address m))
  (define port
    (findf (lambda (pr) (address-prefix? (append root (first pr)) a))
           (ck-schema-move-providers m)))
  (if port
      (append root (second port) (drop a (+ (length root) (length (first port)))))
      a))
(define (hole-map remainder)
  (for/list ([a (in-list (puncture-addresses remainder))] [i (in-naturals)]) (list i a)))
(define (ordered-hole-providers holes providers)
  (map (lambda (p) (list-ref providers (first p)))
       (sort holes (lambda (p q) (address<? (second p) (second q))))))
(define (step-holes m holes)
  (map (lambda (h) (list (first h) (transport-hole m (second h)))) holes))
(define (reads-provider? m holes)
  (for*/first ([a (in-list (ck-schema-move-read-shell m))]
               [h (in-list holes)]
               #:when (address-prefix? (second h) (append (ck-schema-move-address m) a)))
    (hash 'provider-index (first h) 'interface-address (second h)
          'read-address (append (ck-schema-move-address m) a))))
(define (moves-for p policy)
  (enumerate-ck-schema-moves p #:policy policy #:generation-limit 20000 #:time-limit-ms 10000))

;; A supplied event must both be a native checked source event and have the
;; same routed open event. Projection never normalizes or peeks into fillers.
(define (project-opaque-history source frontier history #:policy [policy 'bidirectional])
  (let/ec stop
    (define (fail why data) (stop (reuse-contract 'INELIGIBLE #f why data)))
    (unless (and (cut-witness? frontier) (eq? source (cut-witness-source frontier))
                 (complete-proof? source) (list? history) (andmap ck-schema-move? history))
      (fail 'malformed-history-or-frontier (hash)))
    (define initial (cut-witness-remainder frontier))
    (define K (checked-term-calculus source))
    (unless (checked-term-has-exact-calculus? initial K) (fail 'foreign-remainder-provenance (hash)))
    (define old-providers (map detached-entry-term (cut-witness-detached frontier)))
    (define current source) (define open initial) (define holes (hole-map initial))
    (define steps '())
    (for ([event (in-list history)] [i (in-naturals)])
      (unless (checked-term-has-exact-calculus? (ck-schema-move-target event) K)
        (fail 'foreign-event-target-provenance (hash 'event i)))
      (define-values (actual complete? reason) (moves-for current policy))
      (unless (member event actual equal?)
        (if complete? (fail 'not-an-admitted-source-event (hash 'event i))
            (stop (unknown 'history-check-incomplete (hash 'event i 'reason reason)))))
      (define exposed (reads-provider? event holes))
      (when exposed (fail 'recorded-event-reads-provider (hash 'event i 'exposure exposed)))
      (define-values (open-moves open-complete? open-reason) (moves-for open policy))
      (unless (equal? current (opaque-fill open (ordered-hole-providers holes old-providers)))
        (fail 'projected-before-refill-mismatch (hash 'event i)))
      (define projected
        (findf (lambda (m)
                 (and (equal? (move-key event) (move-key m))
                      (equal? (ck-schema-move-target event)
                        (opaque-fill (ck-schema-move-target m)
                          (ordered-hole-providers (step-holes m holes) old-providers))))) open-moves))
      (unless projected
        (if open-complete? (fail 'event-not-open-at-complete-interfaces (hash 'event i))
            (stop (unknown 'open-projection-incomplete (hash 'event i 'reason open-reason)))))
      (define next-holes (step-holes projected holes))
      (unless (equal? (sort (map second next-holes) address<?)
                      (puncture-addresses (ck-schema-move-target projected)))
        (fail 'physical-hole-transport-mismatch (hash 'event i)))
      (set! steps (append steps (list (opaque-replay-step projected holes next-holes))))
      (set! holes next-holes) (set! open (ck-schema-move-target projected))
      (set! current (ck-schema-move-target event)))
    (define c (opaque-replay-certificate source frontier policy history initial steps open holes))
    (reuse-contract 'ELIGIBLE c 'checked-open-event-word
                    (hash 'events (length steps) 'provider-body-reads 0))))

;; Fresh matching of every open event, including exact routes, not a call to
;; the projection producer. Source-event validation binds the input history.
(define (verify-opaque-replay c #:source [source #f] #:frontier [frontier #f])
  (let/ec reject
    (define (bad why) (reject (reuse-verification #f why (hash))))
    (with-handlers ([exn:fail? (lambda (_) (bad 'malformed-replay-evidence))])
      (unless (opaque-replay-certificate? c) (bad 'not-replay-evidence))
      (define s (opaque-replay-certificate-source c))
      (define f (opaque-replay-certificate-frontier c))
      (define K (checked-term-calculus s))
      (unless (and (or (not source) (eq? s source))
                   (or (not frontier) (equal? f frontier))
                   (eq? s (cut-witness-source f))
                   (checked-term-has-exact-calculus? (opaque-replay-certificate-initial c) K)
                   (checked-term-has-exact-calculus? (opaque-replay-certificate-terminal c) K)
                   (equal? (cut-witness-remainder f) (opaque-replay-certificate-initial c))
                   (= (length (opaque-replay-certificate-history c))
                      (length (opaque-replay-certificate-steps c))))
        (bad 'source-frontier-history-mismatch))
      (define open (opaque-replay-certificate-initial c))
      (define old s) (define holes (hole-map open))
      (define old-providers (map detached-entry-term (cut-witness-detached f)))
      (for ([step (in-list (opaque-replay-certificate-steps c))]
            [event (in-list (opaque-replay-certificate-history c))])
        (define m (opaque-replay-step-move step))
        (unless (and (checked-term-has-exact-calculus? (ck-schema-move-target event) K)
                     (checked-term-has-exact-calculus? (ck-schema-move-target m) K))
          (bad 'foreign-event-target-provenance))
        (define-values (source-moves _sc _sr) (moves-for old (opaque-replay-certificate-policy c)))
        (define-values (open-moves _oc _or) (moves-for open (opaque-replay-certificate-policy c)))
        (unless (and (member event source-moves equal?) (member m open-moves equal?)
                     (equal? (move-key event) (move-key m))
                     (equal? old (opaque-fill open (ordered-hole-providers holes old-providers)))
                     (equal? (ck-schema-move-target event)
                       (opaque-fill (ck-schema-move-target m)
                         (ordered-hole-providers (step-holes m holes) old-providers)))
                     (not (reads-provider? m holes))
                     (equal? holes (opaque-replay-step-before-holes step))
                     (equal? (step-holes m holes) (opaque-replay-step-after-holes step)))
          (bad 'invalid-open-event-or-transport))
        (set! holes (step-holes m holes)) (set! open (ck-schema-move-target m))
        (set! old (ck-schema-move-target event)))
      (unless (and (equal? open (opaque-replay-certificate-terminal c))
                   (equal? holes (opaque-replay-certificate-terminal-holes c))
                   (equal? (puncture-addresses open) (sort (map second holes) address<?)))
        (bad 'terminal-hole-mismatch))
      (reuse-verification #t 'independently-checked-open-replay (hash 'provider-body-reads 0)))))

(define (profile-contract proof profile)
  (define K (checked-term-calculus proof))
  (define rejected
    (for/list ([a (in-list (vertex-addresses proof))]
               #:do [(define o (checked-node-occurrence (vertex-at-address proof a)))]
               #:when (and (eq? (mixed-occurrence-family K o) 'material)
                           (not (memq (concrete-occurrence-id o) profile))))
      (list a (concrete-occurrence-id o))))
  (reuse-contract (if (null? rejected) 'ELIGIBLE 'INELIGIBLE) rejected
                  (if (null? rejected) 'all-live-material-ids-admitted 'live-material-id-outside-profile)
                  (hash 'profile profile 'historical-support-not-used #t)))

(define (crossing-exposure c)
  (define crossing (ck-boundary-certificate-crossing c))
  (define source (ck-boundary-certificate-source c))
  (define pi (ck-marked-state-partition
              (list-ref (ck-boundary-certificate-states c) (ck-boundary-certificate-terminal c))))
  (define rep (first crossing))
  (define interfaces (filter list? (remove-duplicates (list (third crossing) (fifth crossing)) equal?)))
  (hash 'source-origin-block rep
        'source-region (for/list ([a (in-list (vertex-addresses source))] [i (in-naturals)]
                                  #:when (= (vector-ref pi i) rep)) a)
        'interfaces (for/list ([a (in-list interfaces)])
                      (list a (derivation-root-boundary (vertex-at-address source a))))
        'resume-recomputation 'crossing-source-origin-block 'global-cost-minimal? #f))

(define (boundary-contract source frontier policy cap gen ms #:protection [supplied #f])
  (define protected (or supplied (prepare-ck-protection source #:policy policy #:state-limit cap
                      #:generation-limit gen #:time-limit-ms ms)))
  (define evidence (ck-protection-result-evidence protected))
  (if (and (eq? (ck-protection-result-status protected) 'SAFE)
           (ck-protection-retains-cut? source (ck-protection-evidence-partition evidence) frontier))
      (reuse-contract 'SAFE evidence 'independently-certified-partition-retains-frontier (hash))
      (let ([result (certify-native-ck-boundary source frontier #:policy policy
                      #:state-limit cap #:generation-limit gen #:time-limit-ms ms)])
        (reuse-contract (ck-boundary-result-status result) (ck-boundary-result-certificate result)
                        (ck-boundary-result-reason result)
                        (if (eq? (ck-boundary-result-status result) 'UNSAFE)
                            (hash-set (ck-boundary-result-details result) 'exposure-region
                                      (crossing-exposure (ck-boundary-result-certificate result)))
                            (ck-boundary-result-details result))))))
(define (dependencies source frontier model observation policy profile history)
  (hash 'source source 'registry (checked-term-calculus source)
        'frontier-addresses (cut-witness-addresses frontier)
        'interfaces (map telescope-entry-requirement (premise-telescope (cut-witness-remainder frontier)))
        'occurrence-routes (checked-term->raw (cut-witness-remainder frontier))
        'interpretation model 'interpretation-version (rational-model-version model)
        'observation observation 'policy policy 'profile profile 'history history
        'conversion-version ck-conversion-version 'routing-version ck-canonicalization-version))

(define (prepare-reuse source frontier model #:policy [policy 'bidirectional]
                       #:observation [observation #f] #:profile [profile '()]
                       #:history [history '()] #:require [requested '(behavior boundary replay profile)]
                       #:state-limit [cap 256] #:generation-limit [gen 20000]
                       #:time-limit-ms [ms 10000] #:semantic-budget [budget (make-semantic-budget)])
  (define semantic-phase 'context-compilation)
  (with-handlers ([exn:fail:semantic-budget?
                   (lambda (e) (unknown 'semantic-budget-exhausted
                     (hash 'phase semantic-phase 'reason (exn:fail:semantic-budget-reason e)
                           'preparation-created? #f)))])
  (unless (and (complete-proof? source) (cut-witness? frontier)
               (eq? source (cut-witness-source frontier)) (cut-witness-reconstructs? frontier)
               (eq? (rational-model-calculus model) (checked-term-calculus source)))
    (raise-arguments-error 'prepare-reuse "exact checked source, frontier and model required"))
  (unless (and (list? requested) (andmap (lambda (x) (memq x '(behavior boundary replay profile fidelity))) requested))
    (raise-argument-error 'prepare-reuse "list of named contracts" requested))
  (define providers (map detached-entry-term (cut-witness-detached frontier)))
  (define remainder (cut-witness-remainder frontier))
  (define-values (compiled compile-ms) (timed (lambda () (compile-rational-context model remainder #:budget budget))))
  (set! semantic-phase 'provider-admission)
  (define-values (summaries admission-ms) (timed (lambda () (map (lambda (p) (admit-rational-proof model p #:budget budget)) providers))))
  (define-values (protection protection-ms)
    (timed (lambda () (prepare-ck-protection source #:policy policy #:state-limit cap
                        #:generation-limit gen #:time-limit-ms ms))))
  (define-values (boundary boundary-ms)
    (timed (lambda () (boundary-contract source frontier policy cap gen ms #:protection protection))))
  (define-values (observables provenance-ms)
    (timed (lambda () (and (memq 'fidelity requested) (eq? (ck-protection-result-status protection) 'SAFE)
                          (protected-ck-observables (ck-protection-result-evidence protection) profile)))))
  (define-values (replay replay-ms) (timed (lambda () (project-opaque-history source frontier history #:policy policy))))
  (reuse-preparation source frontier remainder providers compiled summaries model observation
    policy profile requested boundary protection observables replay
    (dependencies source frontier model observation policy profile history)
    (hash 'context-compilations 1 'provider-admissions (length providers)
          'provider-vertices (apply + (map derivation-vertex-count providers))
          'scaffold-vertices (derivation-vertex-count remainder)
          'context-stats (compiled-rational-context-stats compiled)
          'phase-ms (hash 'provider-admission admission-ms 'context-compilation compile-ms
                          'protection-preparation protection-ms 'frontier-check boundary-ms
                          'provenance-query provenance-ms 'replay-projection replay-ms)))))

;; Registry changes are explicit rechecking, never structural-equality casts.
(define (lift-remainder p K)
  (if (eq? K (checked-term-calculus p)) p
      (let ([q (validate-candidate K (checked-term->raw p) #:expected (derivation-root-boundary p))])
        (unless (checked-term? q) (error 'apply-reuse-update "target registry rejects scaffold: ~e" q)) q)))
(define (compatible-model? old new)
  (rational-model-extension? old new))

(define (apply-reuse-update prepared replacements #:model [model (reuse-preparation-model prepared)]
                           #:profile [profile (reuse-preparation-profile prepared)]
                           #:history [history #f] #:state-limit [cap 256]
                           #:generation-limit [gen 20000] #:time-limit-ms [ms 10000]
                           #:semantic-budget [budget (make-semantic-budget)])
  (define semantic-phase 'provider-admission)
  (with-handlers ([exn:fail:semantic-budget?
                   (lambda (e) (unknown 'semantic-budget-exhausted
                     (hash 'phase semantic-phase 'reason (exn:fail:semantic-budget-reason e)
                           'accepted-update-created? #f)))])
  (unless (reuse-preparation? prepared) (raise-argument-error 'apply-reuse-update "reuse-preparation?" prepared))
  (define K (rational-model-calculus model))
  (define remainder (lift-remainder (reuse-preparation-remainder prepared) K))
  (define-values (filled filling-ms) (timed (lambda () (opaque-fill remainder replacements))))
  (define same-model? (eq? model (reuse-preparation-model prepared)))
  (define unchanged
    (for/list ([p (in-list replacements)] [old (in-list (reuse-preparation-providers prepared))])
      (and same-model? (eq? p old))))
  (define-values (summaries admission-ms)
    (timed (lambda () (for/list ([p (in-list replacements)] [keep? (in-list unchanged)]
               [old (in-list (reuse-preparation-summaries prepared))])
      (if keep? old (admit-rational-proof model p #:budget budget))))))
  (define old-model (reuse-preparation-model prepared))
  (set! semantic-phase 'context-compilation)
  (define-values (compiled compile-ms)
    (timed (lambda () (if (compatible-model? old-model model) (reuse-preparation-compiled prepared)
        (compile-rational-context model remainder #:budget budget)))))
  ;; Compiled rigid material maps must not silently change. Under a changed
  ;; interpretation comparison is between separately admitted native proofs.
  (set! semantic-phase 'joint-behavior)
  (define-values (behavior behavior-ms)
    (timed (lambda () (if (compatible-model? old-model model)
        (let ([b (compare-rational-tuples compiled (reuse-preparation-summaries prepared) summaries
                   #:observation (reuse-preparation-observation prepared)
                   #:old-proof (reuse-preparation-source prepared) #:new-proof filled #:new-model model #:budget budget)])
          (reuse-contract (behavior-result-status b) b (behavior-result-reason b) (behavior-result-stats b)))
        (unknown 'changed-ambient-map-assignment (hash 'recompiled #t))))))
  (define frontier (make-cut-witness filled (cut-witness-addresses (reuse-preparation-frontier prepared))))
  (define-values (protection protection-ms)
    (timed (lambda () (prepare-ck-protection filled #:policy (reuse-preparation-policy prepared)
                       #:state-limit cap #:generation-limit gen #:time-limit-ms ms))))
  (define-values (boundary boundary-ms)
    (timed (lambda () (boundary-contract filled frontier (reuse-preparation-policy prepared) cap gen ms #:protection protection))))
  (define-values (replay replay-ms)
    (timed (lambda () (cond
      [(not (eq? K (checked-term-calculus (reuse-preparation-source prepared))))
       (unknown 'registry-change-needs-new-history-admission)]
      [history (project-opaque-history (reuse-preparation-source prepared)
                 (reuse-preparation-frontier prepared) history #:policy (reuse-preparation-policy prepared))]
      [else (reuse-preparation-replay prepared)]))))
  (define-values (replayed assembly-ms)
    (timed (lambda () (and (eq? (reuse-contract-status replay) 'ELIGIBLE)
         (let ([c (reuse-contract-evidence replay)])
           (opaque-fill (opaque-replay-certificate-terminal c)
             (ordered-hole-providers (opaque-replay-certificate-terminal-holes c) replacements)))))))
  (define-values (material profile-ms) (timed (lambda () (profile-contract filled profile))))
  (define-values (observables provenance-ms)
    (timed (lambda () (and (memq 'fidelity (reuse-preparation-requested prepared))
         (eq? (ck-protection-result-status protection) 'SAFE)
         (protected-ck-observables (ck-protection-result-evidence protection) profile)))))
  (define fidelity
    (if (and observables (reuse-preparation-observables prepared))
        (let ([v (full-protected-fidelity (reuse-preparation-observables prepared) observables)])
          (reuse-contract (ck-closure-report-status v)
            (list (reuse-preparation-observables prepared) observables) (ck-closure-report-reason v)
            (ck-closure-report-details v)))
        (unknown 'full-protected-object-unavailable)))
  (define changed (for/list ([keep? (in-list unchanged)] [i (in-naturals)] #:unless keep?) i))
  (define plan
    (hash 'cached-remainder (if (compatible-model? old-model model) 'VALID 'RECOMPILED)
          'cached-summaries (for/list ([keep? (in-list unchanged)] [i (in-naturals)] #:when keep?) i)
          'changed-components changed 'provider-admissions (length changed)
          'admitted-provider-vertices (for/sum ([i (in-list changed)]) (derivation-vertex-count (list-ref replacements i)))
          'context-compilations (if (compatible-model? old-model model) 0 1)
          'affected-scaffold-interfaces (map (lambda (i) (list-ref (cut-witness-addresses frontier) i)) changed)
          'boundary-recertified #t 'source-certificate-reused #f
          'profile-invalidated (not (equal? profile (reuse-preparation-profile prepared)))
          'replayed-events (if replayed (length (opaque-replay-certificate-steps (reuse-contract-evidence replay))) 0)
          'replay-provider-body-reads 0 'exposure (reuse-contract-details boundary)
          'global-minimum-cost-claimed #f
          'phase-ms (hash 'provider-admission admission-ms 'joint-behavior behavior-ms
                          'native-filling filling-ms 'context-compilation compile-ms
                          'protection-preparation protection-ms 'frontier-check boundary-ms
                          'replay-check replay-ms 'replay-assembly assembly-ms
                          'live-profile profile-ms 'provenance-query provenance-ms)))
  (define contracts (hash 'behavior behavior 'boundary boundary 'replay replay 'profile material 'fidelity fidelity))
  (define accepted? (for/and ([name (in-list (reuse-preparation-requested prepared))])
                      (reuse-contract-certified? (hash-ref contracts name) name)))
  (reuse-update prepared replacements model profile filled replayed boundary behavior replay material fidelity plan accepted?)))

;; Independent verification recomputes denotations on native filled proofs,
;; checks returned matrices/counterinputs, and validates boundary/replay evidence.
;; It does not call preparation or update or trust their acceptance flag.
(define (verify-reuse-update prepared result)
  (let/ec reject
    (define (bad why [data (hash)]) (reject (reuse-verification #f why data)))
    (with-handlers ([exn:fail? (lambda (e) (bad 'malformed-update (hash 'message (exn-message e))))])
      (unless (and (reuse-preparation? prepared) (reuse-update? result)
                   (eq? prepared (reuse-update-preparation result))) (bad 'preparation-identity-mismatch))
      (unless (and (list? (reuse-preparation-requested prepared))
                   (andmap (lambda (name) (hash-has-key? contract-statuses name))
                           (reuse-preparation-requested prepared)))
        (bad 'invalid-requested-contract-list))
      (for ([(name c) (in-hash (reuse-update-contracts result))])
        (unless (and (reuse-contract? c) (memq (reuse-contract-status c) (hash-ref contract-statuses name)))
          (bad 'invalid-status-for-named-contract (hash 'contract name))))
      (define source (reuse-preparation-source prepared))
      (define f (reuse-preparation-frontier prepared))
      (unless (and (eq? source (cut-witness-source f)) (cut-witness-reconstructs? f)
                   (equal? (reuse-preparation-dependencies prepared)
                     (dependencies source f (reuse-preparation-model prepared)
                       (reuse-preparation-observation prepared) (reuse-preparation-policy prepared)
                       (reuse-preparation-profile prepared)
                       (hash-ref (reuse-preparation-dependencies prepared) 'history))))
        (bad 'stale-preparation-dependencies))
      (unless (and (eq? (reuse-preparation-remainder prepared) (cut-witness-remainder f))
                   (eq? (compiled-rational-context-source (reuse-preparation-compiled prepared))
                        (reuse-preparation-remainder prepared))
                   (eq? (compiled-rational-context-model (reuse-preparation-compiled prepared))
                        (reuse-preparation-model prepared))
                   (equal? (reuse-preparation-providers prepared) (map detached-entry-term (cut-witness-detached f)))
                   (= (length (reuse-preparation-providers prepared)) (length (reuse-preparation-summaries prepared))))
        (bad 'unbound-cached-context-or-providers))
      (for ([provider (in-list (reuse-preparation-providers prepared))]
            [summary (in-list (reuse-preparation-summaries prepared))])
        (unless (and (eq? provider (semantic-summary-proof summary))
                     (eq? (reuse-preparation-model prepared) (semantic-summary-model summary)))
          (bad 'unbound-cached-provider-summary)))
      (define new (reuse-update-filled result))
      (define K (rational-model-calculus (reuse-update-model result)))
      (unless (and (checked-term-has-exact-calculus? new K)
                   (equal? new (opaque-fill (lift-remainder (reuse-preparation-remainder prepared) K)
                                           (reuse-update-replacements result)))) (bad 'incorrect-native-refilling))
      (define b (reuse-update-behavior result))
      (when (memq (reuse-contract-status b) '(EQUAL DIFFERENT))
        (define old-m (semantic-summary-matrix (admit-rational-proof (reuse-preparation-model prepared) source)))
        (define new-m (semantic-summary-matrix (admit-rational-proof (reuse-update-model result) new)))
        (define O (reuse-preparation-observation prepared))
        (define old-O (if O (qmatrix-multiply O old-m) old-m))
        (define new-O (if O (qmatrix-multiply O new-m) new-m))
        (define evidence (reuse-contract-evidence b))
        (unless (and (behavior-result? evidence)
                     (equal? old-O (behavior-result-old-observed evidence))
                     (equal? new-O (behavior-result-new-observed evidence))
                     (eq? (reuse-contract-status b) (if (equal? old-O new-O) 'EQUAL 'DIFFERENT)))
          (bad 'incorrect-behavior-evidence))
        (when (eq? (reuse-contract-status b) 'DIFFERENT)
          (define w (behavior-result-witness evidence))
          (unless (and (semantic-counterinput? w) (semantic-counterinput-verified? w)
                       (equal? (qmatrix-ref old-O (semantic-counterinput-observed-index w) (semantic-counterinput-input-index w))
                               (semantic-counterinput-old-value w))
                       (equal? (qmatrix-ref new-O (semantic-counterinput-observed-index w) (semantic-counterinput-input-index w))
                               (semantic-counterinput-new-value w))
                       (not (equal? (semantic-counterinput-old-value w) (semantic-counterinput-new-value w))))
            (bad 'incorrect-basis-counterinput))))
      (define boundary (reuse-update-boundary result))
      (when (memq (reuse-contract-status boundary) '(SAFE UNSAFE))
        (define evidence (reuse-contract-evidence boundary))
        (define new-frontier (make-cut-witness new (cut-witness-addresses f)))
        (define v
          (if (ck-protection-evidence? evidence)
              (begin
                (unless (and (eq? new (ck-protection-evidence-source evidence))
                             (eq? (reuse-preparation-policy prepared) (ck-protection-evidence-policy evidence))
                             (ck-protection-retains-cut? new (ck-protection-evidence-partition evidence) new-frontier))
                  (bad 'source-bound-partition-frontier-mismatch))
                (verify-ck-protection-evidence evidence))
              (verify-ck-boundary-certificate evidence #:source new #:frontier new-frontier
                    #:policy (reuse-preparation-policy prepared))))
        (unless (and (ck-closure-report-valid? v) (eq? (ck-closure-report-status v) (reuse-contract-status boundary)))
          (bad 'invalid-updated-boundary-certificate))
        (when (eq? (reuse-contract-status boundary) 'UNSAFE)
          (unless (equal? (hash-ref (reuse-contract-details boundary) 'exposure-region)
                          (crossing-exposure evidence)) (bad 'incorrect-exposure-region))))
      (define replay (reuse-update-replay result))
      (when (eq? (reuse-contract-status replay) 'ELIGIBLE)
        (define c (reuse-contract-evidence replay))
        (unless (reuse-verification-valid? (verify-opaque-replay c #:source source #:frontier f))
          (bad 'invalid-opaque-replay))
        (unless (and (checked-term-has-exact-calculus? (reuse-update-replayed result) K)
                     (equal? (reuse-update-replayed result)
                       (opaque-fill (opaque-replay-certificate-terminal c)
                         (ordered-hole-providers (opaque-replay-certificate-terminal-holes c)
                                                 (reuse-update-replacements result)))))
          (bad 'incorrect-replayed-target)))
      (unless (equal? (reuse-update-material result) (profile-contract new (reuse-update-profile result)))
        (bad 'incorrect-live-profile-evidence))
      (define fidelity (reuse-update-fidelity result))
      (when (memq (reuse-contract-status fidelity) '(SAFE UNSAFE))
        (define pair (reuse-contract-evidence fidelity))
        (define old-protection (reuse-preparation-protection prepared))
        (unless (and (eq? (ck-protection-result-status old-protection) 'SAFE)
                     (ck-protection-evidence? (ck-protection-result-evidence old-protection))
                     (eq? source (ck-protection-evidence-source (ck-protection-result-evidence old-protection)))
                     (eq? (reuse-preparation-policy prepared)
                          (ck-protection-evidence-policy (ck-protection-result-evidence old-protection)))
                     (ck-closure-report-valid?
                       (verify-ck-protection-evidence (ck-protection-result-evidence old-protection))))
          (bad 'unverified-original-protection))
        (define fresh-old
          (protected-ck-observables (ck-protection-result-evidence old-protection)
                                   (reuse-preparation-profile prepared)))
        (define new-protection (prepare-ck-protection new #:policy (reuse-preparation-policy prepared)))
        (unless (eq? (ck-protection-result-status new-protection) 'SAFE) (bad 'unverified-updated-protection))
        (define fresh-new (protected-ck-observables (ck-protection-result-evidence new-protection)
                                                  (reuse-update-profile result)))
        (unless (and (eq? 'SAFE (ck-closure-report-status (full-protected-fidelity fresh-old (first pair))))
                     (eq? 'SAFE (ck-closure-report-status (full-protected-fidelity fresh-new (second pair)))))
          (bad 'unbound-or-altered-full-fidelity-evidence))
        (define v (full-protected-fidelity (first pair) (second pair)))
        (unless (eq? (ck-closure-report-status v) (reuse-contract-status fidelity)) (bad 'incorrect-fidelity-evidence)))
      (define expected? (for/and ([name (in-list (reuse-preparation-requested prepared))])
                          (reuse-contract-certified? (hash-ref (reuse-update-contracts result) name) name)))
      (unless (eq? expected? (reuse-update-accepted? result)) (bad 'incorrect-overall-plan))
      (define same-model? (eq? (reuse-update-model result) (reuse-preparation-model prepared)))
      (define keeps
        (for/list ([q (in-list (reuse-update-replacements result))]
                   [old (in-list (reuse-preparation-providers prepared))]) (and same-model? (eq? q old))))
      (define changes (for/list ([keep? (in-list keeps)] [i (in-naturals)] #:unless keep?) i))
      (define expected-plan
        (hash 'cached-remainder (if (compatible-model? (reuse-preparation-model prepared) (reuse-update-model result)) 'VALID 'RECOMPILED)
              'cached-summaries (for/list ([keep? (in-list keeps)] [i (in-naturals)] #:when keep?) i)
              'changed-components changes 'provider-admissions (length changes)
              'admitted-provider-vertices (for/sum ([i (in-list changes)])
                                           (derivation-vertex-count (list-ref (reuse-update-replacements result) i)))
              'context-compilations (if (compatible-model? (reuse-preparation-model prepared) (reuse-update-model result)) 0 1)
              'affected-scaffold-interfaces (map (lambda (i) (list-ref (cut-witness-addresses f) i)) changes)
              'boundary-recertified #t 'source-certificate-reused #f
              'profile-invalidated (not (equal? (reuse-update-profile result) (reuse-preparation-profile prepared)))
              'replayed-events (if (reuse-update-replayed result)
                                  (length (opaque-replay-certificate-steps (reuse-contract-evidence replay))) 0)
              'replay-provider-body-reads 0 'exposure (reuse-contract-details boundary) 'global-minimum-cost-claimed #f))
      (define phases (hash-ref (reuse-update-plan result) 'phase-ms))
      (unless (and (hash? phases) (for/and ([v (in-hash-values phases)]) (and (real? v) (>= v 0)))
                   (equal? expected-plan (hash-remove (reuse-update-plan result) 'phase-ms)))
        (bad 'incorrect-cache-or-recomputation-plan))
      (reuse-verification #t 'independently-checked-native-update
                          (hash 'unknown-contracts-not-certified #t)))))
