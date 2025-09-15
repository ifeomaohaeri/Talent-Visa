;; Global Talent Visa System Smart Contract

;; Error constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INVALID-VISA-TYPE (err u101))
(define-constant ERR-VISA-ALREADY-EXISTS (err u102))
(define-constant ERR-VISA-NOT-FOUND (err u103))
(define-constant ERR-VISA-EXPIRED (err u104))
(define-constant ERR-INVALID-STATUS (err u105))
(define-constant ERR-INSUFFICIENT-SCORE (err u106))
(define-constant ERR-INVALID-DURATION (err u107))
(define-constant ERR-INVALID-APPLICANT (err u108))
(define-constant ERR-VISA-ALREADY-APPROVED (err u109))
(define-constant ERR-VISA-ALREADY-REJECTED (err u110))
(define-constant ERR-INVALID-COUNTRY-CODE (err u111))
(define-constant ERR-INVALID-TALENT-CATEGORY (err u112))
(define-constant ERR-ENDORSEMENT-REQUIRED (err u113))
(define-constant ERR-MAINTENANCE-MODE (err u114))
(define-constant ERR-INVALID-PRINCIPAL (err u115))
(define-constant ERR-INVALID-LIMIT (err u116))

;; Validation constants
(define-constant MIN-TALENT-SCORE u70)
(define-constant MAX-VISA-DURATION u1095)
(define-constant MIN-VISA-DURATION u90)
(define-constant MAX-COUNTRY-CODE-LENGTH u3)
(define-constant MIN-COUNTRY-CODE-LENGTH u2)
(define-constant MAX-ENDORSEMENT-COUNT u10)
(define-constant MAX-COUNTRY-QUOTA-LIMIT u10000)

;; Status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-APPROVED u1)
(define-constant STATUS-REJECTED u2)
(define-constant STATUS-EXPIRED u3)
(define-constant STATUS-REVOKED u4)

;; Talent category constants
(define-constant CATEGORY-TECHNOLOGY u0)
(define-constant CATEGORY-SCIENCE u1)
(define-constant CATEGORY-ARTS u2)
(define-constant CATEGORY-BUSINESS u3)
(define-constant CATEGORY-SPORTS u4)
(define-constant CATEGORY-ACADEMIA u5)

;; Contract owner
(define-data-var contract-owner principal tx-sender)
(define-data-var maintenance-mode bool false)
(define-data-var total-visas-issued uint u0)

;; Authorized officers map
(define-map authorized-officers principal bool)

;; Visa applications map
(define-map visa-applications
  { applicant: principal, application-id: uint }
  {
    country-code: (string-ascii 3),
    talent-category: uint,
    talent-score: uint,
    duration-days: uint,
    status: uint,
    applied-at: uint,
    processed-at: (optional uint),
    expires-at: (optional uint),
    processing-officer: (optional principal),
    endorsements: (list 10 principal),
    rejection-reason: (optional (string-ascii 500))
  }
)

;; Application counter
(define-data-var next-application-id uint u1)

;; Country quotas
(define-map country-quotas (string-ascii 3) { limit: uint, used: uint })

;; Endorser registry
(define-map authorized-endorsers principal { category: uint, active: bool })

;; Application history
(define-map application-history
  { applicant: principal }
  { 
    total-applications: uint,
    approved-count: uint,
    rejected-count: uint,
    last-application: (optional uint)
  }
)

;; Read-only functions

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (is-authorized-officer (officer principal))
  (default-to false (map-get? authorized-officers officer))
)

(define-read-only (is-maintenance-mode)
  (var-get maintenance-mode)
)

(define-read-only (get-total-visas-issued)
  (var-get total-visas-issued)
)

(define-read-only (get-visa-application (applicant principal) (application-id uint))
  (map-get? visa-applications { applicant: applicant, application-id: application-id })
)

(define-read-only (get-country-quota (country-code (string-ascii 3)))
  (map-get? country-quotas country-code)
)

(define-read-only (is-authorized-endorser (endorser principal))
  (match (map-get? authorized-endorsers endorser)
    endorser-data (get active endorser-data)
    false
  )
)

(define-read-only (get-endorser-category (endorser principal))
  (match (map-get? authorized-endorsers endorser)
    endorser-data 
      (if (get active endorser-data)
        (some (get category endorser-data))
        none
      )
    none
  )
)

(define-read-only (get-application-history (applicant principal))
  (default-to 
    { total-applications: u0, approved-count: u0, rejected-count: u0, last-application: none }
    (map-get? application-history { applicant: applicant })
  )
)

(define-read-only (is-valid-talent-category (category uint))
  (or 
    (is-eq category CATEGORY-TECHNOLOGY)
    (or 
      (is-eq category CATEGORY-SCIENCE)
      (or 
        (is-eq category CATEGORY-ARTS)
        (or 
          (is-eq category CATEGORY-BUSINESS)
          (or 
            (is-eq category CATEGORY-SPORTS)
            (is-eq category CATEGORY-ACADEMIA)
          )
        )
      )
    )
  )
)

(define-read-only (is-valid-country-code (country-code (string-ascii 3)))
  (let ((code-length (len country-code)))
    (and 
      (>= code-length MIN-COUNTRY-CODE-LENGTH)
      (<= code-length MAX-COUNTRY-CODE-LENGTH)
    )
  )
)

(define-read-only (calculate-processing-time (talent-score uint) (category uint))
  (let ((base-time u7))
    (if (>= talent-score u90)
      base-time
      (if (>= talent-score u80)
        (+ base-time u7)
        (+ base-time u14)
      )
    )
  )
)

;; Private functions

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (validate-visa-duration (duration uint))
  (and 
    (>= duration MIN-VISA-DURATION)
    (<= duration MAX-VISA-DURATION)
  )
)

(define-private (is-valid-principal (principal-to-check principal))
  (not (is-eq principal-to-check (as-contract tx-sender)))
)

(define-private (is-valid-quota-limit (limit uint))
  (and 
    (> limit u0)
    (<= limit MAX-COUNTRY-QUOTA-LIMIT)
  )
)

(define-private (update-application-history (applicant principal) (status uint))
  (let (
    (current-history (default-to 
      { total-applications: u0, approved-count: u0, rejected-count: u0, last-application: none }
      (map-get? application-history { applicant: applicant })))
    (new-total (+ (get total-applications current-history) u1))
    (new-approved (if (is-eq status STATUS-APPROVED) 
                    (+ (get approved-count current-history) u1)
                    (get approved-count current-history)))
    (new-rejected (if (is-eq status STATUS-REJECTED)
                    (+ (get rejected-count current-history) u1)
                    (get rejected-count current-history)))
  )
    (map-set application-history
      { applicant: applicant }
      {
        total-applications: new-total,
        approved-count: new-approved,
        rejected-count: new-rejected,
        last-application: (some (var-get next-application-id))
      }
    )
  )
)

(define-private (update-country-quota (country-code (string-ascii 3)))
  (match (map-get? country-quotas country-code)
    quota-data
      (let ((new-used (+ (get used quota-data) u1)))
        (map-set country-quotas country-code
          { limit: (get limit quota-data), used: new-used }
        )
      )
    true
  )
)

(define-private (has-quota-available (country-code (string-ascii 3)))
  (match (map-get? country-quotas country-code)
    quota-data (< (get used quota-data) (get limit quota-data))
    true
  )
)

(define-private (validate-endorsement (endorser principal) (prev-result (response bool uint)))
  (match prev-result
    success (if (is-authorized-endorser endorser)
              (ok true)
              ERR-UNAUTHORIZED-ACCESS)
    error (err error)
  )
)

;; Public functions

(define-public (set-authorized-officer (officer principal) (authorized bool))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (var-get maintenance-mode)) ERR-MAINTENANCE-MODE)
    (asserts! (is-valid-principal officer) ERR-INVALID-PRINCIPAL)
    (asserts! (not (is-eq officer (var-get contract-owner))) ERR-INVALID-PRINCIPAL)
    (ok (map-set authorized-officers officer authorized))
  )
)

(define-public (set-maintenance-mode (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (ok (var-set maintenance-mode enabled))
  )
)

(define-public (set-country-quota (country-code (string-ascii 3)) (limit uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (var-get maintenance-mode)) ERR-MAINTENANCE-MODE)
    (asserts! (is-valid-country-code country-code) ERR-INVALID-COUNTRY-CODE)
    (asserts! (is-valid-quota-limit limit) ERR-INVALID-LIMIT)
    (let ((current-quota (default-to { limit: u0, used: u0 } (map-get? country-quotas country-code))))
      (ok (map-set country-quotas country-code
        { limit: limit, used: (get used current-quota) }
      ))
    )
  )
)

(define-public (set-authorized-endorser (endorser principal) (category uint) (active bool))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (var-get maintenance-mode)) ERR-MAINTENANCE-MODE)
    (asserts! (is-valid-talent-category category) ERR-INVALID-TALENT-CATEGORY)
    (asserts! (is-valid-principal endorser) ERR-INVALID-PRINCIPAL)
    (asserts! (not (is-eq endorser (var-get contract-owner))) ERR-INVALID-PRINCIPAL)
    (ok (map-set authorized-endorsers endorser { category: category, active: active }))
  )
)

(define-public (apply-for-visa 
  (country-code (string-ascii 3))
  (talent-category uint)
  (talent-score uint)
  (duration-days uint)
  (endorsements (list 10 principal))
)
  (let (
    (application-id (var-get next-application-id))
    (current-height stacks-block-height)
  )
    (asserts! (not (var-get maintenance-mode)) ERR-MAINTENANCE-MODE)
    (asserts! (is-valid-country-code country-code) ERR-INVALID-COUNTRY-CODE)
    (asserts! (is-valid-talent-category talent-category) ERR-INVALID-TALENT-CATEGORY)
    (asserts! (>= talent-score MIN-TALENT-SCORE) ERR-INSUFFICIENT-SCORE)
    (asserts! (validate-visa-duration duration-days) ERR-INVALID-DURATION)
    (asserts! (<= (len endorsements) MAX-ENDORSEMENT-COUNT) ERR-ENDORSEMENT-REQUIRED)
    (asserts! (has-quota-available country-code) ERR-INVALID-COUNTRY-CODE)
    (asserts! (is-none (map-get? visa-applications 
      { applicant: tx-sender, application-id: application-id })) ERR-VISA-ALREADY-EXISTS)
    
    (try! (fold validate-endorsement endorsements (ok true)))
    
    (map-set visa-applications
      { applicant: tx-sender, application-id: application-id }
      {
        country-code: country-code,
        talent-category: talent-category,
        talent-score: talent-score,
        duration-days: duration-days,
        status: STATUS-PENDING,
        applied-at: current-height,
        processed-at: none,
        expires-at: none,
        processing-officer: none,
        endorsements: endorsements,
        rejection-reason: none
      }
    )
    
    (update-application-history tx-sender STATUS-PENDING)
    (var-set next-application-id (+ application-id u1))
    (ok application-id)
  )
)

(define-public (process-visa-application 
  (applicant principal) 
  (application-id uint) 
  (approve bool)
  (rejection-reason (optional (string-ascii 500)))
)
  (let (
    (application-key { applicant: applicant, application-id: application-id })
    (current-height stacks-block-height)
  )
    (asserts! (is-authorized-officer tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (var-get maintenance-mode)) ERR-MAINTENANCE-MODE)
    (asserts! (is-valid-principal applicant) ERR-INVALID-PRINCIPAL)
    
    (match (map-get? visa-applications application-key)
      application-data
        (begin
          (asserts! (is-eq (get status application-data) STATUS-PENDING) ERR-INVALID-STATUS)
          
          (let (
            (new-status (if approve STATUS-APPROVED STATUS-REJECTED))
            (expires-at (if approve 
                         (some (+ current-height (get duration-days application-data)))
                         none))
          )
            (map-set visa-applications application-key
              (merge application-data {
                status: new-status,
                processed-at: (some current-height),
                expires-at: expires-at,
                processing-officer: (some tx-sender),
                rejection-reason: (if approve none rejection-reason)
              })
            )
            
            (update-application-history applicant new-status)
            
            (if approve
              (begin
                (update-country-quota (get country-code application-data))
                (var-set total-visas-issued (+ (var-get total-visas-issued) u1))
              )
              true
            )
            
            (ok approve)
          )
        )
      ERR-VISA-NOT-FOUND
    )
  )
)

(define-public (revoke-visa (applicant principal) (application-id uint))
  (let ((application-key { applicant: applicant, application-id: application-id }))
    (asserts! (is-authorized-officer tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (var-get maintenance-mode)) ERR-MAINTENANCE-MODE)
    (asserts! (is-valid-principal applicant) ERR-INVALID-PRINCIPAL)
    
    (match (map-get? visa-applications application-key)
      application-data
        (begin
          (asserts! (is-eq (get status application-data) STATUS-APPROVED) ERR-INVALID-STATUS)
          (map-set visa-applications application-key
            (merge application-data { status: STATUS-REVOKED })
          )
          (ok true)
        )
      ERR-VISA-NOT-FOUND
    )
  )
)

(define-public (check-visa-validity (applicant principal) (application-id uint))
  (let ((application-key { applicant: applicant, application-id: application-id }))
    (asserts! (is-valid-principal applicant) ERR-INVALID-PRINCIPAL)
    (match (map-get? visa-applications application-key)
      application-data
        (let ((current-height stacks-block-height))
          (if (is-eq (get status application-data) STATUS-APPROVED)
            (match (get expires-at application-data)
              expiry-height
                (if (<= current-height expiry-height)
                  (ok true)
                  (begin
                    (map-set visa-applications application-key
                      (merge application-data { status: STATUS-EXPIRED })
                    )
                    ERR-VISA-EXPIRED
                  )
                )
              ERR-VISA-NOT-FOUND
            )
            ERR-INVALID-STATUS
          )
        )
      ERR-VISA-NOT-FOUND
    )
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR-INVALID-APPLICANT)
    (asserts! (is-valid-principal new-owner) ERR-INVALID-PRINCIPAL)
    (ok (var-set contract-owner new-owner))
  )
)