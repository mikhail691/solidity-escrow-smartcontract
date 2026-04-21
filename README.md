# Solidity Escrow Smart Contract

This repository contains a minimal Solidity escrow contract for a buyer, seller, and arbiter flow.

## Story Arc Diagram

```mermaid
flowchart TD
    A[Create Escrow] --> B[Buyer Deposits Funds]
    B --> C{Outcome}
    C -->|Buyer confirms delivery| D[Release funds to Seller]
    C -->|Dispute or failed delivery| E[Arbiter resolves]
    E -->|Refund Buyer| F[Return funds to Buyer]
    E -->|Pay Seller| D
    D --> G[Escrow Closed]
    F --> G
```

## Contract

The escrow contract is located at:

- `contracts/Escrow.sol`
