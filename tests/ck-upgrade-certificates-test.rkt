#lang racket/base

(require rackunit racket/list
         "../potkin/main.rkt"
         "../potkin/kernel/mll-schema.rkt"
         "../potkin/analysis/mll-net.rkt"
         "../potkin/analysis/mll-normalization.rkt"
         "../potkin/analysis/ck-upgrade-certificates.rkt"
         "../examples/ck-upgrade-certificates.rkt")

;; Fixed adversarial examples only. These checks certify delivered finite
;; native witnesses; they do not mechanize the universal paper theorem.
(define literal (make-upgrade-fixture))
(define compound (make-upgrade-fixture #:compound? #t))
(define (status r) (ck-upgrade-result-status r))
(define (certificate r expected)
  (check-eq? (status r) expected (format "~s" (ck-upgrade-result-reason r)))
  (ck-upgrade-result-certificate r))
(define (invalid c)
  (check-eq? (status (verify-ck-upgrade-certificate c)) 'UNKNOWN))
(define (root-index p f)
  (add1 (index-of (mll-boundary-formulas (derivation-root-boundary p)) f equal?)))
(define (boundary-connected? net choices)
  (define components (mll-graph-components (hash-keys (mll-net-nodes net))
                                            (mll-net-switching net choices)))
  (for/or ([component (in-list components)])
    (andmap (lambda (p) (and (member p component equal?) #t)) (mll-net-roots net))))

(test-case "separate immutable one-sided MLL admission and exact native checks"
  (define k (upgrade-fixture-calculus literal))
  (check-equal? (mll-dual '(tensor (tensor p q) r)) '(par (par (neg p) (neg q)) (neg r)))
  (check-equal? (mll-rank '(tensor (tensor p q) r)) 2)
  (check-false (mll-formula? '(unit)))
  (check-exn exn:fail? (lambda () (mll-apply k 'mix '())))
  (define id (mll-id k 'p))
  (check-exn exn:fail? (lambda () (mll-apply k 'par (list id) #:indices '(1 1))))
  (check-exn exn:fail? (lambda () (mll-apply k 'mix (list id id) #:order '((1 1)))))
  (define foreign (mll-id (make-mll-schema-calculus) 'p))
  (check-exn exn:fail? (lambda () (mll-apply k 'mix (list id foreign))))
  (check-true (mll-net-valid? (mll-observe (upgrade-fixture-host compound)))))

(test-case "switching keeps physical parallel incidences and logical child roles"
  (define parallel (list (mll-edge 'first 'left 'right)
                        (mll-edge 'second 'left 'right)))
  (define cycle (mll-find-cycle parallel))
  (check-equal? (length cycle) 2)
  (check-equal? (length (remove-duplicates (map mll-edge-id cycle))) 2)
  (define net (mll-observe (upgrade-fixture-host literal)))
  (define tensor-link (findf (lambda (l) (eq? (mll-link-kind l) 'tensor)) (mll-net-links net)))
  ;; Reversing distinct logical principals while retaining the claimed
  ;; ordered formula constructor is malformed, not an alternate proof.
  (define wrong (struct-copy mll-link tensor-link [inputs (reverse (mll-link-inputs tensor-link))]))
  (check-false (mll-net-valid? (struct-copy mll-net net
                                [links (cons wrong (remove tensor-link (mll-net-links net)))]))))

(define singleton1 (query-ck-upgrade (fixture-singleton literal 1)))
(define singleton2 (query-ck-upgrade (fixture-singleton literal 2)))
(define negative (query-ck-upgrade (fixture-input literal)))
(define supported (query-ck-upgrade (fixture-supported-union literal)))

(test-case "old cross-branch K2,2: actual singleton CK remainders, rejecting union"
  (for ([r (in-list (list singleton1 singleton2))] [i '(1 2)])
    (define c (certificate r 'ACCEPT))
    (check-eq? (status (verify-ck-upgrade-certificate c)) 'ACCEPT)
    (check-true (cut-witness? (ck-upgrade-positive-cut c)))
    (check-true (cut-witness-reconstructs? (ck-upgrade-positive-cut c)))
    (check-true (andmap pair? (ck-upgrade-positive-provider-addresses c)))
    (check-equal? (puncture-addresses (ck-upgrade-positive-remainder c))
                  (ck-upgrade-positive-provider-addresses c))
    (define filled (consume-ck-upgrade c
                     (list (list-ref (upgrade-fixture-providers literal) (sub1 i)))))
    (check-eq? (ck-upgrade-fill-result-status filled) 'ACCEPT)
    (check-true (ck-upgrade-fill-result-normal-preserved? filled)))
  (define c (certificate negative 'REJECT))
  (check-eq? (status (verify-ck-upgrade-certificate c)) 'REJECT)
  (check-true (pair? (ck-upgrade-negative-cycle c)))
  (for ([q (in-list (ck-upgrade-negative-replacements c))]
        [s (in-list (upgrade-fixture-providers literal))])
    (check-true (complete-proof? q))
    (check-true (<= (mll-proof-max-cut-rank q) 1))
    (check-equal?
     (count (lambda (a) (eq? 'cut (mll-occurrence-family (checked-term-calculus q)
                                   (checked-node-occurrence (vertex-at-address q a)))))
            (vertex-addresses q))
     1 "literal passage uses one pair detour, not full two-detour V1")
    (check-true (mll-normal-equivalent? q s))))

(test-case "actual compound/repeated interfaces exercise normal-body rank-one stress"
  (define c (certificate (query-ck-upgrade (fixture-input compound)) 'REJECT))
  (for ([s (in-list (upgrade-fixture-providers compound))]
        [q (in-list (ck-upgrade-negative-replacements c))])
    (check-equal? (length (mll-boundary-formulas (derivation-root-boundary s))) 4)
    (check-true (andmap (lambda (f) (= (mll-rank f) 2))
                       (mll-boundary-formulas (derivation-root-boundary s))))
    (check-true (mll-normal-equivalent? q s))
    (check-equal? (mll-proof-max-cut-rank q) 1)
    (define v (mll-v1 s))
    (check-true (mll-v1-result? v))
    (define paths (mll-v1-result-paths v))
    (check-true (mll-net=? (hash-ref paths 'net)
                  (mll-observe (mll-v1-result-proof v)
                    #:labels (hash-ref paths 'labels) #:ports (hash-ref paths 'ports))))
    (check-true (boundary-connected? (hash-ref paths 'net) (mll-v1-result-choices v)))
    (check-true (<= (mll-v1-result-added-vertices v) (* 10 (mll-v1-result-mix-count v))))
    (check-true (mll-normal-equivalent? (mll-v1-result-proof v) s)))
  (define higher (make-upgrade-fixture #:compound? #t #:higher-rank? #t))
  (check-true (> (mll-proof-max-cut-rank (first (upgrade-fixture-providers higher))) 1))
  (define high-cert (certificate (query-ck-upgrade (fixture-input higher)) 'REJECT))
  (check-true (andmap (lambda (q) (<= (mll-proof-max-cut-rank q) 1))
                      (ck-upgrade-negative-replacements high-cert)))
  (invalid (struct-copy ck-upgrade-negative high-cert
             [replacements (upgrade-fixture-providers higher)])))

(test-case "atomic-equivalent raw batch is correct without claiming an opaque remainder"
  (define ps (upgrade-fixture-providers literal))
  (define qs (map atomic-detour ps '(a b)))
  (check-true (andmap (lambda (q) (zero? (mll-proof-max-cut-rank q))) qs))
  (for ([q (in-list qs)] [s (in-list ps)]) (check-true (mll-normal-equivalent? q s)))
  (define raw (mll-net-replace-net (mll-observe (upgrade-fixture-host literal))
                                 (map mll-observe ps) (upgrade-fixture-embeddings literal)
                                 (map mll-observe qs)))
  (check-eq? (hash-ref (mll-net-correctness raw) 'status) 'CORRECT)
  (define seq (mll-sequentialize (upgrade-fixture-calculus literal) raw))
  (check-true (mll-sequentialization? seq))
  (check-equal? (mll-normal-identity (mll-sequentialization-tree seq))
                (mll-normal-identity (upgrade-fixture-host literal)))
  (check-eq? (status negative) 'REJECT))

(test-case "supported union is consumed and reverse chronological staged maps are checked"
  (define c (certificate supported 'ACCEPT))
  (define originals (ck-upgrade-input-providers (fixture-supported-union literal)))
  (define ps (map atomic-detour originals '((neg a) (neg c))))
  (for ([q (in-list ps)] [s (in-list originals)])
    (check-true (mll-normal-equivalent? q s))
    (check-not-equal? q s))
  (define flag (prepare-ck-upgrade-stages c
                 (map list (reverse (ck-upgrade-positive-provider-order c)))))
  (check-true (ck-upgrade-stages? flag))
  (check-eq? (status (verify-ck-upgrade-stages flag)) 'ACCEPT)
  (check-equal? (append* (ck-upgrade-stages-stage-index-maps flag)) '(2 1))
  (define direct (consume-ck-upgrade c ps))
  (define staged (consume-ck-upgrade-stages flag ps))
  (check-eq? (ck-upgrade-fill-result-status direct) 'ACCEPT)
  (check-eq? (ck-upgrade-fill-result-status staged) 'ACCEPT)
  (check-equal? (ck-upgrade-fill-result-proof direct) (ck-upgrade-fill-result-proof staged))
  (check-eq? (status (verify-ck-upgrade-stages
                      (struct-copy ck-upgrade-stages flag [stage-index-maps '((1) (2))]))) 'UNKNOWN)
  (define other-k (make-mll-schema-calculus))
  (define first-cut (first (ck-upgrade-stages-stage-cuts flag)))
  (define other-source
    (validate-candidate other-k (checked-term->raw (cut-witness-source first-cut))
                        #:expected (derivation-root-boundary (cut-witness-source first-cut))))
  (define other-cut (make-cut-witness other-source (cut-witness-addresses first-cut)))
  (check-eq? (status (verify-ck-upgrade-stages
                      (struct-copy ck-upgrade-stages flag
                        [stage-cuts (cons other-cut (cdr (ck-upgrade-stages-stage-cuts flag)))])))
             'UNKNOWN)
  (check-eq? (status (prepare-ck-upgrade-stages (certificate singleton1 'ACCEPT) '((1) (2))))
             'UNKNOWN))

(test-case "normal replay recomputes reductions, indexed matching and native result routes"
  (define s (first (upgrade-fixture-providers literal)))
  (define q (atomic-detour s 'a))
  (define normal (mll-normalize q))
  (check-true (verify-mll-normal-result q normal))
  (check-false (verify-mll-normal-result q
                 (struct-copy mll-normal-result normal [signature 'forged-normal-matching])))
  (check-false (verify-mll-normal-result q
                 (struct-copy mll-normal-result normal [trace '()])))
  (check-eq? (hash-ref (mll-normalize q #:step-limit 0) 'status) 'UNKNOWN))

(test-case "positive verifier recomputes ordered tuple, actual cut, seams and source identity"
  (define c (certificate supported 'ACCEPT))
  (invalid (struct-copy ck-upgrade-positive c [source-identity 'stale]))
  (invalid (struct-copy ck-upgrade-positive c [detached (reverse (ck-upgrade-positive-detached c))]))
  (invalid (struct-copy ck-upgrade-positive c [provider-order (reverse (ck-upgrade-positive-provider-order c))]))
  (invalid (struct-copy ck-upgrade-positive c [provider-addresses '((1) (1 1))]))
  (invalid (struct-copy ck-upgrade-positive c [seams '((changed-seam))]))
  (invalid (struct-copy ck-upgrade-positive c [external-judgment (mll-boundary '(p))]))
  (invalid (struct-copy ck-upgrade-positive c [cut (make-cut-witness (ck-upgrade-positive-presentation c) '())]))
  (invalid (struct-copy ck-upgrade-positive c [coaction '(unrelated-projection)]))
  (invalid (struct-copy ck-upgrade-positive c [calculus (make-mll-schema-calculus)]))
  (define foreign-k (make-mll-schema-calculus))
  (define (foreign-copy p)
    (validate-candidate foreign-k (checked-term->raw p)
                        #:expected (derivation-root-boundary p)))
  (invalid (struct-copy ck-upgrade-positive c
             [remainder (foreign-copy (ck-upgrade-positive-remainder c))]))
  (invalid (struct-copy ck-upgrade-positive c
             [detached (map foreign-copy (ck-upgrade-positive-detached c))]))
  (invalid (struct-copy ck-upgrade-positive c
             [cut (make-cut-witness (foreign-copy (ck-upgrade-positive-presentation c))
                                    (ck-upgrade-positive-provider-addresses c))]))
  (invalid (struct-copy ck-upgrade-positive c
             [labels (make-hash (hash->list (ck-upgrade-positive-labels c)))]))
  (check-eq? (ck-upgrade-fill-result-status (consume-ck-upgrade c '())) 'UNKNOWN)
  (define foreign (make-upgrade-fixture))
  (check-eq? (status (verify-ck-upgrade-certificate c #:input (fixture-supported-union foreign))) 'UNKNOWN))

(test-case "complete source ownership and passive roots cannot be silently omitted"
  (define e (first (upgrade-fixture-embeddings literal)))
  (define p (first (upgrade-fixture-providers literal)))
  (define missing (struct-copy mll-embedding e
                    [ports (hash-remove (mll-embedding-ports e) (first (mll-net-roots (mll-observe p))))]))
  (define bad (ck-upgrade-input (upgrade-fixture-host literal) (list p) (list missing)))
  (check-eq? (status (query-ck-upgrade bad)) 'UNKNOWN)
  (define mutable-e (struct-copy mll-embedding e
                      [ports (make-hash (hash->list (mll-embedding-ports e)))]))
  (check-eq? (status (query-ck-upgrade
                      (ck-upgrade-input (upgrade-fixture-host literal) (list p) (list mutable-e))))
             'UNKNOWN)
  (check-eq? (status (query-ck-upgrade (fixture-input literal) #:switch-budget 0)) 'UNKNOWN)
  (define atomic-only (make-upgrade-fixture #:sector 'F0))
  (check-eq? (status (query-ck-upgrade (fixture-input atomic-only))) 'UNKNOWN))

(test-case "negative verifier distrusts false cycles, switches, tuple and normal matching"
  (define c (certificate negative 'REJECT))
  (invalid (struct-copy ck-upgrade-negative c [source-identity 'stale]))
  (invalid (struct-copy ck-upgrade-negative c [replacements (reverse (ck-upgrade-negative-replacements c))]))
  (invalid (struct-copy ck-upgrade-negative c [quotient-cycle '()]))
  (check-true (positive? (hash-count (ck-upgrade-negative-paths c))))
  (invalid (struct-copy ck-upgrade-negative c [paths (hash)]))
  (invalid (struct-copy ck-upgrade-negative c
             [choices (make-hash (hash->list (ck-upgrade-negative-choices c)))]))
  (invalid (struct-copy ck-upgrade-negative c
             [choices (hash-set (ck-upgrade-negative-choices c) 'not-a-par 1)]))
  (invalid (struct-copy ck-upgrade-negative c
             [cycle (cons (first (ck-upgrade-negative-cycle c)) (ck-upgrade-negative-cycle c))]))
  ;; A locally correct alternate proof of the SAME repeated-type judgment
  ;; can still change indexed axiom matching. Only the equal-type positive
  ;; output occurrences are exchanged; their negative partners remain fixed.
  (define cc (certificate (query-ck-upgrade (fixture-input compound)) 'REJECT))
  (define s (first (upgrade-fixture-providers compound)))
  (define k (upgrade-fixture-calculus compound))
  (define order (mll-occurrence-order k (checked-node-occurrence s)))
  (define fs (mll-boundary-formulas (derivation-root-boundary s)))
  (define duplicate (for/first ([f (in-list fs)] #:when (> (count (lambda (x) (equal? x f)) fs) 1)) f))
  (define positions (for/list ([f (in-list fs)] [i (in-naturals)] #:when (equal? f duplicate)) i))
  (define ia (first positions)) (define ib (second positions))
  (define exchanged (for/list ([token (in-list order)] [i (in-naturals)])
                      (cond [(= i ia) (list-ref order ib)] [(= i ib) (list-ref order ia)] [else token])))
  (define different (mll-apply k 'mix (checked-node-children s) #:order exchanged))
  (check-equal? (derivation-root-boundary different) (derivation-root-boundary s))
  (check-false (mll-normal-equivalent? different s))
  (invalid (struct-copy ck-upgrade-negative cc
             [replacements (cons different (cdr (ck-upgrade-negative-replacements cc)))])))

(test-case "positive exact fixed-net verification retains existing logical Cut links"
  (define k (make-mll-schema-calculus))
  (define a '(tensor (tensor p q) r))
  (define left (mll-expanded-id k a)) (define right (mll-expanded-id k a))
  (define host (mll-apply k 'cut (list left right)
                         #:indices (list (root-index left a) (root-index right (mll-dual a)))))
  (define in (ck-upgrade-input host (list left)
               (list (embedding-by-address host left (lambda (address) (cons 1 address))))))
  (define c (certificate (query-ck-upgrade in) 'ACCEPT))
  (check-true (> (mll-proof-max-cut-rank (ck-upgrade-positive-presentation c)) 1))
  (define nf (mll-normalize host))
  (check-true (mll-normal-result? nf))
  (invalid (struct-copy ck-upgrade-positive c [presentation (mll-normal-result-proof nf)])))

(test-case "empty and whole endpoints keep unit, proof and typed consumer distinct"
  (define host (upgrade-fixture-host literal))
  (define empty (certificate (query-ck-upgrade (ck-upgrade-input host '() '())) 'ACCEPT))
  (check-eq? (ck-upgrade-positive-endpoint empty) 'empty)
  (check-equal? (cut-witness-addresses (ck-upgrade-positive-cut empty)) '())
  (check-equal? (ck-upgrade-positive-detached empty) '())
  (check-true (checked-node? (ck-upgrade-positive-remainder empty)))
  (check-eq? (ck-upgrade-fill-result-status (consume-ck-upgrade empty '())) 'ACCEPT)
  (define whole (certificate (query-ck-upgrade
                  (ck-upgrade-input host (list host)
                    (list (embedding-by-address host host values)))) 'ACCEPT))
  (check-eq? (ck-upgrade-positive-endpoint whole) 'whole)
  (check-false (ck-upgrade-positive-cut whole))
  (check-true (checked-hole? (ck-upgrade-positive-remainder whole)))
  (check-eq? (ck-upgrade-fill-result-status (consume-ck-upgrade whole (list host))) 'ACCEPT)
  (check-eq? (status (prepare-ck-upgrade-stages whole '((1)))) 'UNKNOWN)
  (check-eq? (car (ck-upgrade-positive-coaction whole)) 'atomic-cut-rank-filter)
  (define higher-host (upgrade-fixture-host
                       (make-upgrade-fixture #:compound? #t #:higher-rank? #t)))
  (define full (certificate (query-ck-upgrade
                 (ck-upgrade-input higher-host (list higher-host)
                   (list (embedding-by-address higher-host higher-host values)))) 'ACCEPT))
  (check-eq? (car (ck-upgrade-positive-coaction full)) 'full-coproduct))
