// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ZakatHook is BaseHook {
    address public zakatWallet;
    mapping(address => bool) public zakatEcosystemWallets;

    constructor(IPoolManager _manager, address _zakatWallet) BaseHook(_manager) {
        zakatWallet = _zakatWallet;
    }

    /// Define which hook events to listen to
    function getHookFlags() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeModifyPosition: false,
            afterModifyPosition: false,
            beforeSwap: true, // we want to deduct 2.5% before swap executes
            afterSwap: true, // to perform analytics or logging
            beforeDonate: false,
            afterDonate: false
        });
    }

    /// @notice Before swap, deduct 2.5% from output amount
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    ) external override returns (bytes4) {
        // Determine which token is being output
        address outputToken = params.zeroForOne ? key.currency1 : key.currency0;

        // Only process if sender is in ecosystem list
        if (zakatEcosystemWallets[sender]) {
            // Calculate 2.5%
            uint256 amountOut = uint256(params.amountSpecified < 0 ? -params.amountSpecified : params.amountSpecified);
            uint256 zakatAmount = (amountOut * 25) / 1000; // 2.5%

            // Transfer zakatAmount to zakat wallet
            IERC20(outputToken).transfer(zakatWallet, zakatAmount);
        }

        return BaseHook.beforeSwap.selector;
    }

    /// @notice After swap, just log results
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata data
    ) external override returns (bytes4) {
        // Example: only act if sender is ecosystem wallet
        if (zakatEcosystemWallets[sender]) {
            emit SwapWithZakat(sender, delta.amount0(), delta.amount1());
        }

        return BaseHook.afterSwap.selector;
    }

    /// Manage access
    function setEcosystemWallet(address user, bool status) external onlyOwner {
        zakatEcosystemWallets[user] = status;
    }

    event SwapWithZakat(address indexed sender, int128 amount0, int128 amount1);
}
