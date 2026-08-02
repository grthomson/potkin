#lang racket/base

(require potkin)

(define-formula-signature L
  #:atoms [G])

(define G-boundary
  (hseq L (seq L [] => [G])))

(define identity-incidence
  (make-component-incidence
   (list G-boundary)
   G-boundary
   (list (make-component-edge 1 1 1))))

(define binary-incidence
  (make-component-incidence
   (list G-boundary G-boundary)
   G-boundary
   (list (make-component-edge 1 1 1)
         (make-component-edge 2 1 1))))

(define-rule-signature Rules
  [ground #:kind material #:arity 0]
  [step   #:kind logical  #:arity 1]
  [branch #:kind logical  #:arity 2])

(define-occurrence seed
  #:type ground
  #:instance 'G-seed
  #:premises []
  #:conclusion G-boundary
  #:incidence (make-component-incidence '() G-boundary '()))

(define-occurrence recur
  #:type step
  #:instance 'G-return
  #:premises [G-boundary]
  #:conclusion G-boundary
  #:incidence identity-incidence)

(define-occurrence with-side
  #:type branch
  #:instance 'G-return-with-side-evidence
  #:premises [G-boundary G-boundary]
  #:conclusion G-boundary
  #:incidence binary-incidence)

(define-calculus K
  #:language L
  #:rules Rules
  #:occurrences [seed recur with-side])

(define-proof seed-proof
  #:in K #:root G-boundary
  seed)

(define-context C
  #:in K #:root G-boundary
  (recur _))

(define-context C2
  #:in K #:root G-boundary
  (recur (recur _)))

(define-context side-C
  #:in K #:root G-boundary
  (with-side _ seed))

(define rho (make-boundary-return-character K G-boundary))
(define first (certify-first-return rho C))
(define composite (certify-first-return rho C2))
(define unfolded (unfold-first-return-context rho C 3))
(define seeded (certify-seeded-unfolding rho C 3 seed-proof))
(define side-product (check-side-evidence-product side-C side-C))
(define grafting
  (typed-grafting-cocycle
   K recur (list (identity-context K G-boundary))))

(unless
    (and
     (first-return-certificate-theorem-holds? first)
     (= (first-return-certificate-first-return-indicator first) 1)
     (equal?
      (return-polynomial-data-coefficients
       (first-return-certificate-polynomial first))
      #(0 1))
     (first-return-certificate-theorem-holds? composite)
     (= (first-return-certificate-first-return-indicator composite) 0)
     (equal?
      (return-polynomial-data-coefficients
       (first-return-certificate-polynomial composite))
      #(0 1 1))
     (andmap unfolding-layer-power-law? unfolded)
     (seeded-unfolding-certificate-reconstructs? seeded)
     (side-evidence-product-certificate-frontier-equal? side-product)
     (side-evidence-product-certificate-forest-equal? side-product)
     (typed-grafting-cocycle-certificate-witness-bijection? grafting)
     (typed-grafting-cocycle-certificate-equal? grafting))
  (error 'dsl-hopf-recurrence "a recurrence certificate failed"))

;; The first report distinguishes a realised frame cycle with a complete seed.
;; The second exposes the composite return polynomial, antipode value, and
;; supplied identity component-endorelation powers.
(write-analysis
 (analyze-calculus-recurrence
  K G-boundary #:component-bound 3))
(write-analysis
 (analyze-return-context C2 #:component-bound 3))
