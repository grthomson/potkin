#lang racket/base

(require racket/list
         racket/vector
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/cut.rkt")

(provide formal-sum?
         formal-sum-calculus
         formal-sum-rank
         make-formal-sum
         formal-zero
         formal-zero?
         formal-one
         formal-sum-support-size
         formal-sum-support
         formal-sum-terms
         formal-sum-coefficient
         rank-one-formal-sum?
         rank-two-formal-sum?
         forest-basis
         checked-node-basis
         algebra-unit
         forest-coefficient
         tensor-zero
         tensor-unit
         pure-tensor
         formal-sum-add
         formal-sum-negate
         formal-sum-subtract
         formal-sum-scale
         formal-sum-multiply
         formal-sum-expand-coordinate
         formal-sum-contract-coordinate
         algebra-error?
         algebra-error-code
         algebra-error-message
         algebra-error-operation
         algebra-error-expected
         algebra-error-actual
         algebra-error-details)

;; A formal sum has one exact operational calculus identity.  Its coefficient
;; hash may use the structural equality of forest presentations only because
;; construction separately verifies that every coordinate carries this exact
;; snapshot.  The hash and its immutable vector keys are never exposed for
;; mutation.
(struct formal-sum (calculus rank support-hash)
  #:constructor-name make-formal-sum/internal
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (formal-sum? right)
          (eq? (formal-sum-calculus left)
               (formal-sum-calculus right))
          (= (formal-sum-rank left)
             (formal-sum-rank right))
          (recur (formal-sum-support-hash left)
                 (formal-sum-support-hash right))))
   (lambda (value recur)
     (bitwise-xor
      (eq-hash-code (formal-sum-calculus value))
      (arithmetic-shift (recur (formal-sum-rank value)) 1)
      (arithmetic-shift (recur (formal-sum-support-hash value)) 2)))
   (lambda (value recur)
     (bitwise-xor
      #x5f356495
      (arithmetic-shift
       (eq-hash-code (formal-sum-calculus value)) 2)
      (arithmetic-shift (recur (formal-sum-rank value)) 3)
      (recur (formal-sum-support-hash value))))))

(struct algebra-error
  (code message operation expected actual details)
  #:transparent)

(define (make-algebra-error code message operation
                            #:expected [expected #f]
                            #:actual [actual #f]
                            #:details [details (hash)])
  (algebra-error code message operation expected actual details))

(define (check-calculus who calculus)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus)))

(define (validate-positive-rank who operation rank)
  (unless (exact-integer? rank)
    (raise-argument-error who "exact-integer?" rank))
  (and (not (positive? rank))
       (make-algebra-error
        'invalid-rank
        "a formal tensor rank must be positive"
        operation
        #:expected 'exact-positive-integer
        #:actual rank)))

(define (immutable-vector-copy value)
  (vector->immutable-vector (vector-copy value)))

(define (validate-key who operation calculus rank key)
  (unless (vector? key)
    (raise-argument-error who "vector?" key))
  (cond
    [(not (= (vector-length key) rank))
     (make-algebra-error
      'rank-mismatch
      "the support key length does not match the formal tensor rank"
      operation
      #:expected rank
      #:actual (vector-length key)
      #:details (hash 'key key))]
    [else
     (define bad-coordinate
       (for/first ([forest (in-vector key)]
                   [coordinate (in-naturals 1)]
                   #:unless (proof-forest? forest))
         (cons coordinate forest)))
     (when bad-coordinate
       (raise-arguments-error
        who
        "every support coordinate must be a proof forest"
        "coordinate" (car bad-coordinate)
        "value" (cdr bad-coordinate)))
     (define foreign-coordinate
       (for/first ([forest (in-vector key)]
                   [coordinate (in-naturals 1)]
                   #:unless (eq? (proof-forest-calculus forest) calculus))
         (cons coordinate forest)))
     (if foreign-coordinate
         (make-algebra-error
          'calculus-mismatch
          "every support coordinate must carry the exact formal-sum calculus snapshot"
          operation
          #:expected calculus
          #:actual (proof-forest-calculus (cdr foreign-coordinate))
          #:details (hash 'coordinate (car foreign-coordinate)
                          'forest (cdr foreign-coordinate)))
         (immutable-vector-copy key))]))

(define (support-add support key coefficient)
  (define combined (+ (hash-ref support key 0) coefficient))
  (if (zero? combined)
      (hash-remove support key)
      (hash-set support key combined)))

(define (zero/internal calculus rank)
  (make-formal-sum/internal calculus rank (hash)))

(define (basis/internal calculus key [coefficient 1])
  (if (zero? coefficient)
      (zero/internal calculus (vector-length key))
      (make-formal-sum/internal
       calculus
       (vector-length key)
       (hash key coefficient))))

(define (make-formal-sum calculus rank summands)
  (check-calculus 'make-formal-sum calculus)
  (define rank-error
    (validate-positive-rank 'make-formal-sum 'make-formal-sum rank))
  (cond
    [rank-error rank-error]
    [else
     (unless (list? summands)
       (raise-argument-error 'make-formal-sum "list?" summands))
     (let loop ([remaining summands] [support (hash)])
       (cond
         [(null? remaining)
          (make-formal-sum/internal calculus rank support)]
         [else
          (define summand (car remaining))
          (unless (and (pair? summand)
                       (vector? (car summand))
                       (exact-integer? (cdr summand)))
            (raise-arguments-error
             'make-formal-sum
             "each summand must be (cons vector-of-forests exact-integer)"
             "summand" summand))
          (define key-or-error
            (validate-key 'make-formal-sum
                          'make-formal-sum
                          calculus
                          rank
                          (car summand)))
          (if (algebra-error? key-or-error)
              key-or-error
              (loop (cdr remaining)
                    (support-add support
                                 key-or-error
                                 (cdr summand))))]))]))

(define (formal-zero calculus [rank 1])
  (check-calculus 'formal-zero calculus)
  (define rank-error
    (validate-positive-rank 'formal-zero 'formal-zero rank))
  (if rank-error rank-error (zero/internal calculus rank)))

(define (formal-zero? value)
  (and (formal-sum? value)
       (zero? (hash-count (formal-sum-support-hash value)))))

(define (unit-key calculus rank)
  (vector->immutable-vector
   (for/vector #:length rank ([coordinate (in-range rank)])
     (empty-proof-forest calculus))))

(define (formal-one calculus [rank 1])
  (check-calculus 'formal-one calculus)
  (define rank-error
    (validate-positive-rank 'formal-one 'formal-one rank))
  (if rank-error
      rank-error
      (basis/internal calculus (unit-key calculus rank))))

(define (formal-sum-support-size sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'formal-sum-support-size "formal-sum?" sum))
  (hash-count (formal-sum-support-hash sum)))

;; Support traversal is normalized but deliberately unordered.  Every key is
;; immutable, and no mutable or immutable coefficient hash is exposed.
(define (formal-sum-support sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'formal-sum-support "formal-sum?" sum))
  (hash-keys (formal-sum-support-hash sum)))

(define (formal-sum-terms sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'formal-sum-terms "formal-sum?" sum))
  (for/list ([(key coefficient)
              (in-hash (formal-sum-support-hash sum))])
    (cons key coefficient)))

(define (coefficient/internal sum key who operation)
  (define key-or-error
    (validate-key who
                  operation
                  (formal-sum-calculus sum)
                  (formal-sum-rank sum)
                  key))
  (if (algebra-error? key-or-error)
      key-or-error
      (hash-ref (formal-sum-support-hash sum) key-or-error 0)))

(define (formal-sum-coefficient sum key)
  (unless (formal-sum? sum)
    (raise-argument-error 'formal-sum-coefficient "formal-sum?" sum))
  (coefficient/internal
   sum key 'formal-sum-coefficient 'formal-sum-coefficient))

(define (rank-one-formal-sum? value)
  (and (formal-sum? value) (= (formal-sum-rank value) 1)))

(define (rank-two-formal-sum? value)
  (and (formal-sum? value) (= (formal-sum-rank value) 2)))

(define (forest-basis forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'forest-basis "proof-forest?" forest))
  (define key (vector->immutable-vector (vector forest)))
  (basis/internal (proof-forest-calculus forest) key))

(define (checked-node-basis node)
  (unless (checked-node? node)
    (raise-argument-error 'checked-node-basis "checked-node?" node))
  (forest-basis
   (make-proof-forest (checked-node-calculus node) (list node))))

(define (algebra-unit calculus)
  (formal-one calculus 1))

(define (forest-coefficient sum forest)
  (unless (formal-sum? sum)
    (raise-argument-error 'forest-coefficient "formal-sum?" sum))
  (unless (proof-forest? forest)
    (raise-argument-error 'forest-coefficient "proof-forest?" forest))
  (cond
    [(not (= (formal-sum-rank sum) 1))
     (make-algebra-error
      'rank-mismatch
      "forest coefficient lookup is defined only at rank one"
      'forest-coefficient
      #:expected 1
      #:actual (formal-sum-rank sum))]
    [else
     (coefficient/internal
      sum (vector forest) 'forest-coefficient 'forest-coefficient)]))

(define (tensor-zero calculus rank)
  (check-calculus 'tensor-zero calculus)
  (define rank-error
    (validate-positive-rank 'tensor-zero 'tensor-zero rank))
  (if rank-error rank-error (zero/internal calculus rank)))

(define (tensor-unit calculus rank)
  (check-calculus 'tensor-unit calculus)
  (define rank-error
    (validate-positive-rank 'tensor-unit 'tensor-unit rank))
  (if rank-error
      rank-error
      (basis/internal calculus (unit-key calculus rank))))

(define (pure-tensor calculus coordinates)
  (check-calculus 'pure-tensor calculus)
  (unless (vector? coordinates)
    (raise-argument-error 'pure-tensor "vector?" coordinates))
  (define rank (vector-length coordinates))
  (define rank-error
    (validate-positive-rank 'pure-tensor 'pure-tensor rank))
  (cond
    [rank-error rank-error]
    [else
     (define key-or-error
       (validate-key 'pure-tensor
                     'pure-tensor
                     calculus
                     rank
                     coordinates))
     (if (algebra-error? key-or-error)
         key-or-error
         (basis/internal calculus key-or-error))]))

(define (compatible-sums-error operation left right)
  (cond
    [(not (eq? (formal-sum-calculus left)
               (formal-sum-calculus right)))
     (make-algebra-error
      'calculus-mismatch
      "formal-sum operations require one exact calculus snapshot"
      operation
      #:expected (formal-sum-calculus left)
      #:actual (formal-sum-calculus right))]
    [(not (= (formal-sum-rank left) (formal-sum-rank right)))
     (make-algebra-error
      'rank-mismatch
      "formal-sum operations require equal tensor ranks"
      operation
      #:expected (formal-sum-rank left)
      #:actual (formal-sum-rank right))]
    [else #f]))

(define (formal-sum-add left right)
  (unless (formal-sum? left)
    (raise-argument-error 'formal-sum-add "formal-sum?" left))
  (unless (formal-sum? right)
    (raise-argument-error 'formal-sum-add "formal-sum?" right))
  (define compatibility-error
    (compatible-sums-error 'formal-sum-add left right))
  (if compatibility-error
      compatibility-error
      (make-formal-sum/internal
       (formal-sum-calculus left)
       (formal-sum-rank left)
       (for/fold ([support (formal-sum-support-hash left)])
                 ([(key coefficient)
                   (in-hash (formal-sum-support-hash right))])
         (support-add support key coefficient)))))

(define (formal-sum-negate sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'formal-sum-negate "formal-sum?" sum))
  (make-formal-sum/internal
   (formal-sum-calculus sum)
   (formal-sum-rank sum)
   (for/fold ([support (hash)])
             ([(key coefficient)
               (in-hash (formal-sum-support-hash sum))])
     (hash-set support key (- coefficient)))))

(define (formal-sum-subtract left right)
  (unless (formal-sum? left)
    (raise-argument-error 'formal-sum-subtract "formal-sum?" left))
  (unless (formal-sum? right)
    (raise-argument-error 'formal-sum-subtract "formal-sum?" right))
  (define compatibility-error
    (compatible-sums-error 'formal-sum-subtract left right))
  (if compatibility-error
      compatibility-error
      (make-formal-sum/internal
       (formal-sum-calculus left)
       (formal-sum-rank left)
       (for/fold ([support (formal-sum-support-hash left)])
                 ([(key coefficient)
                   (in-hash (formal-sum-support-hash right))])
         (support-add support key (- coefficient))))))

(define (formal-sum-scale coefficient sum)
  (unless (exact-integer? coefficient)
    (raise-argument-error 'formal-sum-scale "exact-integer?" coefficient))
  (unless (formal-sum? sum)
    (raise-argument-error 'formal-sum-scale "formal-sum?" sum))
  (cond
    [(zero? coefficient)
     (zero/internal (formal-sum-calculus sum) (formal-sum-rank sum))]
    [else
     (make-formal-sum/internal
      (formal-sum-calculus sum)
      (formal-sum-rank sum)
      (for/fold ([support (hash)])
                ([(key old-coefficient)
                  (in-hash (formal-sum-support-hash sum))])
        (hash-set support key (* coefficient old-coefficient))))]))

(define (coordinatewise-forest-union left-key right-key)
  (vector->immutable-vector
   (for/vector #:length (vector-length left-key)
               ([left-forest (in-vector left-key)]
                [right-forest (in-vector right-key)])
     (forest-union left-forest right-forest))))

(define (formal-sum-multiply left right)
  (unless (formal-sum? left)
    (raise-argument-error 'formal-sum-multiply "formal-sum?" left))
  (unless (formal-sum? right)
    (raise-argument-error 'formal-sum-multiply "formal-sum?" right))
  (define compatibility-error
    (compatible-sums-error 'formal-sum-multiply left right))
  (if compatibility-error
      compatibility-error
      (make-formal-sum/internal
       (formal-sum-calculus left)
       (formal-sum-rank left)
       (for*/fold ([support (hash)])
                  ([(left-key left-coefficient)
                    (in-hash (formal-sum-support-hash left))]
                   [(right-key right-coefficient)
                    (in-hash (formal-sum-support-hash right))])
         (support-add
          support
          (coordinatewise-forest-union left-key right-key)
          (* left-coefficient right-coefficient))))))

(define (validate-coordinate sum coordinate operation)
  (unless (exact-integer? coordinate)
    (raise-argument-error operation "exact-integer?" coordinate))
  (and (not (<= 1 coordinate (formal-sum-rank sum)))
       (make-algebra-error
        'coordinate-out-of-range
        "the coordinate is outside this positive tensor rank"
        operation
        #:expected (list 1 (formal-sum-rank sum))
        #:actual coordinate)))

(define (splice-coordinate original coordinate-zero-based replacement)
  (define original-list (vector->list original))
  (vector->immutable-vector
   (list->vector
    (append (take original-list coordinate-zero-based)
            (vector->list replacement)
            (drop original-list (add1 coordinate-zero-based))))))

(define (remove-coordinate original coordinate-zero-based)
  (define original-list (vector->list original))
  (vector->immutable-vector
   (list->vector
    (append (take original-list coordinate-zero-based)
            (drop original-list (add1 coordinate-zero-based))))))

(define (formal-sum-expand-coordinate sum coordinate replacement-rank mapper)
  (unless (formal-sum? sum)
    (raise-argument-error
     'formal-sum-expand-coordinate "formal-sum?" sum))
  (unless (procedure? mapper)
    (raise-argument-error
     'formal-sum-expand-coordinate "procedure?" mapper))
  (define coordinate-error
    (validate-coordinate sum coordinate 'formal-sum-expand-coordinate))
  (define replacement-rank-error
    (validate-positive-rank 'formal-sum-expand-coordinate
                            'formal-sum-expand-coordinate
                            replacement-rank))
  (cond
    [coordinate-error coordinate-error]
    [replacement-rank-error replacement-rank-error]
    [else
     (define calculus (formal-sum-calculus sum))
     (define output-rank
       (+ (sub1 (formal-sum-rank sum)) replacement-rank))
     (if (formal-zero? sum)
         (zero/internal calculus output-rank)
         (let outer ([source-terms (formal-sum-terms sum)]
                     [support (hash)])
           (cond
             [(null? source-terms)
              (make-formal-sum/internal calculus output-rank support)]
             [else
              (define source-key (caar source-terms))
              (define source-coefficient (cdar source-terms))
              (define mapped
                (mapper (vector-ref source-key (sub1 coordinate))))
              (cond
                [(algebra-error? mapped) mapped]
                [(not (formal-sum? mapped))
                 (make-algebra-error
                  'invalid-coordinate-expansion
                  "the coordinate mapper must return a formal sum"
                  'formal-sum-expand-coordinate
                  #:expected 'formal-sum
                  #:actual mapped
                  #:details (hash 'coordinate coordinate))]
                [(not (eq? (formal-sum-calculus mapped) calculus))
                 (make-algebra-error
                  'calculus-mismatch
                  "coordinate expansion must remain in the exact calculus snapshot"
                  'formal-sum-expand-coordinate
                  #:expected calculus
                  #:actual (formal-sum-calculus mapped)
                  #:details (hash 'coordinate coordinate))]
                [(not (= (formal-sum-rank mapped) replacement-rank))
                 (make-algebra-error
                  'rank-mismatch
                  "the coordinate mapper returned the wrong replacement rank"
                  'formal-sum-expand-coordinate
                  #:expected replacement-rank
                  #:actual (formal-sum-rank mapped)
                  #:details (hash 'coordinate coordinate))]
                [else
                 (define next-support
                   (for/fold ([current support])
                             ([mapped-term
                               (in-list (formal-sum-terms mapped))])
                     (support-add
                      current
                      (splice-coordinate source-key
                                         (sub1 coordinate)
                                         (car mapped-term))
                      (* source-coefficient (cdr mapped-term)))))
                 (outer (cdr source-terms) next-support)])])))]))

(define (formal-sum-contract-coordinate sum coordinate functional)
  (unless (formal-sum? sum)
    (raise-argument-error
     'formal-sum-contract-coordinate "formal-sum?" sum))
  (unless (procedure? functional)
    (raise-argument-error
     'formal-sum-contract-coordinate "procedure?" functional))
  (define rank (formal-sum-rank sum))
  (define contraction-rank-error
    (and (= rank 1)
         (make-algebra-error
          'invalid-rank
          "coordinate contraction cannot create a rank-zero formal sum"
          'formal-sum-contract-coordinate
          #:expected 'rank-at-least-two
          #:actual rank)))
  (define coordinate-error
    (validate-coordinate sum coordinate 'formal-sum-contract-coordinate))
  (cond
    [contraction-rank-error contraction-rank-error]
    [coordinate-error coordinate-error]
    [(formal-zero? sum)
     (zero/internal (formal-sum-calculus sum) (sub1 rank))]
    [else
     (define calculus (formal-sum-calculus sum))
     (let loop ([source-terms (formal-sum-terms sum)]
                [support (hash)])
       (cond
         [(null? source-terms)
          (make-formal-sum/internal calculus (sub1 rank) support)]
         [else
          (define source-key (caar source-terms))
          (define source-coefficient (cdar source-terms))
          (define scalar
            (functional (vector-ref source-key (sub1 coordinate))))
          (cond
            [(algebra-error? scalar) scalar]
            [(not (exact-integer? scalar))
             (make-algebra-error
              'invalid-coordinate-contraction
              "the coordinate functional must return an exact integer"
              'formal-sum-contract-coordinate
              #:expected 'exact-integer
              #:actual scalar
              #:details (hash 'coordinate coordinate))]
            [else
             (loop
              (cdr source-terms)
              (support-add
               support
               (remove-coordinate source-key (sub1 coordinate))
               (* source-coefficient scalar)))])]))]))
