// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Registry} from "../src/v1/Registry.sol";
import {Token} from "../src/v1/Token.sol";
import {PaymentProcessor} from "../src/v1/PaymentProcessor.sol";
import {GigMarketplace} from "../src/v1/GigMarketplace.sol";
import {ReviewSystem} from "../src/v1/ReviewSystem.sol";
import {ChatSystem} from "../src/v1/ChatSystem.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Registry registry = new Registry();
        Token token = new Token();
        PaymentProcessor paymentProcessor = new PaymentProcessor(address(token));
        GigMarketplace gigMarketplace = new GigMarketplace(address(registry), address(paymentProcessor));
        ReviewSystem reviewSystem = new ReviewSystem(address(registry), address(gigMarketplace));
        ChatSystem chatSystem = new ChatSystem(address(gigMarketplace));

        console.log("Registry deployed at:", address(registry));
        console.log("CraftLinkToken deployed at:", address(token));
        console.log("PaymentProcessor deployed at:", address(paymentProcessor));
        console.log("GigMarketplace deployed at:", address(gigMarketplace));
        console.log("ReviewSystem deployed at:", address(reviewSystem));
        console.log("ChatSystem deployed at:", address(chatSystem));

        vm.stopBroadcast();
    }
}
