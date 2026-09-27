#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis.rkt")

(define S (singleton-hypersequent '() '(S)))
(define I0 (make-component-incidence '() S '()))
(define I1 (make-component-incidence (list S) S '()))
(define I2 (make-component-incidence (list S S) S '()))

(define a-occ
  (make-concrete-occurrence
   'sharing-a '() S #:instance 'a #:incidence I0))
(define c-occ
  (make-concrete-occurrence
   'sharing-c '() S #:instance 'c #:incidence I0))
(define u-occ
  (make-concrete-occurrence
   'sharing-u (list S) S #:instance 'u #:incidence I1))
(define left-occ
  (make-concrete-occurrence
   'sharing-left (list S) S #:instance 'left #:incidence I1))
(define right-occ
  (make-concrete-occurrence
   'sharing-right (list S) S #:instance 'right #:incidence I1))
(define j-occ
  (make-concrete-occurrence
   'sharing-j (list S S) S #:instance 'join #:incidence I2))
(define r-occ
  (make-concrete-occurrence
   'sharing-r (list S S) S #:instance 'root #:incidence I2))
(define p-occ
  (make-concrete-occurrence
   'sharing-p (list S S) S #:instance 'ordered-parent #:incidence I2))
(define e-occ
  (make-concrete-occurrence
   'sharing-e (list S) S #:instance 'extension #:incidence I1))
(define opaque-occ
  (make-concrete-occurrence
   'sharing-opaque '() S #:instance 'opaque #:incidence 'unknown))
(define occurrences
  (list a-occ c-occ u-occ left-occ right-occ j-occ r-occ p-occ e-occ
        opaque-occ))
(define calculus (make-equipped-calculus occurrences))

(define (checked raw #:calculus [registry calculus])
  (define result (validate-candidate registry raw #:expected S))
  (check-false (validation-error? result))
  result)

(define (qmap bindings #:calculus [registry calculus])
  (make-sharing-source-map registry bindings))

(define (coefficient polynomial . bindings)
  (sharing-character-polynomial-coefficient polynomial bindings))

(define (record-at audit addresses)
  (findf (lambda (record)
           (equal? (sharing-cut-record-addresses record) addresses))
         (sharing-saturation-audit-records audit)))

(define (check-certified audit expected-total expected-saturated
                         expected-unsaturated)
  (check-equal? (sharing-saturation-audit-status audit) 'certified)
  (check-true (sharing-saturation-certified? audit))
  (check-equal? (sharing-saturation-audit-reasons audit) '())
  (check-equal? (length (sharing-saturation-audit-records audit))
                expected-total)
  (check-equal? (length (sharing-saturation-audit-saturated audit))
                expected-saturated)
  (check-equal? (length (sharing-saturation-audit-unsaturated audit))
                expected-unsaturated)
  (check-equal?
   (sharing-residual-support-size
    (sharing-saturation-audit-residual audit))
   expected-unsaturated)
  (for ([(law result)
         (in-hash (sharing-saturation-audit-laws audit))])
    (check-true result (format "failed sharing law: ~a" law)))
  (check-equal? (sharing-saturation-audit-native-character audit)
                (sharing-saturation-audit-recurrence-character audit))
  (check-equal? (sharing-saturation-audit-saturated-character audit)
                (sharing-saturation-audit-recurrence-saturated-character
                 audit))
  audit)

;; 1. No sharing: the unique-address quotient of U(U(A)) has four
;; endpoint-completed states, all source-saturated.
(define chain
  (checked
   (raw-app 'sharing-u
            (raw-app 'sharing-u (raw-app 'sharing-a)))))
(define chain-map
  (qmap (list (cons '() 'outer-u)
              (cons '(1) 'inner-u)
              (cons '(1 1) 'a))))
(define chain-audit
  (check-certified
   (audit-sharing-saturation chain chain-map #:antichain-limit 16)
   4 4 0))
(check-equal?
 (sharing-residual-records (sharing-saturation-audit-residual chain-audit))
 '())
(check-equal?
 (map sharing-source-node-use-multiplicity
      (sharing-saturation-audit-source-nodes chain-audit))
 '(1 1 1))

;; 2. Minimal shared diamond J(A,A): five occurrence states, of which only
;; empty, both aliases together, and the witness-free whole endpoint saturate.
(define diamond
  (checked (raw-app 'sharing-j (raw-app 'sharing-a) (raw-app 'sharing-a))))
(define diamond-map
  (qmap (list (cons '() 'j)
              (cons '(1) 'a)
              (cons '(2) 'a))))
(define diamond-audit
  (check-certified
   (audit-sharing-saturation diamond diamond-map #:antichain-limit 8)
   5 3 2))
(define a-node
  (findf (lambda (node) (equal? (sharing-source-node-id node) 'a))
         (sharing-saturation-audit-source-nodes diamond-audit)))
(check-equal? (sharing-source-node-fibre a-node) '((1) (2)))
(check-equal? (sharing-source-node-use-multiplicity a-node) 2)
(check-equal? (length (sharing-saturation-audit-use-edges diamond-audit)) 2)

(define left-only (record-at diamond-audit '((1))))
(define right-only (record-at diamond-audit '((2))))
(define both-leaves (record-at diamond-audit '((1) (2))))
(check-not-false left-only)
(check-not-false right-only)
(check-not-false both-leaves)
(check-false (sharing-cut-record-saturated? left-only))
(check-false (sharing-cut-record-saturated? right-only))
(check-true (sharing-cut-record-saturated? both-leaves))
(check-equal? (proof-forest-size (sharing-cut-record-forest both-leaves)) 2)
(check-equal? (length (sharing-cut-record-detached both-leaves)) 2)
(check-equal?
 (map detached-entry-address (sharing-cut-record-detached both-leaves))
 '((1) (2)))

(define diamond-full
  (sharing-saturation-audit-native-character diamond-audit))
(define diamond-saturated
  (sharing-saturation-audit-saturated-character diamond-audit))
(check-equal? (coefficient diamond-full) 1)
(check-equal? (coefficient diamond-full (cons 'j 1)) 1)
(check-equal? (coefficient diamond-full (cons 'a 1)) 2)
(check-equal? (coefficient diamond-full (cons 'a 2)) 1)
(check-equal? (coefficient diamond-saturated) 1)
(check-equal? (coefficient diamond-saturated (cons 'j 1)) 1)
(check-equal? (coefficient diamond-saturated (cons 'a 1)) 0)
(check-equal? (coefficient diamond-saturated (cons 'a 2)) 1)
(check-equal? (sharing-character-polynomial-degree diamond-full 'a) 2)
(check-equal? (length (sharing-saturation-audit-antichain-matches
                       diamond-audit))
              2)

;; The whole contribution has no witness and never uses the native root as a
;; cut address.
(define diamond-whole
  (findf (lambda (record)
           (eq? (sharing-cut-record-kind record) 'whole))
         (sharing-saturation-audit-records diamond-audit)))
(check-not-false diamond-whole)
(check-false (sharing-cut-record-native-witness diamond-whole))
(check-equal? (sharing-cut-record-addresses diamond-whole) '())
(define root-cut-attempt (make-cut-witness diamond (list root-address)))
(check-true (cut-error? root-cut-attempt))
(check-equal? (cut-error-code root-cut-attempt) 'root-cut)

;; 3. R(L(C),R(C)): ten states, six saturated, and the four exact use-local
;; residual witnesses from the mathematical example.
(define two-level
  (checked
   (raw-app 'sharing-r
            (raw-app 'sharing-left (raw-app 'sharing-c))
            (raw-app 'sharing-right (raw-app 'sharing-c)))))
(define two-level-map
  (qmap (list (cons '() 'r)
              (cons '(1) 'left)
              (cons '(1 1) 'c)
              (cons '(2) 'right)
              (cons '(2 1) 'c))))
(define two-level-audit
  (check-certified
   (audit-sharing-saturation two-level two-level-map
                             #:antichain-limit 32)
   10 6 4))
(check-equal?
 (map sharing-cut-record-addresses
      (sharing-saturation-audit-unsaturated two-level-audit))
 '(((1 1)) ((1 1) (2)) ((2 1)) ((1) (2 1))))
;; The enumerator's order is native and need not be the prose order; compare
;; the exact residual address family as a set as well.
(for ([expected (in-list '(((1 1)) ((2 1)) ((1) (2 1)) ((1 1) (2))))])
  (check-not-false
   (findf (lambda (record)
            (equal? expected (sharing-cut-record-addresses record)))
          (sharing-saturation-audit-unsaturated two-level-audit))))
(define two-full
  (sharing-saturation-audit-native-character two-level-audit))
(define two-saturated
  (sharing-saturation-audit-saturated-character two-level-audit))
(check-equal? (coefficient two-full (cons 'c 1)) 2)
(check-equal? (coefficient two-full (cons 'c 2)) 1)
(check-equal? (coefficient two-full (cons 'left 1) (cons 'c 1)) 1)
(check-equal? (coefficient two-full (cons 'right 1) (cons 'c 1)) 1)
(check-equal? (coefficient two-saturated (cons 'c 1)) 0)
(check-equal? (coefficient two-saturated (cons 'c 2)) 1)
(check-equal? (length (sharing-saturation-audit-antichain-matches
                       two-level-audit))
              5)

;; 4. Existing one-port macro composition: source identity remains separate
;; from the two copied native use addresses in both one-shot and staged paths.
(define x-port (make-macro-port 'x S))
(define chain-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'sharing-e (raw-app 'sharing-u raw-hole)))
   (list x-port)
   (list (cons '(1 1) 'x))))
(define dup-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'sharing-j raw-hole raw-hole))
   (list x-port)
   (list (cons '(1) 'x) (cons '(2) 'x))))
(define material-profile
  (make-material-profile calculus (list a-occ u-occ j-occ)))
(define material-selector (prepare-material-hopf-selector material-profile))
(define a-proof (checked (raw-app 'sharing-a)))
(define macro-comparison
  (audit-material-macro-composition
   chain-summary 'x dup-summary 'x a-proof material-selector #:limit 128))
(check-true (material-macro-composition-certified? macro-comparison))
(define one-shot-target
  (material-macro-transport-target
   (material-macro-composition-one-shot-audit macro-comparison)))
(define staged-target
  (material-macro-transport-target
   (material-macro-composition-two-stage-audit macro-comparison)))
(check-equal? one-shot-target staged-target)
(define macro-map
  (qmap (list (cons '() 'extension)
              (cons '(1) 'chain)
              (cons '(1 1) 'copy)
              (cons '(1 1 1) 'input-a)
              (cons '(1 1 2) 'input-a))))
(define macro-sharing
  (check-certified
   (audit-sharing-saturation one-shot-target macro-map
                             #:antichain-limit 32)
   7 5 2))
(define copied-input-node
  (findf (lambda (node)
           (equal? (sharing-source-node-id node) 'input-a))
         (sharing-saturation-audit-source-nodes macro-sharing)))
(check-equal? (sharing-source-node-fibre copied-input-node)
              '((1 1 1) (1 1 2)))

;; 5. An exact material profile is necessarily fibre-constant for one source
;; occurrence.  A separate use-local observation can demand a split, but is
;; intentionally not represented as a native material profile.
(define fibre-constant-actions
  (for/hash ([address (in-list (vertex-addresses diamond))])
    (define occurrence
      (checked-node-occurrence (vertex-at-address diamond address)))
    (values
     address
     (make-sharing-local-action-key
      'keep
      (material-profile-designates? material-profile occurrence)))))
(define constant-action-audit
  (audit-sharing-actions diamond-audit fibre-constant-actions))
(check-equal? (sharing-action-audit-status constant-action-audit)
              'preserve-share)
(check-equal? (sharing-action-audit-variant-count constant-action-audit 'a)
              1)

(define use-local-actions
  (for/hash ([address (in-list (vertex-addresses diamond))])
    (values
     address
     (make-sharing-local-action-key
      'keep
      (cond [(equal? address '(1)) 'left-use]
            [(equal? address '(2)) 'right-use]
            [else 'same-root])))))
(define use-local-action-audit
  (audit-sharing-actions diamond-audit use-local-actions))
(check-equal? (sharing-action-audit-status use-local-action-audit)
              'local-split-lower-bound)
(check-equal? (sharing-action-audit-variant-count use-local-action-audit 'a)
              2)
(check-true
 (hash-ref (sharing-action-audit-laws use-local-action-audit)
           'bottom-up-sufficient?))
(check-true
 (hash-ref (sharing-action-audit-laws use-local-action-audit)
           'source-respecting-minimal?))

;; Child routing participates in complete state equality.  The two U uses
;; have the same local key, but distinct child states force two U variants.
(define shared-parents
  (checked
   (raw-app 'sharing-j
            (raw-app 'sharing-u (raw-app 'sharing-a))
            (raw-app 'sharing-u (raw-app 'sharing-a)))))
(define shared-parent-map
  (qmap (list (cons '() 'j)
              (cons '(1) 'u)
              (cons '(1 1) 'a)
              (cons '(2) 'u)
              (cons '(2 1) 'a))))
(define shared-parent-audit
  (check-certified
   (audit-sharing-saturation shared-parents shared-parent-map
                             #:antichain-limit 16)
   10 4 6))
(define propagated-actions
  (for/hash ([address (in-list (vertex-addresses shared-parents))])
    (values address
            (make-sharing-local-action-key
             'keep
             (cond [(equal? address '(1 1)) 'left-leaf]
                   [(equal? address '(2 1)) 'right-leaf]
                   [else 'same-local-key])))))
(define propagated-audit
  (audit-sharing-actions shared-parent-audit propagated-actions))
(check-equal? (sharing-action-audit-variant-count propagated-audit 'a) 2)
(check-equal? (sharing-action-audit-variant-count propagated-audit 'u) 2)
(check-equal?
 (length
  (filter (lambda (class)
            (equal? (sharing-action-class-source-id class) 'u))
          (sharing-action-audit-local-classes propagated-audit)))
 1)

;; Mutation/negative gates.

;; Ordered premise slots cannot be permuted inside one alleged source class.
(define permuted
  (checked
   (raw-app 'sharing-j
            (raw-app 'sharing-p (raw-app 'sharing-a) (raw-app 'sharing-c))
            (raw-app 'sharing-p (raw-app 'sharing-c) (raw-app 'sharing-a)))))
(define permuted-map
  (qmap (list (cons '() 'j)
              (cons '(1) 'p)
              (cons '(1 1) 'a)
              (cons '(1 2) 'c)
              (cons '(2) 'p)
              (cons '(2 1) 'c)
              (cons '(2 2) 'a))))
(check-exn exn:fail:contract?
           (lambda () (audit-sharing-saturation permuted permuted-map)))

;; Opaque incidence is not enough to compare two aliases as one exact source.
(define opaque-diamond
  (checked
   (raw-app 'sharing-j
            (raw-app 'sharing-opaque)
            (raw-app 'sharing-opaque))))
(define opaque-map
  (qmap (list (cons '() 'j)
              (cons '(1) 'opaque)
              (cons '(2) 'opaque))))
(check-exn exn:fail:contract?
           (lambda () (audit-sharing-saturation opaque-diamond opaque-map)))

;; Exact map provenance cannot cross an otherwise structurally equal registry.
(define foreign-calculus (make-equipped-calculus occurrences))
(define foreign-diamond
  (checked
   (raw-app 'sharing-j (raw-app 'sharing-a) (raw-app 'sharing-a))
   #:calculus foreign-calculus))
(check-exn exn:fail:contract?
           (lambda ()
             (audit-sharing-saturation foreign-diamond diamond-map)))

;; Source annotations do not add CK vertices, and a low source-subset bound is
;; inconclusive rather than a false bijection certificate.
(check-equal? (length (vertex-addresses diamond)) 3)
(check-equal? (length (sharing-saturation-audit-source-nodes diamond-audit)) 2)
(define truncated
  (audit-sharing-saturation diamond diamond-map #:antichain-limit 1))
(check-equal? (sharing-saturation-audit-status truncated) 'inconclusive)
(check-false (sharing-saturation-certified? truncated))
(check-not-false
 (member 'source-subset-limit-exceeded
         (sharing-saturation-audit-reasons truncated)))

;; Correlated alias selection would lose these two positive singleton-use
;; witnesses; neither is accepted as a source-global edit.
(check-equal?
 (map sharing-cut-record-addresses
      (sharing-residual-records
       (sharing-saturation-audit-residual diamond-audit)))
 '(((1)) ((2))))

(printf
 (string-append
  "SHARING SATURATION: tree 4/4/0; diamond 5/3/2 with residual "
  "{(1),(2)} and 1+z_j+2z_a+z_a^2; two-level 10/6/4; "
  "nested macro 7/5/2; local split a=2 and propagated u=2; "
  "all complete bounded audits certified.\n"))
