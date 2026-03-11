// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Simple7702Account, ISimple7702PolicyRegistry} from "../src/Simple7702Account.sol";
import {Test} from "./Test.sol";

contract MockPolicyRegistry is ISimple7702PolicyRegistry {
    bool public enableSponsorWhitelist;
    bool public enableTargetWhitelist;

    mapping(address => bool) public sponsorWhitelist;
    mapping(address => bool) public targetWhitelist;

    function setSponsorWhitelistEnabled(bool enabled) external {
        enableSponsorWhitelist = enabled;
    }

    function setTargetWhitelistEnabled(bool enabled) external {
        enableTargetWhitelist = enabled;
    }

    function setSponsor(address sponsor, bool allowed) external {
        sponsorWhitelist[sponsor] = allowed;
    }

    function setTarget(address target, bool allowed) external {
        targetWhitelist[target] = allowed;
    }
}

contract Simple7702AccountHarness is Simple7702Account {
    constructor(address registryAddress) Simple7702Account(registryAddress) {}

    function recoverSignerReference(Action calldata action, bytes calldata signature) external view returns (address) {
        return _recoverSigner(action, signature);
    }

    function _actionDigest(Action calldata action) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                ACTION_TYPEHASH,
                action.target,
                action.value,
                keccak256(action.data),
                action.nonce,
                action.deadline,
                action.executor
            )
        );

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));
    }

    function recoverSignerASM(Action calldata action, bytes calldata signature) external view returns (address) {
        return _recoverSignerASM(action, signature);
    }

    function actionDigest(Action calldata action) external view returns (bytes32) {
        return _actionDigest(action);
    }

    function actionDigestASM(Action calldata action) external view returns (bytes32) {
        return _actionDigestASM(action);
    }
}

contract Simple7702AccountTest is Test {
    uint256 internal constant SIGNER_PRIVATE_KEY = 0xA11CE;

    MockPolicyRegistry internal registry;
    Simple7702AccountHarness internal account;
    address internal signer;

    function setUp() public {
        registry = new MockPolicyRegistry();
        account = new Simple7702AccountHarness(address(registry));
        signer = VM.addr(SIGNER_PRIVATE_KEY);
    }

    function testRecoverSignerAsmMatchesReference() public {
        Simple7702Account.Action memory action = _buildTransferAction(
            hex"a9059cbb0000000000000000000000009769713aa909c73914dac551c8d434ad84db941000000000000000000000000000000000000000000000000000000000004c4b40"
        );
        bytes memory signature = _signAction(action);
        bytes32 digestReference = account.actionDigest(action);
        bytes32 digestAsm = account.actionDigestASM(action);

        address recoveredReference = account.recoverSignerReference(action, signature);
        address recoveredAsm = account.recoverSignerASM(action, signature);

        assertEq(digestAsm, digestReference, "asm and reference digest mismatch");
        assertEq(recoveredReference, signer, "reference recovered wrong signer");
        assertEq(recoveredAsm, signer, "asm recovered wrong signer");
        assertEq(recoveredAsm, recoveredReference, "asm and reference signer mismatch");
    }

    function testRecoverSignerAsmMatchesReferenceWithLargeData() public {
        bytes memory payload = abi.encodeWithSignature(
            "multicall(bytes[],uint256)",
            _bytesArray(hex"1234", hex"abcdef", hex"00112233445566778899aabbccddeeff"),
            uint256(42)
        );
        Simple7702Account.Action memory action = _buildTransferAction(payload);
        bytes memory signature = _signAction(action);
        bytes32 digestReference = account.actionDigest(action);
        bytes32 digestAsm = account.actionDigestASM(action);

        address recoveredReference = account.recoverSignerReference(action, signature);
        address recoveredAsm = account.recoverSignerASM(action, signature);

        assertEq(digestAsm, digestReference, "asm and reference large-data digest mismatch");
        assertEq(recoveredReference, signer, "reference large-data signer mismatch");
        assertEq(recoveredAsm, signer, "asm large-data signer mismatch");
    }

    function testRecoverSignerAsmRevertsLikeReferenceOnInvalidLength() public view {
        Simple7702Account.Action memory action = _buildTransferAction(hex"12345678");
        bytes memory signature = new bytes(64);

        (bool referenceSuccess,) = address(account)
            .staticcall(abi.encodeCall(Simple7702AccountHarness.recoverSignerReference, (action, signature)));
        (bool asmSuccess,) =
            address(account).staticcall(abi.encodeCall(Simple7702AccountHarness.recoverSignerASM, (action, signature)));

        assertTrue(!referenceSuccess, "reference should revert on invalid length");
        assertTrue(!asmSuccess, "asm should revert on invalid length");
    }

    function testRecoverSignerAsmRevertsLikeReferenceOnHighS() public {
        Simple7702Account.Action memory action = _buildTransferAction(hex"deadbeef");
        bytes memory signature = _signAction(action);

        assembly {
            mstore(add(signature, 0x40), not(0))
        }

        (bool referenceSuccess,) = address(account)
            .staticcall(abi.encodeCall(Simple7702AccountHarness.recoverSignerReference, (action, signature)));
        (bool asmSuccess,) =
            address(account).staticcall(abi.encodeCall(Simple7702AccountHarness.recoverSignerASM, (action, signature)));

        assertTrue(!referenceSuccess, "reference should revert on high-s");
        assertTrue(!asmSuccess, "asm should revert on high-s");
    }

    function _buildTransferAction(bytes memory data) internal view returns (Simple7702Account.Action memory action) {
        action = Simple7702Account.Action({
            target: address(0x1234),
            value: 0,
            data: data,
            nonce: 7,
            deadline: block.timestamp + 600,
            executor: address(0xBEEF)
        });
    }

    function _signAction(Simple7702Account.Action memory action) internal returns (bytes memory) {
        bytes32 digest = account.actionDigest(action);
        (uint8 v, bytes32 r, bytes32 s) = VM.sign(SIGNER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _bytesArray(bytes memory a, bytes memory b, bytes memory c) internal pure returns (bytes[] memory arr) {
        arr = new bytes[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
    }
}
