// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Registry} from "../src/v2/Registry.sol";
import {Token} from "../src/v2/Token.sol";
import {PaymentProcessor} from "../src/v2/PaymentProcessor.sol";
import {GigMarketplace} from "../src/v2/GigMarketplace.sol";
import {ReviewSystem} from "../src/v2/ReviewSystem.sol";
import {ChatSystem} from "../src/v2/ChatSystem.sol";
import {CraftCoin} from "../src/v2/CraftCoin.sol";

contract DeployV2Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey != 0, "Deployer private key is not set");

        address relayer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        Registry registry = new Registry(relayer);
        Token token = new Token(relayer);
        CraftCoin craftCoin = new CraftCoin(relayer, address(registry));
        PaymentProcessor paymentProcessor = new PaymentProcessor(relayer, address(token));
        GigMarketplace gigMarketplace =
            new GigMarketplace(relayer, address(registry), address(paymentProcessor), address(craftCoin));
        ReviewSystem reviewSystem = new ReviewSystem(relayer, address(registry), address(gigMarketplace));
        ChatSystem chatSystem = new ChatSystem(address(gigMarketplace));

        console.log("Registry deployed at:", address(registry));
        console.log("CraftLinkToken deployed at:", address(token));
        console.log("CraftCoinToken deployed at:", address(craftCoin));
        console.log("PaymentProcessor deployed at:", address(paymentProcessor));
        console.log("GigMarketplace deployed at:", address(gigMarketplace));
        console.log("ReviewSystem deployed at:", address(reviewSystem));
        console.log("ChatSystem deployed at:", address(chatSystem));

        vm.stopBroadcast();
    }
}
