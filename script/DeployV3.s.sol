// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Registry} from "../src/v3/Registry.sol";
import {Token} from "../src/v3/Token.sol";
import {PaymentProcessor} from "../src/v3/PaymentProcessor.sol";
import {GigMarketplace} from "../src/v3/GigMarketplace.sol";
import {ReviewSystem} from "../src/v3/ReviewSystem.sol";
import {ChatSystem} from "../src/v3/ChatSystem.sol";
import {CraftCoin} from "../src/v3/CraftCoin.sol";

contract DeployV3Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey != 0, "Deployer private key is not set");

        address relayer = vm.addr(deployerPrivateKey);
        // address relayer = vm.envAddress("RELAYER");

        vm.startBroadcast(deployerPrivateKey);
        Registry registry = new Registry(relayer);
        Token token = new Token(relayer);
        CraftCoin craftCoin = new CraftCoin(relayer, address(registry));
        PaymentProcessor paymentProcessor = new PaymentProcessor(relayer, address(token));
        GigMarketplace gigMarketplace =
            new GigMarketplace(relayer, address(registry), address(paymentProcessor), address(craftCoin));
        ReviewSystem reviewSystem = new ReviewSystem(relayer, address(registry), address(gigMarketplace));
        ChatSystem chatSystem = new ChatSystem(address(gigMarketplace));

        writeAddressesToFile(address(registry), "Registry");
        writeAddressesToFile(address(token), "CraftLinkToken");
        writeAddressesToFile(address(craftCoin), "CraftCoinToken");
        writeAddressesToFile(address(paymentProcessor), "PaymentProcessor");
        writeAddressesToFile(address(gigMarketplace), "GigMarketplace");
        writeAddressesToFile(address(reviewSystem), "ReviewSystem");
        writeAddressesToFile(address(chatSystem), "ChatSystem");
        vm.stopBroadcast();
    }

    function writeAddressesToFile(address addr, string memory text) public {
        string memory filename = "./deployed_contracts.txt";

        vm.writeLine(
            filename,
            "---------------------------------------------------------------------------------------------------------------------------"
        );
        vm.writeLine(filename, text);
        vm.writeLine(filename, vm.toString(addr));
        vm.writeLine(
            filename,
            "---------------------------------------------------------------------------------------------------------------------------"
        );
    }
}

// DEPLOY COMMAND
// forge script script/DeployV3.s.sol:DeployV3Script --rpc-url $LISK_SEPOLIA_RPC_URL --broadcast --verify -vvvv

// forge script script/DeployV3.s.sol:DeployV3Script --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify --verifier etherscan -vvvv --slow (The slow is optional to allow more time for verification)
