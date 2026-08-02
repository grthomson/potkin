#lang racket/base

(require potkin)

(define-formula-signature L
  #:atoms [P A Q B])

(define G-left
  (hseq L (seq L [P] => [A])))
(define G-right
  (hseq L (seq L [Q] => [B])))
(define G-communication
  (hseq L
    (seq L [P] => [B])
    (seq L [Q] => [A])))
(define G-assembly (hypersequent-union G-left G-right))

(define (component-index-of boundary displayed-sequent)
  (or
   (for/first ([component (in-list (hypersequent-components boundary))]
               #:when
               (equal? displayed-sequent
                       (component-occurrence-sequent component)))
     (component-occurrence-index component))
   (error 'component-index-of "component not found")))

;; Conclusion indices are discovered from the canonical multiset
;; presentation; the source code's displayed order is not used as evidence.
(define com-P=>B
  (component-index-of G-communication (make-sequent '(P) '(B))))
(define com-Q=>A
  (component-index-of G-communication (make-sequent '(Q) '(A))))
(define asm-P=>A
  (component-index-of G-assembly (make-sequent '(P) '(A))))
(define asm-Q=>B
  (component-index-of G-assembly (make-sequent '(Q) '(B))))

(define com-incidence
  (make-component-incidence
   (list G-left G-right)
   G-communication
   (list (make-component-edge 1 1 com-P=>B)
         (make-component-edge 1 1 com-Q=>A)
         (make-component-edge 2 1 com-P=>B)
         (make-component-edge 2 1 com-Q=>A))))

(define asm-incidence
  (make-component-incidence
   (list G-left G-right)
   G-assembly
   (list (make-component-edge 1 1 asm-P=>A)
         (make-component-edge 2 1 asm-Q=>B))))

(define-rule-signature Rules
  [left-ground #:kind material #:arity 0]
  [right-ground #:kind material #:arity 0]
  [communication #:kind structural #:arity 2]
  [bar-assembly #:kind structural #:arity 2])

(define-occurrence b-left
  #:type left-ground
  #:instance '(P-to-A)
  #:premises []
  #:conclusion G-left
  #:incidence (make-component-incidence '() G-left '()))

(define-occurrence b-right
  #:type right-ground
  #:instance '(Q-to-B)
  #:premises []
  #:conclusion G-right
  #:incidence (make-component-incidence '() G-right '()))

(define-occurrence Com
  #:type communication
  #:instance '(crossed-components)
  #:premises [G-left G-right]
  #:conclusion G-communication
  #:incidence com-incidence)

(define-occurrence Asm
  #:type bar-assembly
  #:instance '(disjoint-hypersequent-union)
  #:premises [G-left G-right]
  #:conclusion G-assembly
  #:incidence asm-incidence)

(define-calculus K
  #:language L
  #:rules Rules
  #:occurrences [b-left b-right Com Asm])

;; These two checked nullary proofs are replayed beneath both connected
;; binary occurrences; the shared detached CK forest is not an assembly.
(define-proof left-proof #:in K #:root G-left b-left)
(define-proof right-proof #:in K #:root G-right b-right)

(define communication-proof
  (validate-candidate
   K
   (raw-app 'Com
            (checked-term->raw left-proof)
            (checked-term->raw right-proof))
   #:expected G-communication))

(define assembly-proof
  (validate-candidate
   K
   (raw-app 'Asm
            (checked-term->raw left-proof)
            (checked-term->raw right-proof))
   #:expected G-assembly))

(define com-properties (classify-component-relation com-incidence))
(define asm-properties (classify-component-relation asm-incidence))
(unless
    (and (not (component-relation-classification-functional?
               com-properties))
         (not (component-relation-classification-inverse-functional?
               com-properties))
         (component-relation-classification-total? com-properties)
         (component-relation-classification-surjective? com-properties)
         (component-relation-classification-functional? asm-properties)
         (component-relation-classification-inverse-functional?
          asm-properties)
         (component-relation-classification-total? asm-properties)
         (component-relation-classification-surjective? asm-properties))
  (error 'component-footprints "unexpected component classification"))

(define com-profiles (component-profiles-of communication-proof))
(define asm-profiles (component-profiles-of assembly-proof))
(define immediate-addresses '((1) (2)))
(define (immediate-profile profiles)
  (for/first ([profile (in-list profiles)]
              #:when
              (equal? immediate-addresses
                      (ck-component-profile-addresses profile)))
    profile))
(define com-immediate (immediate-profile com-profiles))
(define asm-immediate (immediate-profile asm-profiles))

(unless
    (and (= (length com-profiles) 3)
         (= (length asm-profiles) 3)
         (ck-component-profile-final-corolla-law com-immediate)
         (ck-component-profile-final-corolla-law asm-immediate)
         (equal?
          (cut-witness-forest
           (ck-component-profile-witness com-immediate))
          (cut-witness-forest
           (ck-component-profile-witness asm-immediate)))
         (not (equal? communication-proof assembly-proof)))
  (error 'component-footprints "unexpected CK comparison"))

(write-analysis (analyze-derivation communication-proof))
(write-analysis (analyze-derivation assembly-proof))
