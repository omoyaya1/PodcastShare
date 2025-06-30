;; PodcastShare - Podcast creator revenue sharing and listener engagement platform
(define-data-var platform-manager principal tx-sender)
(define-data-var total-podcast-tokens uint u0)
(define-data-var listener-engagement-rate uint u28) ;; tokens per engagement metric
(define-data-var last-revenue-cycle uint u0)

(define-map creator-earnings principal uint)
(define-map podcast-categories principal (string-utf8 64))
(define-map approved-categories (string-utf8 64) bool)

;; Error codes
(define-constant err-unauthorized-manager (err u2200))
(define-constant err-manager-already-set (err u2201))
(define-constant err-invalid-token-amount (err u2202))
(define-constant err-no-revenue-available (err u2203))
(define-constant err-no-podcast-earnings (err u2204))
(define-constant err-invalid-category (err u2205))
(define-constant err-category-not-approved (err u2206))

;; Verify manager authorization
(define-private (is-platform-manager (caller principal))
  (begin
    (asserts! (is-eq caller (var-get platform-manager)) err-unauthorized-manager)
    (ok true)))

;; Initialize podcast revenue sharing platform
(define-public (launch-podcast-platform (manager principal))
  (begin
    (asserts! (is-none (map-get? creator-earnings manager)) err-manager-already-set)
    (var-set platform-manager manager)
    (ok "PodcastShare revenue sharing platform launched")))

;; Approve podcast category for monetization
(define-public (approve-podcast-category (category (string-utf8 64)))
  (begin
    (try! (is-platform-manager tx-sender))
    (asserts! (> (len category) u0) err-invalid-category)
    (map-set approved-categories category true)
    (ok "Podcast category approved for monetization")))

;; Register podcast content creation
(define-public (publish-podcast-content (tokens uint) (category (string-utf8 64)))
  (begin
    (asserts! (> tokens u0) err-invalid-token-amount)
    (asserts! (default-to false (map-get? approved-categories category)) err-category-not-approved)
    
    (let ((current-earnings (default-to u0 (map-get? creator-earnings tx-sender))))
      (map-set creator-earnings tx-sender (+ current-earnings tokens))
      (map-set podcast-categories tx-sender category)
      (var-set total-podcast-tokens (+ (var-get total-podcast-tokens) tokens))
      (ok (+ current-earnings tokens)))))

;; Calculate listener engagement rewards
(define-public (calculate-engagement-rewards)
  (begin
    (try! (is-platform-manager tx-sender))
    (let ((current-cycle (+ (var-get last-revenue-cycle) u1))
          (total-tokens (var-get total-podcast-tokens)))
      (asserts! (> total-tokens (var-get last-revenue-cycle)) err-no-revenue-available)
      
      (let ((engagement-reward-pool (* (var-get listener-engagement-rate) total-tokens)))
        (var-set last-revenue-cycle current-cycle)
        (ok engagement-reward-pool)))))

;; Claim podcast monetization rewards
(define-public (claim-podcast-revenue)
  (begin
    (let ((creator-token-earnings (default-to u0 (map-get? creator-earnings tx-sender))))
      (asserts! (> creator-token-earnings u0) err-no-podcast-earnings)
      
      (let ((total-tokens (var-get total-podcast-tokens))
            (base-engagement-rewards (* (var-get listener-engagement-rate) creator-token-earnings))
            (earnings-ratio (/ (* creator-token-earnings u100000) total-tokens)))
        
        (let ((final-revenue (/ (* earnings-ratio base-engagement-rewards) u100000)))
          (map-delete creator-earnings tx-sender)
          (map-delete podcast-categories tx-sender)
          (var-set total-podcast-tokens (- (var-get total-podcast-tokens) creator-token-earnings))
          (ok (+ creator-token-earnings final-revenue)))))))

;; Read-only functions
(define-read-only (get-creator-earnings (creator principal))
  (default-to u0 (map-get? creator-earnings creator)))

(define-read-only (get-podcast-category (creator principal))
  (map-get? podcast-categories creator))

(define-read-only (get-total-podcast-tokens)
  (var-get total-podcast-tokens))

(define-read-only (is-category-approved (category (string-utf8 64)))
  (default-to false (map-get? approved-categories category)))