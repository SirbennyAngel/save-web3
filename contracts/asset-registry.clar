;; asset-registry
;; This contract serves as the central hub for the save-web3 platform, maintaining a comprehensive
;; registry of decentralized assets that can operate across different web3 environments. It stores 
;; essential metadata about each asset, including its origin platform, trait categories, capability 
;; definitions, and conversion rules for cross-platform asset representation.

;; =================================
;; Error Constants
;; =================================

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-GAME-ALREADY-REGISTERED (err u101))
(define-constant ERR-GAME-NOT-FOUND (err u102))
(define-constant ERR-NFT-ALREADY-REGISTERED (err u103))
(define-constant ERR-NFT-NOT-FOUND (err u104))
(define-constant ERR-TRAIT-CATEGORY-NOT-FOUND (err u105))
(define-constant ERR-CAPABILITY-NOT-FOUND (err u106))
(define-constant ERR-CONVERSION-RULE-EXISTS (err u107))
(define-constant ERR-CONVERSION-RULE-NOT-FOUND (err u108))
(define-constant ERR-INVALID-ROYALTY-PERCENTAGE (err u109))
(define-constant ERR-INVALID-PARAMETERS (err u110))
(define-constant ERR-CAPABILITY-ALREADY-EXISTS (err u111))
(define-constant ERR-TRAIT-CATEGORY-ALREADY-EXISTS (err u112))

;; =================================
;; Data Structures
;; =================================

;; Contract administrator
(define-data-var contract-owner principal tx-sender)

;; Game registry
;; Stores information about registered games
(define-map games
  { game-id: (string-ascii 50) }
  {
    name: (string-ascii 100),
    developer: principal,
    website-url: (optional (string-ascii 255)),
    description: (string-utf8 500),
    registered-at: uint,
    active: bool
  }
)

;; Game IDs for quick lookup
(define-map game-ids-by-developer
  { developer: principal }
  { game-ids: (list 20 (string-ascii 50)) }
)

;; NFT registry
;; Stores core information about registered NFT assets
(define-map nfts
  { nft-id: (string-ascii 50) }
  {
    name: (string-ascii 100),
    origin-game-id: (string-ascii 50),
    creator: principal,
    creation-block: uint,
    metadata-url: (string-ascii 255),
    royalty-percentage: uint,  ;; in basis points (e.g., 250 = 2.5%)
    active: bool
  }
)

;; Trait categories for NFTs
;; These define the types of attributes an NFT can have
(define-map trait-categories
  { category-id: (string-ascii 50) }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    created-by: principal,
    created-at: uint
  }
)

;; NFT traits mapping
;; Links NFTs to their trait values across categories
(define-map nft-traits
  { nft-id: (string-ascii 50), category-id: (string-ascii 50) }
  {
    value: (string-utf8 255)
  }
)

;; Capability definitions
;; These define what an NFT can do within game environments
(define-map capabilities
  { capability-id: (string-ascii 50) }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    created-by: principal,
    created-at: uint
  }
)

;; NFT capabilities mapping
;; Links NFTs to their capabilities
(define-map nft-capabilities
  { nft-id: (string-ascii 50), capability-id: (string-ascii 50) }
  {
    enabled: bool,
    properties: (optional (string-utf8 1000))  ;; JSON-formatted additional properties
  }
)

;; Conversion rules
;; Define how NFTs translate between different games
(define-map conversion-rules
  { nft-id: (string-ascii 50), source-game-id: (string-ascii 50), target-game-id: (string-ascii 50) }
  {
    display-name: (string-ascii 100),
    asset-url: (string-ascii 255), 
    properties: (string-utf8 1000),   ;; JSON-formatted representation of game-specific properties
    created-by: principal,
    created-at: uint,
    last-updated-at: uint
  }
)

;; =================================
;; Private Functions
;; =================================

;; Checks if the caller is the contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Checks if the caller is the developer of a specific game
(define-private (is-game-developer (game-id (string-ascii 50)))
  (match (map-get? games { game-id: game-id })
    game (is-eq tx-sender (get developer game))
    false
  )
)

;; Checks if the caller is either the contract owner or the game developer
(define-private (is-authorized-for-game (game-id (string-ascii 50)))
  (or (is-contract-owner) (is-game-developer game-id))
)

;; Checks if the caller is the creator of an NFT
(define-private (is-nft-creator (nft-id (string-ascii 50)))
  (match (map-get? nfts { nft-id: nft-id })
    nft (is-eq tx-sender (get creator nft))
    false
  )
)

;; Checks if the caller is authorized to modify an NFT (contract owner or NFT creator)
(define-private (is-authorized-for-nft (nft-id (string-ascii 50)))
  (or (is-contract-owner) (is-nft-creator nft-id))
)

;; Adds a game ID to the developer's list
(define-private (add-game-id-for-developer (developer principal) (game-id (string-ascii 50)))
  (match (map-get? game-ids-by-developer { developer: developer })
    existing-data (map-set game-ids-by-developer 
                    { developer: developer }
                    { game-ids: (unwrap-panic (as-max-len? (append (get game-ids existing-data) game-id) u20)) })
    (map-set game-ids-by-developer 
              { developer: developer }
              { game-ids: (list game-id) })
  )
)

;; =================================
;; Read-Only Functions
;; =================================

;; Get game details
(define-read-only (get-game (game-id (string-ascii 50)))
  (map-get? games { game-id: game-id })
)

;; Get games by developer
(define-read-only (get-games-by-developer (developer principal))
  (match (map-get? game-ids-by-developer { developer: developer })
    game-data (get game-ids game-data)
    (list)
  )
)

;; Get NFT details
(define-read-only (get-nft (nft-id (string-ascii 50)))
  (map-get? nfts { nft-id: nft-id })
)

;; Get trait category details
(define-read-only (get-trait-category (category-id (string-ascii 50)))
  (map-get? trait-categories { category-id: category-id })
)

;; Get NFT trait value
(define-read-only (get-nft-trait (nft-id (string-ascii 50)) (category-id (string-ascii 50)))
  (map-get? nft-traits { nft-id: nft-id, category-id: category-id })
)

;; Get capability details
(define-read-only (get-capability (capability-id (string-ascii 50)))
  (map-get? capabilities { capability-id: capability-id })
)

;; Get NFT capability
(define-read-only (get-nft-capability (nft-id (string-ascii 50)) (capability-id (string-ascii 50)))
  (map-get? nft-capabilities { nft-id: nft-id, capability-id: capability-id })
)

;; Get conversion rule
(define-read-only (get-conversion-rule (nft-id (string-ascii 50)) (source-game-id (string-ascii 50)) (target-game-id (string-ascii 50)))
  (map-get? conversion-rules { nft-id: nft-id, source-game-id: source-game-id, target-game-id: target-game-id })
)

;; Check if an NFT is compatible with a specific game
(define-read-only (is-nft-compatible-with-game (nft-id (string-ascii 50)) (game-id (string-ascii 50)))
  (match (map-get? nfts { nft-id: nft-id })
    nft-data (if (is-eq (get origin-game-id nft-data) game-id)
              true
              (is-some (map-get? conversion-rules { 
                nft-id: nft-id, 
                source-game-id: (get origin-game-id nft-data), 
                target-game-id: game-id 
              })))
    false
  )
)

;; =================================
;; Public Functions
;; =================================

;; Set a new contract owner
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)

;; Register a new game
(define-public (register-game 
  (game-id (string-ascii 50)) 
  (name (string-ascii 100)) 
  (website-url (optional (string-ascii 255))) 
  (description (string-utf8 500)))
  (begin
    ;; Check if game already exists
    (asserts! (is-none (map-get? games { game-id: game-id })) ERR-GAME-ALREADY-REGISTERED)
    
    ;; Register the game
    (map-set games 
      { game-id: game-id }
      {
        name: name,
        developer: tx-sender,
        website-url: website-url,
        description: description,
        registered-at: block-height,
        active: true
      }
    )
    
    ;; Add game ID to developer's list
    (add-game-id-for-developer tx-sender game-id)
    
    (ok true)
  )
)


;; Register a new NFT
(define-public (register-nft 
  (nft-id (string-ascii 50))
  (name (string-ascii 100))
  (origin-game-id (string-ascii 50))
  (metadata-url (string-ascii 255))
  (royalty-percentage uint))
  (begin
    ;; Check if the game exists
    (asserts! (is-some (map-get? games { game-id: origin-game-id })) ERR-GAME-NOT-FOUND)
    
    ;; Check if the caller is authorized for the game
    (asserts! (is-authorized-for-game origin-game-id) ERR-NOT-AUTHORIZED)
    
    ;; Check if NFT already exists
    (asserts! (is-none (map-get? nfts { nft-id: nft-id })) ERR-NFT-ALREADY-REGISTERED)
    
    ;; Check royalty percentage (max 30%)
    (asserts! (<= royalty-percentage u3000) ERR-INVALID-ROYALTY-PERCENTAGE)
    
    ;; Register the NFT
    (map-set nfts
      { nft-id: nft-id }
      {
        name: name,
        origin-game-id: origin-game-id,
        creator: tx-sender,
        creation-block: block-height,
        metadata-url: metadata-url,
        royalty-percentage: royalty-percentage,
        active: true
      }
    )
    
    (ok true)
  )
)

;; Register a trait category
(define-public (register-trait-category
  (category-id (string-ascii 50))
  (name (string-ascii 100))
  (description (string-utf8 500)))
  (begin
    ;; Only contract owner can create trait categories
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    ;; Check if category already exists
    (asserts! (is-none (map-get? trait-categories { category-id: category-id })) ERR-TRAIT-CATEGORY-ALREADY-EXISTS)
    
    ;; Register the trait category
    (map-set trait-categories
      { category-id: category-id }
      {
        name: name,
        description: description,
        created-by: tx-sender,
        created-at: block-height
      }
    )
    
    (ok true)
  )
)

;; Set NFT trait
(define-public (set-nft-trait
  (nft-id (string-ascii 50))
  (category-id (string-ascii 50))
  (value (string-utf8 255)))
  (begin
    ;; Check if the NFT exists
    (asserts! (is-some (map-get? nfts { nft-id: nft-id })) ERR-NFT-NOT-FOUND)
    
    ;; Check if the category exists
    (asserts! (is-some (map-get? trait-categories { category-id: category-id })) ERR-TRAIT-CATEGORY-NOT-FOUND)
    
    ;; Check if the caller is authorized
    (asserts! (is-authorized-for-nft nft-id) ERR-NOT-AUTHORIZED)
    
    ;; Set the trait value
    (map-set nft-traits
      { nft-id: nft-id, category-id: category-id }
      { value: value }
    )
    
    (ok true)
  )
)

;; Register a capability
(define-public (register-capability
  (capability-id (string-ascii 50))
  (name (string-ascii 100))
  (description (string-utf8 500)))
  (begin
    ;; Only contract owner can create capabilities
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    ;; Check if capability already exists
    (asserts! (is-none (map-get? capabilities { capability-id: capability-id })) ERR-CAPABILITY-ALREADY-EXISTS)
    
    ;; Register the capability
    (map-set capabilities
      { capability-id: capability-id }
      {
        name: name,
        description: description,
        created-by: tx-sender,
        created-at: block-height
      }
    )
    
    (ok true)
  )
)

;; Set NFT capability
(define-public (set-nft-capability
  (nft-id (string-ascii 50))
  (capability-id (string-ascii 50))
  (enabled bool)
  (properties (optional (string-utf8 1000))))
  (begin
    ;; Check if the NFT exists
    (asserts! (is-some (map-get? nfts { nft-id: nft-id })) ERR-NFT-NOT-FOUND)
    
    ;; Check if the capability exists
    (asserts! (is-some (map-get? capabilities { capability-id: capability-id })) ERR-CAPABILITY-NOT-FOUND)
    
    ;; Check if the caller is authorized
    (asserts! (is-authorized-for-nft nft-id) ERR-NOT-AUTHORIZED)
    
    ;; Set the capability
    (map-set nft-capabilities
      { nft-id: nft-id, capability-id: capability-id }
      { 
        enabled: enabled,
        properties: properties
      }
    )
    
    (ok true)
  )
)

;; Create conversion rule
(define-public (create-conversion-rule
  (nft-id (string-ascii 50))
  (target-game-id (string-ascii 50))
  (display-name (string-ascii 100))
  (asset-url (string-ascii 255))
  (properties (string-utf8 1000)))
  (begin
    ;; Check if the NFT exists
    (asserts! (is-some (map-get? nfts { nft-id: nft-id })) ERR-NFT-NOT-FOUND)
    
    ;; Check if the target game exists
    (asserts! (is-some (map-get? games { game-id: target-game-id })) ERR-GAME-NOT-FOUND)
    
    ;; Get the origin game ID
    (match (map-get? nfts { nft-id: nft-id })
      nft-data
        (let ((source-game-id (get origin-game-id nft-data)))
          ;; Check if the caller is authorized (either NFT creator or target game developer)
          (asserts! (or 
            (is-nft-creator nft-id) 
            (is-game-developer target-game-id)
            (is-contract-owner)
          ) ERR-NOT-AUTHORIZED)
          
          ;; Check if conversion rule already exists
          (asserts! (is-none (map-get? conversion-rules { 
            nft-id: nft-id, 
            source-game-id: source-game-id, 
            target-game-id: target-game-id 
          })) ERR-CONVERSION-RULE-EXISTS)
          
          ;; Create the conversion rule
          (map-set conversion-rules
            { nft-id: nft-id, source-game-id: source-game-id, target-game-id: target-game-id }
            {
              display-name: display-name,
              asset-url: asset-url,
              properties: properties,
              created-by: tx-sender,
              created-at: block-height,
              last-updated-at: block-height
            }
          )
          
          (ok true)
        )
      ERR-NFT-NOT-FOUND
    )
  )
)

;; Delete conversion rule
(define-public (delete-conversion-rule
  (nft-id (string-ascii 50))
  (source-game-id (string-ascii 50))
  (target-game-id (string-ascii 50)))
  (begin
    ;; Check if the conversion rule exists
    (asserts! (is-some (map-get? conversion-rules { 
      nft-id: nft-id, 
      source-game-id: source-game-id, 
      target-game-id: target-game-id 
    })) ERR-CONVERSION-RULE-NOT-FOUND)
    
    ;; Check if the caller is authorized (either NFT creator or target game developer)
    (asserts! (or 
      (is-nft-creator nft-id) 
      (is-game-developer target-game-id)
      (is-contract-owner)
    ) ERR-NOT-AUTHORIZED)
    
    ;; Delete the conversion rule
    (map-delete conversion-rules { 
      nft-id: nft-id, 
      source-game-id: source-game-id, 
      target-game-id: target-game-id 
    })
    
    (ok true)
  )
)