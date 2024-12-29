;; YieldHive Contract
;; Yield farming and staking platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-enough-balance (err u101))
(define-constant err-pool-not-found (err u102))
(define-constant err-pool-inactive (err u103))

;; Data vars
(define-data-var total-staked uint u0)
(define-data-var reward-rate uint u100) ;; Base points (1% = 100)

;; Data maps
(define-map pools
    uint
    {
        token-address: principal,
        total-staked: uint,
        reward-rate: uint,
        active: bool
    }
)

(define-map staker-positions
    {user: principal, pool-id: uint}
    {
        amount: uint,
        rewards: uint,
        last-update: uint
    }
)

;; Public functions
(define-public (create-pool (pool-id uint) (token principal) (rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set pools pool-id
            {
                token-address: token,
                total-staked: u0,
                reward-rate: rate,
                active: true
            }
        )
        (ok true)
    )
)

(define-public (stake (pool-id uint) (amount uint))
    (let (
        (pool (unwrap! (map-get? pools pool-id) err-pool-not-found))
        (token (get token-address pool))
        (position (default-to
            {amount: u0, rewards: u0, last-update: block-height}
            (map-get? staker-positions {user: tx-sender, pool-id: pool-id})
        ))
    )
    (asserts! (get active pool) err-pool-inactive)
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender)))
    (update-rewards tx-sender pool-id)
    (map-set staker-positions
        {user: tx-sender, pool-id: pool-id}
        {
            amount: (+ (get amount position) amount),
            rewards: (get rewards position),
            last-update: block-height
        }
    )
    (ok true))
)

(define-public (unstake (pool-id uint) (amount uint))
    (let (
        (pool (unwrap! (map-get? pools pool-id) err-pool-not-found))
        (token (get token-address pool))
        (position (unwrap! (map-get? staker-positions {user: tx-sender, pool-id: pool-id})
            err-not-enough-balance))
    )
    (asserts! (<= amount (get amount position)) err-not-enough-balance)
    (update-rewards tx-sender pool-id)
    (try! (as-contract (contract-call? token transfer amount (as-contract tx-sender) tx-sender)))
    (map-set staker-positions
        {user: tx-sender, pool-id: pool-id}
        {
            amount: (- (get amount position) amount),
            rewards: (get rewards position),
            last-update: block-height
        }
    )
    (ok true))
)

(define-public (claim-rewards (pool-id uint))
    (let (
        (position (unwrap! (map-get? staker-positions {user: tx-sender, pool-id: pool-id})
            err-not-enough-balance))
    )
    (update-rewards tx-sender pool-id)
    (map-set staker-positions
        {user: tx-sender, pool-id: pool-id}
        {
            amount: (get amount position),
            rewards: u0,
            last-update: block-height
        }
    )
    (ok true))
)

;; Private functions
(define-private (update-rewards (user principal) (pool-id uint))
    (let (
        (pool (unwrap-panic (map-get? pools pool-id)))
        (position (unwrap-panic (map-get? staker-positions {user: user, pool-id: pool-id})))
        (blocks-passed (- block-height (get last-update position)))
        (reward-amount (* blocks-passed (get reward-rate pool)))
    )
    (map-set staker-positions
        {user: user, pool-id: pool-id}
        {
            amount: (get amount position),
            rewards: (+ (get rewards position) reward-amount),
            last-update: block-height
        }
    )
    true)
)

;; Read only functions
(define-read-only (get-pool-info (pool-id uint))
    (map-get? pools pool-id)
)

(define-read-only (get-position (user principal) (pool-id uint))
    (map-get? staker-positions {user: user, pool-id: pool-id})
)