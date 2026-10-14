#lang racket/base

;; Logical-net analysis is an observer, not a proof/Hopf carrier. Every
;; returned proof is built by the native checker in the supplied snapshot.
(require racket/list racket/match
         "../kernel/mll-schema.rkt"
         "../kernel/check.rkt" "../kernel/calculus.rkt"
         "../kernel/context.rkt" "../kernel/address.rkt"
         "mll-net.rkt")

(provide (struct-out mll-normal-result) (struct-out mll-reduction-step)
         (struct-out mll-v1-result)
         mll-normalize mll-normal-identity mll-normal-equivalent?
         mll-net-normal-signature mll-proof-max-cut-rank mll-v1 mll-literal-port-stress
         verify-mll-normal-result)

(struct mll-reduction-step (kind cut before after) #:transparent)
(struct mll-normal-result (proof net signature trace labels ports) #:transparent)
(struct mll-v1-result
  (proof normal-signature choices paths mix-count added-vertices max-cut-rank)
  #:transparent)

(define (unknown reason [details (hash)])
  (hash 'status 'UNKNOWN 'reason reason 'details details))
(define (replace-port link old new)
  (define (f p) (if (equal? p old) new p))
  (mll-link (mll-link-id link) (mll-link-kind link)
            (map f (mll-link-inputs link)) (map f (mll-link-outputs link))))
(define (producer net port)
  (for/first ([l (in-list (mll-net-links net))]
              #:when (member port (mll-link-outputs l) equal?)) l))

;; A single principal reduction. All passives remain literally untouched.
;; Atomic elimination splices the surviving partner into the other axiom;
;; tensor/par elimination retains each ordered child role in its own Cut.
(define (reduce-once net)
  (for/or ([c (in-list (mll-net-links net))]
           #:when (eq? 'cut (mll-link-kind c)))
    (define a (first (mll-link-inputs c)))
    (define b (second (mll-link-inputs c)))
    (define pa (producer net a))
    (define pb (producer net b))
    (define (without ls)
      (filter (lambda (l) (not (member (mll-link-id l) ls equal?)))
              (mll-net-links net)))
    (define (delete-nodes ps)
      (for/fold ([h (mll-net-nodes net)]) ([p (in-list ps)]) (hash-remove h p)))
    (cond
      [(or (eq? (mll-link-kind pa) 'id) (eq? (mll-link-kind pb) 'id))
       (define id (if (eq? (mll-link-kind pa) 'id) pa pb))
       (define old (if (eq? id pa) a b))
       (define other (if (eq? id pa) b a))
       (define partner (first (remove old (mll-link-outputs id) equal?)))
       (define after
         (mll-net (delete-nodes (list old other))
                  (map (lambda (l) (replace-port l other partner))
                       (without (list (mll-link-id id) (mll-link-id c))))
                  (mll-net-roots net)))
       (mll-reduction-step 'atomic (mll-link-id c) net after)]
      [(or (and (eq? (mll-link-kind pa) 'tensor) (eq? (mll-link-kind pb) 'par))
           (and (eq? (mll-link-kind pa) 'par) (eq? (mll-link-kind pb) 'tensor)))
       (define children
         (for/list ([u (in-list (mll-link-inputs pa))]
                    [v (in-list (mll-link-inputs pb))] [i (in-naturals 1)])
           (mll-link (list 'reduce (mll-link-id c) i) 'cut (list u v) '())))
       (mll-reduction-step
        'principal (mll-link-id c) net
        (mll-net (delete-nodes (list a b))
                 (append (without (map mll-link-id (list pa pb c))) children)
                 (mll-net-roots net)))]
      [else #f])))

;; Complete indexed normal identity: root positions and formula-child roles
;; determine every port path. Private link names are forgotten, not axiom
;; matching, multiplicity, or ordered logical children.
(define (mll-net-normal-signature net)
  (unless (mll-net-valid? net)
    (raise-argument-error 'mll-net-normal-signature "valid indexed net" net))
  (when (ormap (lambda (l) (memq (mll-link-kind l) '(cut source))) (mll-net-links net))
    (raise-arguments-error 'mll-net-normal-signature "requires a Cut-free closed net"))
  (define paths (make-hash))
  (define (visit p path)
    (when (hash-has-key? paths p)
      (raise-arguments-error 'mll-net-normal-signature "formula ports have overlapping ownership"))
    (hash-set! paths p path)
    (define l (producer net p))
    (when (and l (memq (mll-link-kind l) '(tensor par)))
      (for ([q (in-list (mll-link-inputs l))] [i (in-naturals 1)])
        (visit q (append path (list i))))))
  (for ([r (in-list (mll-net-roots net))] [i (in-naturals 1)]) (visit r (list i)))
  (unless (= (hash-count paths) (hash-count (mll-net-nodes net)))
    (raise-arguments-error 'mll-net-normal-signature "normal net contains hidden components"))
  (define (key x) (format "~s" x))
  (list 'mll/indexed-normal-v1
        (map (lambda (p) (hash-ref (mll-net-nodes net) p)) (mll-net-roots net))
        (sort
         (for/list ([l (in-list (mll-net-links net))] #:when (eq? (mll-link-kind l) 'id))
           (sort (map (lambda (p) (hash-ref paths p)) (mll-link-outputs l)) string<? #:key key))
         string<? #:key key)))

(define (mll-normalize proof #:step-limit [step-limit 10000])
  (unless (and (complete-proof? proof) (mll-schema-calculus? (checked-term-calculus proof)))
    (raise-argument-error 'mll-normalize "native complete MLL proof" proof))
  (define original (mll-observe proof))
  (let loop ([net original] [trace '()] [n 0])
    (cond
      [(>= n step-limit) (unknown 'normalization-budget (hash 'steps n))]
      [else
       (define step (reduce-once net))
       (cond
         [step (loop (mll-reduction-step-after step) (cons step trace) (add1 n))]
         [(ormap (lambda (l) (eq? (mll-link-kind l) 'cut)) (mll-net-links net))
          (unknown 'unsupported-cut-redex)]
         [else
          (define seq (mll-sequentialize (checked-term-calculus proof) net))
          (if (mll-sequentialization? seq)
              (mll-normal-result (mll-sequentialization-tree seq) net
                                 (mll-net-normal-signature net) (reverse trace)
                                 (mll-sequentialization-labels seq)
                                 (mll-sequentialization-ports seq))
              seq)])])))

(define (mll-normal-identity proof)
  (define r (mll-normalize proof))
  (unless (mll-normal-result? r)
    (raise-arguments-error 'mll-normal-identity "normalization unavailable" "result" r))
  (mll-normal-result-signature r))
(define (mll-normal-equivalent? a b)
  (and (eq? (checked-term-calculus a) (checked-term-calculus b))
       (equal? (mll-normal-identity a) (mll-normal-identity b))))
(define (verify-mll-normal-result original result)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (and (mll-normal-result? result)
         (eq? (checked-term-calculus original)
              (checked-term-calculus (mll-normal-result-proof result)))
         (let ([fresh (mll-normalize original)])
           (and (mll-normal-result? fresh)
                (equal? (mll-normal-result-net fresh) (mll-normal-result-net result))
                (equal? (mll-normal-result-trace fresh) (mll-normal-result-trace result))
                (equal? (mll-normal-result-signature fresh) (mll-normal-result-signature result))
                (mll-net=? (mll-observe (mll-normal-result-proof result)
                                       #:labels (mll-normal-result-labels result)
                                       #:ports (mll-normal-result-ports result))
                            (mll-normal-result-net result)))))))

(define (mll-proof-max-cut-rank p)
  (for/fold ([rank 0]) ([a (in-list (vertex-addresses p))])
    (define n (vertex-at-address p a))
    (define d (mll-occurrence-data (checked-term-calculus p) (checked-node-occurrence n)))
    (if (eq? (hash-ref d 'family) 'cut)
        (max rank (mll-rank (hash-ref d 'formula))) rank)))

;; The constructive stress constructor is defined below. Unsupported budgets
;; return UNKNOWN rather than a negative logical answer.

;; Track output occurrences through the *entire* native rule order. A root
;; marker is not a formula, and equal formulas never identify these markers.
(define (tracked-apply k family children #:indices [indices '()] #:principal [principal #f])
  (define p (mll-apply k family (map car children) #:indices indices))
  (define order (mll-occurrence-order k (checked-node-occurrence p)))
  (cons p (for/list ([token (in-list order)])
            (if (eq? token 'principal) principal
                (list-ref (cdr (list-ref children (sub1 (first token)))) (sub1 (second token)))))))
(define (tracked-id k atom positive negative)
  (cons (mll-id k atom) (list positive negative)))
(define (marker-index tracked marker)
  (define i (index-of (cdr tracked) marker equal?))
  (unless i (error 'mll-v1 "lost an indexed root while constructing the detour"))
  (add1 i))
(define (identity-detour k tracked a-marker b-marker generation)
  (define fs (mll-boundary-formulas (derivation-root-boundary (car tracked))))
  (define ia (marker-index tracked a-marker))
  (define ib (marker-index tracked b-marker))
  (define a (list-ref fs (sub1 ia))) (define b (list-ref fs (sub1 ib)))
  (unless (and (mll-literal? a) (mll-literal? b))
    (error 'mll-v1 "detour principals must be literals"))
  (define par-marker (list 'par generation))
  (define par (tracked-apply k 'par (list tracked) #:indices (list ia ib) #:principal par-marker))
  (define fresh-a (list 'fresh generation 1))
  (define fresh-b (list 'fresh generation 2))
  (define dual-a (list 'helper generation 1))
  (define dual-b (list 'helper generation 2))
  (define ida
    (if (symbol? a) (tracked-id k a fresh-a dual-a)
        (tracked-id k (cadr a) dual-a fresh-a)))
  (define idb
    (if (symbol? b) (tracked-id k b fresh-b dual-b)
        (tracked-id k (cadr b) dual-b fresh-b)))
  (define tensor-marker (list 'tensor generation))
  (define tensor
    (tracked-apply k 'tensor (list ida idb)
                   #:indices (list (marker-index ida dual-a) (marker-index idb dual-b))
                   #:principal tensor-marker))
  (define cut
    (tracked-apply k 'cut (list par tensor)
                   #:indices (list (marker-index par par-marker) (marker-index tensor tensor-marker))))
  (values cut fresh-a fresh-b))

;; Genuine native G_{a,b}. The second detour uses the FRESH first a root;
;; its other principal is the ORIGINAL negative b root. This matters even
;; when a=b. Native checked construction establishes all-switch correctness.
(define (literal-gadget k a b)
  (define pa (tracked-id k a '(old 1 +) '(old 1 -)))
  (define pb (tracked-id k b '(old 2 +) '(old 2 -)))
  (define mix (tracked-apply k 'mix (list pa pb)))
  (define-values (first fresh-a fresh-b)
    (identity-detour k mix '(old 1 +) '(old 2 +) 1))
  (define-values (second final-a final-b)
    (identity-detour k first fresh-a '(old 2 -) 2))
  (values second (list final-a '(old 1 -) fresh-b final-b)))

(define (map-net-ports net transport)
  (define (p x) (hash-ref transport x x))
  (mll-net (for/hash ([(x f) (in-hash (mll-net-nodes net))]) (values (p x) f))
           (for/list ([l (in-list (mll-net-links net))])
             (mll-link (mll-link-id l) (mll-link-kind l)
                       (map p (mll-link-inputs l)) (map p (mll-link-outputs l))))
           (map p (mll-net-roots net))))

;; One pair detour is sufficient for a particular quotient-cycle passage
;; through two literal exports. Unlike V1 this does NOT claim to connect all
;; exports. Existing compound syntax is untouched; compound principals must
;; use the body-inspecting general constructor below.
(define (mll-literal-port-stress proof first-index second-index)
  (with-handlers ([exn:fail? (lambda (e) (unknown 'literal-port-shortcut-unavailable
                                                 (hash 'message (exn-message e))))])
    (define n (mll-normalize proof))
    (if (not (mll-normal-result? n)) n
        (let* ([p (mll-normal-result-proof n)] [k (checked-term-calculus p)]
               [roots (mll-boundary-formulas (derivation-root-boundary p))]
               [markers (range 1 (add1 (length roots)))])
          (unless (and (member first-index markers) (member second-index markers)
                       (not (= first-index second-index))
                       (mll-literal? (list-ref roots (sub1 first-index)))
                       (mll-literal? (list-ref roots (sub1 second-index))))
            (error 'mll-literal-port-stress "two distinct literal output occurrences required"))
          (define-values (tracked fresh-a fresh-b)
            (identity-detour k (cons p markers) first-index second-index 'shortcut))
          (define desired
            (map (lambda (marker) (cond [(= marker first-index) fresh-a]
                                        [(= marker second-index) fresh-b] [else marker])) markers))
          (define o (checked-node-occurrence (car tracked)))
          (define order (mll-occurrence-order k o))
          (define reordered
            (map (lambda (marker) (list-ref order (sub1 (marker-index tracked marker)))) desired))
          (define target (mll-apply k 'cut (checked-node-children (car tracked))
                                    #:indices (mll-occurrence-indices k o) #:order reordered))
          (unless (equal? (mll-normal-identity target) (mll-normal-result-signature n))
            (error 'mll-literal-port-stress "shortcut changed indexed normal identity"))
          (define net (mll-observe target))
          (define choices
            (for/hash ([l (in-list (mll-net-links net))] #:when (eq? 'par (mll-link-kind l)))
              (values (mll-link-id l) 1)))
          (unless (= 1 (mll-proof-max-cut-rank target))
            (error 'mll-literal-port-stress "shortcut violated the replacement-body rank bound"))
          (mll-v1-result target (mll-normal-result-signature n) choices
                         (hash 'net net 'labels (hash) 'ports (hash) 'shortcut #t)
                         (count (lambda (a) (eq? 'mix (mll-occurrence-family k
                                                     (checked-node-occurrence (vertex-at-address p a)))))
                                (vertex-addresses p))
                         5 1)))))

(define (insert-gadget net first-id second-id k generation)
  (define first-link (for/first ([l (in-list (mll-net-links net))] #:when (equal? (mll-link-id l) first-id)) l))
  (define second-link (for/first ([l (in-list (mll-net-links net))] #:when (equal? (mll-link-id l) second-id)) l))
  (unless (and first-link second-link (eq? 'id (mll-link-kind first-link)) (eq? 'id (mll-link-kind second-link)))
    (error 'mll-v1 "Mix exposure lost its designated atomic occurrences"))
  (define a (hash-ref (mll-net-nodes net) (first (mll-link-outputs first-link))))
  (define b (hash-ref (mll-net-nodes net) (first (mll-link-outputs second-link))))
  (define-values (tracked markers) (literal-gadget k a b))
  (define labels (for/hash ([address (in-list (vertex-addresses (car tracked)))])
                   (values address (list 'stress generation address))))
  (define observed (mll-observe (car tracked) #:labels labels))
  (define old-ports (append (mll-link-outputs first-link) (mll-link-outputs second-link)))
  (define transport
    (for/hash ([marker (in-list markers)] [old-port (in-list old-ports)])
      (values (list-ref (mll-net-roots observed) (sub1 (marker-index tracked marker))) old-port)))
  ;; Keep the two original axiom link IDs for subsequent Mix joins, but all
  ;; their new internal support ports are fresh. External attachments alone
  ;; keep the old ports. No formula movement is inferred from incidence.
  (define gadget (map-net-ports observed transport))
  (define original-id-links
    (filter (lambda (l) (and (eq? (mll-link-kind l) 'id)
                            (match (mll-link-id l)
                              [(list 'stress _ address)
                               (define n (vertex-at-address (car tracked) address))
                               (and (checked-node? n)
                                    ;; The initial two IDs sit beneath the
                                    ;; unique Mix (all added IDs are outside).
                                    (ormap (lambda (ma) (and (equal? (mll-occurrence-family k (checked-node-occurrence (vertex-at-address (car tracked) ma))) 'mix)
                                                            (proper-address-prefix? ma address)))
                                           (vertex-addresses (car tracked))))]
                              [_ #f])))
            (mll-net-links gadget)))
  (unless (= 2 (length original-id-links)) (error 'mll-v1 "gadget axiom support is ambiguous"))
  (define ids-to-keep
    (hash (mll-link-id (first original-id-links)) first-id
          (mll-link-id (second original-id-links)) second-id))
  (define gadget-links
    (map (lambda (l) (mll-link (hash-ref ids-to-keep (mll-link-id l) (mll-link-id l))
                              (mll-link-kind l) (mll-link-inputs l) (mll-link-outputs l)))
         (mll-net-links gadget)))
  (mll-net
   (for/fold ([h (mll-net-nodes net)]) ([(p f) (in-hash (mll-net-nodes gadget))]) (hash-set h p f))
   (append (filter (lambda (l) (not (member (mll-link-id l) (list first-id second-id) equal?)))
                   (mll-net-links net)) gadget-links)
   (mll-net-roots net)))

;; Enumerate a single finite input's par switches, not replacement bodies or
;; Hopf terms. Its bounded search is only witness delivery; a miss is UNKNOWN.
(define (boundary-connected-switch net limit)
  (define pars (filter (lambda (l) (eq? (mll-link-kind l) 'par)) (mll-net-links net)))
  (define work 0)
  (let/ec found
    (define (try choices remaining)
      (when (< work limit)
        (if (pair? remaining)
            (for ([side '(1 2)]) (try (hash-set choices (mll-link-id (car remaining)) side) (cdr remaining)))
            (begin
              (set! work (add1 work))
              (let* ([edges (mll-net-switching net choices)] [adj (make-hash)])
                (for ([e (in-list edges)])
                  (hash-update! adj (mll-edge-left e) (lambda (xs) (cons (mll-edge-right e) xs)) '())
                  (hash-update! adj (mll-edge-right e) (lambda (xs) (cons (mll-edge-left e) xs)) '()))
                (define reached (make-hash))
                (define (visit p) (unless (hash-has-key? reached p) (hash-set! reached p #t)
                                   (for-each visit (hash-ref adj p '()))))
                (visit (first (mll-net-roots net)))
                (when (andmap (lambda (r) (hash-has-key? reached r)) (mll-net-roots net))
                  (found choices)))))))
    (try (hash) pars) #f))

(define (mll-v1 proof #:switch-limit [switch-limit 65536])
  (with-handlers ([exn:fail? (lambda (e) (unknown 'rank-one-construction-unavailable (hash 'message (exn-message e))))])
    (define normalized (mll-normalize proof))
    (if (not (mll-normal-result? normalized)) normalized
        (let* ([normal (mll-normal-result-proof normalized)]
               [k (checked-term-calculus proof)] [labels (mll-normal-result-labels normalized)]
               [net (mll-observe normal #:labels labels #:ports (mll-normal-result-ports normalized))] [mixes '()])
          (define (first-id p address)
            (if (eq? 'id (mll-occurrence-family k (checked-node-occurrence p)))
                (hash-ref labels address address)
                (first-id (first (checked-node-children p)) (append address '(1)))))
          (define (collect p address)
            (for ([c (in-list (checked-node-children p))] [i (in-naturals 1)]) (collect c (append address (list i))))
            (when (eq? 'mix (mll-occurrence-family k (checked-node-occurrence p)))
              (set! mixes (append mixes (list (list (first-id (first (checked-node-children p)) (append address '(1)))
                                                   (first-id (second (checked-node-children p)) (append address '(2)))))))))
          (collect normal '())
          (for ([pair (in-list mixes)] [generation (in-naturals 1)])
            (set! net (insert-gadget net (first pair) (second pair) k generation)))
          (define seq (mll-sequentialize k net))
          (cond
            [(not (mll-sequentialization? seq)) seq]
            [else
             (define target (mll-sequentialization-tree seq))
             (define signature (mll-normal-identity target))
             (unless (equal? signature (mll-normal-result-signature normalized))
               (error 'mll-v1 "native gadget changed indexed normal identity"))
             (define added (- (derivation-vertex-count target) (derivation-vertex-count normal)))
             (define rank (mll-proof-max-cut-rank target))
             (define target-mixes
               (count (lambda (a) (eq? 'mix (mll-occurrence-family k
                                            (checked-node-occurrence (vertex-at-address target a)))))
                      (vertex-addresses target)))
             (define target-cuts
               (count (lambda (a) (eq? 'cut (mll-occurrence-family k
                                            (checked-node-occurrence (vertex-at-address target a)))))
                      (vertex-addresses target)))
             (unless (and (<= rank 1) (<= added (* 10 (length mixes)))
                          (<= target-cuts (* 2 (length mixes))) (<= target-mixes (length mixes)))
               (error 'mll-v1 "native rank/vertex/Cut/Mix constructor bound failed"))
             (define choices (boundary-connected-switch net switch-limit))
             (if (not choices) (unknown 'boundary-switch-witness-budget)
                 (mll-v1-result target signature choices
                                (hash 'net net 'labels (mll-sequentialization-labels seq)
                                      'ports (mll-sequentialization-ports seq))
                                (length mixes) added rank)) ])))))
