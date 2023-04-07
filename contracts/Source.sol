// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./lzApp/NonblockingLzApp.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStargateRouter.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IStargateEthVault.sol";

contract Source is NonblockingLzApp {
    using SafeMath for uint256;

    uint256 constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    IStargateRouter public stargateRouter;
    // Address of Destination contract where all the money will be sent
    address public destination;
    // Price for each NFT
    uint256 public constant price = 50000000000000000; // 0.05 ETH
    // Maximum amount of NFTs mintable in one transaction
    uint public constant maxPurchase = 20;
    // Chain id of Destination Chain
    uint16 dstChainId;
    // Chain id of Source Chain
    uint256 srcPoolId;
    // Pool id of the Destination Chain
    uint256 dstPoolId;
    // Stargate ETH Vault
    IStargateEthVault public stargateEthVault;

    constructor(
        address _lzEndpoint,
        address _stargateRouter,
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address _stargateEthVault
    ) NonblockingLzApp(_lzEndpoint) {
        require(_stargateEthVault != address(0x0), "RouterETH: _stargateEthVault cant be 0x0");
        require(_stargateRouter != address(0x0), "RouterETH: _stargateRouter cant be 0x0");
        
        stargateRouter = IStargateRouter(_stargateRouter);
        stargateEthVault = IStargateEthVault(_stargateEthVault);
        dstChainId = _dstChainId;
        srcPoolId = _srcPoolId;
        dstPoolId = _dstPoolId;
    }

    function omniMint(uint256 _amount, uint256 _fee) public payable {
        require(_amount > 0, "need _amount > 0");
        uint256 cost = _amount.mul(price);
        require(msg.value > (cost + _fee), "stargate requires fee to pay crosschain message");
        
        bytes memory data = abi.encode(msg.sender);

        // wrap the ETH into WETH
        IStargateEthVault(stargateEthVault).deposit{value: cost}();
        IStargateEthVault(stargateEthVault).approve(address(stargateRouter), MAX_INT);

        // Stargate's Router.swap() function sends the tokens to the destination chain.
        stargateRouter.swap{value:_fee}(
            dstChainId,                                     // the destination chain id
            srcPoolId,                                      // the source Stargate poolId
            dstPoolId,                                      // the destination Stargate poolId
            payable(msg.sender),                            // refund adddress. if msg.sender pays too much gas, return extra eth
            cost,                                           // total tokens to send to destination chain
            cost,                                            // min amount allowed out
            IStargateRouter.lzTxObj(200000, 0, "0x"),       // default lzTxObj
            abi.encodePacked(destination),                   // destination address 
            data                                            // bytes payload
        );
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId, 
        bytes memory _srcAddress, 
        uint64 _nonce, 
        bytes memory _payload
    ) internal override {

    }
}