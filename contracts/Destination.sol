// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./lzApp/NonblockingLzApp.sol";
import "./interfaces/IStargateRouter.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../node_modules/@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IStargateEthVault.sol";

contract NFTMint is NonblockingLzApp, ERC721Enumerable {
    using SafeMath for uint256;
    IStargateRouter public stargateRouter;
    IStargateEthVault public stargateEthVault;
    
    string public PROVENANCE = ""; // IPFS URL WILL BE ADDED WHEN NFTS ARE ALL SOLD OUT
    
    string public LICENSE_TEXT = ""; // IT IS WHAT IT SAYS
    
    bool licenseLocked = false; // TEAM CAN'T EDIT THE LICENSE AFTER THIS GETS TRUE

    uint256 public constant price = 50000000000000000; // 0.05 ETH

    uint public constant maxPurchase = 20;

    uint256 public constant MAX_NFTS = 100000;

    bool public saleIsActive = false;
    
    mapping(uint => string) public names;
    
    // Reserve 125 for team - Giveaways/Prizes etc
    uint public reserve = 100;
    
    event nameChange(address _by, uint _tokenId, string _name);
    
    event licenseisLocked(string _licenseText);

    constructor(
        address _lzEndpoint,
        address _stargateRouter,
        string memory _name,
        string memory _symbol,
        address _stargateEthVault
    ) NonblockingLzApp(_lzEndpoint) ERC721(_name, _symbol) {
        stargateRouter = IStargateRouter(_stargateRouter);
        stargateEthVault = IStargateEthVault(_stargateEthVault);
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
    
    function reserveNft(address _to, uint256 _reserveAmount) public onlyOwner {        
        uint supply = totalSupply();
        require(_reserveAmount > 0 && _reserveAmount <= reserve, "Not enough reserve left for team");
        for (uint i = 0; i < _reserveAmount; i++) {
            _safeMint(_to, supply + i);
        }
        reserve = reserve.sub(_reserveAmount);
    }


    function setProvenanceHash(string memory provenanceHash) public onlyOwner {
        PROVENANCE = provenanceHash;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        setBaseURI(baseURI);
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }
    
    function tokensOfOwner(address _owner) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }
    
    // Returns the license for tokens
    function tokenLicense(uint _id) public view returns(string memory) {
        require(_id < totalSupply(), "CHOOSE A NFT WITHIN RANGE");
        return LICENSE_TEXT;
    }
    
    // Locks the license to prevent further changes 
    function lockLicense() public onlyOwner {
        licenseLocked =  true;
        emit licenseisLocked(LICENSE_TEXT);
    }
    
    // Change the license
    function changeLicense(string memory _license) public onlyOwner {
        require(licenseLocked == false, "License already locked");
        LICENSE_TEXT = _license;
    }
    
    
    function mint(uint numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint NFT");
        require(numberOfTokens > 0 && numberOfTokens <= maxPurchase, "Can only mint 20 tokens at a time");
        require(totalSupply().add(numberOfTokens) <= MAX_NFTS, "Purchase would exceed max supply of Bananas");
        require(msg.value >= price.mul(numberOfTokens), "Ether value sent is not correct");
        
        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_NFTS) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }
     
    function changeName(uint _tokenId, string memory _name) public {
        require(ownerOf(_tokenId) == msg.sender, "Hey, your wallet doesn't own this banana!");
        require(sha256(bytes(_name)) != sha256(bytes(names[_tokenId])), "New name is same as the current one");
        names[_tokenId] = _name;
        
        emit nameChange(msg.sender, _tokenId, _name);
        
    }
    
    function viewName(uint _tokenId) public view returns( string memory ){
        require( _tokenId < totalSupply(), "Choose a NFT within range" );
        return names[_tokenId];
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId, 
        bytes memory _srcAddress, 
        uint64 _nonce, 
        bytes memory _payload
    ) internal override {

    }

    function sgReceive(
        uint16 _chainId, 
        bytes memory _srcAddress, 
        uint _nonce, 
        address _token, 
        uint amountLD, 
        bytes memory _payload
    ) external payable {
        require(_token == address(0), "sgReceive: only native token supported");
        require(msg.sender == address(stargateRouter), "Unauthorized");
        require(_amountLD > 0, "_amount must be greater than 0");

        // Approve & Unwrap ETH
        stargateEthVault.approve(address(stargateEthVault), _amountLD);
        stargateEthVault.withdraw(_amountLD);

        (address _depositor) = abi.decode(_payload, (address));

        uint256 _amountToMint = _amountLD.div(price);

        if (totalSupply().add(_amountToMint) <= MAX_NFTS) {
            payable(_depositor).transfer(amountLD);
        } else {
            for(uint i = 0; i < amount; i++) {
                uint mintIndex = totalSupply();
                if (totalSupply() < MAX_NFTS) {
                    _safeMint(_depositor, mintIndex);
                }
            }
        }
    }
}