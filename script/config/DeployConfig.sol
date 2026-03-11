// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library DeployConfig {
    struct ChainConfig {
        uint256 chainId;
        string name;
        string rpcEnvVar;
        string explorerApiKeyEnvVar;
        string explorerUrl;
    }

    function polygonAmoy() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            chainId: 80002,
            name: "Polygon Amoy",
            rpcEnvVar: "POLYGON_AMOY_RPC_URL",
            explorerApiKeyEnvVar: "POLYGONSCAN_API_KEY",
            explorerUrl: "https://amoy.polygonscan.com"
        });
    }

    function getConfig(uint256 chainId) internal pure returns (ChainConfig memory) {
        if (chainId == 80002) return polygonAmoy();
        revert("Unsupported chain");
    }
}
