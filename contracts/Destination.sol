// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./lzApp/NonblockingLzApp.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../node_modules/@openzeppelin/contracts/utils/Strings.sol";

contract NFTMint is NonblockingLzApp, ERC721Enumerable {
    using SafeMath for uint256;
    
    string public PROVENANCE = ""; // IPFS URL WILL BE ADDED WHEN NFTS ARE ALL SOLD OUT
    
    string public LICENSE_TEXT = ""; // IT IS WHAT IT SAYS
    
    bool licenseLocked = false; // TEAM CAN'T EDIT THE LICENSE AFTER THIS GETS TRUE

    uint256 public constant price = 50000000000000000; // 0.05 ETH

    uint public constant maxPurchase = 5;

    uint256 public constant MAX_NFTS = 100000;

    bool public saleIsActive = false;
    
    mapping(uint => string) public names;

    struct SrcDetails {
        bool allowed;
        uint256 feeIfFailed;
        uint256 feeInNative;
    }

    mapping(address => SrcDetails) public srcDetails;

    IERC20 public weth;
    // in case if the chain's native currency is ETH
    bool public ethChain;
    
    // Reserved NFTs
    uint public reserve = 100;
    
    event nameChange(address _by, uint _tokenId, string _name);
    
    event licenseisLocked(string _licenseText);

    constructor(
        address _lzEndpoint,
        string memory _name,
        string memory _symbol,
        bool _ethChain
    ) NonblockingLzApp(_lzEndpoint) ERC721(_name, _symbol) {
        ethChain = _ethChain;
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

    function setSrcDetails(
        address _srcAddress,
        bool _allowed,
        uint256 _feeIfFailed,
        uint256 _feeInNative
    ) public onlyOwner {
        srcDetails[_srcAddress].allowed = _allowed;
        srcDetails[_srcAddress].feeIfFailed = _feeIfFailed;
        srcDetails[_srcAddress].feeInNative = _feeInNative;
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
    
    
    function mint(uint numberOfTokens) public {
        require(saleIsActive, "Sale must be active to mint NFT");
        require(numberOfTokens > 0 && numberOfTokens <= maxPurchase, "Can only mint 5 tokens at a time");
        require(totalSupply().add(numberOfTokens) <= MAX_NFTS, "Purchase would exceed max supply of NFTs");

        weth.transferFrom(
            msg.sender,
            address(this),
            price.mul(numberOfTokens)
        );
        
        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_NFTS) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    function mintViaEth(uint numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint NFT");
        require(numberOfTokens > 0 && numberOfTokens <= maxPurchase, "Can only mint 5 tokens at a time");
        require(totalSupply().add(numberOfTokens) <= MAX_NFTS, "Purchase would exceed max supply of NFTs");
        require(numberOfTokens.mul(price) == msg.value, "not enough eth to mint");
        
        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_NFTS) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }
     
    function changeName(uint _tokenId, string memory _name) public {
        require(ownerOf(_tokenId) == msg.sender, "Hey, your wallet doesn't own this nft!");
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
        (address _user, uint256 _amountToMint) = abi.decode(_payload, (address, uint256));

        address srcAddress;
        assembly {
            srcAddress := mload(add(_srcAddress, 20))
        }

        require(srcDetails[srcAddress].allowed, "contract not allowed");

        
        if (totalSupply().add(_amountToMint) <= MAX_NFTS || saleIsActive) {
            bytes memory data = abi.encode(msg.sender, (_amountToMint * price) - srcDetails[srcAddress].feeIfFailed);
        
            _lzSend(
                _srcChainId, 
                data, 
                payable(_user), 
                address(0x0), 
                bytes(""),
                srcDetails[srcAddress].feeInNative
            );
        } else {
            for(uint i = 0; i < _amountToMint; i++) {
                uint mintIndex = totalSupply();
                if (totalSupply() < MAX_NFTS) {
                    _safeMint(msg.sender, mintIndex);
                }
            }
        }
    }
}