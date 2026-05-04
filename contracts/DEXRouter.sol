// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DEXRouter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Pair {
        address token0; address token1;
        uint256 reserve0; uint256 reserve1;
        uint256 totalSupply; uint256 fee;
        bool exists;
    }

    mapping(bytes32 => Pair) public pairs;
    mapping(bytes32 => mapping(address => uint256)) public lpBalances;

    event Swap(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event LiquidityAdded(address indexed user, bytes32 pairId, uint256 amount0, uint256 amount1, uint256 lpTokens);

    constructor() Ownable(msg.sender) {}

    function getPairId(address _t0, address _t1) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_t0 < _t1 ? _t0 : _t1, _t0 < _t1 ? _t1 : _t0));
    }

    function createPair(address _token0, address _token1, uint256 _fee) external onlyOwner {
        bytes32 pairId = getPairId(_token0, _token1);
        require(!pairs[pairId].exists, "Pair exists");
        pairs[pairId] = Pair(_token0 < _token1 ? _token0 : _token1, _token0 < _token1 ? _token1 : _token0, 0, 0, 0, _fee, true);
    }

    function addLiquidity(address _token0, address _token1, uint256 _amount0, uint256 _amount1) external nonReentrant returns (uint256 lpTokens) {
        bytes32 pairId = getPairId(_token0, _token1);
        Pair storage pair = pairs[pairId];
        require(pair.exists, "Pair not found");
        IERC20(pair.token0).safeTransferFrom(msg.sender, address(this), _amount0);
        IERC20(pair.token1).safeTransferFrom(msg.sender, address(this), _amount1);
        if (pair.totalSupply == 0) { lpTokens = _sqrt(_amount0 * _amount1); }
        else { lpTokens = (_amount0 * pair.totalSupply) / pair.reserve0; }
        pair.reserve0 += _amount0; pair.reserve1 += _amount1;
        pair.totalSupply += lpTokens; lpBalances[pairId][msg.sender] += lpTokens;
        emit LiquidityAdded(msg.sender, pairId, _amount0, _amount1, lpTokens);
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn) external nonReentrant returns (uint256 amountOut) {
        bytes32 pairId = getPairId(_tokenIn, _tokenOut);
        Pair storage pair = pairs[pairId];
        require(pair.exists, "Pair not found");
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
        bool isToken0In = _tokenIn == pair.token0;
        uint256 reserveIn = isToken0In ? pair.reserve0 : pair.reserve1;
        uint256 reserveOut = isToken0In ? pair.reserve1 : pair.reserve0;
        uint256 amountInWithFee = _amountIn * (10000 - pair.fee);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 10000 + amountInWithFee);
        if (isToken0In) { pair.reserve0 += _amountIn; pair.reserve1 -= amountOut; IERC20(pair.token1).safeTransfer(msg.sender, amountOut); }
        else { pair.reserve1 += _amountIn; pair.reserve0 -= amountOut; IERC20(pair.token0).safeTransfer(msg.sender, amountOut); }
        emit Swap(msg.sender, _tokenIn, _tokenOut, _amountIn, amountOut);
    }

    function getAmountOut(address _tokenIn, address _tokenOut, uint256 _amountIn) external view returns (uint256) {
        Pair storage pair = pairs[getPairId(_tokenIn, _tokenOut)];
        if (!pair.exists) return 0;
        bool isToken0In = _tokenIn == pair.token0;
        uint256 reserveIn = isToken0In ? pair.reserve0 : pair.reserve1;
        uint256 reserveOut = isToken0In ? pair.reserve1 : pair.reserve0;
        return (_amountIn * (10000 - pair.fee) * reserveOut) / (reserveIn * 10000 + _amountIn * (10000 - pair.fee));
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2; uint256 y = x;
        while (z < y) { y = z; z = (x / z + z) / 2; }
        return y;
    }
}