# MC-RWA Vault (MVP)

## 1. Project Overview

**MC-RWA Vault** is a **multi-collateral, on-chain lending system** that bridges **real-world assets (RWA/RealFi)** with DeFi.

Users can deposit **ERC20 tokens** or **ERC721 NFTs** as collateral and borrow **USDT** based on **dynamic Loan-to-Value (LTV) scores** powered by **zero-knowledge attestations (ZK proofs)**.

**Key Features:**

* **RWA & RealFi integration:** Tokenized real-world assets as collateral
* **DeFi composability:** Borrow stablecoins on-chain
* **Privacy-first credit scoring:** ZK-powered dynamic LTV

## 2. Problem Statement
Traditional DeFi lending platforms rely on static LTVs and lack privacy-preserving credit scoring. **MC-RWA Vault solves this by:**
1. Providing **dynamic, ZK-powered LTVs**.
2. Supporting **multiple collateral types** (ERC20 + ERC721).
3. Demonstrating **privacy-first credit scoring.** 

## 3. Solution and Workflow

**User Flow:**

1. Deposit ERC20/ERC721 collateral
2. Borrow USDT based on **dynamic LTV**
3. Update credit score via **ZK attestations**
4. Borrow additional USDT if LTV increases
5. Withdraw collateral safely while maintaining solvency

**Tech Stack:**

* Solidity 0.8.x
* OpenZeppelin contracts
* Foundry (forge) for testing and deployment
* Mantle Sepolia Testnet

## 4. Deployment on Mantle Sepolia

**Deployed Contracts:**

| Contract                   | Address                                                                                           
| -------------------------- | ------------------------------------------ 
| `USDT_ADDRESS`             | 0x915cC86fE0871835e750E93e025080FFf9927A3f 
| `VAULT_ADDRESS`            | 0x61dAF0E077555362ea135C1C56c808aA8b0e71F8 
| `INTEGRATOR_ADDRESS`       | 0xD168D3185E1A972b32719169e42Bb949De61B6d9 
| `CREDIT_SCORE_ADDRESS`     | 0xf8f7EE86662e6eC391033EFcF4221057F723f9B1 
| `INTEGRATOR_ADDRESS`       | 0x255C053490060Df61D374A42D95Fd570D25418a7

**Gas & Payment Summary:**

* Estimated total gas: ~11.8B
* Paid in Mantle Sepolia: 0.2374 MNT
* Deployment successful ✅

## 5. Demo / Functional MVP

Run the demo workflow locally using Foundry:

```bash
export PRIVATE_KEY=0xYOUR_PRIVATE_KEY
forge script script/Demo.s.sol \
  --rpc-url https://5003.rpc.thirdweb.com \
  --broadcast \
  --private-key $PRIVATE_KEY \
  --ffi
```

**Demo Steps:**

1. Deploy `USDTMock`, `CreditScore`, `ZKAttestationUpdaterMock`, `MCRWAVault`
2. Configure ERC20/ERC721 prices in the vault
3. Deposit collateral
4. Borrow USDT
5. Update credit score via ZK attestation
6. Borrow additional USDT
7. Withdraw collateral safely

## 6. Architecture Overview

**Contracts and Responsibilities:**

* `CreditScore.sol` → Manages user LTVs
* `ZKAttestationUpdaterMock.sol` → Updates credit scores via ZK attestations
* `MCRWAVault.sol` → Multi-collateral vault handling deposits, borrowings, and withdrawals
* `USDTMock.sol` → Test stablecoin for borrowing

**Integration:**

* Designed to run on **Mantle Testnet / L2**
* Fully composable with other Mantle-native DeFi protocols

---

## 7. Business Model (MVP)

* **Borrowing Fee:** Small percentage of borrowed USDT
* **Liquidation Incentives:** Optional, for under-collateralized loans
* **Future Revenue:** Tokenization partnerships for real-world assets

---

## 8. Compliance and Notes

* MVP contains **mocked ZK attestations**
* No regulated real-world assets are on-chain
* Focus is **experimental & educational** for hackathon/demo purposes
* ✅ All systems deployed, ready for testing, verified on Mantle Sepolia
9. Demo Execution and Logs (Mantle Sepolia)

##### Demo Workflow
 Wireframe (Simple Layout)
+---------------------------------------+
| MC-RWA Vault                           |
| [Connect Wallet]                       |
+---------------------------------------+
| Collateral Overview                    |
| - Total Deposited: $X                  |
| - Max Borrowable: $Y                   |
+---------------------------------------+
| Deposit Collateral                     |
| [Select ERC20/ERC721] [Amount] [Deposit]|
+---------------------------------------+
| Borrow USDT                             |
| [Amount] [Borrow]                       |
| Current LTV: 50%                        |
+---------------------------------------+
| Update Credit Score (ZK)               |
| [Update LTV]                             |
+---------------------------------------+
| Withdraw Collateral                     |
| [Select Token/NFT] [Withdraw]           |
+---------------------------------------+


## 10. Security and UX Guardrails (Phase 1)
To ensure capital safety and a robust user experience, the following "Hardening" measures have been implemented:

### ✅ Frontend Safety Layers
- **Balance Guardrails:** The UI automatically disables 'Deposit' and 'Borrow' buttons if the user input exceeds their available balance or the vault's borrowable limit.
- **Explicit Transaction States:** Users are provided with real-time feedback during the transaction lifecycle:
  - *Awaiting Signature:* Prompts the user to check their wallet.
  - *Confirming:* Provides a direct link to the **Mantle Explorer** while the block is being mined.
  - *Success/Fail:* Clear visual confirmation of the final state.
- **Chain Verification:** The UI strictly enforces the **Mantle Sepolia (5003)** network, preventing accidental transactions on the wrong chain.

### ✅ Technical Trust UI
- **Contract Transparency:** The footer explicitly surfaces the Vault and USDT contract addresses for manual verification.
- **Dynamic Explorer Integration:** Every transaction provides a one-click link to the block explorer for auditability.

## 11. Risk Disclosure
- **Smart Contract Risk:** This is an MVP. While logic is tested, the contracts have not undergone a formal audit.
- **Mocked Components:** ZK-attestations are currently mocked for demonstration purposes.
- **Liquidation:** Users must monitor their LTV to prevent liquidation if collateral values fluctuate (future implementation).

# MC-RWA Vault Security & Threat Model

### Composability
- **Tokenized Receipts**: Deposits generate `mRWA-USDT`. While this allows for yield-bearing collateral, it introduces "Recursive Borrowing" risks if mRWA-USDT is accepted back into the vault as collateral.
- **Integrator Trust**: The `VaultIntegrator` is stateless. It does not hold user funds permanently, reducing the attack surface.

### Attack Vectors
- **Flash Loans**: An attacker could flash-loan the collateral token to manipulate the Vault's TVL. **Mitigation**: Our Vault uses an admin-controlled price oracle, making spot-price manipulation impossible.
- **Reentrancy**: We follow the Checks-Effects-Interactions pattern. The `_mint` (Effect) and `_burn` happen before the external `transfer` (Interaction).
Verified Vault: https://sepolia.mantlescan.xyz/address/0x40776dF7BB64828BfaFBE4cfacFECD80fED34266

Verified Integrator: https://sepolia.mantlescan.xyz/address/0xAE95E2F4DBFa908fb88744C12325e5e44244b6B0
We've built a modular RWA infrastructure on Mantle. Our Vault is integrated with a ZK-ready Credit Score system, allowing for intelligent, risk-adjusted leverage on real-world assets.

