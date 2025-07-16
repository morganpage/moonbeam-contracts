# Outmine Smart Contracts for Moonbeam

## The Contracts

### Streak System
The streak system contract is designed to implement a standard streak system that you often find in many games (Outmine), apps (Duolingo) and quest systems (Zealy). A streak system encourages users to participate regularly to increase their streak earning more points and optionally receiving NFT gifts when certain streak milestones are met. If a user doesn't claim within the streakResetTime they will go back to streak 1 (this can be turned off by setting streakResetTime to 0).

Example:
```code
setPointMilestone(1,10)
setPointMilestone(5,50)
setTokenMilestone(1,13)
setTokenMilestone(10,14)
```
With the above set, on the 1st claim (streak 1), the user would receive 10 points and an NFT with a tokenId of 13. On the 2nd claim (streak 2) they would get another 10 points bringing the total to 20 but no additional NFT. For streaks 3 and 4 they would still get 10 points but on streak 5 they would start to get 50 points and streak 10 they would get an NFT with a tokenId of 14.


### Outmine Pets
An ERC721 NFT contract. Usually the pets will be minted within the game by the admin account. I've added the possibility of public minting for a set price since this may be useful in the future. Hence the need for the withdraw function.

### Outmine Items
The ERC1155 contract. Implements all the on-chain game items in Outmine. Since we also use Outmine Items for achievements I've added the ability to make some items Soulbound.


## Testnet Deployment
```
forge create --broadcast --rpc-url https://rpc.api.moonbase.moonbeam.network --private-key $PRIVATE_KEY src/StreakSystem.sol:StreakSystem
forge create --broadcast --rpc-url https://rpc.api.moonbase.moonbeam.network --private-key $PRIVATE_KEY src/OutminePets.sol:OutminePets
forge create --broadcast --rpc-url https://rpc.api.moonbase.moonbeam.network --private-key $PRIVATE_KEY src/OutmineItems.sol:OutmineItems

StreakSystem - 0xc2dEaE151C731c1c8fCcd2af1227b1A4bFBb73Db
OutminePets - 0x6B408F069B78098c0959a65c8583bFa398AceA05
OutmineItems - 0x8EcCE4d0D74436a72fd0cAc45774f6E303F2808e

forge verify-contract --chain moonbase 0xc2dEaE151C731c1c8fCcd2af1227b1A4bFBb73Db src/StreakSystem.sol:StreakSystem
forge verify-contract --chain moonbase 0x6B408F069B78098c0959a65c8583bFa398AceA05 src/OutminePets.sol:OutminePets
forge verify-contract --chain moonbase 0x8EcCE4d0D74436a72fd0cAc45774f6E303F2808e src/OutmineItems.sol:OutmineItems

If above verify doesn't work (didn't for me) then do:
forge flatten --output src/OutminePets.flattened.sol src/OutminePets.sol
Then verify at: https://moonbeam.moonscan.io/verifyContract

```

## Mainnet Deployment
```
forge create --broadcast --rpc-url https://moonbeam.public.blastapi.io --private-key $PRIVATE_KEY src/StreakSystem.sol:StreakSystem
forge create --broadcast --rpc-url https://moonbeam.public.blastapi.io --private-key $PRIVATE_KEY src/OutminePets.sol:OutminePets
forge create --broadcast --rpc-url https://moonbeam.public.blastapi.io --private-key $PRIVATE_KEY src/OutmineItems.sol:OutmineItems

StreakSystem - 0x8EcCE4d0D74436a72fd0cAc45774f6E303F2808e
OutminePets - 0xc2dEaE151C731c1c8fCcd2af1227b1A4bFBb73Db
OutmineItems - 0x6B408F069B78098c0959a65c8583bFa398AceA05

forge verify-contract --chain moonbeam 0x8EcCE4d0D74436a72fd0cAc45774f6E303F2808e src/StreakSystem.sol:StreakSystem
forge verify-contract --chain moonbeam 0xc2dEaE151C731c1c8fCcd2af1227b1A4bFBb73Db src/OutminePets.sol:OutminePets
forge verify-contract --chain moonbeam 0x6B408F069B78098c0959a65c8583bFa398AceA05 src/OutmineItems.sol:OutmineItems
```



## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
