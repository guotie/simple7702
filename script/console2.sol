// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library console2 {
    address internal constant CONSOLE_ADDRESS = 0x000000000000000000636F6e736F6c652e6c6f67;

    function _send(bytes memory payload) private view {
        address consoleAddress = CONSOLE_ADDRESS;
        assembly {
            let payloadStart := add(payload, 32)
            let payloadLength := mload(payload)
            pop(staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0))
        }
    }

    function log(string memory value) internal view {
        _send(abi.encodeWithSignature("log(string)", value));
    }

    function log(address value) internal view {
        _send(abi.encodeWithSignature("log(address)", value));
    }

    function log(uint256 value) internal view {
        _send(abi.encodeWithSignature("log(uint256)", value));
    }

    function log(bool value) internal view {
        _send(abi.encodeWithSignature("log(bool)", value));
    }

    function log(string memory label, address value) internal view {
        _send(abi.encodeWithSignature("log(string,address)", label, value));
    }

    function log(string memory label, uint256 value) internal view {
        _send(abi.encodeWithSignature("log(string,uint256)", label, value));
    }

    function log(string memory label, bool value) internal view {
        _send(abi.encodeWithSignature("log(string,bool)", label, value));
    }

    function log(string memory label, string memory value) internal view {
        _send(abi.encodeWithSignature("log(string,string)", label, value));
    }
}
