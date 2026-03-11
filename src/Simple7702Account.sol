// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error ExpiredAction();
error InvalidArrayLength();
error InvalidExecutor(address executor);
error InvalidSignature();
error NonceAlreadyUsed(uint256 nonce);
error ReentrantCall();
error RegistryIsZeroAddress();
error TargetNotAllowed(address target);
error SponsorNotAllowed(address sponsor);

interface ISimple7702PolicyRegistry {
    function enableSponsorWhitelist() external view returns (bool);
    function enableTargetWhitelist() external view returns (bool);
    function sponsorWhitelist(address sponsor) external view returns (bool);
    function targetWhitelist(address target) external view returns (bool);
}

/// @notice 7702 delegate that lets a sponsor relay signed actions with per-wallet storage controls.
/// @dev Signatures are bound to target/value/dataHash/nonce/deadline/executor.
contract Simple7702Account {
    string public constant NAME = "Simple7702Account";
    string public constant VERSION = "1";
    bytes32 private constant NAME_HASH = keccak256("Simple7702Account");
    bytes32 private constant VERSION_HASH = keccak256("1");

    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant ACTION_TYPEHASH = keccak256(
        "Action(address target,uint256 value,bytes32 dataHash,uint256 nonce,uint256 deadline,address executor)"
    );
    bytes32 private constant LOW_S_MAX = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    // forge-lint: disable-next-line(screaming-snake-case-immutable)
    ISimple7702PolicyRegistry public immutable registry;
    mapping(uint256 => uint256) private nonceBitmap;

    uint256 private executionLock;

    struct Action {
        address target;
        uint256 value;
        bytes data;
        uint256 nonce;
        uint256 deadline;
        address executor;
    }

    event ActionExecuted(address indexed executor, address indexed target, uint256 value, uint256 nonce);
    event BatchExecuted(address indexed executor, uint256 actionCount);
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() internal {
        if (executionLock == 1) revert ReentrantCall();
        executionLock = 1;
    }

    function _nonReentrantAfter() internal {
        executionLock = 0;
    }

    constructor(address registryAddress) {
        if (registryAddress == address(0)) revert RegistryIsZeroAddress();
        registry = ISimple7702PolicyRegistry(registryAddress);
    }

    function domainSeparator() public view returns (bytes32) {
        bytes32 typeHash = EIP712_DOMAIN_TYPEHASH;
        bytes32 nameHash = NAME_HASH;
        bytes32 versionHash = VERSION_HASH;
        address verifyingContract = address(this);
        uint256 chainId = block.chainid;
        bytes32 result;

        assembly {
            let ptr := mload(0x40)
            mstore(ptr, typeHash)
            mstore(add(ptr, 0x20), nameHash)
            mstore(add(ptr, 0x40), versionHash)
            mstore(add(ptr, 0x60), chainId)
            mstore(add(ptr, 0x80), verifyingContract)
            mstore(0x40, add(ptr, 0xa0))
            result := keccak256(ptr, 0xa0)
        }

        return result;
    }

    function isNonceUsed(uint256 nonce) public view returns (bool) {
        uint256 word = nonceBitmap[nonce >> 8];
        uint256 mask = uint256(1) << (nonce & 0xff);
        return (word & mask) != 0;
    }

    function execute(Action calldata action, bytes calldata signature) external payable nonReentrant {
        _executeAction(action, signature);
    }

    function executeBatch(Action[] calldata actions, bytes[] calldata signatures) external payable nonReentrant {
        uint256 length = actions.length;
        if (length != signatures.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < length; ++i) {
            _executeAction(actions[i], signatures[i]);
        }

        emit BatchExecuted(msg.sender, length);
    }

    function _executeAction(Action calldata action, bytes calldata signature) private {
        _validateAction(action, signature);
        _useNonce(action.nonce);

        (bool success, bytes memory result) = action.target.call{value: action.value}(action.data);
        if (!success) _revertWithData(result);

        emit ActionExecuted(msg.sender, action.target, action.value, action.nonce);
    }

    function _validateAction(Action calldata action, bytes calldata signature) private view {
        if (action.executor != msg.sender) revert InvalidExecutor(msg.sender);
        if (block.timestamp > action.deadline) revert ExpiredAction();
        if (registry.enableSponsorWhitelist() && !registry.sponsorWhitelist(msg.sender)) {
            revert SponsorNotAllowed(msg.sender);
        }
        if (registry.enableTargetWhitelist() && !registry.targetWhitelist(action.target)) {
            revert TargetNotAllowed(action.target);
        }
        if (isNonceUsed(action.nonce)) revert NonceAlreadyUsed(action.nonce);

        address signer = _recoverSigner(action, signature);
        if (signer != address(this)) revert InvalidSignature();
    }

    function _useNonce(uint256 nonce) private {
        uint256 bucket = nonce >> 8;
        uint256 mask = uint256(1) << (nonce & 0xff);
        nonceBitmap[bucket] |= mask;
    }

    function _recoverSigner(Action calldata action, bytes calldata signature) internal view returns (address) {
        if (signature.length != 65) revert InvalidSignature();

        // bytes32 digest = _actionDigest(action);
        bytes32 digest = _actionDigestASM(action);

        bytes32 r = bytes32(signature[0:32]);
        bytes32 s = bytes32(signature[32:64]);
        uint8 v = uint8(signature[64]);

        if (uint256(s) > uint256(LOW_S_MAX)) revert InvalidSignature();
        if (v < 27) v += 27;
        if (v != 27 && v != 28) revert InvalidSignature();

        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
        return signer;
    }

    function _recoverSignerASM(Action calldata action, bytes calldata signature)
        internal
        view
        returns (address signer)
    {
        if (signature.length != 65) revert InvalidSignature();

        bytes32 digest = _actionDigestASM(action);
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 0x20))
            v := byte(0, calldataload(add(signature.offset, 0x40)))
        }

        if (uint256(s) > uint256(LOW_S_MAX)) revert InvalidSignature();
        if (v < 27) v += 27;
        if (v != 27 && v != 28) revert InvalidSignature();

        signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
    }

    function _actionDigestASM(Action calldata action) internal view returns (bytes32 digest) {
        address target = action.target;
        uint256 value = action.value;
        bytes calldata actionData = action.data;
        uint256 nonce = action.nonce;
        uint256 deadline = action.deadline;
        address executor = action.executor;
        bytes32 typeHash = ACTION_TYPEHASH;
        bytes32 domain = domainSeparator();

        assembly {
            let ptr := mload(0x40)
            let dataPtr := add(ptr, 0xe0)
            calldatacopy(dataPtr, actionData.offset, actionData.length)
            let dataHash := keccak256(dataPtr, actionData.length)

            mstore(ptr, typeHash)
            mstore(add(ptr, 0x20), target)
            mstore(add(ptr, 0x40), value)
            mstore(add(ptr, 0x60), dataHash)
            mstore(add(ptr, 0x80), nonce)
            mstore(add(ptr, 0xa0), deadline)
            mstore(add(ptr, 0xc0), executor)
            let structHash := keccak256(ptr, 0xe0)

            mstore(ptr, 0x1901000000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x02), domain)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
            mstore(0x40, add(dataPtr, actionData.length))
        }
    }

    function _revertWithData(bytes memory result) private pure {
        assembly {
            revert(add(result, 32), mload(result))
        }
    }

    receive() external payable {}
}
