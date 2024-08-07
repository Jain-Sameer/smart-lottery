-include .env

.PHONY: all test deploy

build:; forge build

test :; forge test

install :; forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts && forge install foundry-rs/forge-std@v1.8.2 --no-commit && forge install transmissions/solmate@v6 --no-commit

deploy-sepolia :
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account mainWallet --broadcast --verify --etherscan-api-key $(ETHERSCAN_API) -vvvv --legacy
