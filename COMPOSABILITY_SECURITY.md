Composability Threat Model

External Contract Dependency: Our Vault uses msg.sender for state updates. This allows contracts like VaultIntegrator to hold positions.

Flash Loan Risk: An attacker could use a flash loan to inflate the vault's USDT balance, potentially manipulating the getBorrowable return value if it relies on total TVL.

Reentrancy: All state-changing functions in the Vault must follow the Checks-Effects-Interactions pattern to prevent external contracts from calling back into the vault before balances update.