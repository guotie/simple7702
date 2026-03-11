// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal helper for deterministic CREATE2 deployments.
contract Create2Deployer {
    event Deployed(address indexed deployed, bytes32 indexed salt);

    function deploy(bytes32 salt, bytes memory bytecode) external returns (address deployed) {
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(deployed) { revert(0, 0) }
        }

        emit Deployed(deployed, salt);
    }

    function computeAddress(bytes32 salt, bytes32 bytecodeHash) external view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)))));
    }

    function computeAddressFromBytecode(bytes32 salt, bytes memory bytecode) external view returns (address) {
        return
            address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)))))
            );
    }
}
