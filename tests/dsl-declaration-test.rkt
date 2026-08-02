#lang racket/base

(require racket/runtime-path
         rackunit
         "../potkin/main.rkt")

(define-formula-signature L
  #:atoms [S T U]
  [truth 0]
  [fusion 2]
  [implication 2])

(check-true (formula-signature? L))
(check-equal? (formula-signature-atoms L) '(S T U))
(check-equal? (formula-signature-operators L)
              '((fusion . 2) (implication . 2) (truth . 0)))
(check-equal? (formula-signature-operator-arity L 'fusion) 2)
(check-equal? (formula-signature-operator-arity L 'truth) 0)
(check-false (formula-signature-operator-arity L 'missing))

;; Generated formulae are the existing deeply immutable symbolic data.
(check-equal? S 'S)
(check-equal? (truth) '(truth))
(check-equal? (fusion S T) '(fusion S T))
(check-true (formula-datum? (implication (fusion S T) U)))
(check-true (formula-in-signature? L '(implication (fusion S T) U)))
(check-false (formula-in-signature? L 'outside))
(check-false (formula-in-signature? L '(fusion S)))
(check-false (formula-in-signature? L (vector S T)))
(check-false (formula-in-signature? L (string-copy "S")))
(check-exn exn:fail:contract? (lambda () (fusion S)))
(check-exn exn:fail:contract? (lambda () (fusion S 'outside)))

(define HS
  (hseq L
    (seq L [] => [S])))
(define HT
  (hseq L
    (seq L [] => [T])))
(define HST
  (hseq L
    (seq L [] => [(fusion S T)])))
(define HU
  (hseq L
    (seq L [] => [U])))

(check-true (hypersequent-in-signature? L HST))
(check-equal?
 (formula-context->list
  (sequent-left (car (hypersequent-sequents
                      (hseq L (seq L [T S S] => [U]))))))
 '(S S T))
(define repeated-HS
  (hseq L (seq L [] => [S]) (seq L [] => [S])))
(check-equal? (hypersequent-size repeated-HS) 2)
(check-equal? (hypersequent-count repeated-HS
                                  (make-sequent '() '(S)))
              2)
(check-exn
 exn:fail:contract?
 (lambda ()
   (hseq L (make-sequent '() '(outside)))))

(define-rule-signature Rules
  [ground   #:kind material   #:arity 0]
  [fusion-R #:kind logical    #:arity 2]
  [wrap     #:kind structural #:arity 1])

(check-true (rule-signature? Rules))
(check-equal? (map rule-type-tag (rule-signature-types Rules))
              '(fusion-R ground wrap))
(check-eq? (rule-signature-lookup Rules 'ground) ground)
(check-true (rule-signature-admits? Rules fusion-R))
(check-equal? (list (rule-type-tag wrap)
                    (rule-type-kind wrap)
                    (rule-type-arity wrap))
              '(wrap structural 1))

(define-occurrence bS
  #:type ground
  #:instance S
  #:premises []
  #:conclusion HS)
(define-occurrence bS-prime
  #:type ground
  #:id 'bS/prime
  #:instance '(alternate S evidence)
  #:premises []
  #:conclusion HS
  #:incidence '#(opaque component metadata))
(define-occurrence bT
  #:type ground
  #:instance T
  #:premises []
  #:conclusion HT)
(define-occurrence m
  #:type fusion-R
  #:instance (list S T)
  #:premises [HS HT]
  #:conclusion HST)
(define-occurrence i
  #:type wrap
  #:instance U
  #:premises [HST]
  #:conclusion HU)

(check-equal? (concrete-occurrence-id bS) 'bS)
(check-equal? (concrete-occurrence-id bS-prime) 'bS/prime)
(check-equal? (concrete-occurrence-tag bS) 'ground)
(check-equal? (concrete-occurrence-kind bS) 'material)
(check-equal? (occurrence-arity m) 2)
(check-equal? (concrete-occurrence-incidence bS-prime)
              '#(opaque component metadata))
(check-true (occurrence-matches-rule-signature? Rules bS))
(check-true (occurrence-matches-rule-signature? Rules bS-prime))

(define-calculus K
  #:language L
  #:rules Rules
  #:occurrences [bS bS-prime bT m i])

(check-true (equipped-calculus? K))
(check-equal? (calculus-size K) 5)
(check-eq? (calculus-lookup K 'bS) bS)
(check-eq? (calculus-lookup K 'bS/prime) bS-prime)

;; Declaration failures are bounded constructor checks, not proof search.
(check-exn
 exn:fail:contract?
 (lambda ()
   (let ()
     (define-occurrence wrong-arity
       #:type fusion-R
       #:instance #f
       #:premises [HS]
       #:conclusion HST)
     wrong-arity)))

(check-exn
 exn:fail:contract?
 (lambda ()
   (let ()
     (define foreign-boundary
       (singleton-hypersequent '() '(outside)))
     (define foreign-ground
       (make-concrete-occurrence
        'foreign-ground
        '()
        foreign-boundary
        #:kind 'material
        #:tag 'ground))
     (define-calculus BadBoundary
       #:language L
       #:rules Rules
       #:occurrences [foreign-ground])
     BadBoundary)))

(check-exn
 exn:fail:contract?
 (lambda ()
   (let ()
     (define wrong-profile
       (make-concrete-occurrence
        'wrong-profile
        '()
        HS
        #:kind 'logical
        #:tag 'ground))
     (define-calculus BadProfile
       #:language L
       #:rules Rules
       #:occurrences [wrong-profile])
     BadProfile)))

(check-exn
 exn:fail:contract?
 (lambda ()
   (let ()
     (define-occurrence duplicate-bS
       #:type ground
       #:id 'bS
       #:instance 'duplicate
       #:premises []
       #:conclusion HS)
     (define-calculus DuplicateIDs
       #:language L
       #:rules Rules
       #:occurrences [bS duplicate-bS])
     DuplicateIDs)))

;; Expansion-time declaration errors are tested in isolated namespaces so
;; they neither pollute this module nor create an unbounded expansion matrix.
(define-runtime-path potkin-main "../potkin/main.rkt")
(define expansion-namespace (make-base-namespace))
(parameterize ([current-namespace expansion-namespace])
  (namespace-require `(file ,(path->string potkin-main))))

(define (eval-with-potkin form)
  (parameterize ([current-namespace expansion-namespace])
    (eval form)))

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval-with-potkin
    '(define-formula-signature BadAtoms #:atoms [A A]))))
(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval-with-potkin
    '(define-formula-signature BadCollision #:atoms [A] [A 1]))))
(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval-with-potkin
    '(define-formula-signature BadOperators
       #:atoms [A]
       [f 1]
       [f 2]))))
(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval-with-potkin
    '(define-rule-signature BadRules
       [r #:kind logical #:arity 0]
       [r #:kind logical #:arity 1]))))
(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval-with-potkin
    '(define-rule-signature BadKind
       [r #:kind semantic #:arity 0]))))
(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval-with-potkin
    '(define-rule-signature BadArity
       [r #:kind logical #:arity -1]))))
