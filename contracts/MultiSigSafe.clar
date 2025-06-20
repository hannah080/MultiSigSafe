(define-constant max-owners u5)

;; Owners list (max 5), initialized with tx-sender
(define-data-var owners (list 5 principal) (list tx-sender))

;; Proposal structure: id -> recipient, amount, approvals (owners who approved)
(define-map proposals
  {id: uint}
  {
    recipient: principal,
    amount: uint,
    approvals: (list 5 principal),
    executed: bool
  }
)

;; Generate new proposal ID counter
(define-data-var proposal-counter uint u0)

;; Error codes
(define-constant ERR_NOT_OWNER (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_APPROVED (err u102))
(define-constant ERR_MAX_APPROVALS (err u103))
(define-constant ERR_PROPOSAL_EXECUTED (err u104))
(define-constant ERR_NOT_ENOUGH_APPROVALS (err u105))
(define-constant ERR_OWNER_EXISTS (err u106))
(define-constant ERR_OWNER_LIMIT (err u107))
(define-constant ERR_OWNER_NOT_FOUND (err u108))

;; Helper: check if sender is an owner
(define-private (is-owner (sender principal))
  (is-some (index-of (var-get owners) sender))
)

;; Add a new owner (only existing owners can add)
(define-public (add-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_NOT_OWNER)
    (let ((owners-list (var-get owners)))
      (asserts! (not (is-some (index-of owners-list new-owner))) ERR_OWNER_EXISTS)
      (let ((new-list (match (as-max-len? (concat owners-list (list new-owner)) u5)
                        value value
                        owners-list)))
        (asserts! (is-eq (len new-list) (+ (len owners-list) u1)) ERR_OWNER_LIMIT)
        (var-set owners new-list)
        (ok true)
      )
    )
  )
)

;; Remove an owner (only existing owners)
(define-public (remove-owner (owner-to-remove principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_NOT_OWNER)
    (let ((owners-list (var-get owners)))
      (asserts! (is-some (index-of owners-list owner-to-remove)) ERR_OWNER_NOT_FOUND)
      (var-set owners (filter not-equal-to-remove owners-list))
      (ok true)
    )
  )
)

(define-private (not-equal-to-remove (entry principal))
  (not (is-eq entry (var-get remove-owner-target)))
)

(define-data-var remove-owner-target principal tx-sender)


;; Propose a new transfer
(define-public (propose-transfer (recipient principal) (amount uint))
  (begin
    (asserts! (is-owner tx-sender) ERR_NOT_OWNER)
    (let ((proposal-id (+ (var-get proposal-counter) u1)))
      (map-set proposals
        {id: proposal-id}
        {
          recipient: recipient,
          amount: amount,
          approvals: (list),
          executed: false
        })
      (var-set proposal-counter proposal-id)
      (ok proposal-id)
    )
  )
)

;; Approve a proposal
(define-public (approve-proposal (id uint))
  (let ((owners-list (var-get owners)))
    (asserts! (is-owner tx-sender) ERR_NOT_OWNER)
    (match (map-get? proposals {id: id})
      proposal
      (begin
        (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXECUTED)
        (let ((approvals (get approvals proposal)))
          (asserts! (>= (len approvals) (+ (/ (len owners-list) u2) (if (is-eq (mod (len owners-list) u2) u0) u0 u1))) ERR_NOT_ENOUGH_APPROVALS)
          ;; Execute proposal (simulate STX transfer)
          (map-set proposals {id: id}
            {
              recipient: (get recipient proposal),
              amount: (get amount proposal),
              approvals: approvals,
              executed: true
            }
          )
          (ok true)
        )
      )
      ERR_PROPOSAL_NOT_FOUND
    )
  )
)


;; Execute proposal if majority approved (3 out of 5)
(define-public (execute-transfer (id uint))
  (let ((owners-list (var-get owners)))
    (asserts! (is-owner tx-sender) ERR_NOT_OWNER)
    (match (map-get? proposals {id: id})
      proposal
      (begin
        (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXECUTED)
        (let ((approvals (get approvals proposal)))
          (asserts! (>= (len approvals) (+ (/ (len owners-list) u2) (if (is-eq (mod (len owners-list) u2) u0) u0 u1))) ERR_NOT_ENOUGH_APPROVALS)
          ;; Here you would normally transfer STX to recipient, 
          ;; but Clarity contracts can only send STX via contract calls, 
          ;; so this is a placeholder for actual transfer logic
          ;; (contract-call? ...) or (stx-transfer?)
          ;; For now, we just mark executed true
          (map-set proposals {id: id} 
            {
              recipient: (get recipient proposal),
              amount: (get amount proposal),
              approvals: approvals,
              executed: true
            }
          )
          (ok "Transfer executed")
        )
      )
      ERR_PROPOSAL_NOT_FOUND)
  )
)

;; Get owners list
(define-read-only (get-owners)
  (ok (var-get owners))
)

;; Get proposal details by id
(define-read-only (get-proposal (id uint))
  (match (map-get? proposals {id: id})
    proposal (ok proposal)
    ERR_PROPOSAL_NOT_FOUND)
)

;; Get number of proposals created so far
(define-read-only (get-proposal-count)
  (ok (var-get proposal-counter))
)
