#lang racket/base

;; Run: racket examples/ck-upgrade-certificates.rkt
;; These are finite native certificate demonstrations, not a test of the
;; universal paper theorem. The literal K2,2 obstruction is old material.
(require racket/list
         "../potkin/main.rkt"
         "../potkin/kernel/mll-schema.rkt"
         "../potkin/analysis/mll-net.rkt"
         "../potkin/analysis/mll-normalization.rkt"
         "../potkin/analysis/ck-upgrade-certificates.rkt")

(provide (struct-out upgrade-fixture) make-upgrade-fixture
         fixture-input fixture-singleton fixture-supported-union embedding-by-address
         identity-detour atomic-detour)

(struct upgrade-fixture (calculus host modules providers embeddings) #:transparent)
(define (formula-index p f [skip 0])
  (or (for/first ([x (in-list (mll-boundary-formulas (derivation-root-boundary p)))]
                 [i (in-naturals 1)]
                 #:when (equal? x f)
                 #:when (begin0 (zero? skip) (set! skip (sub1 skip)))) i)
      (error 'formula-index "missing indexed formula ~s" f)))
(define (mix k a b) (mll-apply k 'mix (list a b)))
(define (tensor k a b fa fb)
  (mll-apply k 'tensor (list a b)
             #:indices (list (formula-index a fa) (formula-index b fb))))

;; A real logical identity detour. Compound arguments are deliberately NOT
;; claimed to give rank-one Cuts.
(define (identity-detour p a b)
  (define k (checked-term-calculus p))
  (define left (mll-apply k 'par (list p)
                #:indices (list (formula-index p a)
                                (formula-index p b (if (equal? a b) 1 0)))))
  (define right (tensor k (mll-expanded-id k a) (mll-expanded-id k b)
                        (mll-dual a) (mll-dual b)))
  (define principal (list 'par a b))
  (mll-apply k 'cut (list left right)
             #:indices (list (formula-index left principal)
                             (formula-index right (mll-dual principal)))))
(define (atomic-detour p atom)
  (define k (checked-term-calculus p))
  (define id (mll-id k (if (symbol? atom) atom (cadr atom))))
  (mll-apply k 'cut (list p id)
             #:indices (list (formula-index p atom)
                             (formula-index id (mll-dual atom)))))

;; Match complete logical links and all their physical ports; administrative
;; Mix vertices are intentionally absent from the auxiliary exact observer.
(define (embedding-by-address host provider address-map)
  (define hn (mll-observe host))
  (define pn (mll-observe provider))
  (define links
    (for/hash ([l (in-list (mll-net-links pn))])
      (values (mll-link-id l) (address-map (mll-link-id l)))))
  (define ports (make-hash))
  (for ([l (in-list (mll-net-links pn))])
    (define target
      (findf (lambda (t) (equal? (mll-link-id t) (hash-ref links (mll-link-id l))))
             (mll-net-links hn)))
    (unless (and target (eq? (mll-link-kind l) (mll-link-kind target)))
      (error 'embedding-by-address "missing corresponding complete logical link"))
    (for ([p (in-list (append (mll-link-inputs l) (mll-link-outputs l)))]
          [q (in-list (append (mll-link-inputs target) (mll-link-outputs target)))])
      (when (and (hash-has-key? ports p) (not (equal? (hash-ref ports p) q)))
        (error 'embedding-by-address "inconsistent physical-port transport"))
      (hash-set! ports p q)))
  (mll-embedding (for/hash ([(p q) (in-hash ports)]) (values p q)) links))

(define (make-upgrade-fixture #:compound? [compound? #f]
                              #:higher-rank? [higher-rank? #f]
                              #:sector [sector 'full])
  (define k (make-mll-schema-calculus #:sector sector))
  (define compound '(tensor (tensor p q) r))
  (define formulas (if compound? (make-list 4 compound) '(a b c d)))
  (define original (map (lambda (f) (mll-expanded-id k f)) formulas))
  (define modules
    (if higher-rank?
        (cons (identity-detour (car original) (car formulas) (mll-dual (car formulas)))
              (cdr original)) original))
  (define left (tensor k (first modules) (second modules) (first formulas) (second formulas)))
  (define right (tensor k (third modules) (fourth modules) (third formulas) (fourth formulas)))
  (define host (mix k left right))
  (define providers (list (mix k (first modules) (third modules))
                          (mix k (second modules) (fourth modules))))
  (define (cross first-stem second-stem)
    (lambda (a)
      (unless (pair? a) (error 'fixture "provider Mix has no observed root link"))
      (append (if (= (car a) 1) first-stem second-stem) (cdr a))))
  (define embeddings
    (list (embedding-by-address host (first providers) (cross '(1 1) '(2 1)))
          (embedding-by-address host (second providers) (cross '(1 2) '(2 2)))))
  (upgrade-fixture k host modules providers embeddings))
(define (fixture-input f)
  (ck-upgrade-input (upgrade-fixture-host f) (upgrade-fixture-providers f)
                    (upgrade-fixture-embeddings f)))
(define (fixture-singleton f i)
  (ck-upgrade-input (upgrade-fixture-host f)
                    (list (list-ref (upgrade-fixture-providers f) (sub1 i)))
                    (list (list-ref (upgrade-fixture-embeddings f) (sub1 i)))))
(define (fixture-supported-union f)
  (define host (upgrade-fixture-host f))
  (define ps (checked-node-children host))
  (ck-upgrade-input host ps
    (for/list ([p (in-list ps)] [i (in-naturals 1)])
      (embedding-by-address host p (lambda (a) (cons i a))))))
(define (show name result)
  (printf "~a: ~a" name (ck-upgrade-result-status result))
  (when (ck-upgrade-result-reason result) (printf " (~a)" (ck-upgrade-result-reason result)))
  (newline))
(define (require-status result expected)
  (unless (eq? (ck-upgrade-result-status result) expected)
    (error 'demonstration "expected ~a, received ~s" expected result)))

(module+ main
  (define literal (make-upgrade-fixture))
  (for ([i '(1 2)])
    (define accepted (query-ck-upgrade (fixture-singleton literal i)))
    (show (format "old literal singleton ~a" i) accepted)
    (require-status accepted 'ACCEPT)
    (define filled (consume-ck-upgrade (ck-upgrade-result-certificate accepted)
                     (list (list-ref (upgrade-fixture-providers literal) (sub1 i)))))
    (unless (eq? (ck-upgrade-fill-result-status filled) 'ACCEPT)
      (error 'demonstration "actual singleton remainder was not consumed")))
  (define rejected (query-ck-upgrade (fixture-input literal)))
  (show "old literal K2,2 union" rejected)
  (require-status rejected 'REJECT)
  (printf "  independently checked raw cycle: ~s\n"
          (ck-upgrade-negative-cycle (ck-upgrade-result-certificate rejected)))

  ;; An admitted F0 update of the unsupported opaque batch is still correct.
  (define atomic-qs
    (for/list ([p (in-list (upgrade-fixture-providers literal))] [a '(a b)])
      (atomic-detour p a)))
  (define raw-atomic
    (mll-net-replace-net (mll-observe (upgrade-fixture-host literal))
      (map mll-observe (upgrade-fixture-providers literal))
      (upgrade-fixture-embeddings literal) (map mll-observe atomic-qs)))
  (unless (eq? (hash-ref (mll-net-correctness raw-atomic) 'status) 'CORRECT)
    (error 'demonstration "atomic-equivalent raw update failed"))
  (define atomic-seq (mll-sequentialize (upgrade-fixture-calculus literal) raw-atomic))
  (unless (and (mll-sequentialization? atomic-seq)
               (equal? (mll-normal-identity (mll-sequentialization-tree atomic-seq))
                       (mll-normal-identity (upgrade-fixture-host literal))))
    (error 'demonstration "atomic update changed whole indexed normal identity"))
  (printf "atomic equivalent batch: correct; whole normal identity preserved; no opaque remainder claimed\n")

  (define compound (make-upgrade-fixture #:compound? #t))
  (define compound-result (query-ck-upgrade (fixture-input compound)))
  (show "repeated compound interfaces" compound-result)
  (require-status compound-result 'REJECT)
  (printf "  general native countertuple maximum Cut ranks: ~s\n"
          (map mll-proof-max-cut-rank
               (ck-upgrade-negative-replacements (ck-upgrade-result-certificate compound-result))))
  (define higher (make-upgrade-fixture #:compound? #t #:higher-rank? #t))
  (define higher-result (query-ck-upgrade (fixture-input higher)))
  (show "higher-rank original normalized before binary stress" higher-result)
  (require-status higher-result 'REJECT)

  (define supported (query-ck-upgrade (fixture-supported-union literal)))
  (show "supported native union" supported)
  (require-status supported 'ACCEPT)
  (define certificate (ck-upgrade-result-certificate supported))
  (define flags (prepare-ck-upgrade-stages certificate
                  (map list (reverse (ck-upgrade-positive-provider-order certificate)))))
  (require-status (verify-ck-upgrade-stages flags) 'ACCEPT)
  (define union-fillers
    (map atomic-detour (ck-upgrade-input-providers (fixture-supported-union literal))
         '((neg a) (neg c))))
  (define staged (consume-ck-upgrade-stages flags
                   union-fillers))
  (unless (and (eq? (ck-upgrade-fill-result-status staged) 'ACCEPT)
               (ck-upgrade-fill-result-normal-preserved? staged))
    (error 'demonstration "staged/direct native consumption failed"))
  (printf "  reverse chronological stage-to-union indices: ~s\n"
          (ck-upgrade-stages-stage-index-maps flags))
  (printf "Evidence: CODE-CHECKED finite certificates. No universal theorem or registered replay claimed.\n"))
