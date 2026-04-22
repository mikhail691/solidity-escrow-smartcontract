# Escrow Smart Contract — Architecture

## Actors & Roles

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          ESCROW CONTRACT                                │
│                                                                         │
│  ┌─────────────┐   deploy + lock ETH    ┌──────────────────────────┐   │
│  │  Depositor  │ ──────────────────────►│  constructor()           │   │
│  │  (msg.sender│                        │  stores: depositor       │   │
│  │   + ETH)    │◄── withdraw() ─────────│           beneficiary    │   │
│  └──────┬──────┘                        │           arbiter        │   │
│         │ claimTimeout()                │           amount         │   │
│         │ (after deadline)              │           fee            │   │
│         │                              │           deadline        │   │
│  ┌──────▼──────┐   approve() ─────────►│                          │   │
│  │   Arbiter   │                        └──────────────────────────┘   │
│  │  (trusted   │   refund()  ──────────►                               │
│  │   3rd party)│◄── withdraw() (fee) ───                               │
│  └─────────────┘                                                        │
│                                                                         │
│  ┌─────────────┐◄── withdraw() ─────────────────────────────────────   │
│  │ Beneficiary │    (amount − fee, after approve())                     │
│  └─────────────┘                                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

> **Role uniqueness enforced at construction:**
> `depositor ≠ arbiter`, `arbiter ≠ beneficiary`, `depositor ≠ beneficiary`

---

## State Machine

```
                     ┌──────────────────────┐
     deploy()        │                      │
  ──────────────────►│  AWAITING_DELIVERY   │
                     │                      │
                     └───────────┬──────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          │                      │                      │
       approve()             refund()            claimTimeout()
       (arbiter)             (arbiter)           (depositor,
          │                      │               after deadline)
          ▼                      ▼                      │
 ┌────────────────┐    ┌──────────────────┐             │
 │    COMPLETE    │    │     REFUNDED     │◄────────────┘
 │                │    │                  │
 │ beneficiary ←  │    │ depositor ←      │
 │  amount − fee  │    │  full amount     │
 │ arbiter ← fee  │    │                  │
 │ (via withdraw) │    │ (via withdraw)   │
 └────────────────┘    └──────────────────┘
```

---

## Fund Flow

### On `approve()`

```
Contract Balance (amount)
        │
        ├── pendingWithdrawals[arbiter]      += fee
        │
        └── pendingWithdrawals[beneficiary]  += amount − fee
                │
                └── parties call withdraw() → ETH transferred
```

### On `refund()` or `claimTimeout()`

```
Contract Balance (amount)
        │
        └── pendingWithdrawals[depositor]    += amount
                │
                └── depositor calls withdraw() → ETH transferred
```

> **Pull-over-push:** arbiter-gated functions never make external calls.
> Recipients pull their funds via `withdraw()`, eliminating DoS via reverting recipients.

---

## Contract Interface

```
Escrow
├── Immutables
│   ├── depositor        : address
│   ├── beneficiary      : address
│   ├── arbiter          : address
│   ├── amount           : uint256   (total ETH locked)
│   ├── fee              : uint256   (arbiter fee on approval)
│   └── deadline         : uint256   (UNIX timestamp for timeout)
│
├── State
│   ├── currentState     : State { AWAITING_DELIVERY, COMPLETE, REFUNDED }
│   └── pendingWithdrawals : mapping(address => uint256)
│
├── Write — arbiter only
│   ├── approve()        → credits beneficiary + arbiter fee
│   └── refund()         → credits depositor
│
├── Write — depositor only
│   └── claimTimeout()   → credits depositor after deadline
│
├── Write — any credited address
│   └── withdraw()       → pulls pending ETH to caller
│
├── Read
│   ├── isResolved()     : bool
│   └── balance()        : uint256   (returns immutable `amount`)
│
└── Events
    ├── FundsDeposited(depositor, amount)
    ├── FundsApproved(arbiter, beneficiary, payout)
    ├── FundsRefunded(arbiter, depositor, amount)
    ├── TimedOut(depositor, amount)
    └── Withdrawn(recipient, amount)
```

---

## Security Properties

| Property | Mechanism |
|---|---|
| Only arbiter can approve/refund | `onlyArbiter` modifier → custom error `OnlyArbiter` |
| Cannot resolve twice | `notResolved` modifier → custom error `AlreadyResolved` |
| Role uniqueness enforced | Constructor guards → `SameDepositorArbiter`, `SameBeneficiaryArbiter`, `SameDepositorBeneficiary` |
| Liveness guarantee | `claimTimeout()` callable by depositor after `deadline` |
| No reverting-recipient DoS | Pull-over-push: `approve`/`refund` credit `pendingWithdrawals`, never push ETH |
| Reentrancy safe | State + balances updated **before** any `.call` transfer (CEI) |
| No gas-limit transfer issues | Low-level `.call{value: v}("")` instead of `transfer` |
| Overflow-safe arithmetic | Solidity `^0.8.20` built-in checked math |
| Immutable parties & amounts | `immutable` keyword — set once at construction |
| `balance()` not inflatable | Returns `amount` immutable, not `address(this).balance` |

---

## Arbiter Incentive Note

The arbiter earns `fee` only on `approve()`. This creates a theoretical bias
toward approval. If neutral incentives are required, replace with a flat
resolution fee deducted on **both** `approve()` and `refund()`.
