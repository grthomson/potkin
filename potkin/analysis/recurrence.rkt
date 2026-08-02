#lang racket/base

(require racket/list
         racket/vector
         "ancestry.rkt"
         "component-trace.rkt"
         "convolution.rkt"
         "../algebra/formal-sum.rkt"
         "../hopf/antipode.rkt"
         "../hopf/ck.rkt"
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt")

(provide boundary-return-character?
         make-boundary-return-character
         boundary-return-character-calculus
         boundary-return-character-boundary
         boundary-return-context?
         boundary-return-forest-value
         boundary-return-evaluate
         reduced-boundary-return-forest-value
         reduced-boundary-return-evaluate
         boundary-return-convolution-power
         (struct-out return-spine-frame)
         (struct-out return-spine-decomposition)
         return-spine-decomposition-of
         proper-boundary-return-addresses
         (struct-out return-tensor-evaluation)
         (struct-out return-expansion-step)
         (struct-out return-iterated-witness)
         iterated-return-witnesses
         (struct-out return-chain-witness)
         (struct-out return-witness-bijection)
         return-chain-witnesses
         (struct-out return-power-certificate)
         certify-return-convolution-power
         (struct-out return-polynomial-data)
         return-factorization-polynomial
         return-polynomial-evaluate
         (struct-out first-return-certificate)
         certify-first-return
         compose-one-hole-context
         (struct-out unfolding-layer)
         unfold-first-return-context
         (struct-out seeded-unfolding-certificate)
         certify-seeded-unfolding
         (struct-out side-evidence-data)
         side-evidence-factorization
         (struct-out side-evidence-product-certificate)
         check-side-evidence-product
         (struct-out component-relation-power)
         (struct-out component-recurrence-analysis)
         component-recurrence-powers)

;; The character is tied operationally to one exact calculus snapshot.  Its
;; structural boundary is a colour, not a replacement for provenance.
(struct boundary-return-character (calculus boundary)
  #:constructor-name make-boundary-return-character/internal
  #:sealed
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (boundary-return-character? right)
          (eq? (boundary-return-character-calculus left)
               (boundary-return-character-calculus right))
          (recur (boundary-return-character-boundary left)
                 (boundary-return-character-boundary right))))
   (lambda (value recur)
     (bitwise-xor
      (eq-hash-code (boundary-return-character-calculus value))
      (arithmetic-shift
       (recur (boundary-return-character-boundary value)) 1)))
   (lambda (value recur)
     (bitwise-xor
      #x2c1b3c6d
      (arithmetic-shift
       (eq-hash-code (boundary-return-character-calculus value)) 1)
      (recur (boundary-return-character-boundary value))))))

(struct return-tensor-evaluation
  (key coefficient coordinate-values contribution survives?)
  #:transparent)

;; The universal argument follows the unique puncture-bearing constructor
;; child.  Every frame retains the ordered off-spine children needed for the
;; inverse reconstruction; return? classifies the current constructor root.
(struct return-spine-frame
  (address occurrence selected-slot root-boundary selected-boundary
           off-spine-children return?)
  #:transparent)

(struct return-spine-decomposition
  (character source puncture frames proper-return-addresses reconstructed
             reconstructs?)
  #:transparent)

;; These are the uncollected occurrence witnesses for the same rightmost
;; coproduct expansion used by `iterated-coproduct`.  Whole is the separately
;; adjoined algebraic endpoint; empty and proper are actual CK cut witnesses;
;; unit is the unique coproduct witness for an empty-forest right coordinate.
(struct return-expansion-step
  (stage kind source-forest addresses cut-witness left-forest right-forest)
  #:transparent)

(struct return-iterated-witness
  (source
   power
   steps
   coordinate-forests
   tensor
   coordinate-values
   survives?
   reverse-chain-addresses)
  #:transparent)

;; addresses are stored outer-to-inner.  staged-witnesses and coordinate
;; forests follow the actual rightmost-coproduct construction: inner-to-outer.
(struct return-chain-witness
  (source
   spine-decomposition
   constructor-decisions
   addresses
   staged-witnesses
   coordinate-forests
   tensor
   reconstructs?)
  #:transparent)

(struct return-witness-bijection
  (addresses
   chain-witness
   iterated-witness
   forward-tensor-equal?
   reverse-chain-equal?
   roundtrip?)
  #:transparent)

(struct return-power-certificate
   (character
    source
    power
    spine-decomposition
    actual-iterated-coproduct
    tensor-evaluations
    actual-survivor-projection
    iterated-occurrence-witnesses
    uncollected-iterated-sum
    surviving-occurrence-witnesses
    uncollected-survivor-projection
    chain-witnesses
    recursive-chain-projection
    witness-bijections
    actual-value
    chain-count
    binomial-expected
    uncollected-iterated-equal?
    occurrence-projection-equal?
    projection-equal?
    scalar-equal?
    witness-count-equal?
    witness-bijection-holds?)
  #:transparent)

(struct return-polynomial-data
  (source return-count coefficients closed-form-coefficients equal?)
  #:transparent)

(struct first-return-certificate
  (character
   source
   puncture
   proper-return-addresses
   power-certificates
   polynomial
   antipode-image
   antipode-character-value
   polynomial-at-minus-one
   first-return-indicator
   direct-first-return?
   polynomial-antipode-sign-law?
   indicator-law?
   theorem-holds?)
  #:transparent)

(struct unfolding-layer
  (power context inserted-root-address puncture-address return-certificate
         power-law?)
  #:transparent)

(struct seeded-unfolding-certificate
  (base-context
   power
   layers
   seed
   completed-proof
   separation-addresses
   staged-witnesses
   coordinate-forests
   actual-iterated-coproduct
   collected-coefficient
   reconstructs?)
  #:transparent)

(struct side-evidence-data
  (source
   puncture
   spine-addresses
   frontier-addresses
   witness
   forest
   bare-spine-remainder
   new-puncture-addresses
   reconstruction
   reconstructs?)
  #:transparent)

(struct side-evidence-product-certificate
  (outer
   inner
   composed
   outer-factorization
   inner-factorization
   composed-factorization
   prefixed-inner-frontier
   expected-forest
   frontier-equal?
   forest-equal?
   reconstruction-holds?)
  #:transparent)

(struct component-relation-power
  (power edges context direct-trace direct-edges agrees?)
  #:transparent)
(struct component-recurrence-analysis
  (source
   trace
   powers
   status
   repeat-start
   period
   relation-state-count-bound
   exhaustive-state-bound-reached?
   direct-power-agreement?
   scalar-analysis
   scalar-calibrated?
   local-scalar-distribution)
  #:transparent)

(define (make-boundary-return-character calculus boundary)
  (unless (equipped-calculus? calculus)
    (raise-argument-error
     'make-boundary-return-character "equipped-calculus?" calculus))
  (unless (hypersequent? boundary)
    (raise-argument-error
     'make-boundary-return-character "hypersequent?" boundary))
  (make-boundary-return-character/internal calculus boundary))

(define (check-character who character)
  (unless (boundary-return-character? character)
    (raise-argument-error who "boundary-return-character?" character)))

(define (check-limit who limit)
  (unless (or (not limit) (exact-nonnegative-integer? limit))
    (raise-argument-error
     who "(or/c #f exact-nonnegative-integer?)" limit)))

(define (limit-result operation limit required metric [details (hash)])
  (analysis-limit
   'not-computed-limit
   "the exact recurrence analysis exceeds its configured finite limit"
   operation limit required metric details))

(define (boundary-return-context? character value)
  (check-character 'boundary-return-context? character)
  (define calculus (boundary-return-character-calculus character))
  (define boundary (boundary-return-character-boundary character))
  (and (checked-node? value)
       (checked-term-has-exact-calculus? value calculus)
       (= (length (premise-telescope value)) 1)
       (equal? (derivation-root-boundary value) boundary)
       (equal? (telescope-entry-requirement
                (car (premise-telescope value)))
               boundary)))

(define (boundary-return-forest-value character forest)
  (check-character 'boundary-return-forest-value character)
  (unless (proof-forest? forest)
    (raise-argument-error
     'boundary-return-forest-value "proof-forest?" forest))
  (unless (eq? (proof-forest-calculus forest)
               (boundary-return-character-calculus character))
    (raise-arguments-error
     'boundary-return-forest-value
     "the forest must carry the character's exact calculus snapshot"
     "character calculus" (boundary-return-character-calculus character)
     "forest calculus" (proof-forest-calculus forest)))
  (for/product ([factor (in-list (proof-forest-factors forest))])
    (if (boundary-return-context? character factor) 1 0)))

(define (reduced-boundary-return-forest-value character forest)
  (- (boundary-return-forest-value character forest)
     (forest-counit forest)))

(define (check-rank-one-character-input who character sum)
  (check-character who character)
  (unless (formal-sum? sum)
    (raise-argument-error who "formal-sum?" sum))
  (unless (= (formal-sum-rank sum) 1)
    (raise-arguments-error
     who
     "character evaluation is defined on rank-one formal sums"
     "rank" (formal-sum-rank sum)))
  (unless (eq? (formal-sum-calculus sum)
               (boundary-return-character-calculus character))
    (raise-arguments-error
     who
     "character evaluation requires the exact character calculus"
     "character calculus" (boundary-return-character-calculus character)
     "sum calculus" (formal-sum-calculus sum))))

(define (evaluate-character-on-sum who forest-functional character sum)
  (check-rank-one-character-input who character sum)
  (for/sum ([entry (in-list (formal-sum-terms sum))])
    (* (cdr entry)
       (forest-functional character (vector-ref (car entry) 0)))))

(define (boundary-return-evaluate character sum)
  (evaluate-character-on-sum
   'boundary-return-evaluate
   boundary-return-forest-value
   character
   sum))

(define (reduced-boundary-return-evaluate character sum)
  (evaluate-character-on-sum
   'reduced-boundary-return-evaluate
   reduced-boundary-return-forest-value
   character
   sum))

(define (boundary-return-convolution-power
         character source power #:limit [limit analysis-default-limit])
  (check-character 'boundary-return-convolution-power character)
  (unless (checked-node? source)
    (raise-argument-error
     'boundary-return-convolution-power "checked-node?" source))
  (unless (exact-positive-integer? power)
    (raise-argument-error
     'boundary-return-convolution-power "exact-positive-integer?" power))
  (check-limit 'boundary-return-convolution-power limit)
  (unless (checked-term-has-exact-calculus?
           source (boundary-return-character-calculus character))
    (raise-arguments-error
     'boundary-return-convolution-power
     "the source must carry the character's exact calculus snapshot"
     "source" source))
  (define iterated (iterated-coproduct source power #:limit limit))
  (if (formal-sum? iterated)
      (for/sum ([entry (in-list (formal-sum-terms iterated))])
        (define values
          (for/list ([forest (in-vector (car entry))])
            (reduced-boundary-return-forest-value character forest)))
        (* (cdr entry) (apply * values)))
      iterated))

(define (return-spine-decomposition-of character source)
  (check-character 'return-spine-decomposition-of character)
  (unless (boundary-return-context? character source)
    (raise-argument-error
     'return-spine-decomposition-of
     "source satisfying boundary-return-context?"
     source))
  (define puncture (car (puncture-addresses source)))
  (define boundary (boundary-return-character-boundary character))
  (define frames
    (let walk ([current source]
               [address root-address]
               [remaining puncture]
               [result '()])
      (cond
        [(null? remaining)
         (unless (checked-hole? current)
           (error
            'return-spine-decomposition-of
            "the unique puncture path did not end in its checked hole"))
         (reverse result)]
        [else
         (unless (checked-node? current)
           (error
            'return-spine-decomposition-of
            "a strict puncture prefix was not a checked constructor"))
         (define slot (car remaining))
         (define occurrence (checked-node-occurrence current))
         (define selected (list-ref (checked-node-children current) (sub1 slot)))
         (define off-spine
           (for/list ([child (in-list (checked-node-children current))]
                      [child-slot (in-naturals 1)]
                      #:unless (= child-slot slot))
             (cons child-slot child)))
         (define frame
           (return-spine-frame
            address
            occurrence
            slot
            (derivation-root-boundary current)
            (occurrence-premise occurrence slot)
            off-spine
            (and (pair? address)
                 (equal? (derivation-root-boundary current) boundary))))
         (walk selected
               (address-append address (list slot))
               (cdr remaining)
               (cons frame result))])))
  ;; This fold is the inverse constructor map.  It uses the retained ordered
  ;; side children and never infers composition from a commutative forest.
  (define reconstructed
    (for/fold ([current (checked-term-at-address source puncture)])
              ([frame (in-list (reverse frames))])
      (define occurrence (return-spine-frame-occurrence frame))
      (define selected-slot (return-spine-frame-selected-slot frame))
      (define children
        (for/list ([slot (in-range 1 (add1 (occurrence-arity occurrence)))])
          (if (= slot selected-slot)
              current
              (let ([entry
                     (assoc slot
                            (return-spine-frame-off-spine-children frame))])
                (unless entry
                  (error
                   'return-spine-decomposition-of
                   "an ordered off-spine constructor child was not retained"))
                (cdr entry)))))
      (define rebuilt
        (context-compose
         (corolla (boundary-return-character-calculus character) occurrence)
         children))
      (when (context-error? rebuilt)
        (error
         'return-spine-decomposition-of
         "inverse constructor recomposition unexpectedly failed: ~e"
         rebuilt))
      rebuilt))
  (define returns
    (for/list ([frame (in-list frames)]
               #:when (return-spine-frame-return? frame))
      (return-spine-frame-address frame)))
  (return-spine-decomposition
   character source puncture frames returns reconstructed
   (equal? reconstructed source)))

(define (proper-boundary-return-addresses character source)
  (return-spine-decomposition-proper-return-addresses
   (return-spine-decomposition-of character source)))

(define (binomial n k)
  (cond
    [(or (< k 0) (> k n)) 0]
    [else
     (define small-k (min k (- n k)))
     (for/fold ([result 1]) ([i (in-range 1 (add1 small-k))])
       (quotient (* result (+ (- n small-k) i)) i))]))

(struct constructor-selection (decisions addresses) #:transparent)

;; Include/omit follows the return-bearing constructor frames themselves.
;; This recursion, paired with the inverse spine reconstruction above, is the
;; theorem construction; the binomial is only its independent scalar check.
(define (return-constructor-selections addresses k)
  (cond
    [(null? addresses)
     (if (zero? k)
         (list (constructor-selection '() '()))
         '())]
    [(or (< k 0) (> k (length addresses))) '()]
    [else
     (append
      (for/list
          ([tail
            (in-list
             (return-constructor-selections
              (cdr addresses) (sub1 k)))])
        (constructor-selection
         (cons (cons (car addresses) #t)
               (constructor-selection-decisions tail))
         (cons (car addresses)
               (constructor-selection-addresses tail))))
      (for/list
          ([tail
            (in-list
             (return-constructor-selections (cdr addresses) k))])
        (constructor-selection
         (cons (cons (car addresses) #f)
               (constructor-selection-decisions tail))
         (constructor-selection-addresses tail))))]))

(define (singleton-forest term)
  (make-proof-forest (checked-term-calculus term) (list term)))

(struct return-witness-state (steps coordinate-forests) #:transparent)

(define (return-expansion-options forest stage)
  (define calculus (proof-forest-calculus forest))
  (define factors (proof-forest-factors forest))
  (cond
    [(null? factors)
     (define unit (empty-proof-forest calculus))
     (list
      (return-expansion-step
       stage 'unit forest '() #f unit unit))]
    [(and (= (length factors) 1) (checked-node? (car factors)))
     (define term (car factors))
     (define endpoint
       (return-expansion-step
        stage
        'whole
        forest
        '()
        #f
        forest
        (empty-proof-forest calculus)))
     (cons
      endpoint
      (for/list ([witness (in-admissible-cut-witnesses term)])
        (when (cut-error? witness)
          (error
           'iterated-return-witnesses
           "the CK cut enumerator produced an invalid witness: ~e"
           witness))
        (return-expansion-step
         stage
         (if (null? (cut-witness-addresses witness)) 'empty 'proper)
         forest
         (cut-witness-addresses witness)
         witness
         (cut-witness-forest witness)
         (singleton-forest (cut-witness-remainder witness)))))]
    [else
     ;; Starting from one connected generator, rightmost CK expansion always
     ;; leaves either the unit or one connected retained context.  Reaching a
     ;; nontrivial forest here would contradict that local constructor law.
     (error
      'iterated-return-witnesses
      "rightmost connected CK expansion produced a multi-factor remainder: ~e"
      forest)]))

(define (reverse-chain-from-steps steps survives?)
  (and
   survives?
   (for/and ([step (in-list steps)])
     (and (eq? (return-expansion-step-kind step) 'proper)
          (= (length (return-expansion-step-addresses step)) 1)))
   (reverse
    (for/list ([step (in-list steps)])
      (car (return-expansion-step-addresses step))))))

(define (iterated-return-witnesses
         character source power #:limit [limit analysis-default-limit])
  (check-character 'iterated-return-witnesses character)
  (unless (checked-node? source)
    (raise-argument-error 'iterated-return-witnesses "checked-node?" source))
  (unless (checked-term-has-exact-calculus?
           source (boundary-return-character-calculus character))
    (raise-arguments-error
     'iterated-return-witnesses
     "the source must carry the character's exact calculus snapshot"
     "source" source))
  (unless (exact-positive-integer? power)
    (raise-argument-error
     'iterated-return-witnesses "exact-positive-integer?" power))
  (check-limit 'iterated-return-witnesses limit)
  (define initial
    (list (return-witness-state '() (list (singleton-forest source)))))
  (define states
    (let loop ([rank 1] [current initial])
      (cond
        [(and limit (> (length current) limit))
         (limit-result
          'iterated-return-witnesses
          limit
          (length current)
          'uncollected-iterated-witness-count
          (hash 'power power 'stage rank))]
        [(= rank power) current]
        [else
         (define next
           (let/ec stop
             (define result '())
             (define count 0)
             (for* ([state (in-list current)]
                    [choice
                     (in-list
                      (let ([coordinates
                             (return-witness-state-coordinate-forests state)])
                        (return-expansion-options (last coordinates) rank)))])
               (define coordinates
                 (return-witness-state-coordinate-forests state))
               (set! count (add1 count))
               (when (and limit (> count limit))
                 (stop
                  (limit-result
                   'iterated-return-witnesses
                   limit
                   count
                   'uncollected-iterated-witness-count
                   (hash 'power power 'stage (add1 rank)))))
               (set!
                result
                (cons
                 (return-witness-state
                  (append (return-witness-state-steps state) (list choice))
                  (append
                   (drop-right coordinates 1)
                   (list (return-expansion-step-left-forest choice)
                         (return-expansion-step-right-forest choice))))
                 result)))
             (reverse result)))
         (if (analysis-limit? next)
             next
             (loop (add1 rank) next))])))
  (cond
    [(analysis-limit? states) states]
    [else
     (define calculus (boundary-return-character-calculus character))
     (for/list ([state (in-list states)])
       (define coordinates
         (return-witness-state-coordinate-forests state))
       (define coordinate-values
         (for/list ([forest (in-list coordinates)])
           (reduced-boundary-return-forest-value character forest)))
       (define survives?
         (andmap (lambda (value) (= value 1)) coordinate-values))
       (return-iterated-witness
        source
        power
        (return-witness-state-steps state)
        coordinates
        (pure-tensor
         calculus
         (vector->immutable-vector (list->vector coordinates)))
        coordinate-values
        survives?
        (reverse-chain-from-steps
          (return-witness-state-steps state) survives?)))]))

(define (make-return-chain-witness
         source decomposition decisions addresses)
  (define calculus (checked-term-calculus source))
  (let loop ([remaining (reverse addresses)]
             [current source]
             [witnesses '()]
             [forests '()]
             [reconstructs? #t])
    (cond
      [(null? remaining)
       (define coordinates
         (append forests (list (singleton-forest current))))
       (define tensor
         (pure-tensor calculus
                      (vector->immutable-vector
                       (list->vector coordinates))))
       (return-chain-witness
         source
         decomposition
         decisions
         addresses
        witnesses
        coordinates
        tensor
        reconstructs?)]
      [else
       (define witness (make-cut-witness current (list (car remaining))))
       (when (cut-error? witness)
         (error
          'return-chain-witnesses
          "a proper return address failed staged CK cutting: ~e"
          witness))
       (loop (cdr remaining)
             (cut-witness-remainder witness)
             (append witnesses (list witness))
             (append forests (list (cut-witness-forest witness)))
             (and reconstructs? (cut-witness-reconstructs? witness)))])))

(define (return-chain-witnesses
         character source power #:limit [limit analysis-default-limit])
  (check-character 'return-chain-witnesses character)
  (unless (boundary-return-context? character source)
    (raise-argument-error
     'return-chain-witnesses
     "source satisfying boundary-return-context?"
     source))
  (unless (exact-positive-integer? power)
    (raise-argument-error
     'return-chain-witnesses "exact-positive-integer?" power))
  (check-limit 'return-chain-witnesses limit)
  (define decomposition (return-spine-decomposition-of character source))
  (define returns
    (return-spine-decomposition-proper-return-addresses decomposition))
  (define required (binomial (length returns) (sub1 power)))
  (if (and limit (> required limit))
      (limit-result
       'return-chain-witnesses limit required 'return-chain-count
       (hash 'return-count (length returns) 'power power))
       (for/list ([selection
                   (in-list
                    (return-constructor-selections
                     returns (sub1 power)))])
         (make-return-chain-witness
          source
          decomposition
          (constructor-selection-decisions selection)
          (constructor-selection-addresses selection)))))

(define (tensor-evaluations character iterated)
  (for/list ([entry (in-list (formal-sum-terms iterated))])
    (define key (car entry))
    (define coefficient (cdr entry))
    (define coordinate-values
      (for/list ([forest (in-vector key)])
        (reduced-boundary-return-forest-value character forest)))
    (define contribution (* coefficient (apply * coordinate-values)))
    (return-tensor-evaluation
     key coefficient coordinate-values contribution
     (andmap (lambda (value) (= value 1)) coordinate-values))))

(define (projection-from-evaluations calculus power evaluations)
  (make-formal-sum
   calculus power
   (for/list ([evaluation (in-list evaluations)]
              #:when (return-tensor-evaluation-survives? evaluation))
     (cons (return-tensor-evaluation-key evaluation)
           (return-tensor-evaluation-coefficient evaluation)))))

(define (chain-projection calculus power witnesses)
  (make-formal-sum
   calculus power
   (for/list ([witness (in-list witnesses)])
     (cons
      (vector->immutable-vector
       (list->vector
       (return-chain-witness-coordinate-forests witness)))
      1))))

(define (occurrence-witness-projection calculus power witnesses)
  (make-formal-sum
   calculus power
   (for/list ([witness (in-list witnesses)])
     (cons
      (vector->immutable-vector
       (list->vector
        (return-iterated-witness-coordinate-forests witness)))
      1))))

(define (witness-bijections source chains survivors)
  (for/list ([actual (in-list survivors)])
    (define addresses
      (return-iterated-witness-reverse-chain-addresses actual))
    (define matches
      (filter
       (lambda (chain)
         (equal? addresses (return-chain-witness-addresses chain)))
       chains))
    (unless (= (length matches) 1)
      (error
       'certify-return-convolution-power
       "a surviving CK witness did not have exactly one recursive chain inverse: ~e"
       addresses))
    (define chain (car matches))
    (define reversed
      (make-return-chain-witness
       source
       (return-chain-witness-spine-decomposition chain)
       (return-chain-witness-constructor-decisions chain)
       addresses))
    (define forward?
      (equal? (return-chain-witness-tensor chain)
              (return-iterated-witness-tensor actual)))
    (define reverse?
      (and
       (equal? (return-chain-witness-addresses reversed) addresses)
       (equal? (return-chain-witness-coordinate-forests reversed)
               (return-iterated-witness-coordinate-forests actual))))
    (return-witness-bijection
     addresses chain actual forward? reverse? (and forward? reverse?))))

(define (witness-bijection-total? chains survivors bijections)
  (and
   (= (length chains) (length survivors) (length bijections))
   (andmap return-witness-bijection-roundtrip? bijections)
   (for/and ([chain (in-list chains)])
     (= 1
        (count
         (lambda (entry)
           (equal?
            (return-chain-witness-addresses chain)
            (return-witness-bijection-addresses entry)))
         bijections)))
   (for/and ([actual (in-list survivors)])
     (= 1
        (count
         (lambda (entry)
           (eq? actual (return-witness-bijection-iterated-witness entry)))
         bijections)))))

(define (certify-return-convolution-power
         character source power #:limit [limit analysis-default-limit])
  (check-character 'certify-return-convolution-power character)
  (unless (boundary-return-context? character source)
    (raise-argument-error
     'certify-return-convolution-power
     "source satisfying boundary-return-context?"
     source))
  (unless (exact-positive-integer? power)
    (raise-argument-error
     'certify-return-convolution-power "exact-positive-integer?" power))
  (check-limit 'certify-return-convolution-power limit)
  (define chains
    (return-chain-witnesses character source power #:limit limit))
  (cond
    [(analysis-limit? chains) chains]
    [else
     (define iterated (iterated-coproduct source power #:limit limit))
     (cond
       [(not (formal-sum? iterated)) iterated]
       [else
         (define calculus (boundary-return-character-calculus character))
         (define decomposition
           (return-spine-decomposition-of character source))
         (define evaluations (tensor-evaluations character iterated))
         (define actual-projection
           (projection-from-evaluations calculus power evaluations))
         (define occurrence-witnesses
           (iterated-return-witnesses
            character source power #:limit limit))
         (when (analysis-limit? occurrence-witnesses)
           (error
            'certify-return-convolution-power
            "the shared iterated-coproduct preflight admitted a larger uncollected witness family: ~e"
            occurrence-witnesses))
         (define surviving-witnesses
           (filter return-iterated-witness-survives? occurrence-witnesses))
         (define occurrence-full-sum
           (occurrence-witness-projection
            calculus power occurrence-witnesses))
         (define occurrence-projection
           (occurrence-witness-projection
            calculus power surviving-witnesses))
         (define recursive-projection
           (chain-projection calculus power chains))
         (define bijections
           (witness-bijections source chains surviving-witnesses))
         (define actual-value
          (for/sum ([evaluation (in-list evaluations)])
            (return-tensor-evaluation-contribution evaluation)))
        (define return-count
          (length (proper-boundary-return-addresses character source)))
        (define expected (binomial return-count (sub1 power)))
         (return-power-certificate
         character
         source
         power
         decomposition
         iterated
         evaluations
         actual-projection
         occurrence-witnesses
         occurrence-full-sum
         surviving-witnesses
         occurrence-projection
         chains
         recursive-projection
         bijections
         actual-value
         (length chains)
         expected
         (equal? iterated occurrence-full-sum)
         (equal? actual-projection occurrence-projection)
         (equal? actual-projection recursive-projection)
         (= actual-value expected)
         (= (length chains) expected)
         (witness-bijection-total?
          chains surviving-witnesses bijections))])]))

(define (return-factorization-polynomial character source coefficients)
  (check-character 'return-factorization-polynomial character)
  (unless (boundary-return-context? character source)
    (raise-argument-error
     'return-factorization-polynomial
     "source satisfying boundary-return-context?"
     source))
  (unless (and (vector? coefficients)
               (for/and ([coefficient (in-vector coefficients)])
                 (exact-integer? coefficient)))
    (raise-argument-error
     'return-factorization-polynomial
     "vector of exact integer coefficients"
     coefficients))
  (define return-count
    (length (proper-boundary-return-addresses character source)))
  (unless (= (vector-length coefficients) (+ return-count 2))
    (raise-arguments-error
     'return-factorization-polynomial
     "the coefficient vector must contain q^0 through its top nonzero degree"
     "expected length" (+ return-count 2)
     "actual length" (vector-length coefficients)
     "proper return count" return-count))
  (define closed
    (vector->immutable-vector
     (for/vector #:length (+ return-count 2) ([power (in-range (+ return-count 2))])
       (if (zero? power)
           0
           (binomial return-count (sub1 power))))))
  (define canonical
    (vector->immutable-vector (vector-copy coefficients)))
  (return-polynomial-data
   source return-count canonical closed (equal? canonical closed)))

(define (return-polynomial-evaluate polynomial q)
  (unless (return-polynomial-data? polynomial)
    (raise-argument-error
     'return-polynomial-evaluate "return-polynomial-data?" polynomial))
  (unless (number? q)
    (raise-argument-error 'return-polynomial-evaluate "number?" q))
  (for/sum ([coefficient
             (in-vector (return-polynomial-data-coefficients polynomial))]
            [power (in-naturals)])
    (* coefficient (expt q power))))

(define (certify-first-return
         character source #:limit [limit analysis-default-limit])
  (check-character 'certify-first-return character)
  (unless (boundary-return-context? character source)
    (raise-argument-error
     'certify-first-return
     "source satisfying boundary-return-context?"
     source))
  (check-limit 'certify-first-return limit)
  (define puncture (car (puncture-addresses source)))
  (define returns (proper-boundary-return-addresses character source))
  (define return-count (length returns))
  ;; The first forced zero above the binomial range is part of the
  ;; certificate, so endpoint annihilation is observed rather than assumed.
  (define certificates
    (let loop ([power 1] [result '()])
      (cond
        [(> power (+ return-count 2)) (reverse result)]
        [else
         (define certificate
           (certify-return-convolution-power
            character source power #:limit limit))
         (if (or (analysis-limit? certificate) (analysis-error? certificate))
             certificate
             (loop (add1 power) (cons certificate result)))])))
  (cond
    [(or (analysis-limit? certificates) (analysis-error? certificates))
     certificates]
    [else
     (define coefficients
       (vector->immutable-vector
        (list->vector
         (cons 0
               (for/list
                   ([certificate
                     (in-list (take certificates (add1 return-count)))])
                 (return-power-certificate-actual-value certificate))))))
     (define polynomial
       (return-factorization-polynomial character source coefficients))
     (define antipode-image (antipode (checked-node-basis source)))
     (cond
       [(not (formal-sum? antipode-image)) antipode-image]
       [else
        (define antipode-character-value
          (boundary-return-evaluate character antipode-image))
        (define at-minus-one (return-polynomial-evaluate polynomial -1))
        (define indicator (- antipode-character-value))
        (define direct-first-return? (zero? return-count))
        (define expected-indicator (if direct-first-return? 1 0))
        (define power-laws?
          (andmap
           (lambda (certificate)
             (and
               (return-power-certificate-uncollected-iterated-equal?
                certificate)
               (return-power-certificate-occurrence-projection-equal?
                certificate)
               (return-power-certificate-projection-equal? certificate)
               (return-power-certificate-scalar-equal? certificate)
               (return-power-certificate-witness-count-equal? certificate)
               (return-power-certificate-witness-bijection-holds?
                certificate)))
           certificates))
        (define sign-law? (= at-minus-one antipode-character-value))
        (define indicator-law? (= indicator expected-indicator))
        (first-return-certificate
         character
         source
         puncture
         returns
         certificates
         polynomial
         antipode-image
         antipode-character-value
         at-minus-one
         indicator
         direct-first-return?
         sign-law?
         indicator-law?
         (and power-laws?
              (return-polynomial-data-equal? polynomial)
              sign-law?
              indicator-law?))])]))

(define (compose-one-hole-context outer inner)
  (unless (and (checked-term? outer)
               (= (length (premise-telescope outer)) 1))
    (raise-argument-error
     'compose-one-hole-context "one-hole checked context outer" outer))
  (unless (and (checked-term? inner)
               (= (length (premise-telescope inner)) 1))
    (raise-argument-error
     'compose-one-hole-context "one-hole checked context inner" inner))
  (define address
    (telescope-entry-address (car (premise-telescope outer))))
  (define result (context-insert outer address inner))
  (if (context-error? result) result result))

(define (repeat-address address count)
  (for/fold ([result root-address]) ([index (in-range count)])
    (address-append result address)))

(define (unfold-first-return-context
         character source power #:limit [limit analysis-default-limit])
  (check-character 'unfold-first-return-context character)
  (unless (boundary-return-context? character source)
    (raise-argument-error
     'unfold-first-return-context
     "source satisfying boundary-return-context?"
     source))
  (define source-returns
    (proper-boundary-return-addresses character source))
  (unless (null? source-returns)
    (raise-arguments-error
     'unfold-first-return-context
     "the unfolding generator must be first-return relative to the boundary"
     "proper return addresses" source-returns))
  (unless (exact-positive-integer? power)
    (raise-argument-error
     'unfold-first-return-context "exact-positive-integer?" power))
  (check-limit 'unfold-first-return-context limit)
  (cond
    [(and limit (> power limit))
     (limit-result
      'unfold-first-return-context limit power 'unfolding-layer-count)]
    [else
     (define base-puncture (car (puncture-addresses source)))
     (let loop ([current source] [current-power 1] [layers '()])
       (define return-certificate
         (certify-first-return character current #:limit limit))
       (cond
         [(or (analysis-limit? return-certificate)
              (analysis-error? return-certificate))
          return-certificate]
         [else
          (define layer
            (unfolding-layer
             current-power
             current
             (if (= current-power 1)
                 root-address
                 (repeat-address base-puncture (sub1 current-power)))
             (car (puncture-addresses current))
             return-certificate
             (and
              (= (length
                  (first-return-certificate-proper-return-addresses
                   return-certificate))
                 (sub1 current-power))
              (return-polynomial-data-equal?
               (first-return-certificate-polynomial
                return-certificate)))))
          (cond
            [(= current-power power) (reverse (cons layer layers))]
            [else
             (define next
               (compose-one-hole-context current source))
             (if (context-error? next)
                 next
                 (loop next
                       (add1 current-power)
                       (cons layer layers)))])]))]))

(define (certify-seeded-unfolding
         character source power seed #:limit [limit analysis-default-limit])
  (check-character 'certify-seeded-unfolding character)
  (unless (boundary-return-context? character source)
    (raise-argument-error
     'certify-seeded-unfolding
     "source satisfying boundary-return-context?"
     source))
  (unless (complete-proof? seed)
    (raise-argument-error 'certify-seeded-unfolding "complete-proof?" seed))
  (unless (and (eq? (checked-term-calculus seed)
                    (boundary-return-character-calculus character))
               (equal? (derivation-root-boundary seed)
                       (boundary-return-character-boundary character)))
    (raise-arguments-error
     'certify-seeded-unfolding
     "the seed must have the character's exact calculus and boundary"
     "seed" seed))
  (define layers
    (unfold-first-return-context character source power #:limit limit))
  (cond
    [(or (analysis-limit? layers)
         (analysis-error? layers)
         (context-error? layers))
     layers]
    [else
     (define final-layer (last layers))
     (define context (unfolding-layer-context final-layer))
     (define final-puncture (unfolding-layer-puncture-address final-layer))
     (define completed (context-insert context final-puncture seed))
     (cond
       [(context-error? completed) completed]
       [else
        (define base-puncture (car (puncture-addresses source)))
        (define separation-addresses
          (cons final-puncture
                (for/list ([layer-power
                            (in-range power 1 -1)])
                  (repeat-address base-puncture (sub1 layer-power)))))
        (let loop ([remaining separation-addresses]
                   [current completed]
                   [witnesses '()]
                   [forests '()]
                   [reconstructs? #t])
          (cond
            [(null? remaining)
             (define coordinates
               (append forests (list (singleton-forest current))))
             (define iterated
               (iterated-coproduct completed (add1 power) #:limit limit))
             (if (not (formal-sum? iterated))
                 iterated
                 (let* ([key
                         (vector->immutable-vector
                          (list->vector coordinates))]
                        [coefficient
                         (formal-sum-coefficient iterated key)])
                   (seeded-unfolding-certificate
                    source power layers seed completed
                    separation-addresses witnesses coordinates iterated
                    coefficient reconstructs?)))]
            [else
             (define witness
               (make-cut-witness current (list (car remaining))))
             (when (cut-error? witness)
               (error
                'certify-seeded-unfolding
                "a distinguished unfolding cut unexpectedly failed: ~e"
                witness))
             (loop (cdr remaining)
                   (cut-witness-remainder witness)
                   (append witnesses (list witness))
                   (append forests (list (cut-witness-forest witness)))
                    (and reconstructs?
                         (cut-witness-reconstructs? witness)))]))])]))

(define (side-evidence-factorization source)
  (unless (and (checked-term? source)
               (= (length (premise-telescope source)) 1))
    (raise-argument-error
     'side-evidence-factorization
     "checked context with exactly one puncture"
     source))
  (define puncture (car (puncture-addresses source)))
  (cond
    [(checked-hole? source)
     ;; Box^G is the context-composition unit, not a connected CK generator;
     ;; its side evidence is the algebra unit and has no manufactured cut.
     (side-evidence-data
      source puncture '() '() #f
      (empty-proof-forest (checked-term-calculus source))
      source '() source #t)]
    [else
     (define spine-addresses
       (for/list ([address (in-list (sort (vertex-addresses source) address<?))]
                  #:when (proper-address-prefix? address puncture))
         address))
     (define frontier
       (sort
        (append-map
         (lambda (spine-address)
           (define node (vertex-at-address source spine-address))
           (define next-slot (list-ref puncture (length spine-address)))
           (for/list ([child (in-list (checked-node-children node))]
                      [slot (in-naturals 1)]
                      #:when (and (not (= slot next-slot))
                                  (checked-node? child)))
             (address-append spine-address (list slot))))
         spine-addresses)
        address<?))
     (define witness (make-cut-witness source frontier))
     (when (cut-error? witness)
       (error
        'side-evidence-factorization
        "the off-spine child frontier unexpectedly failed CK validation: ~e"
        witness))
     (define reconstruction (reconstruct-cut-witness witness))
     (define remainder (cut-witness-remainder witness))
     (side-evidence-data
      source
      puncture
      spine-addresses
      frontier
      witness
      (cut-witness-forest witness)
      remainder
      (filter
       (lambda (address) (not (equal? address puncture)))
       (puncture-addresses remainder))
      reconstruction
      (equal? reconstruction source))]))

(define (check-side-evidence-product outer inner)
  (unless (and (checked-term? outer)
               (= (length (premise-telescope outer)) 1))
    (raise-argument-error
     'check-side-evidence-product
     "one-hole outer context"
     outer))
  (unless (and (checked-term? inner)
               (= (length (premise-telescope inner)) 1))
    (raise-argument-error
     'check-side-evidence-product
     "one-hole inner context"
     inner))
  (define composed (compose-one-hole-context outer inner))
  (cond
    [(context-error? composed) composed]
    [else
     (define outer-data (side-evidence-factorization outer))
     (define inner-data (side-evidence-factorization inner))
     (define composed-data (side-evidence-factorization composed))
     (define outer-puncture (side-evidence-data-puncture outer-data))
     (define prefixed-inner
       (for/list ([address
                   (in-list
                    (side-evidence-data-frontier-addresses inner-data))])
         (address-append outer-puncture address)))
     (define expected-frontier
       (sort
        (append (side-evidence-data-frontier-addresses outer-data)
                prefixed-inner)
        address<?))
     (define expected-forest
       (forest-union (side-evidence-data-forest outer-data)
                     (side-evidence-data-forest inner-data)))
     (side-evidence-product-certificate
      outer inner composed outer-data inner-data composed-data
      prefixed-inner expected-forest
      (equal? expected-frontier
              (side-evidence-data-frontier-addresses composed-data))
      (equal? expected-forest
              (side-evidence-data-forest composed-data))
      (and (side-evidence-data-reconstructs? outer-data)
           (side-evidence-data-reconstructs? inner-data)
           (side-evidence-data-reconstructs? composed-data)))]))

(define (relation-edge<? left right)
  (or (< (car left) (car right))
      (and (= (car left) (car right))
           (< (cadr left) (cadr right)))))

(define (canonical-relation edges)
  (sort (remove-duplicates edges equal?) relation-edge<?))

(define (compose-relations left right)
  (canonical-relation
   (for*/list ([left-edge (in-list left)]
               [right-edge (in-list right)]
               #:when (= (cadr left-edge) (car right-edge)))
     (list (car left-edge) (cadr right-edge)))))

(define (trace->endorelation trace)
  (canonical-relation
   (for/list ([edge (in-list (component-trace-edges trace))])
     (list
      (component-occurrence-index
       (addressed-component-component
        (component-trace-edge-source edge)))
      (component-occurrence-index
       (component-trace-edge-target edge))))))

(define (component-recurrence-powers
         source bound #:limit [limit analysis-default-limit])
  (unless (and (checked-node? source)
               (= (length (premise-telescope source)) 1)
               (equal?
                (derivation-root-boundary source)
                (telescope-entry-requirement
                 (car (premise-telescope source)))))
    (raise-argument-error
     'component-recurrence-powers
     "positive one-hole endocontext"
     source))
  (unless (exact-nonnegative-integer? bound)
    (raise-argument-error
     'component-recurrence-powers "exact-nonnegative-integer?" bound))
  (check-limit 'component-recurrence-powers limit)
  (define boundary (derivation-root-boundary source))
  (define component-count (hypersequent-size boundary))
  (define required-work (* bound (expt component-count 3)))
  (cond
    [(and limit (> required-work limit))
     (limit-result
      'component-recurrence-powers limit required-work
      'component-relation-composition-work
      (hash 'power-bound bound 'component-count component-count))]
    [else
     (define trace (component-trace-of source))
     (define scalar-analysis (derivation-scalar-analysis source))
     (define component-analysis-value (component-analysis-of source))
     (define local-distribution
       (for/list
           ([local
             (in-list
              (component-analysis-local-relations
               component-analysis-value))])
         (list
          (local-component-analysis-address local)
          (local-component-analysis-proof-factor-defect local)
          (local-component-analysis-hypersequent-defect local))))
     (define scalar-calibrated?
       (and
        (= (component-scalar-analysis-proof-factor-total
            scalar-analysis)
           0)
        (= (component-scalar-analysis-hypersequent-total
            scalar-analysis)
           0)
        (component-scalar-analysis-proof-factor-euler-holds?
         scalar-analysis)
        (component-scalar-analysis-hypersequent-euler-holds?
         scalar-analysis)))
     (cond
       [(component-trace-unavailable? trace)
        (component-recurrence-analysis
          source trace '() 'component-analysis-unavailable
          #f #f (expt 2 (* component-count component-count)) #f #f
          scalar-analysis scalar-calibrated? local-distribution)]
       [else
         (define identity-relation
          (for/list ([index (in-range 1 (add1 component-count))])
            (list index index)))
        (define base-relation (trace->endorelation trace))
         (define identity-context
           (checked-term-at-address source (car (puncture-addresses source))))
         (define-values (powers repeat-start period)
           (let loop ([power 0]
                      [current identity-relation]
                      [current-context identity-context]
                      [results '()]
                     [seen '()]
                     [found-start #f]
                     [found-period #f])
            (define prior
              (and (not found-start)
                   (for/first ([entry (in-list seen)]
                               #:when (equal? current (cdr entry)))
                     entry)))
             (define direct-trace (component-trace-of current-context))
             (define direct-edges
               (and (component-trace? direct-trace)
                    (trace->endorelation direct-trace)))
             (define agrees? (equal? current direct-edges))
             (define next-results
               (cons
                (component-relation-power
                 power current current-context direct-trace direct-edges agrees?)
                results))
            (define next-start (if prior (car prior) found-start))
            (define next-period
              (if prior (- power (car prior)) found-period))
            (cond
              [(= power bound)
               (values (reverse next-results)
                       next-start
                       next-period)]
              [else
               (loop
                 (add1 power)
                 (compose-relations current base-relation)
                 (let ([next-context
                        (compose-one-hole-context current-context source)])
                   (when (context-error? next-context)
                     (error
                      'component-recurrence-powers
                      "recursive checked context composition failed: ~e"
                      next-context))
                   next-context)
                 next-results
                (append seen (list (cons power current)))
                next-start
                next-period)])))
        (define status
          (cond
            [(not repeat-start) 'no-repeat-observed]
            [(= period 1) 'stabilized]
            [else 'eventually-periodic]))
         (component-recurrence-analysis
          source trace powers status repeat-start period
          (expt 2 (* component-count component-count))
          (>= (add1 bound)
              (add1 (expt 2 (* component-count component-count))))
          (andmap component-relation-power-agrees? powers)
          scalar-analysis scalar-calibrated? local-distribution)])]))
