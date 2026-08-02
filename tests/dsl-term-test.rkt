#lang racket/base

(require racket/list
         racket/match
         rackunit
         "../potkin/main.rkt")

(define-formula-signature L
  #:atoms [S T U V]
  [fusion 2])

(define HS (hseq L (seq L [] => [S])))
(define HT (hseq L (seq L [] => [T])))
(define HST (hseq L (seq L [] => [(fusion S T)])))
(define HU (hseq L (seq L [] => [U])))
(define HV (hseq L (seq L [] => [V])))
(define Hmulti
  (hseq L
    (seq L [] => [S])
    (seq L [] => [T])))
(define HSS
  (hseq L
    (seq L [] => [S])
    (seq L [] => [S])))

(define-rule-signature Rules
  [ground #:kind material #:arity 0]
  [binary #:kind logical #:arity 2]
  [unary  #:kind structural #:arity 1])

(define-occurrence bS
  #:type ground #:instance S #:premises [] #:conclusion HS)
(define-occurrence bS-prime
  #:type ground #:instance 'S-prime #:premises [] #:conclusion HS)
(define-occurrence bT
  #:type ground #:instance T #:premises [] #:conclusion HT)
(define-occurrence explicit-ground-binding
  #:type ground #:id 'actual-ground-id #:instance 'explicit-ID
  #:premises [] #:conclusion HS)
(define-occurrence b-multi
  #:type ground #:instance 'S-and-T #:premises [] #:conclusion Hmulti)
(define-occurrence b-SS
  #:type ground #:instance 'two-S-components #:premises [] #:conclusion HSS)
(define-occurrence m
  #:type binary #:instance '(S T) #:premises [HS HT] #:conclusion HST)
(define-occurrence m-prime
  #:type binary #:instance '(S T alternate)
  #:premises [HS HT] #:conclusion HST)
(define-occurrence a
  #:type binary #:instance '(S S) #:premises [HS HS] #:conclusion HV)
(define-occurrence reverse
  #:type binary #:instance '(T S) #:premises [HT HS] #:conclusion HST)
(define-occurrence i
  #:type unary #:instance U #:premises [HST] #:conclusion HU)
(define-occurrence i-prime
  #:type unary #:instance 'U-prime #:premises [HST] #:conclusion HU)
(define-occurrence uS
  #:type unary #:instance 'S-wrap #:premises [HS] #:conclusion HS)
(define-occurrence need-multi
  #:type unary #:instance 'multi-input
  #:premises [Hmulti] #:conclusion HU)
(define-occurrence need-SS
  #:type unary #:instance 'repeated-component-input
  #:premises [HSS] #:conclusion HU)

(define-calculus K
  #:language L
  #:rules Rules
  #:occurrences
  [bS bS-prime bT explicit-ground-binding b-multi b-SS
      m m-prime a reverse i i-prime uS need-multi need-SS])

;; The exact surface compiles lexical occurrence bindings to the shared raw
;; syntax and asks the existing checker to construct the checked value.
(define-proof t
  #:in K
  #:root HU
  (i (m bS bT)))
(define-context r
  #:in K
  #:root HU
  (i (m _ bT)))
(define-derivation box-S
  #:in K
  #:root HS
  _)
(define-context m-context
  #:in K
  #:root HST
  (m _ _))
(define-context a-context
  #:in K
  #:root HV
  (a _ _))
(define-context reverse-context
  #:in K
  #:root HST
  (reverse _ _))
(define-context uS-context
  #:in K
  #:root HS
  (uS _))
(define-context need-multi-context
  #:in K
  #:root HU
  (need-multi _))
(define-context need-SS-context
  #:in K
  #:root HU
  (need-SS _))

(define-proof bS-proof #:in K #:root HS bS)
(define-proof bS-prime-proof #:in K #:root HS (bS-prime))
(define-proof bT-proof #:in K #:root HT bT)
(define-proof explicit-ID-proof
  #:in K #:root HS explicit-ground-binding)
(define-proof b-multi-proof #:in K #:root Hmulti b-multi)
(define-proof b-SS-proof #:in K #:root HSS b-SS)

(check-true (checked-node? t))
(check-true (complete-proof? t))
(check-true (proof-context? r))
(check-true (checked-hole? box-S))
(check-equal? (checked-term->raw t)
              (raw-app 'i (raw-app 'm (raw-app 'bS) (raw-app 'bT))))
(check-equal? (checked-term->raw r)
              (raw-app 'i (raw-app 'm raw-hole (raw-app 'bT))))
(check-equal? (checked-term->raw explicit-ID-proof)
              (raw-app 'actual-ground-id))
(check-true (redex-check? K (checked-term->raw t) HU))
(check-true (redex-check? K (checked-term->raw r) HU))

;; Root and child errors retain the checker's exact address and boundaries.
(define wrong-root
  (check-derivation #:in K #:root HS (i (m bS bT))))
(check-true (dsl-error? wrong-root))
(check-equal? (dsl-error-code wrong-root) 'wrong-boundary)
(check-equal? (dsl-error-address wrong-root) '())
(check-equal? (dsl-error-expected wrong-root) HS)
(check-equal? (dsl-error-actual wrong-root) HU)

(define wrong-child
  (check-derivation #:in K #:root HST (m bT bS)))
(check-equal? (dsl-error-code wrong-child) 'wrong-boundary)
(check-equal? (dsl-error-address wrong-child) '(1))
(check-equal? (dsl-error-expected wrong-child) HS)
(check-equal? (dsl-error-actual wrong-child) HT)

(define wrong-arity
  (check-derivation #:in K #:root HST (m bS)))
(check-equal? (dsl-error-code wrong-arity) 'wrong-arity)
(check-equal? (dsl-error-address wrong-arity) '())
(check-equal? (dsl-error-expected wrong-arity) 2)
(check-equal? (dsl-error-actual wrong-arity) 1)

(define not-an-occurrence 'm)
(define wrong-binding
  (check-derivation #:in K #:root HST not-an-occurrence))
(check-equal? (dsl-error-code wrong-binding) 'not-concrete-occurrence)

;; A foreign object with the colliding exact ID bS is rejected before raw
;; compilation; an ID string or a printed rule tag is never used as lookup.
(define-occurrence foreign-bS
  #:type ground #:id 'bS #:instance 'foreign
  #:premises [] #:conclusion HS)
(define foreign-collision
  (check-derivation #:in K #:root HS foreign-bS))
(check-equal? (dsl-error-code foreign-collision) 'foreign-occurrence)
(check-equal? (dsl-error-address foreign-collision) '())
(check-eq? (dsl-error-expected foreign-collision) bS)
(check-eq? (dsl-error-actual foreign-collision) foreign-bS)

(define-proof rejected-open
  #:in K #:root HU (i (m _ bT)))
(define-context rejected-complete
  #:in K #:root HU (i (m bS bT)))
(check-equal? (dsl-error-code rejected-open) 'not-complete-proof)
(check-equal? (dsl-error-address rejected-open) '(1 1))
(check-equal? (dsl-error-code rejected-complete) 'not-punctured-context)

;; Interfaces retain the canonical nonsymmetric telescope word and exact K.
(define t-interface (context-interface-of t))
(define r-interface (context-interface-of r))
(define box-interface (context-interface-of box-S))
(define m-interface (context-interface-of m-context))
(define reverse-interface (context-interface-of reverse-context))
(check-true (context-interface? t-interface))
(check-eq? (context-interface-calculus t-interface) K)
(check-equal? (context-input-word t-interface) '())
(check-equal? (context-output-boundary t-interface) HU)
(check-equal? (context-input-word r-interface) (list HS))
(check-equal? (context-output-boundary r-interface) HU)
(check-equal? (context-input-word box-interface) (list HS))
(check-equal? (context-output-boundary box-interface) HS)
(check-equal? (context-input-word m-interface) (list HS HT))
(check-equal? (context-input-word reverse-interface) (list HT HS))
(check-not-equal? (context-input-word m-interface)
                  (context-input-word reverse-interface))
(check-true (context-in-interface? r r-interface))
(check-false (context-in-interface? m-context reverse-interface))
(check-true (positive-context-operation? t))
(check-true (positive-context-operation? r))
(check-false (positive-context-operation? box-S))
(check-exn
 exn:fail:contract?
 (lambda () (make-proof-forest K (list box-S))))

;; Address maps are complete over the original telescope and are consumed in
;; canonical order, independently of association-list iteration order.
(define m-filled/forward
  (context-compose/addressed
   m-context
   (list (cons '(1) bS-proof)
         (cons '(2) bT-proof))))
(define m-filled/reverse-map
  (context-compose/addressed
   m-context
   (list (cons '(2) bT-proof)
         (cons '(1) bS-proof))))
(define-proof m-proof #:in K #:root HST (m bS bT))
(check-equal? m-filled/forward m-proof)
(check-equal? m-filled/reverse-map m-proof)
(check-equal?
 (context-error-code
  (context-compose m-context (list bT-proof bS-proof)))
 'wrong-boundary)

(check-equal?
 (dsl-error-code
  (context-compose/addressed
   m-context
   (list (cons '(1) bS-proof)
         (cons '(1) bS-prime-proof))))
 'duplicate-address)
(check-equal?
 (dsl-error-code
  (context-compose/addressed
   m-context
   (list (cons '(1) bS-proof))))
 'missing-address)
(check-equal?
 (dsl-error-code
  (context-compose/addressed
   m-context
   (list (cons '(1) bS-proof)
         (cons '(2) bT-proof)
         (cons '(3) bT-proof))))
 'extra-address)
(check-equal?
 (dsl-error-code
  (context-compose/addressed
   m-context
   (list (cons '() m-proof)
         (cons '(1) bS-proof)
         (cons '(2) bT-proof))))
 'nonpuncture-address)
(check-equal?
 (dsl-error-code
  (context-compose/addressed
   m-context
   (list (list '(1) bS-proof)
         (cons '(2) bT-proof))))
 'malformed-address-map)
(check-equal?
 (dsl-error-code (context-compose/addressed m-context (list #f)))
 'malformed-address-map)

;; Telescope concatenation and both typed identities.
(define box-T (identity-context K HT))
(define box-HST (identity-context K HST))
(define m-open-composite
  (context-compose/addressed
   m-context
   (list (cons '(2) box-T)
         (cons '(1) uS-context))))
(check-equal? (puncture-addresses m-open-composite) '((1 1) (2)))
(check-equal?
 (context-input-word (context-interface-of m-open-composite))
 (append (context-input-word (context-interface-of uS-context))
         (context-input-word (context-interface-of box-T))))
(check-equal?
 (context-compose/addressed
  box-HST
  (list (cons '() m-context)))
 m-context)
(check-equal?
 (context-compose/addressed
  m-context
  (list (cons '(1) box-S)
        (cons '(2) box-T)))
 m-context)

;; Genuine two-hole associativity, address-distinct equal requirements, and
;; commutation of independent insertions.
(define twice-refined
  (context-compose/addressed
   a-context
   (list (cons '(2) uS-context)
         (cons '(1) uS-context))))
(check-equal? (puncture-addresses twice-refined) '((1 1) (2 1)))
(define outer-then-inner
  (context-compose/addressed
   twice-refined
   (list (cons '(2 1) bS-prime-proof)
         (cons '(1 1) bS-proof))))
(define uS-bS
  (context-compose/addressed
   uS-context
   (list (cons '(1) bS-proof))))
(define uS-bS-prime
  (context-compose/addressed
   uS-context
   (list (cons '(1) bS-prime-proof))))
(define inner-then-outer
  (context-compose/addressed
   a-context
   (list (cons '(2) uS-bS-prime)
         (cons '(1) uS-bS))))
(check-equal? outer-then-inner inner-then-outer)

(define a-left-right
  (context-compose/addressed
   a-context
   (list (cons '(1) bS-proof)
         (cons '(2) bS-prime-proof))))
(define a-right-left
  (context-compose/addressed
   a-context
   (list (cons '(1) bS-prime-proof)
         (cons '(2) bS-proof))))
(check-not-equal? a-left-right a-right-left)
(check-equal? (vertex-at-address a-left-right '(1)) bS-proof)
(check-equal? (vertex-at-address a-left-right '(2)) bS-prime-proof)

(define S-then-T
  (backward-refine (backward-refine m-context '(1) bS) '(2) bT))
(define T-then-S
  (backward-refine (backward-refine m-context '(2) bT) '(1) bS))
(check-equal? S-then-T T-then-S)
(check-equal? S-then-T m-proof)

;; Backward refinement exposes exactly the selected occurrence's ordered
;; premises, or solves the obligation when the occurrence is nullary.
(define r/refined-uS (backward-refine r '(1 1) uS))
(check-equal? (puncture-addresses r/refined-uS) '((1 1 1)))
(check-equal?
 (map telescope-entry-requirement (premise-telescope r/refined-uS))
 (list HS))
(check-equal? (backward-refine r '(1 1) bS) t)
(check-equal? (dsl-error-code (backward-refine r '(1 1) bT))
              'wrong-boundary)
(check-equal? (dsl-error-code (backward-refine r '(1 1) foreign-bS))
              'foreign-occurrence)
(check-equal? (dsl-error-code (backward-refine r '(1) m))
              'not-a-puncture)
(check-equal? (dsl-error-code (backward-refine r '(9) bS))
              'no-such-address)

;; A filling point is one selected tuple, in telescope order; extraction is
;; structural image membership for the fixed retained context.
(define r-point (make-filling-point r (list bS-proof)))
(check-true (filling-point? r-point))
(check-equal? (filling-point-context r-point) r)
(check-equal? (filling-point-fillers r-point) (list bS-proof))
(check-equal? (evaluate-filling-point r-point) t)
(define r-extracted (extract-filling-point r t))
(check-true (filling-point? r-extracted))
(check-equal? (filling-point-fillers r-extracted) (list bS-proof))
(check-equal? (evaluate-filling-point r-extracted) t)
(check-equal? (extract-filling-point r (evaluate-filling-point r-point))
              r-point)

(define a-point
  (make-filling-point a-context (list bS-proof bS-prime-proof)))
(check-equal? (filling-point-fillers
               (extract-filling-point a-context
                                      (evaluate-filling-point a-point)))
              (list bS-proof bS-prime-proof))
(check-equal?
 (dsl-error-code
  (make-filling-point m-context (list bT-proof bS-proof)))
 'wrong-boundary)
(check-equal?
 (dsl-error-address
  (make-filling-point m-context (list bT-proof bS-proof)))
 '(1))
(check-equal?
 (dsl-error-code (make-filling-point r (list uS-context)))
 'incomplete-filler)
(check-equal?
 (dsl-error-code (make-filling-point t '()))
 'not-context)
(check-equal?
 (dsl-error-code (extract-filling-point r r))
 'incomplete-candidate)

(define-proof changed-final
  #:in K #:root HU (i-prime (m bS bT)))
(define-proof changed-inner
  #:in K #:root HU (i (m-prime bS bT)))
(define final-mismatch (extract-filling-point r changed-final))
(define inner-mismatch (extract-filling-point r changed-inner))
(check-equal? (dsl-error-code final-mismatch)
              'retained-occurrence-mismatch)
(check-equal? (dsl-error-address final-mismatch) '())
(check-equal? (dsl-error-code inner-mismatch)
              'retained-occurrence-mismatch)
(check-equal? (dsl-error-address inner-mismatch) '(1))

(define box-point (make-filling-point box-S (list bS-proof)))
(check-equal? (evaluate-filling-point box-point) bS-proof)
(check-equal? (extract-filling-point box-S bS-proof) box-point)

;; Exact snapshot provenance is separate from structural presentation.
(define Kclone (make-equipped-calculus (calculus-occurrences K)))
(define-proof bS-proof/clone #:in Kclone #:root HS bS)
(define-context uS-context/clone #:in Kclone #:root HS (uS _))
(check-equal? bS-proof bS-proof/clone)
(check-false (eq? K Kclone))
(check-false
 (context-in-interface? uS-context/clone
                        (context-interface-of uS-context)))
(check-not-equal? (context-interface-of uS-context)
                  (context-interface-of uS-context/clone))
(define clone-composition
  (context-compose/addressed
   uS-context
   (list (cons '(1) bS-proof/clone))))
(check-equal? (dsl-error-code clone-composition)
              'wrong-calculus-provenance)
(check-equal?
 (dsl-error-code (make-filling-point box-S (list bS-proof/clone)))
 'wrong-calculus-provenance)
(check-equal?
 (dsl-error-code (extract-filling-point box-S bS-proof/clone))
 'wrong-calculus-provenance)

;; Explicit checked lifting restores common provenance and commutes with the
;; same context composition.
(define fresh-occurrence
  (make-concrete-occurrence
   'fresh-ground '() HS #:kind 'material #:tag 'ground))
(define extension
  (make-calculus-revision K '() (list fresh-occurrence)))
(define K+ (calculus-revision-target extension))
(define lifted-m-context (lift-context extension m-context))
(define lifted-bS (lift-term extension bS-proof))
(define lifted-bT (lift-term extension bT-proof))
(define compose-after-lift
  (context-compose/addressed
   lifted-m-context
   (list (cons '(2) lifted-bT)
         (cons '(1) lifted-bS))))
(define lift-after-compose (lift-term extension m-filled/forward))
(check-equal? compose-after-lift lift-after-compose)
(check-true (checked-term-has-exact-calculus? compose-after-lift K+))

;; Every CK witness reconstructs through its retained address assignment.
(define running-witnesses
  (for/list ([witness (in-admissible-cut-witnesses t)]) witness))
(check-equal? (length running-witnesses) 5)
(for ([witness (in-list running-witnesses)])
  (define assignments
    (for/list ([entry (in-list (cut-witness-detached witness))])
      (cons (detached-entry-address entry)
            (detached-entry-term entry))))
  (check-equal?
   (context-compose/addressed (cut-witness-remainder witness) assignments)
   t))

;; A source puncture predating a cut remains vacant: its complete address map
;; uses the typed Box identity while the newly detached subtree is restored.
(define open-witness (make-cut-witness r '((1 2))))
(define open-reconstructed
  (context-compose/addressed
   (cut-witness-remainder open-witness)
   (list
    (cons '(1 1) (identity-context K HS))
    (cons '(1 2)
          (detached-entry-term
           (car (cut-witness-detached open-witness)))))))
(check-equal? open-reconstructed r)
(check-equal? (puncture-addresses open-reconstructed) '((1 1)))

;; Whole hypersequent equality, including component multiplicity, is the
;; filling colour; flattened or one-component approximations do not suffice.
(check-equal?
 (dsl-error-code
  (context-compose/addressed
   need-multi-context
   (list (cons '(1) bS-proof))))
 'wrong-boundary)
(check-true
 (complete-proof?
  (context-compose/addressed
   need-multi-context
   (list (cons '(1) b-multi-proof)))))
(check-equal? (hypersequent-size HSS) 2)
(check-equal?
 (dsl-error-code
  (context-compose/addressed
   need-SS-context
   (list (cons '(1) bS-proof))))
 'wrong-boundary)
(check-true
 (complete-proof?
  (context-compose/addressed
   need-SS-context
   (list (cons '(1) b-SS-proof)))))

;; Independent bounded oracle: raw simultaneous substitution followed by one
;; checker call.  Six fixed cases cover identities, open and complete inputs,
;; repeated colours, and reversed association-list order without a product
;; explosion.
(define (raw-replace-at candidate address replacement)
  (cond
    [(null? address) replacement]
    [else
     (match candidate
       [(list 'app occurrence-id children ...)
        (list*
         'app
         occurrence-id
         (for/list ([child (in-list children)] [slot (in-naturals 1)])
           (if (= slot (car address))
               (raw-replace-at child (cdr address) replacement)
               child)))]
       [_ candidate])]))

(define (oracle-compose context assignments)
  (define candidate
    (for/fold ([raw (checked-term->raw context)])
              ([entry (in-list (premise-telescope context))])
      (define address (telescope-entry-address entry))
      (define replacement (cdr (assoc address assignments equal?)))
      (raw-replace-at raw address (checked-term->raw replacement))))
  (validate-candidate
   (checked-term-calculus context)
   candidate
   #:expected (derivation-root-boundary context)))

(define oracle-cases
  (list
   (list box-S (list (cons '() bS-proof)))
   (list uS-context (list (cons '(1) bS-proof)))
   (list m-context
         (list (cons '(2) bT-proof) (cons '(1) bS-proof)))
   (list a-context
         (list (cons '(1) bS-proof) (cons '(2) bS-prime-proof)))
   (list r (list (cons '(1 1) bS-prime-proof)))
   (list m-context
         (list (cons '(2) box-T) (cons '(1) uS-context)))))

(check-equal? (length oracle-cases) 6)
(for ([fixture (in-list oracle-cases)])
  (define context (first fixture))
  (define assignments (second fixture))
  (check-equal? (context-compose/addressed context assignments)
                (oracle-compose context assignments)))
