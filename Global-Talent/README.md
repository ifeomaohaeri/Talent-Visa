# Global Talent Visa System Smart Contract

A blockchain-based visa application and management system built on the Stacks blockchain using Clarity smart contracts.

## Overview

This smart contract implements a decentralized global talent visa system that allows qualified individuals to apply for visas based on their talent scores and endorsements. The system includes automated processing, quota management, and comprehensive tracking of application history.

## Features

- **Decentralized Visa Application Process**: Submit visa applications directly on the blockchain
- **Talent-Based Assessment**: Applications evaluated based on talent scores and categories
- **Endorsement System**: Authorized endorsers can validate applications
- **Country Quota Management**: Configurable limits per country
- **Application History Tracking**: Complete audit trail of all applications
- **Officer Authorization**: Role-based access control for processing applications
- **Maintenance Mode**: Emergency system controls
- **Automated Expiry Management**: Smart contract handles visa expiration

## Contract Constants

### Error Codes
- `ERR-UNAUTHORIZED-ACCESS (100)`: Insufficient permissions
- `ERR-INVALID-VISA-TYPE (101)`: Invalid visa type specified
- `ERR-VISA-ALREADY-EXISTS (102)`: Application already exists
- `ERR-VISA-NOT-FOUND (103)`: Application not found
- `ERR-VISA-EXPIRED (104)`: Visa has expired
- `ERR-INVALID-STATUS (105)`: Invalid application status
- `ERR-INSUFFICIENT-SCORE (106)`: Talent score too low
- `ERR-INVALID-DURATION (107)`: Invalid visa duration
- `ERR-INVALID-APPLICANT (108)`: Invalid applicant
- `ERR-VISA-ALREADY-APPROVED (109)`: Visa already approved
- `ERR-VISA-ALREADY-REJECTED (110)`: Visa already rejected
- `ERR-INVALID-COUNTRY-CODE (111)`: Invalid country code
- `ERR-INVALID-TALENT-CATEGORY (112)`: Invalid talent category
- `ERR-ENDORSEMENT-REQUIRED (113)`: Missing required endorsement
- `ERR-MAINTENANCE-MODE (114)`: System in maintenance mode

### Validation Rules
- **Minimum Talent Score**: 70 points
- **Visa Duration**: 90-1095 days (3 months to 3 years)
- **Country Code Length**: 2-3 characters
- **Maximum Endorsements**: 10 per application

### Status Types
- `PENDING (0)`: Application submitted, awaiting review
- `APPROVED (1)`: Application approved, visa active
- `REJECTED (2)`: Application rejected
- `EXPIRED (3)`: Visa has expired
- `REVOKED (4)`: Visa has been revoked

### Talent Categories
- `TECHNOLOGY (0)`: Software, AI, Engineering
- `SCIENCE (1)`: Research, Innovation
- `ARTS (2)`: Creative industries
- `BUSINESS (3)`: Entrepreneurship, Leadership
- `SPORTS (4)`: Athletic excellence
- `ACADEMIA (5)`: Education, Research

## Core Functions

### Read-Only Functions

#### `get-contract-owner`
Returns the current contract owner principal.

#### `is-authorized-officer (officer principal)`
Checks if a principal is authorized to process visa applications.

#### `is-maintenance-mode`
Returns true if the system is in maintenance mode.

#### `get-visa-application (applicant principal) (application-id uint)`
Retrieves a specific visa application by applicant and ID.

#### `get-country-quota (country-code string-ascii)`
Returns the quota information for a specific country.

#### `is-authorized-endorser (endorser principal)`
Checks if a principal is authorized to endorse applications.

#### `get-application-history (applicant principal)`
Returns the complete application history for an applicant.

#### `calculate-processing-time (talent-score uint) (category uint)`
Calculates estimated processing time based on talent score:
- Score 90+: 7 days
- Score 80-89: 14 days  
- Score 70-79: 21 days

### Public Functions

#### `apply-for-visa`
```clarity
(apply-for-visa 
  (country-code (string-ascii 3))
  (talent-category uint)
  (talent-score uint)
  (duration-days uint)
  (endorsements (list 10 principal))
)
```
Submit a new visa application with required parameters and endorsements.

**Requirements:**
- System not in maintenance mode
- Valid country code (2-3 characters)
- Valid talent category (0-5)
- Talent score >= 70
- Duration between 90-1095 days
- Maximum 10 endorsements
- Country quota available
- All endorsers must be authorized

#### `process-visa-application`
```clarity
(process-visa-application 
  (applicant principal) 
  (application-id uint) 
  (approve bool)
  (rejection-reason (optional (string-ascii 500)))
)
```
Process a pending visa application (approve or reject).

**Requirements:**
- Must be authorized officer
- System not in maintenance mode
- Application must be in pending status

#### `revoke-visa`
```clarity
(revoke-visa (applicant principal) (application-id uint))
```
Revoke an approved visa.

**Requirements:**
- Must be authorized officer
- System not in maintenance mode
- Visa must be currently approved

#### `check-visa-validity`
```clarity
(check-visa-validity (applicant principal) (application-id uint))
```
Check if a visa is currently valid and automatically mark as expired if past expiry date.

### Administrative Functions

#### `set-authorized-officer`
```clarity
(set-authorized-officer (officer principal) (authorized bool))
```
Grant or revoke officer permissions for processing applications.

#### `set-maintenance-mode`
```clarity
(set-maintenance-mode (enabled bool))
```
Enable or disable maintenance mode.

#### `set-country-quota`
```clarity
(set-country-quota (country-code (string-ascii 3)) (limit uint))
```
Set the visa quota limit for a specific country.

#### `set-authorized-endorser`
```clarity
(set-authorized-endorser (endorser principal) (category uint) (active bool))
```
Authorize or deauthorize an endorser for a specific talent category.

#### `transfer-ownership`
```clarity
(transfer-ownership (new-owner principal))
```
Transfer contract ownership to a new principal.

## Data Structures

### Visa Application
```clarity
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
```

### Application History
```clarity
{
  total-applications: uint,
  approved-count: uint,
  rejected-count: uint,
  last-application: (optional uint)
}
```

### Country Quota
```clarity
{
  limit: uint,
  used: uint
}
```

### Endorser Registry
```clarity
{
  category: uint,
  active: bool
}
```

## Usage Examples

### Applying for a Visa
```clarity
(contract-call? .global-talent-visa apply-for-visa
  "USA"                    ;; country-code
  u0                       ;; TECHNOLOGY category
  u85                      ;; talent-score
  u365                     ;; duration-days (1 year)
  (list 'SP1ABC... 'SP2DEF...)  ;; endorsements
)
```

### Processing an Application
```clarity
(contract-call? .global-talent-visa process-visa-application
  'SP1APPLICANT...         ;; applicant
  u1                       ;; application-id
  true                     ;; approve
  none                     ;; rejection-reason
)
```

### Checking Visa Status
```clarity
(contract-call? .global-talent-visa check-visa-validity
  'SP1APPLICANT...         ;; applicant
  u1                       ;; application-id
)
```

## Security Features

- **Role-Based Access Control**: Only authorized officers can process applications
- **Ownership Management**: Contract owner controls system configuration
- **Maintenance Mode**: Emergency system shutdown capability
- **Input Validation**: Comprehensive validation of all inputs
- **Quota Management**: Prevents over-allocation by country
- **Endorsement Verification**: All endorsers must be pre-authorized
- **Automatic Expiry**: System automatically handles visa expiration

## Deployment Requirements

- Stacks blockchain testnet/mainnet
- Clarity smart contract deployment
- Initial contract owner setup
- Configuration of authorized officers
- Setup of country quotas
- Registration of authorized endorsers

## Integration

This smart contract can be integrated with:
- Frontend applications for visa applications
- Government systems for application processing
- Identity verification services
- Payment processing systems
- Notification services