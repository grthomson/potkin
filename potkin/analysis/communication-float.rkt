#lang racket/base

;; Checked one-step floats of IW/IC across the standard antecedent-
;; repartition Communication rule.  Indexed formula occurrences below are
;; immutable routing metadata.  They erase into POTKIN's native formula
;; multisets and never serve as proof, cut, forest, context, or calculus data.
;; Every accepted occurrence is the exact object in one equipped registry and
;; is checked against its full ordered boundary, sealed component incidence,
;; and occurrence-indexed instance payload.
;;
;; Paper calculation.  For S = Com(a(X),Y) and T = a(Com(X,Y)), when a and
;; both Com instances are selected by the same exact material profile,
;; ordinary selected cuts (empty and proper, but not the separately supplied
;; whole endpoint) satisfy
;;
;;   C_S - C_T = z epsilon_X (P_Y - epsilon_Y),
;;
;; where P includes its selected whole endpoint.  Recording left-forest
;; vertex degree as t gives
;;
;;   Chat_S - Chat_T
;;     = epsilon_X z t^(|X|+1)
;;         (Phat_Y - epsilon_Y t^|Y|).
;;
;; This is constructor decomposition of the two tree shapes.  In particular,
;; the bigraded difference may have negative coefficients; no tensor equality
;; or coefficientwise positivity is asserted.  The executable audits below
;; independently fold native CK witnesses and the exact material coaction.

(require racket/list
         "../algebra/formal-sum.rkt"
         "../hopf/ck.rkt"
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/component-incidence.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "../kernel/syntax.rkt"
         "ancestry.rkt"
         "material-hopf-selector.rkt"
         "material-stock.rkt")

(provide indexed-formula-occurrence?
         make-indexed-formula-occurrence
         indexed-formula-occurrence-id
         indexed-formula-occurrence-formula
         named-passive-component?
         make-named-passive-component
         named-passive-component-id
         named-passive-component-sequent
         communication-layout?
         make-communication-layout
         communication-layout-left-passives
         communication-layout-right-passives
         communication-layout-gamma
         communication-layout-gamma-prime
         communication-layout-lambda
         communication-layout-lambda-prime
         communication-layout-left-succedent
         communication-layout-right-succedent
         communication-layout-left-boundary
         communication-layout-right-boundary
         communication-layout-conclusion
         communication-layout-incidence
         communication-passive-route?
         make-communication-passive-route
         communication-passive-route-component-id
         communication-iw-action?
         make-communication-iw-action
         communication-iw-action-formula
         communication-iw-action-route
         communication-ic-action?
         make-communication-ic-action
         communication-ic-action-first-id
         communication-ic-action-second-id
         communication-occurrence-profile?
         communication-occurrence-profile-role
         communication-occurrence-profile-premises
         communication-occurrence-profile-conclusion
         communication-occurrence-profile-incidence
         communication-occurrence-profile-instance
         communication-float-shape?
         communication-float-shape-status
         communication-float-shape-action
         communication-float-shape-before-layout
         communication-float-shape-after-layout
         communication-float-shape-routes
         communication-float-shape-source-structural-profile
         communication-float-shape-source-communication-profile
         communication-float-shape-target-communication-profile
         communication-float-shape-target-structural-profile
         prepare-communication-float-shape
         (struct-out communication-float-failure)
         (struct-out communication-float-rejection)
         communication-side-audit?
         communication-side-audit-proof
         communication-side-audit-witnesses
         communication-side-audit-selected-witnesses
         communication-side-audit-contributions
         communication-side-audit-empty-contributions
         communication-side-audit-proper-contributions
         communication-side-audit-whole-contributions
         communication-side-audit-coaction
         communication-side-audit-reconstructed-coaction
         communication-side-audit-full-factor-polynomial
         communication-side-audit-ordinary-factor-polynomial
         communication-side-audit-witness-factor-polynomial
         communication-side-audit-full-bigraded-polynomial
         communication-side-audit-ordinary-bigraded-polynomial
         communication-side-audit-witness-bigraded-polynomial
         communication-side-audit-verified?
         communication-float-certificate?
         communication-float-certificate-calculus
         communication-float-certificate-shape
         communication-float-certificate-x
         communication-float-certificate-y
         communication-float-certificate-source
         communication-float-certificate-target
         communication-float-certificate-source-audit
         communication-float-certificate-target-audit
         communication-float-certificate-y-audit
         communication-float-certificate-epsilon-x
         communication-float-certificate-epsilon-y
         communication-float-certificate-actual-factor-difference
         communication-float-certificate-predicted-factor-difference
         communication-float-certificate-actual-bigraded-difference
         communication-float-certificate-predicted-bigraded-difference
         communication-float-certificate-negative-bigraded-coefficient?
         communication-float-certificate-verified?
         certify-communication-float)

;; --------------------------------------------------------------------------
;; Occurrence-indexed standard Communication data

(struct indexed-formula-occurrence (id formula)
  #:constructor-name make-indexed-formula-occurrence/internal
  #:sealed
  #:transparent)

(define (make-indexed-formula-occurrence id formula)
  (unless (and (symbol? id) (symbol-interned? id))
    (raise-argument-error
     'make-indexed-formula-occurrence "interned-symbol?" id))
  (unless (formula-datum? formula)
    (raise-argument-error
     'make-indexed-formula-occurrence "formula-datum?" formula))
  (make-indexed-formula-occurrence/internal id formula))

(struct named-passive-component (id sequent)
  #:constructor-name make-named-passive-component/internal
  #:sealed
  #:transparent)

(define (make-named-passive-component id sequent)
  (unless (and (symbol? id) (symbol-interned? id))
    (raise-argument-error 'make-named-passive-component "interned-symbol?" id))
  (unless (sequent? sequent)
    (raise-argument-error 'make-named-passive-component "sequent?" sequent))
  (make-named-passive-component/internal id sequent))

(struct communication-layout
  (left-passives right-passives gamma gamma-prime lambda lambda-prime
                 left-succedent right-succedent)
  #:constructor-name make-communication-layout/internal
  #:sealed
  #:transparent)

(define (copy-list values)
  (for/list ([value (in-list values)]) value))

(define (check-indexed-block who name block)
  (unless (and (list? block) (andmap indexed-formula-occurrence? block))
    (raise-arguments-error
     who "antecedent blocks must contain indexed formula occurrences"
     "block" name "value" block)))

(define (make-communication-layout
         left-passives right-passives gamma gamma-prime lambda lambda-prime
         left-succedent right-succedent)
  (define who 'make-communication-layout)
  (for ([entry (in-list (list (cons 'left-passives left-passives)
                              (cons 'right-passives right-passives)))])
    (unless (and (list? (cdr entry))
                 (andmap named-passive-component? (cdr entry)))
      (raise-arguments-error
       who "passive hypersequent components must be explicitly named"
       "side" (car entry) "value" (cdr entry))))
  (for ([entry (in-list (list (cons 'gamma gamma)
                              (cons 'gamma-prime gamma-prime)
                              (cons 'lambda lambda)
                              (cons 'lambda-prime lambda-prime)))])
    (check-indexed-block who (car entry) (cdr entry)))
  (for ([succedent (in-list (list left-succedent right-succedent))])
    (unless (formula-datum? succedent)
      (raise-argument-error who "formula-datum? succedent" succedent)))
  (define passive-ids
    (append (map named-passive-component-id left-passives)
            (map named-passive-component-id right-passives)))
  (define formula-ids
    (map indexed-formula-occurrence-id
         (append gamma gamma-prime lambda lambda-prime)))
  (define duplicate-passive (check-duplicates passive-ids eq?))
  (when duplicate-passive
    (raise-arguments-error
     who "passive component names must be globally distinct"
     "duplicate" duplicate-passive))
  (define duplicate-formula (check-duplicates formula-ids eq?))
  (when duplicate-formula
    (raise-arguments-error
     who "formula occurrence IDs in the four blocks must be distinct"
     "duplicate" duplicate-formula))
  (make-communication-layout/internal
   (copy-list left-passives)
   (copy-list right-passives)
   (copy-list gamma)
   (copy-list gamma-prime)
   (copy-list lambda)
   (copy-list lambda-prime)
   left-succedent
   right-succedent))

(struct communication-passive-route (component-id)
  #:constructor-name make-communication-passive-route/internal
  #:sealed
  #:transparent)

(define (make-communication-passive-route component-id)
  (unless (and (symbol? component-id) (symbol-interned? component-id))
    (raise-argument-error
     'make-communication-passive-route "interned-symbol?" component-id))
  (make-communication-passive-route/internal component-id))

(struct communication-iw-action (formula route)
  #:constructor-name make-communication-iw-action/internal
  #:sealed
  #:transparent)

(define (make-communication-iw-action formula route)
  (unless (indexed-formula-occurrence? formula)
    (raise-argument-error
     'make-communication-iw-action "indexed-formula-occurrence?" formula))
  (unless (or (memq route '(gamma gamma-prime))
              (communication-passive-route? route))
    (raise-argument-error
     'make-communication-iw-action
     "(or/c 'gamma 'gamma-prime communication-passive-route?)"
     route))
  (make-communication-iw-action/internal formula route))

(struct communication-ic-action (first-id second-id)
  #:constructor-name make-communication-ic-action/internal
  #:sealed
  #:transparent)

(define (make-communication-ic-action first-id second-id)
  (for ([id (in-list (list first-id second-id))])
    (unless (and (symbol? id) (symbol-interned? id))
      (raise-argument-error
       'make-communication-ic-action "interned-symbol?" id)))
  (when (eq? first-id second-id)
    (raise-arguments-error
     'make-communication-ic-action
     "contraction needs two distinct occurrence IDs"
     "ID" first-id))
  (make-communication-ic-action/internal first-id second-id))

(struct labelled-component (label sequent) #:transparent)

(define (indexed-formulas block)
  (map indexed-formula-occurrence-formula block))

(define (active-sequent first-block second-block succedent)
  (make-sequent
   (append (indexed-formulas first-block)
           (indexed-formulas second-block))
   (list succedent)))

(define (left-active-sequent layout)
  (active-sequent
   (communication-layout-gamma layout)
   (communication-layout-gamma-prime layout)
   (communication-layout-left-succedent layout)))

(define (right-active-sequent layout)
  (active-sequent
   (communication-layout-lambda layout)
   (communication-layout-lambda-prime layout)
   (communication-layout-right-succedent layout)))

(define (left-output-sequent layout)
  (active-sequent
   (communication-layout-gamma layout)
   (communication-layout-lambda-prime layout)
   (communication-layout-left-succedent layout)))

(define (right-output-sequent layout)
  (active-sequent
   (communication-layout-gamma-prime layout)
   (communication-layout-lambda layout)
   (communication-layout-right-succedent layout)))

(define (passive-label side passive)
  (list side 'passive (named-passive-component-id passive)))

(define (left-entries layout)
  (append
   (for/list ([passive
               (in-list (communication-layout-left-passives layout))])
     (labelled-component
      (passive-label 'left passive)
      (named-passive-component-sequent passive)))
   (list (labelled-component '(left active) (left-active-sequent layout)))))

(define (right-entries layout)
  (append
   (for/list ([passive
               (in-list (communication-layout-right-passives layout))])
     (labelled-component
      (passive-label 'right passive)
      (named-passive-component-sequent passive)))
   (list (labelled-component '(right active) (right-active-sequent layout)))))

(define (conclusion-entries layout)
  (append
   (for/list ([passive
               (in-list (communication-layout-left-passives layout))])
     (labelled-component
      (passive-label 'left passive)
      (named-passive-component-sequent passive)))
   (for/list ([passive
               (in-list (communication-layout-right-passives layout))])
     (labelled-component
      (passive-label 'right passive)
      (named-passive-component-sequent passive)))
   (list (labelled-component '(output left) (left-output-sequent layout))
         (labelled-component '(output right) (right-output-sequent layout)))))

;; Equal displayed components remain separate native component occurrences.
;; Their labels are assigned, in the explicitly supplied entry order, to the
;; canonical local indices occupied by that displayed sequent.
(define (entries->boundary+indices entries)
  (define boundary
    (make-hypersequent (map labelled-component-sequent entries)))
  (define remaining entries)
  (define mutable-indices (make-hash))
  (for ([component (in-list (hypersequent-sequents boundary))]
        [index (in-naturals 1)])
    (define entry
      (findf (lambda (candidate)
               (equal? component (labelled-component-sequent candidate)))
             remaining))
    (unless entry
      (error 'entries->boundary+indices
             "canonical boundary lost a labelled component occurrence"))
    (hash-set! mutable-indices (labelled-component-label entry) index)
    (set! remaining (remove entry remaining eq?)))
  (values
   boundary
   (for/hash ([(label index) (in-hash mutable-indices)])
     (values label index))))

(define (communication-layout-left-boundary layout)
  (unless (communication-layout? layout)
    (raise-argument-error
     'communication-layout-left-boundary "communication-layout?" layout))
  (define-values (boundary _indices)
    (entries->boundary+indices (left-entries layout)))
  boundary)

(define (communication-layout-right-boundary layout)
  (unless (communication-layout? layout)
    (raise-argument-error
     'communication-layout-right-boundary "communication-layout?" layout))
  (define-values (boundary _indices)
    (entries->boundary+indices (right-entries layout)))
  boundary)

(define (communication-layout-conclusion layout)
  (unless (communication-layout? layout)
    (raise-argument-error
     'communication-layout-conclusion "communication-layout?" layout))
  (define-values (boundary _indices)
    (entries->boundary+indices (conclusion-entries layout)))
  boundary)

(define (communication-layout-incidence layout)
  (unless (communication-layout? layout)
    (raise-argument-error
     'communication-layout-incidence "communication-layout?" layout))
  (define left (left-entries layout))
  (define right (right-entries layout))
  (define output (conclusion-entries layout))
  (define-values (left-boundary left-indices)
    (entries->boundary+indices left))
  (define-values (right-boundary right-indices)
    (entries->boundary+indices right))
  (define-values (conclusion conclusion-indices)
    (entries->boundary+indices output))
  (define passive-edges
    (append
     (for/list ([entry (in-list (drop-right left 1))])
       (define label (labelled-component-label entry))
       (make-component-edge
        1 (hash-ref left-indices label) (hash-ref conclusion-indices label)))
     (for/list ([entry (in-list (drop-right right 1))])
       (define label (labelled-component-label entry))
       (make-component-edge
        2 (hash-ref right-indices label) (hash-ref conclusion-indices label)))))
  (define left-active-index (hash-ref left-indices '(left active)))
  (define right-active-index (hash-ref right-indices '(right active)))
  (define output-left-index (hash-ref conclusion-indices '(output left)))
  (define output-right-index (hash-ref conclusion-indices '(output right)))
  (make-component-incidence
   (list left-boundary right-boundary)
   conclusion
   (append
    passive-edges
    (list (make-component-edge 1 left-active-index output-left-index)
          (make-component-edge 1 left-active-index output-right-index)
          (make-component-edge 2 right-active-index output-left-index)
          (make-component-edge 2 right-active-index output-right-index)))))

(define (sequent->datum sequent)
  (list 'sequent
        (formula-context->list (sequent-left sequent))
        (formula-context->list (sequent-right sequent))))

(define (indexed->datum occurrence)
  (list (indexed-formula-occurrence-id occurrence)
        (indexed-formula-occurrence-formula occurrence)))

(define (passive->datum passive)
  (list (named-passive-component-id passive)
        (sequent->datum (named-passive-component-sequent passive))))

(define (layout->datum layout)
  (list
   'communication-layout
   (map passive->datum (communication-layout-left-passives layout))
   (map passive->datum (communication-layout-right-passives layout))
   (map indexed->datum (communication-layout-gamma layout))
   (map indexed->datum (communication-layout-gamma-prime layout))
   (map indexed->datum (communication-layout-lambda layout))
   (map indexed->datum (communication-layout-lambda-prime layout))
   (communication-layout-left-succedent layout)
   (communication-layout-right-succedent layout)))

(struct communication-occurrence-profile
  (role premises conclusion incidence instance)
  #:constructor-name make-communication-occurrence-profile/internal
  #:sealed
  #:transparent)

(define (communication-profile layout [role 'communication])
  (make-communication-occurrence-profile/internal
   role
   (list (communication-layout-left-boundary layout)
         (communication-layout-right-boundary layout))
   (communication-layout-conclusion layout)
   (communication-layout-incidence layout)
   (list 'standard-antecedent-repartition-com (layout->datum layout))))

(define (layout-formula-occurrences layout)
  (append (communication-layout-gamma layout)
          (communication-layout-gamma-prime layout)
          (communication-layout-lambda layout)
          (communication-layout-lambda-prime layout)))

(define (layout-formula-id-used? layout id)
  (for/or ([occurrence (in-list (layout-formula-occurrences layout))])
    (eq? id (indexed-formula-occurrence-id occurrence))))

(define (rebuild-layout layout
                        #:left-passives
                        [left-passives
                         (communication-layout-left-passives layout)]
                        #:gamma [gamma (communication-layout-gamma layout)]
                        #:gamma-prime
                        [gamma-prime
                         (communication-layout-gamma-prime layout)])
  (make-communication-layout
   left-passives
   (communication-layout-right-passives layout)
   gamma
   gamma-prime
   (communication-layout-lambda layout)
   (communication-layout-lambda-prime layout)
   (communication-layout-left-succedent layout)
   (communication-layout-right-succedent layout)))

(define (sequent-add-left sequent formula)
  (make-sequent
   (append (formula-context->list (sequent-left sequent)) (list formula))
   (formula-context->list (sequent-right sequent))))

(define (add-iw-to-layout layout action)
  (define occurrence (communication-iw-action-formula action))
  (define id (indexed-formula-occurrence-id occurrence))
  (when (layout-formula-id-used? layout id)
    (raise-arguments-error
     'prepare-communication-float-shape
     "the weakened formula occurrence ID must be fresh in the layout"
     "ID" id))
  (define route (communication-iw-action-route action))
  (cond
    [(eq? route 'gamma)
     (values
      (rebuild-layout
       layout
       #:gamma (append (communication-layout-gamma layout)
                       (list occurrence)))
      'gamma
      'left-output)]
    [(eq? route 'gamma-prime)
     (values
      (rebuild-layout
       layout
       #:gamma-prime
       (append (communication-layout-gamma-prime layout)
               (list occurrence)))
      'gamma-prime
      'right-output)]
    [else
     (define component-id
       (communication-passive-route-component-id route))
     (define found? #f)
     (define updated
       (for/list ([passive
                   (in-list (communication-layout-left-passives layout))])
         (if (eq? component-id (named-passive-component-id passive))
             (begin
               (set! found? #t)
               (make-named-passive-component
                component-id
                (sequent-add-left
                 (named-passive-component-sequent passive)
                 (indexed-formula-occurrence-formula occurrence))))
             passive)))
     (unless found?
       (raise-arguments-error
        'prepare-communication-float-shape
        "the named passive component is not in the first Com premise"
        "component" component-id))
     (define reported-route (list 'passive component-id))
     (values
      (rebuild-layout layout #:left-passives updated)
      reported-route
      reported-route)]))

(define (locate-first-active-formula layout id)
  (or
   (for/first ([occurrence
                (in-list (communication-layout-gamma layout))]
               #:when (eq? id (indexed-formula-occurrence-id occurrence)))
     (cons 'gamma occurrence))
   (for/first ([occurrence
                (in-list (communication-layout-gamma-prime layout))]
               #:when (eq? id (indexed-formula-occurrence-id occurrence)))
     (cons 'gamma-prime occurrence))))

(define (remove-indexed-id block id)
  (filter (lambda (occurrence)
            (not (eq? id (indexed-formula-occurrence-id occurrence))))
          block))

(define (contract-layout layout action)
  (define first-id (communication-ic-action-first-id action))
  (define second-id (communication-ic-action-second-id action))
  (define first (locate-first-active-formula layout first-id))
  (define second (locate-first-active-formula layout second-id))
  (unless (and first second)
    (raise-arguments-error
     'prepare-communication-float-shape
     "both contraction occurrences must belong to the first active Com input"
     "first ID" first-id
     "first location" (and first (car first))
     "second ID" second-id
     "second location" (and second (car second))))
  (unless (equal?
           (indexed-formula-occurrence-formula (cdr first))
           (indexed-formula-occurrence-formula (cdr second)))
    (raise-arguments-error
     'prepare-communication-float-shape
     "internal contraction requires two equal-formula occurrences"
     "first occurrence" (cdr first)
     "second occurrence" (cdr second)))
  (define post-layout
    (rebuild-layout
     layout
     #:gamma
     (remove-indexed-id (communication-layout-gamma layout) second-id)
     #:gamma-prime
     (remove-indexed-id
      (communication-layout-gamma-prime layout) second-id)))
  (define first-route (car first))
  (define second-route (car second))
  (define (target-route route)
    (if (eq? route 'gamma) 'left-output 'right-output))
  (values post-layout
          (list first-route second-route)
          (list (target-route first-route)
                (target-route second-route))
          (indexed-formula-occurrence-formula (cdr first))))

(define (route->component-label route phase)
  (cond
    [(and (list? route)
          (= (length route) 2)
          (eq? (car route) 'passive))
     (list 'left 'passive (cadr route))]
    [(eq? phase 'source) '(left active)]
    [(eq? route 'left-output) '(output left)]
    [(eq? route 'right-output) '(output right)]
    [else
     (error 'route->component-label "unsupported checked route: ~e" route)]))

(define (structural-profile before-entries after-entries role instance)
  (define-values (premise premise-indices)
    (entries->boundary+indices before-entries))
  (define-values (conclusion conclusion-indices)
    (entries->boundary+indices after-entries))
  (define edges
    (for/list ([entry (in-list before-entries)])
      (define label (labelled-component-label entry))
      (unless (hash-has-key? conclusion-indices label)
        (error 'structural-profile
               "the structural step lost component label ~e" label))
      (make-component-edge
       1
       (hash-ref premise-indices label)
       (hash-ref conclusion-indices label))))
  (make-communication-occurrence-profile/internal
   role
   (list premise)
   conclusion
   (make-component-incidence (list premise) conclusion edges)
   instance))

(define (iw-structural-profile before after action route phase role)
  (define formula (communication-iw-action-formula action))
  (define entries-before
    (if (eq? phase 'source)
        (left-entries before)
        (conclusion-entries before)))
  (define entries-after
    (if (eq? phase 'source)
        (left-entries after)
        (conclusion-entries after)))
  (define component-label (route->component-label route phase))
  (unless
      (for/or ([entry (in-list entries-before)])
        (equal? component-label (labelled-component-label entry)))
    (error 'iw-structural-profile
           "the weakened component label is absent: ~e" component-label))
  (structural-profile
   entries-before entries-after role
   (list 'standard-internal-weakening
         (indexed->datum formula)
         (list phase route))))

(define (ic-structural-profile
         before after action routes formula phase role)
  (define entries-before
    (if (eq? phase 'source)
        (left-entries before)
        (conclusion-entries before)))
  (define entries-after
    (if (eq? phase 'source)
        (left-entries after)
        (conclusion-entries after)))
  (structural-profile
   entries-before entries-after role
   (list 'standard-internal-contraction
         (list (communication-ic-action-first-id action)
               (communication-ic-action-second-id action))
         formula
         (list phase routes))))

(struct communication-float-shape
  (status action before-layout after-layout routes
          source-structural-profile source-communication-profile
          target-communication-profile target-structural-profile)
  #:constructor-name make-communication-float-shape/internal
  #:sealed
  #:transparent)

(define (prepare-communication-float-shape layout action)
  (unless (communication-layout? layout)
    (raise-argument-error
     'prepare-communication-float-shape "communication-layout?" layout))
  (unless (or (communication-iw-action? action)
              (communication-ic-action? action))
    (raise-argument-error
     'prepare-communication-float-shape
     "(or/c communication-iw-action? communication-ic-action?)"
     action))
  (cond
    [(communication-iw-action? action)
     (define-values (after source-route target-route)
       (add-iw-to-layout layout action))
     (define source-structural
       (iw-structural-profile
        layout after action source-route 'source 'source-iw))
     (define target-structural
       (iw-structural-profile
        layout after action target-route 'target 'target-iw))
     (make-communication-float-shape/internal
      'accepted action layout after (list source-route target-route)
      source-structural
      (communication-profile after 'source-communication)
      (communication-profile layout 'target-communication)
      target-structural)]
    [else
     (define-values (after source-routes target-routes formula)
       (contract-layout layout action))
     (define source-structural
       (ic-structural-profile
        layout after action source-routes formula 'source 'source-ic))
     (define same-route?
       (equal? (first target-routes) (second target-routes)))
     (define target-structural
       (and same-route?
            (ic-structural-profile
             layout after action target-routes formula 'target 'target-ic)))
     (make-communication-float-shape/internal
      (if same-route? 'accepted 'split-contraction-routes)
      action layout after
      (list source-routes target-routes)
      source-structural
      (communication-profile after 'source-communication)
      (communication-profile layout 'target-communication)
      target-structural)]))

;; --------------------------------------------------------------------------
;; Independent native-witness and exact-coaction scalar audits

(define (polynomial-add-coefficient polynomial key coefficient)
  (define combined (+ (hash-ref polynomial key 0) coefficient))
  (if (zero? combined)
      (hash-remove polynomial key)
      (hash-set polynomial key combined)))

(define (polynomial-add left right)
  (for/fold ([result left]) ([(key coefficient) (in-hash right)])
    (polynomial-add-coefficient result key coefficient)))

(define (polynomial-scale coefficient polynomial)
  (if (zero? coefficient)
      (hash)
      (for/hash ([(key value) (in-hash polynomial)]
                 #:unless (zero? (* coefficient value)))
        (values key (* coefficient value)))))

(define (polynomial-subtract left right)
  (polynomial-add left (polynomial-scale -1 right)))

(define (factor-key-add left right)
  (+ left right))

(define (bigraded-key-add left right)
  (list (+ (first left) (first right))
        (+ (second left) (second right))))

(define (polynomial-multiply left right key-add)
  (for*/fold ([result (hash)])
             ([(left-key left-coefficient) (in-hash left)]
              [(right-key right-coefficient) (in-hash right)])
    (polynomial-add-coefficient
     result
     (key-add left-key right-key)
     (* left-coefficient right-coefficient))))

(define (forest-factor-key forest)
  (proof-forest-size forest))

(define (forest-bigraded-key forest)
  (list (proof-forest-size forest) (forest-degree forest)))

(define (formal-left-polynomial sum key-of)
  (for/fold ([polynomial (hash)])
            ([term (in-list (formal-sum-terms sum))])
    (define key (car term))
    (define coefficient (cdr term))
    (polynomial-add-coefficient
     polynomial (key-of (vector-ref key 0)) coefficient)))

(define (contribution-polynomial contributions key-of)
  (for/fold ([polynomial (hash)])
            ([contribution (in-list contributions)])
    (define tensor (material-contribution-tensor contribution))
    (polynomial-add-coefficient
     polynomial (key-of (vector-ref tensor 0)) 1)))

(define (witness-polynomial witnesses key-of)
  (for/fold ([polynomial (hash)])
            ([witness (in-list witnesses)])
    (polynomial-add-coefficient
     polynomial (key-of (cut-witness-forest witness)) 1)))

(define (contributions->formal-sum calculus contributions)
  (make-formal-sum
   calculus 2
   (for/list ([contribution (in-list contributions)])
     (cons (material-contribution-tensor contribution) 1))))

(define (witness-native-data-valid? witness calculus)
  (and (cut-witness? witness)
       (checked-term-has-exact-calculus?
        (cut-witness-remainder witness) calculus)
       (equal? (map detached-entry-address
                    (cut-witness-detached witness))
               (cut-witness-addresses witness))
       (equal? (puncture-addresses (cut-witness-remainder witness))
               (cut-witness-addresses witness))
       (equal?
        (make-proof-forest
         calculus
         (map detached-entry-term (cut-witness-detached witness)))
        (cut-witness-forest witness))
       (cut-witness-reconstructs? witness)
       (equal?
        (complete-fill
         (cut-witness-remainder witness)
         (map detached-entry-term (cut-witness-detached witness)))
        (cut-witness-source witness))))

(define (witness-lists-agree? selected contributions)
  (define contribution-witnesses
    (for/list ([contribution (in-list contributions)])
      (material-contribution-witness contribution)))
  (and (= (length selected) (length contribution-witnesses))
       (for/and ([witness (in-list selected)])
         (= 1
            (count
             (lambda (candidate)
               (equal? (cut-witness-addresses candidate)
                       (cut-witness-addresses witness)))
             contribution-witnesses)))))

(struct communication-side-audit
  (proof witnesses selected-witnesses contributions
         empty-contributions proper-contributions whole-contributions
         coaction reconstructed-coaction
         full-factor-polynomial ordinary-factor-polynomial
         witness-factor-polynomial
         full-bigraded-polynomial ordinary-bigraded-polynomial
         witness-bigraded-polynomial
         verified?)
  #:constructor-name make-communication-side-audit/internal
  #:sealed
  #:transparent)

(define (audit-communication-side proof profile selector limit)
  (define calculus (material-profile-calculus profile))
  (define index
    (prepare-material-stock-index proof profile #:limit limit))
  (cond
    [(analysis-limit? index) index]
    [else
     (define query (make-material-all-query #:include-whole-endpoint? #t))
     (define result (indexed-material-query index query))
     (define contributions (material-query-result-contributions result))
     (define empty-contributions
       (filter
        (lambda (contribution)
          (empty-cut-choice?
           (material-contribution-choice contribution)))
        contributions))
     (define proper-contributions
       (filter
        (lambda (contribution)
          (proper-cut-choice?
           (material-contribution-choice contribution)))
        contributions))
     (define whole-contributions
       (filter
        (lambda (contribution)
          (whole-cut-choice?
           (material-contribution-choice contribution)))
        contributions))
     (define ordinary-contributions
       (append empty-contributions proper-contributions))
     (define reconstructed
       (contributions->formal-sum calculus contributions))
     ;; Preparation has already proved that the native witness family is
     ;; inside the requested finite bound.
     (define witnesses
       (for/list ([witness (in-admissible-cut-witnesses proof)]) witness))
     (define selected-witnesses
       (filter
        (lambda (witness)
          (material-hopf-selector-forest-pure?
           selector (cut-witness-forest witness)))
        witnesses))
     (define coaction
       (material-hopf-selector-coaction selector (checked-node-basis proof)))
     (define full-factor
       (formal-left-polynomial coaction forest-factor-key))
     (define full-bigraded
       (formal-left-polynomial coaction forest-bigraded-key))
     (define whole-factor
       (contribution-polynomial whole-contributions forest-factor-key))
     (define whole-bigraded
       (contribution-polynomial whole-contributions forest-bigraded-key))
     (define ordinary-factor
       (polynomial-subtract full-factor whole-factor))
     (define ordinary-bigraded
       (polynomial-subtract full-bigraded whole-bigraded))
     (define contribution-ordinary-factor
       (contribution-polynomial
        ordinary-contributions forest-factor-key))
     (define contribution-ordinary-bigraded
       (contribution-polynomial
        ordinary-contributions forest-bigraded-key))
     (define witness-factor
       (witness-polynomial selected-witnesses forest-factor-key))
     (define witness-bigraded
       (witness-polynomial selected-witnesses forest-bigraded-key))
     (define proof-pure?
       (material-hopf-selector-forest-pure?
        selector (make-proof-forest calculus (list proof))))
     (define verified?
       (and (formal-sum? coaction)
            (formal-sum? reconstructed)
            (equal? coaction reconstructed)
            (= (length empty-contributions) 1)
            (= (length whole-contributions) (if proof-pure? 1 0))
            (andmap
             (lambda (witness)
               (witness-native-data-valid? witness calculus))
             witnesses)
            (witness-lists-agree?
             selected-witnesses ordinary-contributions)
            (equal? ordinary-factor contribution-ordinary-factor)
            (equal? ordinary-factor witness-factor)
            (equal? ordinary-bigraded contribution-ordinary-bigraded)
            (equal? ordinary-bigraded witness-bigraded)))
     (make-communication-side-audit/internal
      proof witnesses selected-witnesses contributions
      empty-contributions proper-contributions whole-contributions
      coaction reconstructed
      full-factor ordinary-factor witness-factor
      full-bigraded ordinary-bigraded witness-bigraded
      verified?)]))

;; --------------------------------------------------------------------------
;; Checked square construction and theorem certificate

(struct communication-float-failure (code message details) #:transparent)

(struct communication-float-rejection
  (code routes source target-communication details)
  #:transparent)

(struct communication-float-certificate
  (calculus shape x y source target source-audit target-audit y-audit
            epsilon-x epsilon-y
            actual-factor-difference predicted-factor-difference
            actual-bigraded-difference predicted-bigraded-difference
            negative-bigraded-coefficient? verified?)
  #:constructor-name make-communication-float-certificate/internal
  #:sealed
  #:transparent)

(define (exact-registry-occurrence? calculus occurrence)
  (and (concrete-occurrence? occurrence)
       (eq? occurrence
            (calculus-lookup
             calculus (concrete-occurrence-id occurrence)))))

(define (occurrence-profile-failure calculus occurrence profile)
  (define role (communication-occurrence-profile-role profile))
  (cond
    [(not (concrete-occurrence? occurrence))
     (communication-float-failure
      'missing-exact-instance
      "the proposed square omitted a concrete exact occurrence"
      (hash 'role role 'occurrence occurrence))]
    [(not (exact-registry-occurrence? calculus occurrence))
     (communication-float-failure
      'missing-exact-instance
      "the proposed occurrence is not the exact object in this registry"
      (hash 'role role
            'occurrence occurrence
            'registry-occurrence
            (calculus-lookup calculus (concrete-occurrence-id occurrence))))]
    [(not (eq? (concrete-occurrence-kind occurrence) 'structural))
     (communication-float-failure
      'wrong-occurrence-kind
      "a checked Com/IW/IC occurrence must be registered as structural"
      (hash 'role role 'occurrence occurrence))]
    [(not
      (equal? (vector->list (concrete-occurrence-premises occurrence))
              (communication-occurrence-profile-premises profile)))
     (communication-float-failure
      'wrong-entire-premise-boundary
      "the occurrence does not have the required ordered whole premises"
      (hash
       'role role
       'expected (communication-occurrence-profile-premises profile)
       'actual (vector->list (concrete-occurrence-premises occurrence))))]
    [(not
      (equal? (concrete-occurrence-conclusion occurrence)
              (communication-occurrence-profile-conclusion profile)))
     (communication-float-failure
      'wrong-entire-conclusion-boundary
      "the occurrence does not have the required whole conclusion"
      (hash
       'role role
       'expected (communication-occurrence-profile-conclusion profile)
       'actual (concrete-occurrence-conclusion occurrence)))]
    [(not (component-incidence?
           (concrete-occurrence-incidence occurrence)))
     (communication-float-failure
      'missing-typed-incidence
      "Com/IW/IC requires supplied endpoint-checked component incidence"
      (hash 'role role
            'actual (concrete-occurrence-incidence occurrence)))]
    [(not
      (equal? (concrete-occurrence-incidence occurrence)
              (communication-occurrence-profile-incidence profile)))
     (communication-float-failure
      'wrong-component-incidence
      "the supplied component incidence does not match the proposed step"
      (hash
       'role role
       'expected (communication-occurrence-profile-incidence profile)
       'actual (concrete-occurrence-incidence occurrence)))]
    [(not
      (equal? (concrete-occurrence-instance occurrence)
              (communication-occurrence-profile-instance profile)))
     (communication-float-failure
      'wrong-indexed-instance
      "the occurrence lacks the exact occurrence-indexed routing payload"
      (hash
       'role role
       'expected (communication-occurrence-profile-instance profile)
       'actual (concrete-occurrence-instance occurrence)))]
    [else #f]))

(define (checked-input-failure calculus proof expected role)
  (cond
    [(not (checked-node? proof))
     (communication-float-failure
      'not-a-checked-proof
      "a Communication premise must be a native checked proof"
      (hash 'role role 'proof proof))]
    [(or (not (eq? (checked-term-calculus proof) calculus))
         (not (checked-term-has-exact-calculus? proof calculus)))
     (communication-float-failure
      'foreign-provenance
      "the checked premise does not carry the exact requested calculus"
      (hash 'role role
            'expected-calculus calculus
            'actual-calculus (checked-term-calculus proof)))]
    [(not (complete-proof? proof))
     (communication-float-failure
      'incomplete-premise
      "Communication-float certification requires complete premise proofs"
      (hash 'role role 'proof proof))]
    [(not (term-admitted-by? calculus proof))
     (communication-float-failure
      'unadmitted-premise
      "the checked premise is not admitted by the exact registry"
      (hash 'role role 'proof proof))]
    [(not (equal? (derivation-root-boundary proof) expected))
     (communication-float-failure
      'wrong-premise-boundary
      "the checked premise has the wrong whole hypersequent boundary"
      (hash 'role role
            'expected expected
            'actual (derivation-root-boundary proof)))]
    [else #f]))

(define (checked-application calculus occurrence children expected role)
  (define checked
    (validate-candidate
     calculus
     (apply raw-app
            (concrete-occurrence-id occurrence)
            (map checked-term->raw children))
     #:expected expected))
  (if (checked-node? checked)
      checked
      (communication-float-failure
       'native-check-failed
       "the exact occurrence failed native ordered-boundary checking"
       (hash 'role role 'validation checked))))

(define (material-input-failure calculus profile occurrences)
  (cond
    [(not (material-profile? profile))
     (communication-float-failure
      'missing-material-profile
      "an exact material profile is required for the CK comparison"
      (hash 'profile profile))]
    [(not (eq? calculus (material-profile-calculus profile)))
     (communication-float-failure
      'foreign-provenance
      "the material profile belongs to a different calculus snapshot"
      (hash 'expected-calculus calculus
            'actual-calculus (material-profile-calculus profile)))]
    [else
     (define missing
       (filter
        (lambda (occurrence)
          (not (material-profile-designates? profile occurrence)))
        occurrences))
     (and (pair? missing)
          (communication-float-failure
           'structural-stock-missing
           "both Com and both structural occurrences must be in the shared stock"
           (hash 'missing-occurrences missing)))]))

(define (finish-communication-certificate
         calculus shape x y source target profile limit)
  (define selector (prepare-material-hopf-selector profile))
  (define source-audit
    (audit-communication-side source profile selector limit))
  (cond
    [(analysis-limit? source-audit) source-audit]
    [else
     (define target-audit
       (audit-communication-side target profile selector limit))
     (cond
       [(analysis-limit? target-audit) target-audit]
       [else
        (define y-audit
          (audit-communication-side y profile selector limit))
        (cond
          [(analysis-limit? y-audit) y-audit]
          [else
           (define epsilon-x
             (if (material-hopf-selector-forest-pure?
                  selector (make-proof-forest calculus (list x)))
                 1 0))
           (define epsilon-y
             (if (material-hopf-selector-forest-pure?
                  selector (make-proof-forest calculus (list y)))
                 1 0))
           (define source-factor
             (communication-side-audit-ordinary-factor-polynomial
              source-audit))
           (define target-factor
             (communication-side-audit-ordinary-factor-polynomial
              target-audit))
           (define actual-factor
             (polynomial-subtract source-factor target-factor))
           (define y-full-factor
             (communication-side-audit-full-factor-polynomial y-audit))
           (define predicted-factor
             (polynomial-scale
              epsilon-x
              (polynomial-multiply
               (hash 1 1)
               (polynomial-subtract y-full-factor (hash 0 epsilon-y))
               factor-key-add)))
           (define source-bigraded
             (communication-side-audit-ordinary-bigraded-polynomial
              source-audit))
           (define target-bigraded
             (communication-side-audit-ordinary-bigraded-polynomial
              target-audit))
           (define actual-bigraded
             (polynomial-subtract source-bigraded target-bigraded))
           (define y-full-bigraded
             (communication-side-audit-full-bigraded-polynomial y-audit))
           (define predicted-bigraded
             (polynomial-scale
              epsilon-x
              (polynomial-multiply
               (hash (list 1 (add1 (derivation-vertex-count x))) 1)
               (polynomial-subtract
                y-full-bigraded
                (hash (list 0 (derivation-vertex-count y)) epsilon-y))
               bigraded-key-add)))
           (define has-negative-coefficient?
             (for/or ([coefficient (in-hash-values actual-bigraded)])
               (negative? coefficient)))
           (define verified?
             (and (communication-side-audit-verified? source-audit)
                  (communication-side-audit-verified? target-audit)
                  (communication-side-audit-verified? y-audit)
                  (equal? actual-factor predicted-factor)
                  (equal? actual-bigraded predicted-bigraded)))
           (if verified?
               (make-communication-float-certificate/internal
                calculus shape x y source target
                source-audit target-audit y-audit
                epsilon-x epsilon-y
                actual-factor predicted-factor
                actual-bigraded predicted-bigraded
                has-negative-coefficient? #t)
               (communication-float-failure
                'native-audit-mismatch
                "native CK witnesses or scalar coactions disagree with the float prediction"
                (hash 'source-audit source-audit
                      'target-audit target-audit
                      'y-audit y-audit
                      'actual-factor actual-factor
                      'predicted-factor predicted-factor
                      'actual-bigraded actual-bigraded
                      'predicted-bigraded predicted-bigraded)))])])]))

(define (certify-communication-float
         calculus shape x y profile
         #:source-structural source-structural
         #:source-communication source-communication
         #:target-communication target-communication
         #:target-structural [target-structural #f]
         #:limit [limit 256])
  (define who 'certify-communication-float)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (communication-float-shape? shape)
    (raise-argument-error who "communication-float-shape?" shape))
  (unless (exact-nonnegative-integer? limit)
    (raise-argument-error who "exact-nonnegative-integer?" limit))
  (define target-com-profile
    (communication-float-shape-target-communication-profile shape))
  (define source-structural-profile
    (communication-float-shape-source-structural-profile shape))
  (define source-com-profile
    (communication-float-shape-source-communication-profile shape))
  (define target-structural-profile
    (communication-float-shape-target-structural-profile shape))
  (define x-error
    (checked-input-failure
     calculus x
     (first (communication-occurrence-profile-premises target-com-profile))
     'X))
  (define y-error
    (checked-input-failure
     calculus y
     (second (communication-occurrence-profile-premises target-com-profile))
     'Y))
  (define occurrence-error
    (or
     (occurrence-profile-failure
      calculus source-structural source-structural-profile)
     (occurrence-profile-failure
      calculus source-communication source-com-profile)
     (occurrence-profile-failure
      calculus target-communication target-com-profile)
     (and (eq? (communication-float-shape-status shape) 'accepted)
          (occurrence-profile-failure
           calculus target-structural target-structural-profile))))
  (cond
    [x-error x-error]
    [y-error y-error]
    [occurrence-error occurrence-error]
    [else
     (define source-step
       (checked-application
        calculus source-structural (list x)
        (communication-occurrence-profile-conclusion source-structural-profile)
        (communication-occurrence-profile-role source-structural-profile)))
     (cond
       [(communication-float-failure? source-step) source-step]
       [else
        (define source
          (checked-application
           calculus source-communication (list source-step y)
           (communication-occurrence-profile-conclusion source-com-profile)
           (communication-occurrence-profile-role source-com-profile)))
        (cond
          [(communication-float-failure? source) source]
          [else
           (define target-com
             (checked-application
              calculus target-communication (list x y)
              (communication-occurrence-profile-conclusion target-com-profile)
              (communication-occurrence-profile-role target-com-profile)))
           (cond
             [(communication-float-failure? target-com) target-com]
             [(eq? (communication-float-shape-status shape)
                   'split-contraction-routes)
              (communication-float-rejection
               'split-contraction-routes
               (second (communication-float-shape-routes shape))
               source target-com
               (hash
                'claim
                "the two occurrences reach different output components"
                'scope
                "only the proposed one-step IC float is rejected"))]
             [else
              (define target
                (checked-application
                 calculus target-structural (list target-com)
                 (communication-occurrence-profile-conclusion
                  target-structural-profile)
                 (communication-occurrence-profile-role
                  target-structural-profile)))
              (cond
                [(communication-float-failure? target) target]
                [(not (equal? (derivation-root-boundary source)
                              (derivation-root-boundary target)))
                 (communication-float-failure
                  'square-boundary-mismatch
                  "the two checked paths do not end at one hypersequent"
                  (hash 'source-boundary
                        (derivation-root-boundary source)
                        'target-boundary
                        (derivation-root-boundary target)))]
                [else
                 (define stock-error
                   (material-input-failure
                    calculus profile
                    (list source-structural source-communication
                          target-communication target-structural)))
                 (if stock-error
                     stock-error
                     (finish-communication-certificate
                      calculus shape x y source target profile limit))])])])])]))
