pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/W4/D2/InscriptionFactory.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployInscriptionFactory is Script {
    function run() external {
        vm.startBroadcast();

        InscriptionTokenV2 tokenImpl = new InscriptionTokenV2();
        InscriptionFactoryV1 factoryV1 = new InscriptionFactoryV1();
        InscriptionFactoryV2 factoryV2 = new InscriptionFactoryV2(address(tokenImpl));

        // Deploy an example token proxy using V2
        address exampleToken = factoryV2.deployInscription("TEST", 1000000, 100, 1e15);

        vm.stopBroadcast();

        console.log("Factory V1 address: %s", address(factoryV1));
        console.log("Factory V2 address: %s", address(factoryV2));
        console.log("Token Implementation address: %s", address(tokenImpl));
        console.log("Example Token Proxy address: %s", address(exampleToken));
    }
} 