// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IERC20.sol";

contract CPAMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint public reserve0;
    uint public reserve1;

    uint public totalSupply;
    mapping(address => uint) public balanceOf;

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function _mint(address _to, uint _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    function _burn(address _from, uint _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    function _sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _update(uint _reserve0, uint _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function _min(uint _x, uint _y) private pure returns (uint) {
        return _x > _y? _y : _x;
    }

    function swap(address _tokenIn, uint _amountIn) external returns (uint amountOut) {
        require(_amountIn > 0, "Invalid Amount");
        require(_tokenIn == address(token0) || _tokenIn == address(token1), "Invalid token");
        
        bool isToken0 = _tokenIn == address(token0);
        (IERC20 tokenIn, IERC20 tokenOut) = 
            isToken0? (token0, token1) : (token1, token0);
        (uint reserveIn, uint reserveOut) = 
            isToken0? (reserve0, reserve1): (reserve1, reserve0);
        //转币到合约
        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        // 计算输出的数量
        amountOut = (_amountIn * reserveOut) / (reserveIn + _amountIn);
        // 转币给用户
        tokenOut.transfer(msg.sender, amountOut);
        // 更新自己的余额表
        _update(token0.balanceOf(address(this)),
                token1.balanceOf(address(this)));
    }

    function addLiquidity(uint _amount0, uint _amount1)
     external returns (uint shares) {
         require(_amount0 > 0 && _amount1 > 0, "Invalid amount");
         // 把token0 和 token1 转入到合约
         token0.transferFrom(msg.sender, address(this), _amount0);
         token1.transferFrom(msg.sender, address(this), _amount1);
         // 计算并mint share 给用户
         if (reserve0 > 0 || reserve1 > 0) {
             require(_amount0 * reserve1 == _amount1 * reserve0, "dy/dx != y/x");
         }

         if (totalSupply == 0) {
            shares = _sqrt(_amount0 * _amount1);
         } else {
            shares = _min(
                (_amount0 * totalSupply) / reserve0,
                (_amount1 * totalSupply) / reserve1
            ); 
         }
         require(shares > 0, "share is zero");
         _mint(msg.sender, shares);
         // 更新余额表
        _update(token0.balanceOf(address(this)),
                token1.balanceOf(address(this)));
     }

    function removeLiquidity(uint _shares) external 
    returns (uint amount0, uint amount1) {
        require(_shares > 0, "Invalid shares");
        // 计算dx 和dy的数量
        amount0 = (_shares * reserve0) / totalSupply;
        amount1 = (_shares * reserve1) / totalSupply;
        // 销毁用户的share
        _burn(msg.sender, _shares);
        // 把两个币转回给用户
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
        // 更新余额表
        _update(token0.balanceOf(address(this)),
                token1.balanceOf(address(this)));
    }
}
