# MC Vault (MVP)

## 1. Project Overview

**MC Vault** is a **multi-collateral, on-chain lending system** that bridges **real-world assets (RWA/RealFi)** with DeFi.

Users can deposit **ERC20 tokens** or **ERC721 NFTs** as collateral and borrow **USDT** based on **dynamic Loan-to-Value (LTV) scores** powered by **zero-knowledge attestations (ZK proofs)**.

## Compliance declaration 

The MC-RWA Vault (MVP) project is a technical prototype currently deployed on the Mantle Sepolia Testnet for experimental and educational purposes. At this stage:

No regulated financial assets are involved in the live demonstration.
The protocol uses mocked ZK-attestations and test tokens (e.g., USDTMock) to simulate RWA workflows.
In a future production deployment, the architecture is designed to integrate with regulated RWA tokenization providers and mandatory KYC/AML identity layers to satisfy regional legal requirements.




## One-Pager Pitch

The Problem: The DeFi-RWA Friction
DeFi lending is currently stuck in a cycle of extreme over-collateralization and privacy trade-offs. Borrowers cannot easily leverage Real-World Assets (RWA) because on-chain protocols lack the nuance to value off-chain creditworthiness without exposing sensitive personal data. This creates a barrier for institutional capital and limits the utility of tokenized RWAs in decentralized markets.

 The Solution: MC Vault
MC-RWA Vault is a multi-collateral lending engine on Mantle that bridges the gap between RealFi and DeFi. It enables users to deposit tokenized RWAs (ERC20/ERC721) and borrow stablecoins against them using ZK-powered dynamic LTVs.

Privacy-First Credit: Leveraging Zero-Knowledge proofs to update credit scores off-chain and attest to them on-chain without revealing underlying data.
Dynamic Leverage: Rewards reliable borrowers with higher LTV ratios based on their ZK-verified financial health.
Multi-Token Repayment: Seamlessly repay loans using any approved token, powered by protected on-chain oracles.
 
Business Model
Borrowing Fees: A transparent, protocol-level fee on all issued loans.
Liquidation Incentives: Capturing a portion of internal liquidation spreads to ensure protocol solvency.
Enterprise API: Providing white-label "Vault-as-a-Service" for institutional RWA originators looking to bring liquidity to their tokenized assets.

Roadmap
Q1 2026 (Current): Full MVP deployment on Mantle Sepolia with multi-token repayment and oracle-fallback systems.
Q2 2026: Migration from mocked attestations to real ZK-identity providers and a comprehensive smart contract security audit.
Q3 2026: Strategic partnership pilot with a tokenized bond or real-estate provider for real-asset integration.
Q4 2026: Mainnet launch and expansion of the "Mantle-Nexus" ecosystem for cross-chain RWA liquidity.

**Key Features:**

* **RWA and RealFi integration:** Tokenized real-world assets as collateral
* **DeFi composability:** Borrow stablecoins on-chain
* **Privacy-first credit scoring:** ZK-powered dynamic LTV

## 2. Problem Statement
Traditional DeFi lending platforms rely on static LTVs and lack privacy-preserving credit scoring. **MC-RWA Vault solves this by:**
1. Providing **dynamic, ZK-powered Loan-to-Values (LTVs)**.
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
| `VAULT_ADDRESS`            | 0x40776dF7BB64828BfaFBE4cfacFECD80fED34266 
| `USDT_ADDRESS`             | 0x915cC86fE0871835e750E93e025080FFf9927A3f 
| `INTEGRATOR_ADDRESS`       | 0xAE95E2F4DBFa908fb88744C12325e5e44244b6B0 
| `CREDIT_SCORE_ADDRESS`     | 0xf8f7EE86662e6eC391033EFcF4221057F723f9B1 

**Gas and Payment Summary:**

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

## 8. Chainlink Oracle Integration 🔗

**Real-time asset pricing with fallback support**

The MC-RWA Vault now integrates with **Chainlink Data Feeds** for accurate, on-chain asset pricing with circuit-breaker fallback protection.

### Architecture

```
┌─────────────────────────────────────────────────────┐
│          MC Vault (Price Queries)                   │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│      ChainlinkPriceOracle (Event Emitter)           │
│  ✓ Aggregator Registry                              │
│  ✓ Fallback Price Circuit Breaker                   │
│  ✓ Staleness Detection & Alerts                     │
└────────────────────┬────────────────────────────────┘
         ┌───────────┴───────────┐
         ▼                       ▼
┌──────────────────────┐  ┌────────────────────┐
│ Chainlink Aggregator │  │ Fallback Price     │
│ (1hr staleness TTL)  │  │ (Circuit Breaker)  │
│ • ETH/USD            │  │ • USDT = $1.00     │
│ • BTC/USD            │  │ • Custom Assets    │
└──────────────────────┘  └────────────────────┘
```

### Features

| Feature | Description |
|---------|-------------|
| **Multi-Source Pricing** | Register Chainlink aggregators for any ERC20 token |
| **Staleness Detection** | Automatically detects when Chainlink feeds haven't updated (1hr TTL) |
| **Fallback Mode** | Circuit-breaker fallback prices if feed becomes stale |
| **Event Emission** | Emits events for monitoring: `PriceUpdated`, `PriceStalenessDetected`, `AggregatorRegistered` |
| **View & Non-View API** | `getPriceUnsafeView()` for read-only calls, `getPriceUnsafe()` with event emission |

### 9 Deployment and Setup

**Deploy Oracle Contract**

```bash
export PRIVATE_KEY=0x...
export RPC_URL=https://5003.rpc.thirdweb.com
export USDT_ADDRESS=0x...
export VAULT_ADDRESS=0x...

./script/deploy-oracle-full.sh
```

**Register Chainlink Aggregators**

```bash
export ORACLE_ADDRESS=0x...

./script/register-aggregators.sh \
  0x...usdt_address 0x...chainlink_usdt_aggregator 8 \
  0x...eth_address 0x...chainlink_eth_aggregator 8
```

**Verify Oracle Status**

```bash
# Monitor live events
export ORACLE_ADDRESS=0x...
./script/monitor-oracle.sh
```

### Multi-Token Repayment

Users can now repay loans using **any allowed borrow token** instead of just USDT:

**Frontend:**
- Token selector in "Repay" tab
- Oracle-based price conversion
- Automatic debt calculation

**Solidity:**
```solidity
// Repay with USDT (traditional)
vault.repay(100e18);

// Repay with any approved borrow token
vault.repayWithBorrowToken(0x...token, 50e18);
```

**Events:**
```solidity
event RepaidWithBorrowToken(
    address indexed user,
    address indexed token,
    uint256 amountToken,
    uint256 amountUSDT
);
```

### Monitoring & Alerts

**On-Chain Events:**

| Event | When | Use Case |
|-------|------|----------|
| `PriceUpdated` | Price fetched from Chainlink or fallback | Update UI, analytics |
| `PriceStalenessDetected` | Feed hasn't updated in 1+ hours | Alert operators, trigger action |
| `AggregatorRegistered` | New Chainlink feed registered | Audit trail |
| `FallbackPriceUpdated` | Fallback price set/updated | Circuit breaker engagement |

**Example Monitoring Script:**
```bash
# Watch for staleness alerts
cast rpc eth_subscribeLogs \
  --address "$ORACLE_ADDRESS" \
  --topics "$(cast keccak 'PriceStalenessDetected(address,uint256,uint256)')"
```

### Testing

**Staleness Detection Tests (5 new tests):**
```bash
forge test -k "Staleness"

# Tests cover:
# ✓ test_StalenessDetection: Verifies staleness flag after 1hr
# ✓ test_FallbackPriceOnStaleness: Fallback activates when feed is stale
# ✓ test_AggregatorRegistrationEvent: Events emitted on registration
# ✓ test_PriceUpdateEmitsEvent: Price events logged
# ✓ test_StalenessClearedWhenFeedUpdates: Recovery from staleness
```

**All 41 tests passing** 
### CI/CD Integration

**Automated smoke test:**
```bash
./script/ci-smoke-test.sh

# Validates:
# ✓ Contracts compile
# ✓ All tests pass
# ✓ Deployment scripts valid
# ✓ Multi-token repay functions exist
# ✓ Oracle integration verified
```

---

## 10. Compliance and Notes


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
|[Select ERC20/ERC721] [Amount] [Deposit]|
+---------------------------------------+
| Borrow USDT                             |
| [Amount] [Borrow]                       |
| Current LTV: 50%                        |
+---------------------------------------+
| Update Credit Score (ZK)                |
| [Update LTV]                            |
+---------------------------------------+
| Withdraw Collateral                     |
| [Select Token/NFT] [Withdraw]           |
+---------------------------------------+


## 11. Security and UX Guardrails (Phase 1)
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

# MC Vault Security and Threat Model

### Composability
- **Tokenized Receipts**: Deposits generate `mRWA-USDT`. While this allows for yield-bearing collateral, it introduces "Recursive Borrowing" risks if mRWA-USDT is accepted back into the vault as collateral.
- **Integrator Trust**: The `VaultIntegrator` is stateless. It does not hold user funds permanently, reducing the attack surface.

### Attack Vectors
- **Flash Loans**: An attacker could flash-loan the collateral token to manipulate the Vault's TVL. **Mitigation**: Our Vault uses an admin-controlled price oracle, making spot-price manipulation impossible.
- **Reentrancy**: We follow the Checks-Effects-Interactions pattern. The `_mint` (Effect) and `_burn` happen before the external `transfer` (Interaction).
Verified Vault: https://sepolia.mantlescan.xyz/address/0x40776dF7BB64828BfaFBE4cfacFECD80fED34266

Verified Integrator: https://sepolia.mantlescan.xyz/address/0xAE95E2F4DBFa908fb88744C12325e5e44244b6B0
We've built a modular RWA infrastructure on Mantle. Our Vault is integrated with a ZK-ready Credit Score system, allowing for intelligent, risk-adjusted leverage on real-world assets.

