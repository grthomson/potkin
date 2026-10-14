#lang racket/base

;; One logical client, not a replacement for generic reuse/replay results.
;; Nets are auxiliary observations: every positive carrier and residual below
;; is an existing native checked rule tree/context and ordered forest.
(require racket/list racket/match racket/runtime-path file/sha1
         "../kernel/calculus.rkt" "../kernel/check.rkt"
         "../kernel/context.rkt" "../kernel/address.rkt"
         "../kernel/cut.rkt" "../kernel/mll-schema.rkt"
         "../hopf/ordered-ck.rkt" "mll-net.rkt" "mll-normalization.rkt")

(provide (struct-out ck-upgrade-input)
         (struct-out ck-upgrade-positive) (struct-out ck-upgrade-negative)
         (struct-out ck-upgrade-result) (struct-out ck-upgrade-fill-result)
         (struct-out ck-upgrade-stages)
         ck-upgrade-source-identity query-ck-upgrade
         verify-ck-upgrade-certificate consume-ck-upgrade
         prepare-ck-upgrade-stages verify-ck-upgrade-stages
         consume-ck-upgrade-stages)

(struct ck-upgrade-input (host providers embeddings) #:transparent)
(struct ck-upgrade-positive
  (input source-identity calculus presentation labels ports provider-addresses
         provider-order cut detached remainder seams external-judgment
         coaction endpoint) #:transparent)
(struct ck-upgrade-negative
  (input source-identity calculus replacements quotient-choices quotient-cycle
         choices cycle paths) #:transparent)
(struct ck-upgrade-result (status certificate reason details) #:transparent)
(struct ck-upgrade-fill-result
  (status proof normal-preserved? reason details) #:transparent)
(struct ck-upgrade-stages
  (certificate stages stage-index-maps stage-cuts stage-remainders) #:transparent)

(define-runtime-path own-file "ck-upgrade-certificates.rkt")
(define-runtime-path schema-file "../kernel/mll-schema.rkt")
(define-runtime-path net-file "mll-net.rkt")
(define-runtime-path normal-file "mll-normalization.rkt")
(define-runtime-path check-file "../kernel/check.rkt")
(define-runtime-path calculus-file "../kernel/calculus.rkt")
(define-runtime-path cut-file "../kernel/cut.rkt")
(define-runtime-path context-file "../kernel/context.rkt")
(define-runtime-path ordered-file "../hopf/ordered-ck.rkt")
(define-runtime-path boundary-file "../kernel/boundary.rkt")
(define-runtime-path address-file "../kernel/address.rkt")
(define-runtime-path syntax-file "../kernel/syntax.rkt")
(define-runtime-path incidence-file "../kernel/component-incidence.rkt")
(define (ck-upgrade-source-identity)
  ;; Content identity includes dirty source, unlike HEAD. Registry identity
  ;; is bound separately by eq? and the immutable schema descriptor.
  (for/list ([p (in-list (list own-file schema-file net-file normal-file
                              check-file calculus-file cut-file context-file
                              ordered-file boundary-file address-file syntax-file
                              incidence-file))])
    (list (path->string p) (call-with-input-file p sha1))))

(define (unknown reason [details (hash)])
  (ck-upgrade-result 'UNKNOWN #f reason details))
(define (ensure yes reason)
  (unless yes (raise-arguments-error 'ck-upgrade reason)))
(define (guard thunk)
  (with-handlers ([exn:fail? (lambda (e) (unknown (exn-message e)))]) (thunk)))
(define (recheck p K #:complete? [complete? #t])
  (ensure (and (checked-term? p) (checked-term-has-exact-calculus? p K))
          "foreign or malformed native provenance")
  (define fresh (validate-candidate K (checked-term->raw p)
                                    #:expected (derivation-root-boundary p)))
  (ensure (and (checked-term? fresh) (equal? fresh p)
               (or (not complete?) (complete-proof? fresh)))
          "native rule/complete-judgment recheck failed")
  fresh)
(define (recheck-cut-evidence c K)
  (ensure (cut-witness? c) "malformed actual CK witness")
  (recheck (cut-witness-source c) K #:complete? #f)
  (recheck (cut-witness-remainder c) K #:complete? #f)
  (for ([d (in-list (cut-witness-detached c))])
    (recheck (detached-entry-term d) K #:complete? #f))
  (ensure (eq? K (proof-forest-calculus (cut-witness-forest c)))
          "stored CK witness forest has foreign registry provenance"))
(define (input-data in)
  (ensure (ck-upgrade-input? in) "malformed logical query input")
  (define host (ck-upgrade-input-host in))
  (ensure (checked-node? host) "host must be a closed native rule tree")
  (define K (checked-node-calculus host))
  (ensure (mll-schema-calculus? K) "unsupported model: exact one-sided MLL schema required")
  (recheck host K)
  (define ps (ck-upgrade-input-providers in))
  (define es (ck-upgrade-input-embeddings in))
  (ensure (and (list? ps) (list? es) (= (length ps) (length es)))
          "one exact complete-region embedding required for every provider")
  (for ([p (in-list ps)]) (recheck p K))
  (define N (mll-observe host))
  (define ns (map mll-observe ps))
  (ensure (andmap (lambda (n) (pair? (mll-net-roots n))) ns)
          "provider whole judgments must be nonempty")
  ;; The quotient constructor checks injectivity, complete ownership,
  ;; disjointness, exact logical links, and only whole-root attachments.
  (define quotient (mll-net-quotient N ns es))
  (ensure (mll-net? quotient) "invalid complete provider regions")
  (values K N ns quotient))

(define (formula-rank f)
  (match f [(list (or 'tensor 'par) a b) (+ 1 (formula-rank a) (formula-rank b))]
    [_ 0]))
(define (net-cut-rank n)
  (for/fold ([r 0]) ([l (in-list (mll-net-links n))]
                    #:when (eq? (mll-link-kind l) 'cut))
    (max r (formula-rank (hash-ref (mll-net-nodes n) (car (mll-link-inputs l)))))))
(define (projected-marked-term K detached remainder providers)
  ;; One ACTUAL selected coproduct term. Never enumerate Delta's class sum.
  ;; pi_at kills entire forest factors containing non-atomic logical Cuts.
  (define atomic? (andmap (lambda (p) (zero? (net-cut-rank (mll-observe p)))) providers))
  (list (if atomic? 'atomic-cut-rank-filter 'full-coproduct)
        (ordered-pure-tensor
         K (vector (make-ordered-forest K detached)
                   (if (checked-node? remainder)
                       (make-ordered-forest K (list remainder))
                       (empty-ordered-forest K))))))
(define (seam-data detached order addresses D labels ports)
  (for/list ([p (in-list detached)] [i (in-list order)] [a (in-list addresses)])
    (list i a (derivation-root-boundary p)
          (mll-net-roots (observe-subtree D a labels ports)))))

(define (generated-port-with-label p links)
  (match p
    [(list 'id id position) (list 'id (hash-ref links id) position)]
    [(list 'out id) (list 'out (hash-ref links id))]
    [_ (error 'ck-upgrade "unsupported native observer port constructor: ~s" p)]))
(define (observe-subtree D address labels ports)
  (define body (vertex-at-address D address))
  (define local-labels
    (for/hash ([a (in-list (vertex-addresses body))])
      (define global (append address a))
      (values a (hash-ref labels global global))))
  (mll-observe body #:labels local-labels #:ports ports))
(define (observe-residual R labels ports addresses order)
  (define source-labels
    (for/fold ([ls labels]) ([a (in-list addresses)] [i (in-list order)])
      (hash-set ls a (list 'provider i))))
  (mll-observe R #:labels source-labels #:ports ports))

(define (edge-provider e)
  (match (mll-edge-id e)
    [(list (list 'replacement i _) _ _ ...) i]
    [_ #f]))
(define (source-passages cycle)
  (define h (make-hash))
  (for ([e (in-list cycle)])
    (match (mll-edge-id e)
      [(list (list 'provider i) 'star _)
       (hash-update! h i (lambda (ps) (cons (mll-edge-right e) ps)) '())]
      [_ (void)]))
  (for/hash ([(i ps) (in-hash h)])
    (ensure (and (= (length ps) 2) (not (equal? (car ps) (cadr ps))))
            "quotient cycle has no simple complete-source passage")
    (values i ps)))
(define (edge-path edges start finish)
  (define seen (make-hash))
  (let/ec found
    (define (visit p path)
      (unless (hash-has-key? seen p)
        (hash-set! seen p #t)
        (when (equal? p finish) (found (reverse path)))
        (for ([e (in-list edges)]
              #:when (or (equal? p (mll-edge-left e)) (equal? p (mll-edge-right e))))
          (visit (if (equal? p (mll-edge-left e)) (mll-edge-right e) (mll-edge-left e))
                 (cons e path)))))
    (visit start '()) #f))
(define (path-valid? edges start finish path)
  (and (list? path) (pair? path) (andmap mll-edge? path)
       (not (check-duplicates (map mll-edge-id path) equal?))
       (andmap (lambda (e) (member e edges equal?)) path)
       (let ([degrees (make-hash)])
         (for ([e (in-list path)])
           (hash-update! degrees (mll-edge-left e) add1 0)
           (hash-update! degrees (mll-edge-right e) add1 0))
         (and (= (hash-ref degrees start 0) 1) (= (hash-ref degrees finish 0) 1)
              (for/and ([(v degree) (in-hash degrees)])
                (= degree (if (or (equal? v start) (equal? v finish)) 1 2)))
              (= (length (mll-graph-components (hash-keys degrees) path)) 1)))))
(define (quotient-exterior-cycle cycle)
  (filter (lambda (e)
            (not (match (mll-edge-id e) [(list (list 'provider _) 'star _) #t] [_ #f])))
          cycle))
(define (lift-countercycle raw quotient-choices quotient-cycle stress)
  (define choices
    (for/fold ([cs quotient-choices]) ([s (in-list stress)] [i (in-naturals 1)])
      (define labels (hash-ref (mll-v1-result-paths s) 'labels))
      (for/fold ([next cs]) ([l (in-list (mll-net-links (mll-observe (mll-v1-result-proof s))))]
                            #:when (eq? (mll-link-kind l) 'par))
        (hash-set next (list 'replacement i (mll-link-id l))
                  (hash-ref (mll-v1-result-choices s)
                            (hash-ref labels (mll-link-id l) (mll-link-id l)))))))
  (define edges (mll-net-switching raw choices))
  (define paths
    (for/hash ([(i ps) (in-hash (source-passages quotient-cycle))])
      (define local (filter (lambda (e) (equal? (edge-provider e) i)) edges))
      (define path (edge-path local (car ps) (cadr ps)))
      (ensure path "selected V1 switch does not connect the visited complete source ports")
      (values i path)))
  (define cycle (append (quotient-exterior-cycle quotient-cycle) (append* (hash-values paths))))
  (ensure (mll-verify-cycle raw choices cycle) "lifted actual quotient cycle is not a simple raw cycle")
  (values choices cycle paths))

(define (positive-from-sequentialization in K N seq)
  (define D (mll-sequentialization-tree seq))
  (define labels (mll-sequentialization-labels seq))
  (define ports (mll-sequentialization-ports seq))
  (define holes (mll-sequentialization-holes seq))
  (define count (length (ck-upgrade-input-providers in)))
  (define pairs
    (sort (for/list ([i (in-range 1 (add1 count))])
            (cons (hash-ref holes (list 'provider i)) i))
          (lambda (x y) (address<? (car x) (car y)))))
  (define addresses (map car pairs))
  (define order (map cdr pairs))
  ;; The sequentializer names source interiors privately. Restore the exact
  ;; submitted region embeddings, not just an isomorphic or normal net.
  (for ([a (in-list addresses)] [i (in-list order)])
    (define pnet (mll-observe (list-ref (ck-upgrade-input-providers in) (sub1 i))))
    (define embedding (list-ref (ck-upgrade-input-embeddings in) (sub1 i)))
    (define links (mll-embedding-links embedding))
    (for ([l (in-list (mll-net-links pnet))])
      (set! labels (hash-set labels (append a (mll-link-id l))
                             (hash-ref links (mll-link-id l)))))
    (for ([p (in-hash-keys (mll-net-nodes pnet))])
      (set! ports (hash-set ports (generated-port-with-label p links)
                            (hash-ref (mll-embedding-ports embedding) p)))))
  ;; Vacant-premise routes are derived from those exact detached interfaces.
  ;; They do not turn holes into native vertices or generators.
  (for ([a (in-list addresses)] [i (in-list order)])
    (define roots (mll-net-roots (observe-subtree D a labels ports)))
    (for ([p (in-list roots)] [j (in-naturals 1)])
      (set! ports (hash-set ports (list 'hole (list 'provider i) j) p))))
  (define endpoint (cond [(zero? count) 'empty]
                         [(and (= count 1) (null? (car addresses))) 'whole]
                         [else 'proper]))
  (define cut (and (not (eq? endpoint 'whole)) (make-cut-witness D addresses)))
  (ensure (or (eq? endpoint 'whole) (cut-witness? cut)) "actual native CK extraction failed")
  (define detached
    (if (eq? endpoint 'whole) (list D) (map detached-entry-term (cut-witness-detached cut))))
  (define R (if (eq? endpoint 'whole)
                (identity-context K (derivation-root-boundary D))
                (cut-witness-remainder cut)))
  (ck-upgrade-positive
   in (ck-upgrade-source-identity) K D labels ports addresses order cut detached R
   (seam-data detached order addresses D labels ports) (derivation-root-boundary D)
   (projected-marked-term K detached R (ck-upgrade-input-providers in)) endpoint))

(define (query-ck-upgrade in #:switch-budget [budget 65536])
  (guard
   (lambda ()
     (define-values (K N ns quotient) (input-data in))
     (define correctness (mll-net-correctness quotient #:budget budget))
     (case (hash-ref correctness 'status)
       [(CORRECT)
        (define seq
          (mll-sequentialize K quotient
                            #:sources (for/hash ([p (in-list (ck-upgrade-input-providers in))]
                                                 [i (in-naturals 1)])
                                        (values (list 'provider i) p))))
        (if (mll-sequentialization? seq)
            (verify-ck-upgrade-certificate (positive-from-sequentialization in K N seq))
            (unknown 'native-whole-source-sequentialization-unavailable (hash 'evidence seq)))]
       [(INCORRECT)
        (define passages (source-passages (hash-ref correctness 'cycle)))
        (define stress
          (for/list ([p (in-list (ck-upgrade-input-providers in))]
                     [n (in-list ns)]
                     [embedding (in-list (ck-upgrade-input-embeddings in))]
                     [i (in-naturals 1)])
            (define passage (hash-ref passages i #f))
            (define embedded
              (mll-net-transport n (mll-embedding-ports embedding)
                                   (mll-embedding-links embedding)))
            (cond
              [(and passage
                    (andmap (lambda (port) (mll-literal? (hash-ref (mll-net-nodes embedded) port)))
                            passage))
               ;; The smaller construction connects just the actually visited
               ;; complete literal exports; never extend this rank-one claim
               ;; to compound detour principals or unrelated boundary ports.
               (define indices
                 (map (lambda (port) (add1 (index-of (mll-net-roots embedded) port equal?))) passage))
               (mll-literal-port-stress p (car indices) (cadr indices))]
              [else (mll-v1 p)])))
        (cond
          [(not (andmap mll-v1-result? stress))
           (unknown 'rank-one-counterproof-construction-unavailable (hash 'evidence stress))]
          [else
           (define qs (map mll-v1-result-proof stress))
           (define raw (mll-net-replace-net N ns (ck-upgrade-input-embeddings in)
                                          (map mll-observe qs)))
           (define-values (choices cycle paths)
             (lift-countercycle raw (hash-ref correctness 'choices)
                                (hash-ref correctness 'cycle) stress))
           (verify-ck-upgrade-certificate
            (ck-upgrade-negative in (ck-upgrade-source-identity) K qs
                                 (hash-ref correctness 'choices)
                                 (hash-ref correctness 'cycle) choices cycle paths))])]
       [else (unknown 'quotient-switching-search-incomplete (hash 'evidence correctness))]))))

(define (verify-ck-upgrade-certificate cert #:input [expected #f])
  (guard
   (lambda ()
     (ensure (or (ck-upgrade-positive? cert) (ck-upgrade-negative? cert))
             "malformed certificate is not a logical counterexample")
     (define positive? (ck-upgrade-positive? cert))
     (define in (if positive? (ck-upgrade-positive-input cert) (ck-upgrade-negative-input cert)))
     (ensure (or (not expected) (equal? expected in)) "certificate/input mismatch")
     (ensure (equal? (ck-upgrade-source-identity)
                     (if positive? (ck-upgrade-positive-source-identity cert)
                         (ck-upgrade-negative-source-identity cert)))
             "stale source-content evidence")
     (define-values (K N ns quotient) (input-data in))
     (when expected
       (ensure (and (checked-node? (ck-upgrade-input-host expected))
                    (eq? K (checked-node-calculus (ck-upgrade-input-host expected)))
                    (andmap (lambda (p) (checked-term-has-exact-calculus? p K))
                            (ck-upgrade-input-providers expected)))
               "expected input has different exact registry provenance"))
     (ensure (eq? K (if positive? (ck-upgrade-positive-calculus cert)
                       (ck-upgrade-negative-calculus cert))) "stale immutable registry evidence")
     (if positive?
         (let* ([D (recheck (ck-upgrade-positive-presentation cert) K)]
                [labels (ck-upgrade-positive-labels cert)]
                [addresses (ck-upgrade-positive-provider-addresses cert)]
                [order (ck-upgrade-positive-provider-order cert)]
                [endpoint (ck-upgrade-positive-endpoint cert)]
                [ps (ck-upgrade-input-providers in)]
                [count (length ps)])
           (ensure (and (hash? labels) (immutable? labels)
                        (hash? (ck-upgrade-positive-ports cert))
                        (immutable? (ck-upgrade-positive-ports cert)))
                   "certificate routing maps must be immutable snapshots")
           (ensure (mll-net=? (mll-observe D #:labels labels #:ports (ck-upgrade-positive-ports cert)) N)
                   "presentation does not observe to the exact fixed net/current Cuts")
           (ensure (and (list? addresses) (andmap address? addresses)
                        (equal? addresses (sort addresses address<?))
                        (= count (length addresses))
                        (equal? (sort order <) (range 1 (add1 count))))
                   "invalid complete address-to-provider index map")
           (define real-endpoint
             (cond [(zero? count) 'empty]
                   [(and (= count 1) (null? (car addresses))) 'whole]
                   [else 'proper]))
           (ensure (eq? endpoint real-endpoint) "false empty/whole endpoint")
           (define real-cut (and (not (eq? endpoint 'whole)) (make-cut-witness D addresses)))
           (ensure (or (eq? endpoint 'whole) (cut-witness? real-cut)) "illegal CK antichain")
           (when real-cut
             (define stored (ck-upgrade-positive-cut cert))
             (recheck-cut-evidence stored K)
             (ensure (eq? (cut-witness-source stored) (ck-upgrade-positive-presentation cert))
                     "stored CK witness is not bound to the submitted native presentation"))
           (recheck (ck-upgrade-positive-remainder cert) K #:complete? #f)
           (for ([p (in-list (ck-upgrade-positive-detached cert))]) (recheck p K))
           (define stored-coaction (ck-upgrade-positive-coaction cert))
           (ensure (and (list? stored-coaction) (= (length stored-coaction) 2)
                        (ordered-sum? (cadr stored-coaction))
                        (eq? K (ordered-sum-calculus (cadr stored-coaction))))
                   "stored coaction tensor has foreign registry provenance")
           (define bodies (if (eq? endpoint 'whole) (list D)
                              (map detached-entry-term (cut-witness-detached real-cut))))
           (for ([body (in-list bodies)] [i (in-list order)] [a (in-list addresses)])
             (define embedded (list-ref (ck-upgrade-input-embeddings in) (sub1 i)))
             (ensure (mll-net=? (observe-subtree D a labels (ck-upgrade-positive-ports cert))
                               (mll-net-transport (list-ref ns (sub1 i))
                                                  (mll-embedding-ports embedded)
                                                  (mll-embedding-links embedded)))
                     "designated detached provider differs from its original fixed embedded net"))
           (define R (if (eq? endpoint 'whole)
                         (identity-context K (derivation-root-boundary D))
                         (cut-witness-remainder real-cut)))
           (ensure (mll-net=? (observe-residual R labels (ck-upgrade-positive-ports cert) addresses order)
                             quotient)
                   "complete routed CK residual differs from the whole-source quotient")
           (ensure (and (equal? real-cut (ck-upgrade-positive-cut cert))
                        (equal? bodies (ck-upgrade-positive-detached cert))
                        (equal? R (ck-upgrade-positive-remainder cert))
                        (equal? (seam-data bodies order addresses D labels (ck-upgrade-positive-ports cert))
                                (ck-upgrade-positive-seams cert))
                        (equal? (derivation-root-boundary D) (ck-upgrade-positive-external-judgment cert))
                        (equal? (projected-marked-term K bodies R ps) (ck-upgrade-positive-coaction cert)))
                   "actual ordered detached tuple/residual/seams/coaction mismatch")
           (ensure (equal? (complete-fill R bodies) D) "literal CK refill does not recover presentation")
           (ck-upgrade-result 'ACCEPT cert #f
                              (hash 'evidence 'CODE-CHECKED 'marked-support #t
                                    'registered-replay 'NOT-CHECKED 'full-class-sum 'NOT-COMPUTED)))
         (let ([qs (ck-upgrade-negative-replacements cert)])
           (ensure (and (list? qs) (= (length qs) (length ns))) "wrong complete countertuple length")
           (for ([q (in-list qs)] [s (in-list (ck-upgrade-input-providers in))])
             (recheck q K)
             (ensure (<= (net-cut-rank (mll-observe q)) 1) "false replacement-body F1 rank bound")
             (ensure (equal? (mll-normal-identity q) (mll-normal-identity s))
                     "local indexed normal identity mismatch"))
           (ensure (mll-verify-cycle quotient (ck-upgrade-negative-quotient-choices cert)
                                     (ck-upgrade-negative-quotient-cycle cert))
                   "false actual quotient switching cycle")
           (define raw (mll-net-replace-net N ns (ck-upgrade-input-embeddings in) (map mll-observe qs)))
           (define choices (ck-upgrade-negative-choices cert))
           (define qchoices (ck-upgrade-negative-quotient-choices cert))
           (define qcycle (ck-upgrade-negative-quotient-cycle cert))
           (define paths (ck-upgrade-negative-paths cert))
           (ensure (and (hash? choices) (immutable? choices)
                        (hash? qchoices) (immutable? qchoices)
                        (hash? paths) (immutable? paths)
                        (for/and ([(id side) (in-hash qchoices)])
                          (equal? (hash-ref choices id #f) side)))
                   "exterior switching choices changed during source-path lifting")
           (define edges (mll-net-switching raw choices))
           (define passages (source-passages qcycle))
           (ensure (and (= (hash-count paths) (hash-count passages))
                        (for/and ([(i ps) (in-hash passages)])
                          (path-valid? (filter (lambda (e) (equal? (edge-provider e) i)) edges)
                                       (car ps) (cadr ps) (hash-ref paths i #f))))
                   "false complete source-star passage/local physical path lift")
           (define lifted (append (quotient-exterior-cycle qcycle) (append* (hash-values paths))))
           (ensure (and (= (length lifted) (length (ck-upgrade-negative-cycle cert)))
                        (andmap (lambda (e) (member e lifted equal?)) (ck-upgrade-negative-cycle cert)))
                   "raw cycle is not the claimed quotient cycle with checked source paths")
           (ensure (mll-verify-cycle raw (ck-upgrade-negative-choices cert)
                                     (ck-upgrade-negative-cycle cert))
                   "false actual raw assembly switching cycle")
           (ck-upgrade-result 'REJECT cert #f
                              (hash 'evidence 'CODE-CHECKED 'meaning 'universal-binary-query-fails)))))))

(define (rebased-fillers cert fillers require-normal?)
  (define in (ck-upgrade-positive-input cert))
  (define K (ck-upgrade-positive-calculus cert))
  (define ps (ck-upgrade-input-providers in))
  (ensure (and (list? fillers) (= (length fillers) (length ps))) "one filler per original provider required")
  (for/list ([i (in-list (ck-upgrade-positive-provider-order cert))]
             [body (in-list (ck-upgrade-positive-detached cert))])
    (define q (list-ref fillers (sub1 i)))
    (recheck q K)
    (when require-normal?
      (ensure (equal? (mll-normal-identity q) (mll-normal-identity (list-ref ps (sub1 i))))
              "same-typed filler has a different indexed normal class"))
    ;; Native judgments name canonical formula occurrences. The checker
    ;; reapplies each retained seam; the net observer derives fresh private
    ;; support from the resulting native addresses instead of transplanting
    ;; producer-assigned net names into the native carrier.
    (ensure (equal? (derivation-root-boundary q) (derivation-root-boundary body))
            "complete filler judgment differs from the actual seam")
    q))
(define (actual-remainder cert)
  ;; Operational consumers derive their residual from the real selected cut,
  ;; rather than trusting even a structurally equal stored residual field.
  (define D (ck-upgrade-positive-presentation cert))
  (if (eq? (ck-upgrade-positive-endpoint cert) 'whole)
      (identity-context (ck-upgrade-positive-calculus cert) (derivation-root-boundary D))
      (cut-witness-remainder (make-cut-witness D (ck-upgrade-positive-provider-addresses cert)))))

(define (consume-ck-upgrade cert fillers #:require-normal? [require-normal? #t])
  (with-handlers ([exn:fail? (lambda (e) (ck-upgrade-fill-result 'UNKNOWN #f #f (exn-message e) (hash)))])
    (ensure (eq? (ck-upgrade-result-status (verify-ck-upgrade-certificate cert)) 'ACCEPT)
            "positive certificate did not independently verify")
    (define qs (rebased-fillers cert fillers require-normal?))
    (define filled (complete-fill (actual-remainder cert) qs))
    (recheck filled (ck-upgrade-positive-calculus cert))
    (define same?
      (equal? (mll-normal-identity filled)
              (mll-normal-identity (ck-upgrade-positive-presentation cert))))
    (ensure (or (not require-normal?) same?) "whole indexed normal identity was not preserved")
    (ck-upgrade-fill-result 'ACCEPT filled same? #f
                            (hash 'consumed 'actual-CK-remainder 'registered-replay 'NOT-CHECKED))))

(define (stage-build cert stages)
  (ensure (eq? (ck-upgrade-result-status (verify-ck-upgrade-certificate cert)) 'ACCEPT)
          "stages require one independently supported UNION")
  (ensure (not (eq? (ck-upgrade-positive-endpoint cert) 'whole))
          "whole-host staged endpoint unsupported; use external identity consumer")
  (define order (ck-upgrade-positive-provider-order cert))
  (define addresses (ck-upgrade-positive-provider-addresses cert))
  (define count (length order))
  (ensure (and (list? stages) (andmap list? stages)
               (equal? (sort (append* stages) <) (range 1 (add1 count))))
          "stages must partition the supported union exactly")
  (define current (ck-upgrade-positive-presentation cert))
  (define maps '()) (define cuts '()) (define remainders '())
  (for ([stage (in-list stages)])
    (define indices (sort (map (lambda (i) (add1 (index-of order i))) stage) <))
    (define selected (map (lambda (j) (list-ref addresses (sub1 j))) indices))
    (define c (make-cut-witness current selected))
    (ensure (cut-witness? c) "staged native cut failed")
    (ensure (andmap (lambda (d) (complete-proof? (detached-entry-term d)))
                   (cut-witness-detached c)) "second-stage detached provider contains an earlier hole")
    (set! maps (append maps (list indices)))
    (set! cuts (append cuts (list c)))
    (set! current (cut-witness-remainder c))
    (set! remainders (append remainders (list current))))
  (ensure (equal? current (ck-upgrade-positive-remainder cert)) "staged/direct union residual mismatch")
  (ck-upgrade-stages cert stages maps cuts remainders))
(define (prepare-ck-upgrade-stages cert stages)
  (guard (lambda () (stage-build cert stages))))
(define (verify-ck-upgrade-stages flag)
  (guard
   (lambda ()
     (ensure (ck-upgrade-stages? flag) "malformed staged flag")
     (define K (ck-upgrade-positive-calculus (ck-upgrade-stages-certificate flag)))
     (for ([c (in-list (ck-upgrade-stages-stage-cuts flag))]) (recheck-cut-evidence c K))
     (for ([R (in-list (ck-upgrade-stages-stage-remainders flag))])
       (recheck R K #:complete? #f))
     (ensure (equal? flag (stage-build (ck-upgrade-stages-certificate flag)
                                     (ck-upgrade-stages-stages flag)))
             "staged cut/subsequence-to-union maps mismatch")
     (ck-upgrade-result 'ACCEPT flag #f (hash 'evidence 'CODE-CHECKED)))))
(define (consume-ck-upgrade-stages flag fillers #:require-normal? [require-normal? #t])
  (with-handlers ([exn:fail? (lambda (e) (ck-upgrade-fill-result 'UNKNOWN #f #f (exn-message e) (hash)))])
    (ensure (eq? (ck-upgrade-result-status (verify-ck-upgrade-stages flag)) 'ACCEPT)
            "staged flag did not independently verify")
    (define cert (ck-upgrade-stages-certificate flag))
    (define qs (rebased-fillers cert fillers require-normal?))
    (define fresh-stages (stage-build cert (ck-upgrade-stages-stages flag)))
    (define current (actual-remainder cert))
    (for ([c (in-list (reverse (ck-upgrade-stages-stage-cuts fresh-stages)))]
          [indices (in-list (reverse (ck-upgrade-stages-stage-index-maps fresh-stages)))])
      (for ([d (in-list (cut-witness-detached c))] [i (in-list indices)])
        (set! current (context-insert current (detached-entry-address d) (list-ref qs (sub1 i))))))
    (define direct (complete-fill (actual-remainder cert) qs))
    (ensure (equal? current direct) "fresh-rebased staged and direct operations differ")
    (recheck current (ck-upgrade-positive-calculus cert))
    (define same? (equal? (mll-normal-identity current)
                         (mll-normal-identity (ck-upgrade-positive-presentation cert))))
    (ensure (or (not require-normal?) same?) "staged whole normal identity mismatch")
    (ck-upgrade-fill-result 'ACCEPT current same? #f (hash 'staged/direct 'literal-equality))))
