// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DefiDexInterface is Ownable, ReentrancyGuard {
    // TODO: Implement Uniswap-style DEX frontend with swap, pool and limit order features
    constructor() Ownable(msg.sender) {}
}
