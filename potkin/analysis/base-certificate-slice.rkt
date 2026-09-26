#lang racket/base

;; Canonical base-provenance certificate slices over native checked proofs.
;;
;; Paper-level correctness argument (PROVED, not a mechanized theorem).
;; For a vertex address a, the material-stock bottom-up summary says that the
;; subtree at a is wholly base exactly when it contains no extension vertex.
;; Hence L = {a | the subtree at a is not wholly base} is precisely the
;; ancestor closure of the extension vertices.  In the complementary forest,
;; the vertices whose parents lie in L are the unique roots of its maximal
;; connected components.  Those roots are nonroot and prefix-free whenever L
;; is nonempty, so the native CK witness at them removes exactly the complement
;; of L.  Any other supported CK cut selects roots inside those same components
;; and therefore removes only a subset of the complement: its remainder still
;; contains L, with equality only at the component-root cut.  With unit vertex
;; weights, selecting a wholly-base component root has mass one greater than
;; the best product of choices strictly below it.  Structural induction on the
;; supported-frontier circuit therefore makes the same canonical selection the
;; unique max-plus choice.  The all-base case is the separately represented
;; whole endpoint, never a root cut.
;;
;; The records below are immutable derived analysis metadata.  They are never
;; accepted as proof, cut, forest, context, or registry evidence; those roles
;; remain with the native POTKIN objects retained in the result.

(require racket/list
         "../kernel/address.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "material-stock.rkt")

(provide base-occurrence-mark?
         base-occurrence-mark-address
         base-occurrence-mark-occurrence
         base-occurrence-mark-base?
         base-occurrence-mark-subtree-base?
         base-occurrence-mark-retained?

         base-slice-whole-endpoint?
         base-slice-whole-endpoint-calculus
         base-slice-whole-endpoint-source
         base-slice-whole-endpoint-profile

         supported-ck-frontier-circuit?
         supported-ck-frontier-circuit-calculus
         supported-ck-frontier-circuit-source
         supported-ck-frontier-circuit-profile
         supported-ck-frontier-circuit-whole-endpoint
         supported-ck-frontier-count
         supported-ck-frontier-exists?

         supported-frontier-choice?
         supported-frontier-choice-mass
         supported-frontier-choice-kind
         supported-frontier-choice-addresses
         supported-frontier-choice-witness
         supported-frontier-choice-endpoint
         supported-ck-frontier-max

         base-certificate-slice?
         base-certificate-slice-calculus
         base-certificate-slice-source
         base-certificate-slice-profile
         base-certificate-slice-classification
         base-certificate-slice-retained-addresses
         base-certificate-slice-kind
         base-certificate-slice-endpoint
         base-certificate-slice-witness
         base-certificate-slice-detached
         base-certificate-slice-forest
         base-certificate-slice-remainder
         base-certificate-slice-hole-module-map
         base-certificate-slice-reconstruction
         base-certificate-slice-circuit
         make-base-certificate-slice)

;; `base?` classifies the exact occurrence at this address.  `subtree-base?`
;; summarizes every occurrence below it.  A retained vertex is in L.
(struct base-occurrence-mark
  (address occurrence base? subtree-base? retained?)
  #:constructor-name make-base-occurrence-mark/internal
  #:transparent)

;; There is intentionally no cut-witness field: the whole endpoint is not a
;; native root cut.
(struct base-slice-whole-endpoint (calculus source profile)
  #:constructor-name make-base-slice-whole-endpoint/internal
  #:transparent)

;; A node is a compact recurrence cell, not a second proof-tree carrier.  It
;; stores only the native occurrence address, the bottom-up base summary and
;; vertex mass, plus ordered recurrence inputs.
(struct supported-frontier-node
  (address subtree-base? subtree-vertex-count children)
  #:constructor-name make-supported-frontier-node/internal
  #:transparent)

(struct supported-ck-frontier-circuit
  (calculus source profile root whole-endpoint)
  #:constructor-name make-supported-ck-frontier-circuit/internal
  #:transparent)

;; The pointer is resolved back to a native witness, except for `whole`, whose
;; endpoint remains explicitly witness-free.
(struct supported-frontier-choice
  (mass kind addresses witness endpoint)
  #:constructor-name make-supported-frontier-choice/internal
  #:transparent)

(struct frontier-evaluation (count exists? mass addresses) #:transparent)

(struct base-certificate-slice
  (calculus source profile classification retained-addresses kind endpoint
            witness detached forest remainder hole-module-map reconstruction
            circuit)
  #:constructor-name make-base-certificate-slice/internal
  #:transparent)

(define (product-evaluation evaluations)
  (frontier-evaluation
   (for/product ([evaluation (in-list evaluations)])
     (frontier-evaluation-count evaluation))
   (for/and ([evaluation (in-list evaluations)])
     (frontier-evaluation-exists? evaluation))
   (for/sum ([evaluation (in-list evaluations)])
     (frontier-evaluation-mass evaluation))
   (sort
    (append-map frontier-evaluation-addresses evaluations)
    address<?)))

(define (evaluate-frontier-node node ambient-root?)
  (define descended
    (product-evaluation
     (for/list ([child (in-list (supported-frontier-node-children node))])
       (evaluate-frontier-node child #f))))
  (cond
    [(or ambient-root?
         (not (supported-frontier-node-subtree-base? node)))
     descended]
    [else
     ;; Positive unit mass makes selecting this entire component strictly
     ;; better than every selection strictly below its root.
     (define selected-mass
       (supported-frontier-node-subtree-vertex-count node))
     (unless (> selected-mass (frontier-evaluation-mass descended))
       (error 'supported-ck-frontier-max
              "positive unit mass failed to distinguish a base component root"))
     (frontier-evaluation
      (add1 (frontier-evaluation-count descended))
      #t
      selected-mass
      (list (supported-frontier-node-address node)))]))

(define (evaluate-frontier circuit who)
  (unless (supported-ck-frontier-circuit? circuit)
    (raise-argument-error who "supported-ck-frontier-circuit?" circuit))
  (evaluate-frontier-node
   (supported-ck-frontier-circuit-root circuit) #t))

;; Counts ordinary native CK cuts, including the empty cut.  The possible
;; whole endpoint is exposed separately on the circuit and is not added here.
(define (supported-ck-frontier-count circuit)
  (frontier-evaluation-count
   (evaluate-frontier circuit 'supported-ck-frontier-count)))

;; Boolean-semiring evaluation of the same ordinary native frontier.
(define (supported-ck-frontier-exists? circuit)
  (frontier-evaluation-exists?
   (evaluate-frontier circuit 'supported-ck-frontier-exists?)))

(define (supported-ck-frontier-max circuit)
  (define evaluation
    (evaluate-frontier circuit 'supported-ck-frontier-max))
  (define endpoint
    (supported-ck-frontier-circuit-whole-endpoint circuit))
  (cond
    [endpoint
     (define whole-mass
       (derivation-vertex-count
        (supported-ck-frontier-circuit-source circuit)))
     (unless (> whole-mass (frontier-evaluation-mass evaluation))
       (error 'supported-ck-frontier-max
              "the whole endpoint did not strictly dominate nonroot cuts"))
     (make-supported-frontier-choice/internal
      whole-mass 'whole '() #f endpoint)]
    [else
     (define addresses (frontier-evaluation-addresses evaluation))
     (define witness
       (make-cut-witness
        (supported-ck-frontier-circuit-source circuit) addresses))
     (when (cut-error? witness)
       (error 'supported-ck-frontier-max
              "the compact circuit produced a non-native cut: ~e"
              witness))
     (make-supported-frontier-choice/internal
      (frontier-evaluation-mass evaluation)
      (if (null? addresses) 'empty 'proper)
      addresses
      witness
      #f)]))

(define (make-base-certificate-slice source profile)
  (define who 'make-base-certificate-slice)
  (unless (complete-proof? source)
    (raise-argument-error who "complete-proof?" source))
  (unless (material-profile? profile)
    (raise-argument-error who "material-profile?" profile))

  ;; This is the unique existing exact-registry classifier.  Its scan is the
  ;; bottom-up half of the construction and also enforces exact provenance.
  (define uses (direct-material-uses source profile))
  (define calculus (material-profile-calculus profile))
  (define use-table
    (for/hash ([use (in-list uses)])
      (values (material-use-address use) use)))

  (define reversed-classification '())
  (define reversed-retained '())
  (define reversed-module-roots '())

  ;; One top-down pass turns the bottom-up summaries into L, maximal
  ;; complementary roots, and the compact recurrence circuit.
  (define (walk term address parent-retained? ambient-root?)
    (unless (checked-node? term)
      (error who "a complete proof unexpectedly contained a puncture"))
    (define use
      (hash-ref use-table address
                (lambda ()
                  (error who "material scan omitted vertex address ~e"
                         address))))
    (define base? (material-use-designated? use))
    (define subtree-base? (material-use-subtree-material? use))
    (define retained? (not subtree-base?))
    (set! reversed-classification
          (cons
           (make-base-occurrence-mark/internal
            address
            (material-use-occurrence use)
            base?
            subtree-base?
            retained?)
           reversed-classification))
    (when retained?
      (set! reversed-retained (cons address reversed-retained)))
    (when (and (not ambient-root?) subtree-base? parent-retained?)
      (set! reversed-module-roots
            (cons address reversed-module-roots)))
    (define children
      (for/list ([child (in-list (checked-node-children term))]
                 [slot (in-naturals 1)])
        (walk child
              (address-append address (list slot))
              retained?
              #f)))
    (make-supported-frontier-node/internal
     address
     subtree-base?
     (material-use-subtree-vertex-count use)
     children))

  (define circuit-root (walk source root-address #f #t))
  (define classification (reverse reversed-classification))
  (define retained-addresses (reverse reversed-retained))
  (define module-roots (reverse reversed-module-roots))
  (define wholly-base?
    (supported-frontier-node-subtree-base? circuit-root))
  (define endpoint
    (and wholly-base?
         (make-base-slice-whole-endpoint/internal
          calculus source profile)))
  (define circuit
    (make-supported-ck-frontier-circuit/internal
     calculus source profile circuit-root endpoint))

  (cond
    [wholly-base?
     (unless (null? retained-addresses)
       (error who "a wholly-base proof unexpectedly retained vertices"))
     (make-base-certificate-slice/internal
      calculus source profile classification retained-addresses 'whole
      endpoint #f #f #f #f #f source circuit)]
    [else
     (define witness (make-cut-witness source module-roots))
     (when (cut-error? witness)
       (error who "canonical component roots are not a native CK cut: ~e"
              witness))
     (unless (equal? (cut-witness-addresses witness) module-roots)
       (error who "native cut validation changed canonical module roots"))
     (define detached (cut-witness-detached witness))
     (unless (equal? (map detached-entry-address detached) module-roots)
       (error who "native detached tuple is not aligned with module roots"))
     (for ([address (in-list module-roots)])
       (unless (material-use-subtree-material?
                (hash-ref use-table address))
         (error who "canonical detached module is not wholly base: ~e"
                address)))
     (define forest (cut-witness-forest witness))
     (unless (eq? (proof-forest-calculus forest) calculus)
       (error who "native detached forest lost exact calculus provenance"))
     (define remainder (cut-witness-remainder witness))
     (unless (and (checked-term-has-exact-calculus? remainder calculus)
                  (equal? (vertex-addresses remainder)
                          retained-addresses))
       (error who "native punctured remainder does not contain exactly L"))
     (define hole-module-map
       (for/hash ([entry (in-list detached)])
         (values (detached-entry-address entry) entry)))
     (unless (= (hash-count hole-module-map) (length detached))
       (error who "hole-to-module occurrence mapping collapsed multiplicity"))
     (define reconstruction (reconstruct-cut-witness witness))
     (unless (and (checked-term? reconstruction)
                  (checked-term-has-exact-calculus?
                   reconstruction calculus)
                  (equal? reconstruction source)
                  (cut-witness-reconstructs? witness))
       (error who "canonical native filling failed exact reconstruction"))
     (make-base-certificate-slice/internal
      calculus source profile classification retained-addresses
      (if (null? module-roots) 'empty 'proper)
      #f witness detached forest remainder hole-module-map reconstruction
      circuit)]))
