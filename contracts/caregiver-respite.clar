;; Caregiver Respite Services Contract
;; Provides temporary relief for family members caring for elderly relatives

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-INPUT (err u501))
(define-constant ERR-NOT-FOUND (err u502))
(define-constant ERR-ALREADY-EXISTS (err u503))
(define-constant ERR-INSUFFICIENT-FUNDS (err u504))
(define-constant ERR-SERVICE-UNAVAILABLE (err u505))

;; Data Variables
(define-data-var next-caregiver-id uint u1)
(define-data-var next-request-id uint u1)
(define-data-var next-service-id uint u1)

;; Data Maps
(define-map respite-caregivers
  uint
  {
    caregiver: principal,
    name: (string-ascii 100),
    qualifications: (list 10 (string-ascii 100)),
    specialties: (list 10 (string-ascii 50)), ;; "dementia", "mobility", "medical", etc.
    hourly-rate: uint,
    availability: (string-ascii 300),
    service-area: (string-ascii 200),
    background-checked: bool,
    certified: bool,
    rating: uint, ;; 1-5 scale
    total-hours-worked: uint,
    active: bool
  }
)

(define-map respite-requests
  uint
  {
    family-caregiver: principal,
    senior: principal,
    care-needs: (string-ascii 500),
    preferred-caregiver-id: (optional uint),
    start-time: uint,
    duration: uint, ;; in hours
    hourly-budget: uint,
    special-instructions: (string-ascii 300),
    emergency-contacts: (string-ascii 200),
    status: (string-ascii 20), ;; "open", "assigned", "confirmed", "in-progress", "completed", "cancelled"
    urgency: (string-ascii 20) ;; "routine", "urgent", "emergency"
  }
)

(define-map service-assignments
  uint
  {
    request-id: uint,
    caregiver-id: uint,
    assignment-time: uint,
    confirmed-by-caregiver: bool,
    confirmed-by-family: bool,
    actual-start-time: uint,
    actual-end-time: uint,
    total-cost: uint,
    payment-status: (string-ascii 20), ;; "pending", "paid", "disputed"
    service-notes: (string-ascii 500)
  }
)

(define-map caregiver-reviews
  {service-id: uint, reviewer: principal}
  {
    rating: uint, ;; 1-5 scale
    review-text: (string-ascii 300),
    review-date: uint,
    categories: {
      reliability: uint,
      communication: uint,
      care-quality: uint,
      professionalism: uint
    }
  }
)

(define-map family-caregiver-profiles
  principal
  {
    name: (string-ascii 100),
    relationship-to-senior: (string-ascii 50),
    contact-info: (string-ascii 200),
    care-duration: uint, ;; months caring for senior
    stress-level: uint, ;; 1-10 scale
    support-network-size: uint,
    previous-respite-hours: uint
  }
)

(define-map emergency-backup-care
  principal ;; senior
  {
    backup-caregivers: (list 5 uint),
    emergency-plan: (string-ascii 500),
    medical-information: (string-ascii 300),
    authorized-contacts: (list 5 principal),
    last-updated: uint
  }
)

;; Private Functions
(define-private (is-authorized-for-senior (senior principal))
  (or (is-eq tx-sender senior)
      (is-eq tx-sender CONTRACT-OWNER))
)

(define-private (calculate-service-cost (hours uint) (hourly-rate uint))
  (* hours hourly-rate)
)

(define-private (is-caregiver-available (caregiver-id uint) (start-time uint) (duration uint))
  ;; Simplified availability check - real implementation would check schedule conflicts
  true
)

(define-private (matches-care-needs (caregiver-id uint) (care-needs (string-ascii 500)))
  ;; Simplified matching - real implementation would analyze needs vs specialties
  true
)

;; Public Functions

;; Register as respite caregiver
(define-public (register-respite-caregiver
  (name (string-ascii 100))
  (qualifications (list 10 (string-ascii 100)))
  (specialties (list 10 (string-ascii 50)))
  (hourly-rate uint)
  (availability (string-ascii 300))
  (service-area (string-ascii 200)))
  (let ((caregiver-id (var-get next-caregiver-id)))
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> hourly-rate u0) ERR-INVALID-INPUT)

    (map-set respite-caregivers caregiver-id
      {
        caregiver: tx-sender,
        name: name,
        qualifications: qualifications,
        specialties: specialties,
        hourly-rate: hourly-rate,
        availability: availability,
        service-area: service-area,
        background-checked: false,
        certified: false,
        rating: u5,
        total-hours-worked: u0,
        active: true
      })

    (var-set next-caregiver-id (+ caregiver-id u1))
    (ok caregiver-id))
)

;; Create family caregiver profile
(define-public (create-family-profile
  (name (string-ascii 100))
  (relationship-to-senior (string-ascii 50))
  (contact-info (string-ascii 200))
  (care-duration uint)
  (stress-level uint)
  (support-network-size uint))
  (begin
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= stress-level u1) (<= stress-level u10)) ERR-INVALID-INPUT)

    (map-set family-caregiver-profiles tx-sender
      {
        name: name,
        relationship-to-senior: relationship-to-senior,
        contact-info: contact-info,
        care-duration: care-duration,
        stress-level: stress-level,
        support-network-size: support-network-size,
        previous-respite-hours: u0
      })
    (ok true))
)

;; Request respite care
(define-public (request-respite-care
  (senior principal)
  (care-needs (string-ascii 500))
  (preferred-caregiver-id (optional uint))
  (start-time uint)
  (duration uint)
  (hourly-budget uint)
  (special-instructions (string-ascii 300))
  (emergency-contacts (string-ascii 200))
  (urgency (string-ascii 20)))
  (let ((request-id (var-get next-request-id)))
    (asserts! (is-authorized-for-senior senior) ERR-NOT-AUTHORIZED)
    (asserts! (> start-time (unwrap-panic (get-block-info? time (- block-height u1)))) ERR-INVALID-INPUT)
    (asserts! (> duration u0) ERR-INVALID-INPUT)
    (asserts! (> hourly-budget u0) ERR-INVALID-INPUT)
    (asserts! (or (is-eq urgency "routine") (is-eq urgency "urgent") (is-eq urgency "emergency")) ERR-INVALID-INPUT)

    (map-set respite-requests request-id
      {
        family-caregiver: tx-sender,
        senior: senior,
        care-needs: care-needs,
        preferred-caregiver-id: preferred-caregiver-id,
        start-time: start-time,
        duration: duration,
        hourly-budget: hourly-budget,
        special-instructions: special-instructions,
        emergency-contacts: emergency-contacts,
        status: "open",
        urgency: urgency
      })

    (var-set next-request-id (+ request-id u1))
    (ok request-id))
)

;; Accept respite care request
(define-public (accept-care-request (request-id uint))
  (let ((request (unwrap! (map-get? respite-requests request-id) ERR-NOT-FOUND))
        (service-id (var-get next-service-id)))
    (asserts! (is-eq (get status request) "open") ERR-INVALID-INPUT)

    ;; Find caregiver ID for tx-sender
    (let ((caregiver-id u1)) ;; Simplified - would need to lookup actual caregiver ID
      (asserts! (is-caregiver-available caregiver-id (get start-time request) (get duration request)) ERR-SERVICE-UNAVAILABLE)
      (asserts! (matches-care-needs caregiver-id (get care-needs request)) ERR-INVALID-INPUT)

      (map-set service-assignments service-id
        {
          request-id: request-id,
          caregiver-id: caregiver-id,
          assignment-time: (unwrap-panic (get-block-info? time (- block-height u1))),
          confirmed-by-caregiver: true,
          confirmed-by-family: false,
          actual-start-time: u0,
          actual-end-time: u0,
          total-cost: (calculate-service-cost (get duration request) (get hourly-budget request)),
          payment-status: "pending",
          service-notes: ""
        })

      (map-set respite-requests request-id
        (merge request {status: "assigned"}))

      (var-set next-service-id (+ service-id u1))
      (ok service-id)))
)

;; Confirm service assignment (by family)
(define-public (confirm-service-assignment (service-id uint))
  (let ((assignment (unwrap! (map-get? service-assignments service-id) ERR-NOT-FOUND))
        (request (unwrap! (map-get? respite-requests (get request-id assignment)) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get family-caregiver request)) ERR-NOT-AUTHORIZED)
    (asserts! (get confirmed-by-caregiver assignment) ERR-INVALID-INPUT)

    (map-set service-assignments service-id
      (merge assignment {confirmed-by-family: true}))

    (map-set respite-requests (get request-id assignment)
      (merge request {status: "confirmed"}))

    (ok true))
)

;; Start service
(define-public (start-service (service-id uint))
  (let ((assignment (unwrap! (map-get? service-assignments service-id) ERR-NOT-FOUND))
        (request (unwrap! (map-get? respite-requests (get request-id assignment)) ERR-NOT-FOUND)))
    ;; Verify caregiver authorization (simplified)
    (asserts! (and (get confirmed-by-caregiver assignment) (get confirmed-by-family assignment)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) "confirmed") ERR-INVALID-INPUT)

    (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
      (map-set service-assignments service-id
        (merge assignment {actual-start-time: current-time}))

      (map-set respite-requests (get request-id assignment)
        (merge request {status: "in-progress"}))

      (ok true)))
)

;; Complete service
(define-public (complete-service (service-id uint) (service-notes (string-ascii 500)))
  (let ((assignment (unwrap! (map-get? service-assignments service-id) ERR-NOT-FOUND))
        (request (unwrap! (map-get? respite-requests (get request-id assignment)) ERR-NOT-FOUND)))
    ;; Verify caregiver authorization (simplified)
    (asserts! (is-eq (get status request) "in-progress") ERR-INVALID-INPUT)
    (asserts! (> (get actual-start-time assignment) u0) ERR-INVALID-INPUT)

    (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
      (map-set service-assignments service-id
        (merge assignment {
          actual-end-time: current-time,
          service-notes: service-notes
        }))

      (map-set respite-requests (get request-id assignment)
        (merge request {status: "completed"}))

      (ok true)))
)

;; Submit caregiver review
(define-public (submit-caregiver-review
  (service-id uint)
  (rating uint)
  (review-text (string-ascii 300))
  (reliability uint)
  (communication uint)
  (care-quality uint)
  (professionalism uint))
  (let ((assignment (unwrap! (map-get? service-assignments service-id) ERR-NOT-FOUND))
        (request (unwrap! (map-get? respite-requests (get request-id assignment)) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get family-caregiver request)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) "completed") ERR-INVALID-INPUT)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-INPUT)
    (asserts! (and (>= reliability u1) (<= reliability u5)) ERR-INVALID-INPUT)
    (asserts! (and (>= communication u1) (<= communication u5)) ERR-INVALID-INPUT)
    (asserts! (and (>= care-quality u1) (<= care-quality u5)) ERR-INVALID-INPUT)
    (asserts! (and (>= professionalism u1) (<= professionalism u5)) ERR-INVALID-INPUT)

    (map-set caregiver-reviews {service-id: service-id, reviewer: tx-sender}
      {
        rating: rating,
        review-text: review-text,
        review-date: (unwrap-panic (get-block-info? time (- block-height u1))),
        categories: {
          reliability: reliability,
          communication: communication,
          care-quality: care-quality,
          professionalism: professionalism
        }
      })
    (ok true))
)

;; Set up emergency backup care
(define-public (setup-emergency-backup
  (senior principal)
  (backup-caregivers (list 5 uint))
  (emergency-plan (string-ascii 500))
  (medical-information (string-ascii 300))
  (authorized-contacts (list 5 principal)))
  (begin
    (asserts! (is-authorized-for-senior senior) ERR-NOT-AUTHORIZED)
    (asserts! (> (len emergency-plan) u0) ERR-INVALID-INPUT)

    (map-set emergency-backup-care senior
      {
        backup-caregivers: backup-caregivers,
        emergency-plan: emergency-plan,
        medical-information: medical-information,
        authorized-contacts: authorized-contacts,
        last-updated: (unwrap-panic (get-block-info? time (- block-height u1)))
      })
    (ok true))
)

;; Cancel respite request
(define-public (cancel-respite-request (request-id uint) (reason (string-ascii 200)))
  (let ((request (unwrap! (map-get? respite-requests request-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get family-caregiver request)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (get status request) "completed")) ERR-INVALID-INPUT)

    (map-set respite-requests request-id
      (merge request {status: "cancelled"}))
    (ok true))
)

;; Read-only functions

;; Get respite caregiver details
(define-read-only (get-respite-caregiver (caregiver-id uint))
  (map-get? respite-caregivers caregiver-id)
)

;; Get respite request details
(define-read-only (get-respite-request (request-id uint))
  (map-get? respite-requests request-id)
)

;; Get service assignment details
(define-read-only (get-service-assignment (service-id uint))
  (map-get? service-assignments service-id)
)

;; Get family caregiver profile
(define-read-only (get-family-caregiver-profile (family-caregiver principal))
  (map-get? family-caregiver-profiles family-caregiver)
)

;; Get caregiver review
(define-read-only (get-caregiver-review (service-id uint) (reviewer principal))
  (map-get? caregiver-reviews {service-id: service-id, reviewer: reviewer})
)

;; Get emergency backup care plan
(define-read-only (get-emergency-backup-care (senior principal))
  (map-get? emergency-backup-care senior)
)

;; Check if caregiver is available for time slot
(define-read-only (is-caregiver-available-for-slot (caregiver-id uint) (start-time uint) (duration uint))
  (match (map-get? respite-caregivers caregiver-id)
    caregiver (and (get active caregiver)
                   (is-caregiver-available caregiver-id start-time duration))
    false)
)

;; Calculate estimated cost for service
(define-read-only (estimate-service-cost (caregiver-id uint) (duration uint))
  (match (map-get? respite-caregivers caregiver-id)
    caregiver (calculate-service-cost duration (get hourly-rate caregiver))
    u0)
)
