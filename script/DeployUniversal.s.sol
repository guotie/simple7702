// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "./Script.sol";
import {console2} from "./console2.sol";
import {DeployConfig} from "./config/DeployConfig.sol";

import {Universal7702Account} from "../src/Universal7702Account.sol";

/// @notice Deployment script for Universal7702Account - a universal 7702 account implementation.
/// @dev Uses CREATE2 for deterministic deployment across all EVM chains.
contract DeployUniversal is Script {
    bytes32 public constant DEPLOYMENT_SALT = keccak256("Universal7702.v1");
    address public constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    address public accountImplementation;

    function run() public {
        uint256 deployerPrivateKey = VM.envUint("PRIVATE_KEY");
        address deployer = VM.addr(deployerPrivateKey);
        DeployConfig.ChainConfig memory config = DeployConfig.getConfig(block.chainid);

        require(CREATE2_DEPLOYER.code.length > 0, "CREATE2 deployer not available on this chain");

        console2.log("========================================");
        console2.log("Universal7702 Deployment");
        console2.log("========================================");
        console2.log("Chain ID", block.chainid);
        console2.log("Chain", config.name);
        console2.log("Deployer", deployer);

        address expectedAccount = computeAddress();
        console2.log("Expected account implementation", expectedAccount);

        VM.startBroadcast(deployerPrivateKey);

        bytes32 accountSalt = keccak256(abi.encodePacked(DEPLOYMENT_SALT, "Universal7702Account"));
        bytes memory accountBytecode = type(Universal7702Account).creationCode;
        accountImplementation = _deployContract(accountSalt, accountBytecode, "Universal7702Account");
        require(accountImplementation == expectedAccount, "Universal7702Account address mismatch");

        VM.stopBroadcast();

        console2.log("========================================");
        console2.log("Deployment Complete");
        console2.log("========================================");
        console2.log("Account implementation", accountImplementation);
    }

    function preview() public view {
        address deployer = _resolveDeployer();
        DeployConfig.ChainConfig memory config = DeployConfig.getConfig(block.chainid);
        address expectedAccount = computeAddress();

        console2.log("========================================");
        console2.log("Universal7702 Deployment Preview");
        console2.log("========================================");
        console2.log("Chain ID", block.chainid);
        console2.log("Chain", config.name);
        console2.log("Deployer", deployer);
        console2.log("Create2 deployer", CREATE2_DEPLOYER);
        console2.log("Expected account implementation", expectedAccount);
        console2.log("Account implementation deployed", expectedAccount.code.length > 0);
    }

    function computeAddress() public pure returns (address expectedAccount) {
        bytes32 accountSalt = keccak256(abi.encodePacked(DEPLOYMENT_SALT, "Universal7702Account"));
        bytes memory accountBytecode = type(Universal7702Account).creationCode;
        expectedAccount = _computeAddress(accountSalt, accountBytecode);
    }

    function _resolveDeployer() internal view returns (address deployer) {
        deployer = VM.envOr("DEPLOYER_ADDRESS", address(0));
        if (deployer == address(0)) {
            try VM.envUint("PRIVATE_KEY") returns (uint256 pk) {
                deployer = VM.addr(pk);
            } catch {
                revert("DEPLOYER_ADDRESS or PRIVATE_KEY required");
            }
        }
    }

    function _deployContract(bytes32 salt, bytes memory bytecode, string memory name)
        internal
        returns (address deployed)
    {
        address expected = _computeAddress(salt, bytecode);

        if (expected.code.length > 0) {
            console2.log(string.concat("[SKIP] ", name, " already deployed"), expected);
            return expected;
        }

        bytes memory deployData = abi.encodePacked(salt, bytecode);
        (bool success, bytes memory result) = CREATE2_DEPLOYER.call(deployData);
        require(success, string.concat(name, " deployment failed"));
        require(result.length == 20, string.concat(name, " unexpected return length"));

        assembly {
            deployed := mload(add(result, 20))
        }

        require(deployed == expected, string.concat(name, " address mismatch"));
        require(deployed.code.length > 0, string.concat(name, " deployment failed - no code"));

        console2.log(string.concat("[OK] ", name, " deployed"), deployed);
    }

    function _computeAddress(bytes32 salt, bytes memory bytecode) internal pure returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), CREATE2_DEPLOYER, salt, keccak256(bytecode)))))
        );
    }
}
