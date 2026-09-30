#lang racket/base

;; Compositional exact-material CK transport through a native one-hole proof
;; context.  No cut of either completed filling is enumerated here.  At a
;; constructor r(U_1,...,U_n), the unique spine child and every off-spine
;; sibling supply their already checked pointed choices.  Their Cartesian
;; product is sent through the ordered pointed-premise graft.  A child whole
;; endpoint is represented in the retained tuple by the native typed Box in
;; that premise slot; only the detached proof forests are multiplied, by
;; commutative forest union.  The result is rechecked and its known prefixed
;; addresses construct a native cut witness and typed remainder.
;;
;; Paper proof (constructor induction).  Below the root, every admissible cut
;; restricts uniquely to one of empty/proper/whole in each ordered child, and
;; conversely a tuple of those restrictions has prefix-free prefixed roots.
;; Native cut reconstruction and ordered filling are inverse on that tuple.
;; Exact materiality is multiplicative over the detached forest, so filtering
;; the child families before their product loses and invents no selected cut.
;; The root cut is not admissible; its t tensor 1 contribution is projected
;; separately exactly when the entire checked filling is material.  Induction
;; along the unique hole spine proves the context-composition law implemented
;; below.  This is a paper argument instantiated by executable certificates,
;; not a mechanized universal theorem.
;;
;; Independent scalar recurrence.  Let p be the ordinary selected left-forest
;; polynomial and let q be the potential whole term with its z factor removed:
;; q_U(t)=epsilon_U t^|U|.  For a pointed constructor, put
;;
;;   A = product_{off-spine V} (p_V + z q_V),
;;   E = epsilon_r product_V epsilon_V,
;;   d = 1 + sum_V |V|.
;;
;; Differences transform by the two-state matrix
;;
;;       [ A   z A ] [Delta p]
;;       [ 0  E t^d] [Delta q].
;;
;; Thus the upper-right entry records exactly the case where changing the
;; filling changes whole-subtree purity.  Matrices are retained inner-to-outer.

(require racket/list
         "../algebra/formal-sum.rkt"
         "../hopf/ck.rkt"
         "../kernel/address.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "ancestry.rkt"
         "cocycle.rkt"
         "material-hopf-selector.rkt"
         "material-stock.rkt")

(provide (struct-out material-context-transport-failure)
         (struct-out material-coaction-state)
         (struct-out material-context-matrix)
         material-context-matrix-upper-right
         apply-material-context-matrix
         material-polynomial-at-t=1
         (struct-out material-context-side-certificate)
         (struct-out material-context-transport-certificate)
         transport-material-coaction-difference)

(struct material-context-transport-failure (code message details)
  #:transparent)

;; Both entries are immutable Laurent-free Z[z,t] polynomials represented by
;; hashes from (list z-degree t-degree) to an exact integer coefficient.  The
;; q entry has z-degree zero by construction.
(struct material-coaction-state (p q) #:transparent)

;; This stores the diagonal entries A and E t^d.  The upper-right entry z A is
;; derived, so the matrix cannot accidentally give it incompatible data.
(struct material-context-matrix
  (occurrence spine-slot off-spine-full-polynomial purity-polynomial)
  #:transparent)

(struct material-context-side-certificate
  (proof choices steps ordinary-coaction whole-endpoint full-coaction
   ordinary-polynomial whole-core-polynomial pure? proper-witnesses)
  #:transparent)

(struct material-context-transport-certificate
  (calculus context profile source target source-filling target-filling
   source-side target-side local-difference transported-difference
   local-state matrices predicted-state actual-state retained-witness
   verified?)
  #:transparent)

(struct side-state
  (proof choices steps ordinary-coaction whole-endpoint full-coaction
   ordinary-polynomial whole-core-polynomial pure? proper-witnesses)
  #:transparent)

(struct paired-state (source target matrices) #:transparent)

(define (transport-failure code message . details)
  (material-context-transport-failure code message
                                      (if (null? details) (hash) (car details))))

;; --------------------------------------------------------------------------
;; Small immutable polynomial layer used only for the independent matrix
;; calculation.  It is summary data, never a proof/cut/forest carrier.

(define zero-polynomial (hash))
(define one-polynomial (hash (list 0 0) 1))
(define z-polynomial (hash (list 1 0) 1))

(define (polynomial-add-coefficient polynomial key coefficient)
  (define combined (+ (hash-ref polynomial key 0) coefficient))
  (if (zero? combined)
      (hash-remove polynomial key)
      (hash-set polynomial key combined)))

(define (polynomial-add left right)
  (for/fold ([result left]) ([(key coefficient) (in-hash right)])
    (polynomial-add-coefficient result key coefficient)))

(define (polynomial-scale coefficient polynomial)
  (for/hash ([(key value) (in-hash polynomial)]
             #:unless (zero? (* coefficient value)))
    (values key (* coefficient value))))

(define (polynomial-subtract left right)
  (polynomial-add left (polynomial-scale -1 right)))

(define (polynomial-multiply left right)
  (for*/fold ([result zero-polynomial])
             ([(left-key left-coefficient) (in-hash left)]
              [(right-key right-coefficient) (in-hash right)])
    (polynomial-add-coefficient
     result
     (list (+ (first left-key) (first right-key))
           (+ (second left-key) (second right-key)))
     (* left-coefficient right-coefficient))))

(define (polynomial-product polynomials)
  (for/fold ([result one-polynomial]) ([polynomial (in-list polynomials)])
    (polynomial-multiply result polynomial)))

(define (material-context-matrix-upper-right matrix)
  (unless (material-context-matrix? matrix)
    (raise-argument-error
     'material-context-matrix-upper-right "material-context-matrix?" matrix))
  (polynomial-multiply
   z-polynomial
   (material-context-matrix-off-spine-full-polynomial matrix)))

(define (apply-material-context-matrix matrix state)
  (unless (material-context-matrix? matrix)
    (raise-argument-error
     'apply-material-context-matrix "material-context-matrix?" matrix))
  (unless (material-coaction-state? state)
    (raise-argument-error
     'apply-material-context-matrix "material-coaction-state?" state))
  (define a
    (material-context-matrix-off-spine-full-polynomial matrix))
  (define e
    (material-context-matrix-purity-polynomial matrix))
  (material-coaction-state
   (polynomial-add
    (polynomial-multiply a (material-coaction-state-p state))
    (polynomial-multiply
     (material-context-matrix-upper-right matrix)
     (material-coaction-state-q state)))
   (polynomial-multiply e (material-coaction-state-q state))))

(define (material-polynomial-at-t=1 polynomial)
  (unless (hash? polynomial)
    (raise-argument-error 'material-polynomial-at-t=1 "hash?" polynomial))
  (for/fold ([result (hash)]) ([(key coefficient) (in-hash polynomial)])
    (define z-degree (first key))
    (define combined (+ (hash-ref result z-degree 0) coefficient))
    (if (zero? combined)
        (hash-remove result z-degree)
        (hash-set result z-degree combined))))

(define (coaction-left-polynomial sum)
  (for/fold ([polynomial zero-polynomial])
            ([term (in-list (formal-sum-terms sum))])
    (define forest (vector-ref (car term) 0))
    (polynomial-add-coefficient
     polynomial
     (list (proof-forest-size forest) (forest-degree forest))
     (cdr term))))

;; --------------------------------------------------------------------------
;; Native pointed choices and compositional constructor steps

(define (singleton-forest term)
  (make-proof-forest (checked-term-calculus term) (list term)))

(define (choice-tensor calculus choice)
  (pure-tensor
   calculus
   (vector
    (pointed-coaction-choice-detached-forest choice)
    (singleton-forest (pointed-coaction-choice-retained-input choice)))))

(define (choices->ordinary-coaction calculus choices)
  (make-formal-sum
   calculus 2
   (for/list ([choice (in-list choices)]
              #:unless (eq? (pointed-coaction-choice-kind choice) 'whole))
     (define tensor (choice-tensor calculus choice))
     (define term (car (formal-sum-terms tensor)))
     (cons (car term) (cdr term)))))

(define (material-whole-endpoint calculus selector proof)
  (if (material-hopf-selector-forest-pure?
       selector (singleton-forest proof))
      (pure-tensor
       calculus
       (vector (singleton-forest proof) (empty-proof-forest calculus)))
      (tensor-zero calculus 2)))

(define (whole-core-polynomial proof pure?)
  (if pure?
      (hash (list 0 (derivation-vertex-count proof)) 1)
      zero-polynomial))

(define (root-position proof)
  (pointed-input-position
   1 root-address (derivation-root-boundary proof) proof))

(define (choice-selected? selector choice)
  (material-hopf-selector-forest-pure?
   selector (pointed-coaction-choice-detached-forest choice)))

(define (initial-side-state proof selector limit)
  (define calculus (checked-term-calculus proof))
  (define choices-or-limit
    (pointed-input-coaction-choices (root-position proof) #:limit limit))
  (cond
    [(analysis-limit? choices-or-limit) choices-or-limit]
    [(analysis-error? choices-or-limit) choices-or-limit]
    [else
     (define choices
       (filter (lambda (choice) (choice-selected? selector choice))
               choices-or-limit))
     (define ordinary
       (choices->ordinary-coaction calculus choices))
     (define pure?
       (material-hopf-selector-forest-pure?
        selector (singleton-forest proof)))
     (define whole (material-whole-endpoint calculus selector proof))
     (define full (formal-sum-add ordinary whole))
     (define proper
       (for/list ([choice (in-list choices)]
                  #:when (and (eq? (pointed-coaction-choice-kind choice)
                                   'proper)
                              (cut-witness?
                               (pointed-coaction-choice-witness choice))))
         (pointed-coaction-choice-witness choice)))
     (side-state
      proof choices '() ordinary whole full
      (coaction-left-polynomial ordinary)
      (whole-core-polynomial proof pure?)
      pure? proper)]))

(define (rebase-choice choice position)
  (pointed-coaction-choice
   position
   (pointed-coaction-choice-kind choice)
   (pointed-coaction-choice-relative-addresses choice)
   (pointed-coaction-choice-witness choice)
   (pointed-coaction-choice-detached-forest choice)
   (pointed-coaction-choice-retained-input choice)))

(define (certificate->choice certificate position)
  (define witness
    (grafting-choice-certificate-global-witness certificate))
  (pointed-coaction-choice
   position
   (if (null? (cut-witness-addresses witness)) 'empty 'proper)
   (cut-witness-addresses witness)
   witness
   (cut-witness-forest witness)
   (cut-witness-remainder witness)))

(define (whole-choice proof position)
  (pointed-coaction-choice
   position 'whole (list root-address) #f
   (singleton-forest proof)
   (typed-pointed-hole
    (checked-term-calculus proof) (derivation-root-boundary proof))))

(define (step-side-state occurrence aligned-states spine-slot selector limit)
  (define inputs (map side-state-proof aligned-states))
  (define calculus (checked-term-calculus (car inputs)))
  (define open-corolla (corolla calculus occurrence))
  (define positions (make-pointed-input-positions open-corolla inputs))
  (cond
    [(analysis-error? positions) positions]
    [else
     (define choice-families
       (for/list ([position (in-list positions)]
                  [state (in-list aligned-states)])
         (map (lambda (choice) (rebase-choice choice position))
              (side-state-choices state))))
     (define step
       (typed-pointed-grafting-step
        calculus occurrence inputs choice-families #:limit limit))
     (cond
       [(or (analysis-limit? step) (analysis-error? step)) step]
       [else
        (define proof (pointed-grafting-step-certificate-grafted step))
        (define certificates
          (pointed-grafting-step-certificate-choice-certificates step))
        (define position (root-position proof))
        (define ordinary-choices
          (map (lambda (certificate)
                 (certificate->choice certificate position))
               certificates))
        (define pure?
          (material-hopf-selector-forest-pure?
           selector (singleton-forest proof)))
        (define choices
          (if pure?
              (cons (whole-choice proof position) ordinary-choices)
              ordinary-choices))
        (define ordinary
          (pointed-grafting-step-certificate-ordinary-coaction step))
        (define whole (material-whole-endpoint calculus selector proof))
        (define full (formal-sum-add ordinary whole))
        (define proper
          (for/list ([certificate (in-list certificates)]
                     #:do [(define witness
                             (grafting-choice-certificate-global-witness
                              certificate))]
                     #:when (pair? (cut-witness-addresses witness)))
            witness))
        (side-state
         proof choices
         (append
          (side-state-steps
           (list-ref aligned-states (sub1 spine-slot)))
          (list step))
         ordinary whole full
         (coaction-left-polynomial ordinary)
         (whole-core-polynomial proof pure?)
         pure? proper)])]))

(define (side-full-polynomial state)
  (polynomial-add
   (side-state-ordinary-polynomial state)
   (polynomial-multiply z-polynomial
                        (side-state-whole-core-polynomial state))))

(define (constructor-matrix occurrence spine-slot aligned-siblings profile)
  (define a
    (polynomial-product (map side-full-polynomial aligned-siblings)))
  (define material-root?
    (material-profile-designates? profile occurrence))
  (define all-siblings-pure?
    (andmap side-state-pure? aligned-siblings))
  (define degree-shift
    (+ 1
       (for/sum ([sibling (in-list aligned-siblings)])
         (derivation-vertex-count (side-state-proof sibling)))))
  (define e
    (if (and material-root? all-siblings-pure?)
        (hash (list 0 degree-shift) 1)
        zero-polynomial))
  (material-context-matrix occurrence spine-slot a e))

(define (context-spine-slot context)
  (for/first ([child (in-list (checked-node-children context))]
              [slot (in-naturals 1)]
              #:when (pair? (puncture-addresses child)))
    slot))

(define (transport-pair context source-state target-state selector profile limit)
  (cond
    [(checked-hole? context)
     (paired-state source-state target-state '())]
    [else
     (define slot (context-spine-slot context))
     (define children (checked-node-children context))
     (define spine-context (list-ref children (sub1 slot)))
     (define inner
       (transport-pair
        spine-context source-state target-state selector profile limit))
     (cond
       [(or (analysis-limit? inner) (analysis-error? inner)) inner]
       [else
        (define sibling-states-or-errors
          (for/list ([child (in-list children)]
                     [child-slot (in-naturals 1)]
                     #:unless (= child-slot slot))
            (initial-side-state child selector limit)))
        (define sibling-error
          (findf (lambda (value)
                   (or (analysis-limit? value) (analysis-error? value)))
                 sibling-states-or-errors))
        (cond
          [sibling-error sibling-error]
          [else
           (define (aligned spine-state)
             (let loop ([remaining children]
                        [child-slot 1]
                        [siblings sibling-states-or-errors]
                        [result '()])
               (cond
                 [(null? remaining) (reverse result)]
                 [(= child-slot slot)
                  (loop (cdr remaining) (add1 child-slot) siblings
                        (cons spine-state result))]
                 [else
                  (loop (cdr remaining) (add1 child-slot) (cdr siblings)
                        (cons (car siblings) result))])))
           (define source-next
             (step-side-state
              (checked-node-occurrence context)
              (aligned (paired-state-source inner)) slot selector limit))
           (define target-next
             (step-side-state
              (checked-node-occurrence context)
              (aligned (paired-state-target inner)) slot selector limit))
           (define step-error
             (or (and (or (analysis-limit? source-next)
                          (analysis-error? source-next))
                      source-next)
                 (and (or (analysis-limit? target-next)
                          (analysis-error? target-next))
                      target-next)))
           (if step-error
               step-error
               (paired-state
                source-next target-next
                (append
                 (paired-state-matrices inner)
                 (list
                  (constructor-matrix
                   (checked-node-occurrence context) slot
                   sibling-states-or-errors profile)))))] )])]))

(define (side-state->certificate state)
  (material-context-side-certificate
   (side-state-proof state)
   (side-state-choices state)
   (side-state-steps state)
   (side-state-ordinary-coaction state)
   (side-state-whole-endpoint state)
   (side-state-full-coaction state)
   (side-state-ordinary-polynomial state)
   (side-state-whole-core-polynomial state)
   (side-state-pure? state)
   (side-state-proper-witnesses state)))

(define (state-difference source target)
  (material-coaction-state
   (polynomial-subtract
    (side-state-ordinary-polynomial source)
    (side-state-ordinary-polynomial target))
   (polynomial-subtract
    (side-state-whole-core-polynomial source)
    (side-state-whole-core-polynomial target))))

(define (native-witness-valid? witness expected-source calculus)
  (and (cut-witness? witness)
       (equal? (cut-witness-source witness) expected-source)
       (checked-term-has-exact-calculus?
        (cut-witness-remainder witness) calculus)
       (equal? (map detached-entry-address
                    (cut-witness-detached witness))
               (cut-witness-addresses witness))
       (equal? (puncture-addresses (cut-witness-remainder witness))
               (cut-witness-addresses witness))
       (cut-witness-reconstructs? witness)
       (equal? (reconstruct-cut-witness witness) expected-source)))

(define (checked-input-failure calculus proof role)
  (cond
    [(not (complete-proof? proof))
     (transport-failure
      'not-a-complete-proof
      "both local fillings must be native complete checked proofs"
      (hash 'role role 'proof proof))]
    [(not (checked-term-has-exact-calculus? proof calculus))
     (transport-failure
      'foreign-provenance
      "the local filling and context must carry one exact calculus snapshot"
      (hash 'role role
            'expected-calculus calculus
            'actual-calculus (checked-term-calculus proof)))]
    [(not (term-admitted-by? calculus proof))
     (transport-failure
      'unadmitted-proof
      "the local filling is not admitted by the context calculus"
      (hash 'role role 'proof proof))]
    [else #f]))

(define (transport-material-coaction-difference
         context source target profile
         #:limit [limit analysis-default-limit])
  (define who 'transport-material-coaction-difference)
  (unless (checked-term? context)
    (raise-argument-error who "checked-term?" context))
  (unless (material-profile? profile)
    (raise-argument-error who "material-profile?" profile))
  (unless (or (not limit) (exact-nonnegative-integer? limit))
    (raise-argument-error who "(or/c #f exact-nonnegative-integer?)" limit))
  (define calculus (checked-term-calculus context))
  (define holes (puncture-addresses context))
  (define source-error (checked-input-failure calculus source 'source))
  (define target-error (checked-input-failure calculus target 'target))
  (cond
    [(not (checked-term-has-exact-calculus? context calculus))
     (transport-failure
      'mixed-context-provenance
      "the checked context must carry one exact calculus snapshot")]
    [(not (term-admitted-by? calculus context))
     (transport-failure
      'unadmitted-context
      "the checked context is not admitted by its exact registry")]
    [(not (= (length holes) 1))
     (transport-failure
      'not-one-hole
      "compositional transport requires exactly one native typed puncture"
      (hash 'puncture-addresses holes))]
    [(not (eq? calculus (material-profile-calculus profile)))
     (transport-failure
      'foreign-profile
      "the material profile must belong to the exact context calculus snapshot"
      (hash 'context-calculus calculus
            'profile-calculus (material-profile-calculus profile)))]
    [source-error source-error]
    [target-error target-error]
    [(not (equal? (derivation-root-boundary source)
                  (derivation-root-boundary target)))
     (transport-failure
      'different-local-boundaries
      "the two local checked proofs must have the same complete boundary")]
    [(not (equal? (puncture-requirement context (car holes))
                  (derivation-root-boundary source)))
     (transport-failure
      'wrong-hole-boundary
      "the local proofs do not match the context's exact typed puncture"
      (hash 'expected (puncture-requirement context (car holes))
            'actual (derivation-root-boundary source)))]
    [else
     (define source-filling (complete-fill context (list source)))
     (define target-filling (complete-fill context (list target)))
     (cond
       [(or (context-error? source-filling) (context-error? target-filling))
        (transport-failure
         'native-filling-failed
         "native checked filling failed before compositional transport"
         (hash 'source source-filling 'target target-filling))]
       [else
        (define selector (prepare-material-hopf-selector profile))
        (define source-local (initial-side-state source selector limit))
        (define target-local (initial-side-state target selector limit))
        (define local-error
          (or (and (or (analysis-limit? source-local)
                       (analysis-error? source-local))
                   source-local)
              (and (or (analysis-limit? target-local)
                       (analysis-error? target-local))
                   target-local)))
        (cond
          [local-error local-error]
          [else
           (define transported
             (transport-pair
              context source-local target-local selector profile limit))
           (cond
             [(or (analysis-limit? transported) (analysis-error? transported))
              transported]
             [else
              (define source-side (paired-state-source transported))
              (define target-side (paired-state-target transported))
              (define local-state
                (state-difference source-local target-local))
              (define predicted-state
                (for/fold ([state local-state])
                          ([matrix (in-list
                                    (paired-state-matrices transported))])
                  (apply-material-context-matrix matrix state)))
              (define actual-state
                (state-difference source-side target-side))
              (define source-proper
                (side-state-proper-witnesses source-side))
              (define target-proper
                (side-state-proper-witnesses target-side))
              (define retained
                (cond [(pair? source-proper) (car source-proper)]
                      [(pair? target-proper) (car target-proper)]
                      [else #f]))
              (define retained-source
                (cond [(pair? source-proper) (side-state-proof source-side)]
                      [(pair? target-proper) (side-state-proof target-side)]
                      [else #f]))
              (define local-difference
                (formal-sum-subtract
                 (side-state-full-coaction source-local)
                 (side-state-full-coaction target-local)))
              (define transported-difference
                (formal-sum-subtract
                 (side-state-full-coaction source-side)
                 (side-state-full-coaction target-side)))
              (define verified?
                (and
                 (equal? (side-state-proof source-side) source-filling)
                 (equal? (side-state-proof target-side) target-filling)
                 (checked-term-has-exact-calculus? source-filling calculus)
                 (checked-term-has-exact-calculus? target-filling calculus)
                 (andmap pointed-grafting-step-certificate-valid?
                         (side-state-steps source-side))
                 (andmap pointed-grafting-step-certificate-valid?
                         (side-state-steps target-side))
                 (equal? predicted-state actual-state)
                 (or (not retained)
                     (native-witness-valid?
                      retained
                      retained-source
                      calculus))))
              (material-context-transport-certificate
               calculus context profile source target
               source-filling target-filling
               (side-state->certificate source-side)
               (side-state->certificate target-side)
               local-difference transported-difference
               local-state (paired-state-matrices transported)
                predicted-state actual-state retained verified?)])])])]))
