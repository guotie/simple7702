// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "./Script.sol";
import {console2} from "./console2.sol";
import {DeployConfig} from "./config/DeployConfig.sol";

import {Simple7702Account} from "../src/Simple7702Account.sol";
import {Simple7702PolicyRegistry} from "../src/Simple7702PolicyRegistry.sol";

/// @notice Deployment script for the Simple7702 policy registry and account implementation.
/// @dev Mirrors the GridEx pattern: preview expected addresses first, then deploy via the deterministic deployment proxy.
contract Deploy is Script {
    bytes32 public constant DEPLOYMENT_SALT = keccak256("Simple7702.v1");
    address public constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    address public policyRegistry;
    address public accountImplementation;

    function run() public {
        uint256 deployerPrivateKey = VM.envUint("PRIVATE_KEY");
        address deployer = VM.addr(deployerPrivateKey);
        address policyOwner = VM.envOr("POLICY_OWNER", deployer);
        DeployConfig.ChainConfig memory config = DeployConfig.getConfig(block.chainid);

        require(CREATE2_DEPLOYER.code.length > 0, "CREATE2 deployer not available on this chain");

        console2.log("========================================");
        console2.log("Simple7702 Deployment");
        console2.log("========================================");
        console2.log("Chain ID", block.chainid);
        console2.log("Chain", config.name);
        console2.log("Deployer", deployer);
        console2.log("Policy owner", policyOwner);

        (address expectedRegistry, address expectedAccount) = computeAddresses(policyOwner);
        console2.log("Expected policy registry", expectedRegistry);
        console2.log("Expected account implementation", expectedAccount);

        VM.startBroadcast(deployerPrivateKey);

        bytes32 registrySalt = keccak256(abi.encodePacked(DEPLOYMENT_SALT, "Simple7702PolicyRegistry"));
        bytes memory registryBytecode =
            abi.encodePacked(type(Simple7702PolicyRegistry).creationCode, abi.encode(policyOwner));
        policyRegistry = _deployContract(registrySalt, registryBytecode, "Simple7702PolicyRegistry");
        require(policyRegistry == expectedRegistry, "Policy registry address mismatch");

        bytes32 accountSalt = keccak256(abi.encodePacked(DEPLOYMENT_SALT, "Simple7702Account"));
        bytes memory accountBytecode =
            abi.encodePacked(type(Simple7702Account).creationCode, abi.encode(policyRegistry));
        accountImplementation = _deployContract(accountSalt, accountBytecode, "Simple7702Account");
        require(accountImplementation == expectedAccount, "Simple7702Account address mismatch");

        VM.stopBroadcast();

        console2.log("========================================");
        console2.log("Deployment Complete");
        console2.log("========================================");
        console2.log("Policy registry", policyRegistry);
        console2.log("Policy registry owner", Simple7702PolicyRegistry(policyRegistry).owner());
        console2.log("Account implementation", accountImplementation);
        console2.log(
            "Account implementation registry", address(Simple7702Account(payable(accountImplementation)).registry())
        );
    }

    function preview() public view {
        address deployer = _resolveDeployer();
        address policyOwner = _resolvePolicyOwner(deployer);
        DeployConfig.ChainConfig memory config = DeployConfig.getConfig(block.chainid);
        (address expectedRegistry, address expectedAccount) = computeAddresses(policyOwner);

        console2.log("========================================");
        console2.log("Simple7702 Deployment Preview");
        console2.log("========================================");
        console2.log("Chain ID", block.chainid);
        console2.log("Chain", config.name);
        console2.log("Deployer", deployer);
        console2.log("Policy owner", policyOwner);
        console2.log("Create2 deployer", CREATE2_DEPLOYER);
        console2.log("Expected policy registry", expectedRegistry);
        console2.log("Expected account implementation", expectedAccount);
        console2.log("Policy registry deployed", expectedRegistry.code.length > 0);
        console2.log("Account implementation deployed", expectedAccount.code.length > 0);
    }

    function computeAddresses(address policyOwner)
        public
        pure
        returns (address expectedRegistry, address expectedAccount)
    {
        bytes32 registrySalt = keccak256(abi.encodePacked(DEPLOYMENT_SALT, "Simple7702PolicyRegistry"));
        bytes memory registryBytecode =
            abi.encodePacked(type(Simple7702PolicyRegistry).creationCode, abi.encode(policyOwner));
        expectedRegistry = _computeAddress(registrySalt, registryBytecode);

        bytes32 accountSalt = keccak256(abi.encodePacked(DEPLOYMENT_SALT, "Simple7702Account"));
        bytes memory accountBytecode =
            abi.encodePacked(type(Simple7702Account).creationCode, abi.encode(expectedRegistry));
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

    function _resolvePolicyOwner(address deployer) internal view returns (address) {
        return VM.envOr("POLICY_OWNER", deployer);
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
