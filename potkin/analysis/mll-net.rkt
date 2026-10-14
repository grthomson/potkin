#lang racket/base

;; Auxiliary indexed nets; these are NOT the native Hopf generators.
(require racket/list racket/match racket/set
         "../kernel/mll-schema.rkt" "../kernel/check.rkt"
         "../kernel/calculus.rkt" "../kernel/syntax.rkt" "../kernel/boundary.rkt")
(provide (struct-out mll-link) (struct-out mll-net) (struct-out mll-edge)
         (struct-out mll-embedding) (struct-out mll-sequentialization)
         mll-observe mll-net-valid? mll-net=? mll-net-switching
         mll-net-full-edges mll-graph-components mll-find-cycle mll-verify-cycle
         mll-net-correctness mll-net-quotient mll-net-replace-net
         mll-sequentialize mll-net-transport)
(struct mll-link (id kind inputs outputs) #:transparent)
(struct mll-net (nodes links roots) #:transparent)
(struct mll-edge (id left right) #:transparent)
(struct mll-embedding (ports links) #:transparent)
(struct mll-sequentialization (tree labels holes ports) #:transparent)

(define (mll-observe tree #:labels [labels (hash)] #:ports [ports (hash)])
  (unless (and (checked-term? tree) (mll-schema-calculus? (checked-term-calculus tree)))
    (raise-argument-error 'mll-observe "native checked MLL term" tree))
  (define k (checked-term-calculus tree))
  (define nodes (make-hash)) (define links '())
  (define (port p f)
    (define out (hash-ref ports p p))
    (when (hash-has-key? nodes out) (error 'mll-observe "physical port collision: ~s" out))
    (hash-set! nodes out f) out)
  (define (walk t address)
    (define id (hash-ref labels address address))
    (cond
      [(checked-hole? t)
       (define roots (for/list ([f (in-list (mll-boundary-formulas (derivation-root-boundary t)))] [i (in-naturals 1)])
                       (port (list 'hole id i) f)))
       (set! links (cons (mll-link id 'source '() roots) links)) roots]
      [else
       (define o (checked-node-occurrence t))
       (define d (mll-occurrence-data k o))
       (define family (hash-ref d 'family))
       (define rs (for/list ([c (in-list (checked-node-children t))] [i (in-naturals 1)])
                    (walk c (append address (list i)))))
       (define (token-ref token)
         (list-ref (list-ref rs (sub1 (car token))) (sub1 (cadr token))))
       (define indices (hash-ref d 'indices))
       (define principal
         (case family
           [(tensor cut) (list (token-ref (list 1 (car indices))) (token-ref (list 2 (cadr indices))))]
           [(par) (map (lambda (i) (token-ref (list 1 i))) indices)] [else '()]))
       (define fresh
         (case family
           [(id) (list (port (list 'id id 1) (hash-ref d 'atom))
                       (port (list 'id id 2) (mll-dual (hash-ref d 'atom))))]
           [(tensor par) (list (port (list 'out id) (hash-ref d 'formula)))]
           [else '()]))
       (unless (eq? family 'mix) (set! links (cons (mll-link id family principal fresh) links)))
       (for/list ([token (in-list (hash-ref d 'order))])
         (cond [(eq? token 'principal) (car fresh)]
               [(eq? (car token) 'axiom) (list-ref fresh (sub1 (cadr token)))]
               [else (token-ref token)]))]))
  (define roots (walk tree '()))
  (define net (mll-net (make-immutable-hash (hash->list nodes)) (reverse links) roots))
  (unless (mll-net-valid? net) (error 'mll-observe "invalid exact indexed net")) net)

(define (mll-net-valid? net)
  (and
   (mll-net? net) (hash? (mll-net-nodes net)) (immutable? (mll-net-nodes net))
   (andmap formula-datum? (hash-keys (mll-net-nodes net)))
   (andmap mll-formula? (hash-values (mll-net-nodes net)))
   (list? (mll-net-links net)) (andmap mll-link? (mll-net-links net))
   (andmap formula-datum? (map mll-link-id (mll-net-links net)))
   (not (check-duplicates (map mll-link-id (mll-net-links net)) equal?))
   (list? (mll-net-roots net)) (not (check-duplicates (mll-net-roots net) equal?))
   (with-handlers ([exn:fail? (lambda (_) #f)])
     (define ns (mll-net-nodes net))
     (define owners (append-map mll-link-outputs (mll-net-links net)))
     (define consumed (append-map mll-link-inputs (mll-net-links net)))
     (and (not (check-duplicates owners equal?)) (not (check-duplicates consumed equal?))
          (= (length owners) (hash-count ns))
          (andmap (lambda (p) (hash-has-key? ns p)) (append owners consumed (mll-net-roots net)))
          (= (+ (length consumed) (length (mll-net-roots net))) (length owners))
          (not (ormap (lambda (p) (member p consumed equal?)) (mll-net-roots net)))
          (equal? (map (lambda (p) (hash-ref ns p)) (mll-net-roots net))
                  (sort (map (lambda (p) (hash-ref ns p)) (mll-net-roots net)) symbolic-datum<?))
          (for/and ([l (in-list (mll-net-links net))])
            (define in (mll-link-inputs l)) (define out (mll-link-outputs l))
            (and (list? in) (list? out)
                 (case (mll-link-kind l)
                   [(id) (and (null? in) (= (length out) 2)
                              (symbol? (hash-ref ns (car out)))
                              (equal? (mll-dual (hash-ref ns (car out))) (hash-ref ns (cadr out))))]
                   [(source) (and (null? in) (pair? out)
                                  (not (hash-has-key? ns (list 'source (mll-link-id l))))
                                  (equal? (map (lambda (p) (hash-ref ns p)) out)
                                          (sort (map (lambda (p) (hash-ref ns p)) out) symbolic-datum<?)))]
                   [(tensor par) (and (= (length in) 2) (= (length out) 1)
                                      (equal? (hash-ref ns (car out))
                                              (list (mll-link-kind l) (hash-ref ns (car in)) (hash-ref ns (cadr in)))))]
                   [(cut) (and (= (length in) 2) (null? out)
                               (not (hash-has-key? ns (list 'cut (mll-link-id l))))
                               (equal? (mll-dual (hash-ref ns (car in))) (hash-ref ns (cadr in))))]
                   [else #f])))))))
(define (mll-net=? a b)
  (and (mll-net-valid? a) (mll-net-valid? b)
       (equal? (mll-net-nodes a) (mll-net-nodes b))
       (equal? (mll-net-roots a) (mll-net-roots b))
       (equal? (for/hash ([l (in-list (mll-net-links a))]) (values (mll-link-id l) l))
               (for/hash ([l (in-list (mll-net-links b))]) (values (mll-link-id l) l)))))

(define (mll-net-switching net choices #:full? [full? #f])
  (unless (mll-net-valid? net) (error 'mll-net-switching "invalid net"))
  (unless (hash? choices) (error 'mll-net-switching "choices must be a hash"))
  (define pars (filter (lambda (l) (eq? (mll-link-kind l) 'par)) (mll-net-links net)))
  (unless (or full? (and (= (hash-count choices) (length pars))
                        (andmap (lambda (l) (memv (hash-ref choices (mll-link-id l) #f) '(1 2))) pars)))
    (error 'mll-net-switching "illegal or incomplete physical Par choices"))
  (append-map
   (lambda (l)
     (define id (mll-link-id l)) (define in (mll-link-inputs l)) (define out (mll-link-outputs l))
     (case (mll-link-kind l)
       [(id) (list (mll-edge (list id 'axiom) (car out) (cadr out)))]
       [(tensor par)
        (for/list ([p (in-list in)] [i (in-naturals 1)]
                   #:when (or full? (eq? (mll-link-kind l) 'tensor) (= i (hash-ref choices id))))
          (mll-edge (list id 'child i) (car out) p))]
       [(cut source)
        (for/list ([p (in-list (if (eq? (mll-link-kind l) 'cut) in out))] [i (in-naturals 1)])
          (mll-edge (list id 'star i) (list (mll-link-kind l) id) p))]))
   (mll-net-links net)))
(define (mll-net-full-edges n) (mll-net-switching n (hash) #:full? #t))
(define (edge-other e v) (if (equal? v (mll-edge-left e)) (mll-edge-right e) (mll-edge-left e)))
(define (adjacency vertices edges)
  (define h (make-hash))
  (for ([v (in-list vertices)]) (hash-set! h v '()))
  (for ([e (in-list edges)])
    (hash-update! h (mll-edge-left e) (lambda (xs) (cons e xs)) '())
    (hash-update! h (mll-edge-right e) (lambda (xs) (cons e xs)) '())) h)
(define (mll-graph-components vertices edges)
  (define adj (adjacency vertices edges)) (define seen (make-hash))
  (define (walk v)
    (if (hash-ref seen v #f) '()
        (begin (hash-set! seen v #t)
               (cons v (append-map (lambda (e) (walk (edge-other e v))) (hash-ref adj v '()))))))
  (for/list ([v (in-list (hash-keys adj))] #:unless (hash-ref seen v #f)) (walk v)))

;; DFS records actual edge incidences, so parallel edges form a real 2-cycle.
(define (mll-find-cycle edges)
  (define adj (adjacency '() edges)) (define seen (make-hash))
  (define answer #f)
  (define (dfs v path-vertices path-edges parent)
    (hash-set! seen v #t)
    (for ([e (in-list (hash-ref adj v '()))] #:break answer
          #:unless (and parent (equal? (mll-edge-id e) parent)))
      (define w (edge-other e v))
      (define old (index-of path-vertices w equal?))
      (cond [old (set! answer (append (take path-edges old) (list e)))]
            [(not (hash-ref seen w #f))
             (dfs w (cons w path-vertices) (cons e path-edges) (mll-edge-id e))])))
  (for ([v (in-list (hash-keys adj))] #:break answer #:unless (hash-ref seen v #f))
    (dfs v (list v) '() #f))
  answer)
(define (mll-verify-cycle net choices cycle)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (define edges (mll-net-switching net choices))
    (and (list? cycle) (>= (length cycle) 2) (andmap mll-edge? cycle)
         (not (check-duplicates (map mll-edge-id cycle) equal?))
         (andmap (lambda (e) (member e edges equal?)) cycle)
         ;; A connected 2-regular physical subgraph is one simple cycle.
         (let* ([adj (adjacency '() cycle)] [vs (hash-keys adj)])
           (and (for/and ([es (in-hash-values adj)]) (= (length es) 2))
                (= (length (mll-graph-components vs cycle)) 1))))))
(define (mll-net-correctness net #:budget [budget 65536])
  (cond
    [(not (mll-net-valid? net)) (hash 'status 'UNKNOWN 'reason 'invalid-indexed-net)]
    [else
     (define pars (filter (lambda (l) (eq? (mll-link-kind l) 'par)) (mll-net-links net)))
     (define work 0) (define bad #f) (define exhausted #f)
     (define (walk rest choices)
       (unless (or bad exhausted)
         (cond [(null? rest)
                (if (>= work budget) (set! exhausted #t)
                    (begin (set! work (add1 work))
                           (let ([cycle (mll-find-cycle (mll-net-switching net choices))])
                             (when cycle (set! bad (hash 'status 'INCORRECT 'choices choices 'cycle cycle))))))]
               [else (for ([i '(1 2)]) (walk (cdr rest) (hash-set choices (mll-link-id (car rest)) i)))])))
     (walk pars (hash))
     (cond [bad bad] [exhausted (hash 'status 'UNKNOWN 'reason 'switching-budget 'checked work)]
           [else (hash 'status 'CORRECT 'checked work)])]))

(define (mll-net-transport n port-map link-map)
  (define (p x) (hash-ref port-map x x)) (define (l x) (hash-ref link-map x x))
  (mll-net (for/hash ([(x f) (in-hash (mll-net-nodes n))]) (values (p x) f))
           (for/list ([x (in-list (mll-net-links n))])
             (mll-link (l (mll-link-id x)) (mll-link-kind x)
                       (map p (mll-link-inputs x)) (map p (mll-link-outputs x))))
           (map p (mll-net-roots n))))

;; Region validation is exact ownership, not just boundary matching.
(define (embedded-regions n providers embeddings)
  (unless (and (mll-net-valid? n) (list? providers) (list? embeddings)
               (= (length providers) (length embeddings)) (andmap mll-net-valid? providers)
               (andmap mll-embedding? embeddings)) (error 'mll-net-quotient "invalid input"))
  (define host-links (for/hash ([l (in-list (mll-net-links n))]) (values (mll-link-id l) l)))
  (define regions
    (for/list ([s (in-list providers)] [e (in-list embeddings)])
      (define ps (mll-embedding-ports e)) (define ls (mll-embedding-links e))
      (unless (and (hash? ps) (immutable? ps) (hash? ls) (immutable? ls)
                   (= (hash-count ps) (hash-count (mll-net-nodes s)))
                   (= (hash-count ls) (length (mll-net-links s)))
                   (not (check-duplicates (hash-values ps) equal?)) (not (check-duplicates (hash-values ls) equal?))
                   (for/and ([(p f) (in-hash (mll-net-nodes s))])
                     (and (hash-has-key? ps p) (equal? f (hash-ref (mll-net-nodes n) (hash-ref ps p) #f)))))
        (error 'mll-net-quotient "incomplete/noninjective formula embedding"))
      (define mapped (mll-net-transport s ps ls))
      (unless (for/and ([l (in-list (mll-net-links mapped))]) (equal? l (hash-ref host-links (mll-link-id l) #f)))
        (error 'mll-net-quotient "logical links not exactly embedded"))
      (define inside (hash-keys (mll-net-nodes mapped)))
      (for ([l (in-list (mll-net-links n))] #:unless (member (mll-link-id l) (hash-values ls) equal?))
        (for ([p (in-list (append (mll-link-inputs l) (mll-link-outputs l)))] #:when (member p inside equal?))
          (unless (and (member p (mll-link-inputs l) equal?) (member p (mll-net-roots mapped) equal?))
            (error 'mll-net-quotient "exterior meets incomplete provider port"))))
      (for ([p (in-list (mll-net-roots n))] #:when (member p inside equal?))
        (unless (member p (mll-net-roots mapped) equal?) (error 'mll-net-quotient "hidden provider port exported")))
      mapped))
  (when (or (check-duplicates (append-map (lambda (s) (hash-keys (mll-net-nodes s))) regions) equal?)
            (check-duplicates (append-map (lambda (s) (map mll-link-id (mll-net-links s))) regions) equal?))
    (error 'mll-net-quotient "provider regions are not disjoint")) regions)
(define (mll-net-quotient n providers embeddings)
  (define regions (embedded-regions n providers embeddings))
  (define removed-ports (append-map (lambda (s) (hash-keys (mll-net-nodes s))) regions))
  (define removed-links (append-map (lambda (s) (map mll-link-id (mll-net-links s))) regions))
  (define retained-ports (append-map mll-net-roots regions))
  (define q (mll-net
    (for/hash ([(p f) (in-hash (mll-net-nodes n))] #:when (or (not (member p removed-ports equal?)) (member p retained-ports equal?)))
      (values p f))
    (append (filter (lambda (l) (not (member (mll-link-id l) removed-links equal?))) (mll-net-links n))
            (for/list ([s (in-list regions)] [i (in-naturals 1)])
              (mll-link (list 'provider i) 'source '() (mll-net-roots s))))
    (mll-net-roots n)))
  (unless (mll-net-valid? q) (error 'mll-net-quotient "invalid complete-source quotient")) q)
(define (mll-net-replace-net n providers embeddings replacements)
  (define regions (embedded-regions n providers embeddings))
  (unless (= (length replacements) (length regions)) (error 'mll-net-replace-net "wrong tuple length"))
  (define q (mll-net-quotient n providers embeddings))
  (define nodes (mll-net-nodes q))
  (define links (filter (lambda (l) (not (eq? (mll-link-kind l) 'source))) (mll-net-links q)))
  (for ([r (in-list replacements)] [s (in-list regions)] [i (in-naturals 1)])
    (unless (and (mll-net-valid? r)
                 (equal? (map (lambda (p) (hash-ref (mll-net-nodes r) p)) (mll-net-roots r))
                         (map (lambda (p) (hash-ref (mll-net-nodes s) p)) (mll-net-roots s))))
      (error 'mll-net-replace-net "replacement changes complete indexed judgment"))
    (define root-map (for/hash ([a (in-list (mll-net-roots r))] [b (in-list (mll-net-roots s))]) (values a b)))
    (define ps (for/hash ([p (in-hash-keys (mll-net-nodes r))]) (values p (hash-ref root-map p (list 'replacement i p)))))
    (define ls (for/hash ([l (in-list (mll-net-links r))]) (values (mll-link-id l) (list 'replacement i (mll-link-id l)))))
    (define fresh (mll-net-transport r ps ls))
    (set! nodes (for/fold ([ns nodes]) ([(p f) (in-hash (mll-net-nodes fresh))])
                  (when (and (hash-has-key? ns p) (not (member p (mll-net-roots s) equal?)))
                    (error 'mll-net-replace-net "private occurrence collision"))
                  (hash-set ns p f)))
    (set! links (append links (mll-net-links fresh))))
  (define result (mll-net nodes links (mll-net-roots n)))
  (unless (mll-net-valid? result) (error 'mll-net-replace-net "invalid raw assembly")) result)

;; Greedy generalized-source sequentialization. Full graph retains BOTH Par
;; edges. Sources are whole typed native premises, not compound logical axioms.
(define (mll-sequentialize k net #:sources [sources (hash)] #:budget [budget 1000000])
  (with-handlers ([exn:fail? (lambda (e) (hash 'status 'UNKNOWN 'reason 'native-sequentialization 'detail (exn-message e)))])
    (unless (and (mll-schema-calculus? k) (mll-net-valid? net)) (error 'mll-sequentialize "unsupported calculus/net"))
    (define work 0)
    (define (charge amount) (set! work (+ work amount)) (when (> work budget) (error 'mll-sequentialize "graph-work budget")))
    ;; Recursive result: tree, canonical physical root list, labels, holes,
    ;; port transport. Composition prefixes native addresses literally.
    (define (join family id results principals)
      (define trees (map mll-sequentialization-tree results))
      (define rlists (map (lambda (r) (mll-net-roots (mll-observe (mll-sequentialization-tree r)
                                      #:labels (mll-sequentialization-labels r) #:ports (mll-sequentialization-ports r)))) results))
      (define indices
        (case family
          [(tensor cut) (list (add1 (index-of (car rlists) (car principals) equal?))
                              (add1 (index-of (cadr rlists) (cadr principals) equal?)))]
          [(par) (map (lambda (p) (add1 (index-of (car rlists) p equal?))) principals)] [else '()]))
      (define tree (mll-apply k family trees #:indices indices))
      (define labels (if (eq? family 'mix) (hash) (hash '() id)))
      (define holes (hash)) (define ports (hash))
      (for ([r (in-list results)] [slot (in-naturals 1)])
        (for ([(a label) (in-hash (mll-sequentialization-labels r))]) (set! labels (hash-set labels (cons slot a) label)))
        (for ([(h a) (in-hash (mll-sequentialization-holes r))]) (set! holes (hash-set holes h (cons slot a))))
        (for ([(p target) (in-hash (mll-sequentialization-ports r))]) (set! ports (hash-set ports p target))))
      ;; Children have stable explicit labels for every logical node/hole;
      ;; administrative Mix labels do not contribute physical ports.
      (mll-sequentialization tree labels holes ports))
    (define (subnet n ls roots removed)
      (define owns (append-map mll-link-outputs ls))
      (mll-net (for/hash ([p (in-list owns)] #:unless (member p removed equal?)) (values p (hash-ref (mll-net-nodes n) p)))
               ls (sort roots (lambda (a b) (symbolic-datum<? (hash-ref (mll-net-nodes n) a) (hash-ref (mll-net-nodes n) b))))))
    (define (walk/raw n)
      (charge (+ (hash-count (mll-net-nodes n)) (length (mll-net-links n))))
      (define ls (mll-net-links n)) (define roots (mll-net-roots n))
      (define leaf (and (= (length ls) 1) (car ls)))
      (cond
        [(and leaf (memq (mll-link-kind leaf) '(id source)))
         (define id (mll-link-id leaf))
         (cond
           [(eq? (mll-link-kind leaf) 'id)
            (define tree (mll-id k (hash-ref (mll-net-nodes n) (car (mll-link-outputs leaf)))))
            (define ps (hash (list 'id id 1) (car (mll-link-outputs leaf))
                             (list 'id id 2) (cadr (mll-link-outputs leaf))))
            (mll-sequentialization tree (hash '() id) (hash) ps)]
           [else
            (define supplied (hash-ref sources id #f))
            (define tree (or supplied (validate-candidate k raw-hole #:expected (mll-boundary (map (lambda (p) (hash-ref (mll-net-nodes n) p)) roots)))))
            (unless (and (checked-term? tree) (eq? (checked-term-calculus tree) k)
                         (or (checked-hole? tree) (derivation-complete? tree))
                         (equal? (mll-boundary-formulas (derivation-root-boundary tree))
                                 (map (lambda (p) (hash-ref (mll-net-nodes n) p)) roots)))
              (error 'mll-sequentialize "source is not a complete exact typed premise"))
            (cond
              [(checked-hole? tree)
               (mll-sequentialization tree (hash '() id) (hash id '())
                 (for/hash ([p (in-list roots)] [i (in-naturals 1)]) (values (list 'hole id i) p)))]
              [else
               (define local-labels (make-hash))
               (define (label-body t a)
                 (hash-set! local-labels a (list 'source-body id a))
                 (when (checked-node? t)
                   (for ([c (in-list (checked-node-children t))] [i (in-naturals 1)]) (label-body c (append a (list i))))))
               (label-body tree '())
               (define frozen (make-immutable-hash (hash->list local-labels)))
               (define own (mll-observe tree #:labels frozen))
               (mll-sequentialization tree frozen (hash id '())
                 (for/hash ([p (in-list (mll-net-roots own))] [q (in-list roots)]) (values p q)))])])]
        [else
         (define par (findf (lambda (l) (and (eq? (mll-link-kind l) 'par)
                                              (member (car (mll-link-outputs l)) roots equal?))) ls))
         (cond
           [par
            (define out (car (mll-link-outputs par)))
            (define remainder (subnet n (remove par ls equal?)
                                     (append (mll-link-inputs par) (remove out roots equal?)) (list out)))
            (define r (join 'par (mll-link-id par) (list (walk remainder)) (mll-link-inputs par)))
            (struct-copy mll-sequentialization r
              [ports (hash-set (mll-sequentialization-ports r) (list 'out (mll-link-id par)) out)])]
           [else
            (define edges (mll-net-full-edges n))
            (define comps (mll-graph-components (hash-keys (mll-net-nodes n)) edges))
            (cond
              [(> (length comps) 1)
               (define results
                 (for/list ([vs (in-list comps)])
                   (define local (filter (lambda (l) (member (car (append (mll-link-outputs l) (mll-link-inputs l))) vs equal?)) ls))
                   (walk (subnet n local (filter (lambda (p) (member p vs equal?)) roots) '()))))
               (for/fold ([result (car results)]) ([r (in-list (cdr results))]) (join 'mix #f (list result r) '()))]
              [else
               (define split #f)
               (for ([l (in-list ls)] #:break split
                     #:when (or (eq? (mll-link-kind l) 'cut)
                                (and (eq? (mll-link-kind l) 'tensor) (member (car (mll-link-outputs l)) roots equal?))))
                 (define removed (mll-link-outputs l))
                 (define remain (remove l ls equal?))
                 (define ns (subnet n remain (append (mll-link-inputs l) (filter (lambda (p) (not (member p removed equal?))) roots)) removed))
                 (define parts (mll-graph-components (hash-keys (mll-net-nodes ns)) (mll-net-full-edges ns)))
                 (charge (+ (hash-count (mll-net-nodes n)) (length edges)))
                 (define a (findf (lambda (vs) (member (car (mll-link-inputs l)) vs equal?)) parts))
                 (define b (findf (lambda (vs) (member (cadr (mll-link-inputs l)) vs equal?)) parts))
                 (when (and a b (not (equal? a b)) (= (length parts) 2)) (set! split (list l ns a b))))
               (unless split (error 'mll-sequentialize "no splitting exterior Tensor/current Cut (incorrect or unsupported quotient)"))
               (define l (car split)) (define ns (cadr split))
               (define results
                 (for/list ([vs (in-list (cddr split))])
                   (define local (filter (lambda (x) (member (car (append (mll-link-outputs x) (mll-link-inputs x))) vs equal?)) (mll-net-links ns)))
                   (walk (subnet ns local (filter (lambda (p) (member p vs equal?)) (mll-net-roots ns)) '()))))
               (define r (join (mll-link-kind l) (mll-link-id l) results (mll-link-inputs l)))
               (if (eq? (mll-link-kind l) 'tensor)
                   (struct-copy mll-sequentialization r [ports (hash-set (mll-sequentialization-ports r) (list 'out (mll-link-id l)) (car (mll-link-outputs l)))]) r)])])]))
    ;; Canonical displayed formulas do not fix the physical order of repeated
    ;; equal roots. Reapply the exact top rule with the indexed exchange needed
    ;; by this induced premise, before its parent consumes designated ports.
    (define (walk n)
      (define r (walk/raw n))
      (define t (mll-sequentialization-tree r))
      (define observed (mll-observe t #:labels (mll-sequentialization-labels r)
                                   #:ports (mll-sequentialization-ports r)))
      (define actual (mll-net-roots observed))
      (define wanted (mll-net-roots n))
      (cond
        [(equal? actual wanted) r]
        [(checked-hole? t) (error 'mll-sequentialize "opaque root transport changed order")]
        [else
         (unless (and (= (length actual) (length wanted))
                      (andmap (lambda (p) (member p actual equal?)) wanted))
           (error 'mll-sequentialize "reconstructed proof changes complete interface"))
         (define d (mll-occurrence-data k (checked-node-occurrence t)))
         (define tokens (hash-ref d 'order))
         (define order (map (lambda (p) (list-ref tokens (index-of actual p equal?))) wanted))
         (define revised (mll-apply k (hash-ref d 'family) (checked-node-children t)
                                   #:indices (hash-ref d 'indices) #:order order #:atom (hash-ref d 'atom)))
         (struct-copy mll-sequentialization r [tree revised])]))
    (define result (walk net))
    ;; No success flag substitutes for exact q; source fills are checked by the
    ;; caller against their original embeddings, while open q is checked here.
    (define observed (mll-observe (mll-sequentialization-tree result)
                                 #:labels (mll-sequentialization-labels result)
                                 #:ports (mll-sequentialization-ports result)))
    (unless (or (positive? (hash-count sources)) (mll-net=? observed net))
      (error 'mll-sequentialize "reconstructed native presentation changes exact q"))
    result))
