// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LeafPresale {

    uint constant MIM_units = 10 ** 18;
    uint constant LEAF_units = 10 ** 18;

    uint public constant PRESALE_MAX_TOKEN = 42800 * LEAF_units ;
    uint public constant DEFAULT_LEAF_PRICE = 7 * MIM_units / LEAF_units ;
    uint public constant MIN_PER_ACCOUNT = 7 * LEAF_units;
    uint public constant MAX_PER_ACCOUNT = 135 * LEAF_units;

    ERC20 MIM;

    mapping (address => bool) private whiteListedMap;

    address public owner;
    ERC20 public PRESALE_LEAF_TOKEN;
    uint public presale_sold;
    bool public presale_enable;
    bool public presale_claim_enable;

    mapping( address => uint256 ) private totalSold;

    struct Claim {
        uint256 lastClaimed;
        uint256 amountClaimable;
        uint256 totalClaimed;
    }

    mapping( address => Claim ) private dailyClaimed;

    address[] private multisig_addresses;
    mapping( address => bool ) private multiSig;

    constructor(address[] memory _owners) {
        MIM = ERC20(0x130966628846BFd36ff31a822705796e8cb8C18D);
        owner = msg.sender;
        multisig_addresses = _owners;
    }

    modifier isOwner() {
      require(msg.sender == owner, "You need to be the owner");
      _;
    }

    function setPresaleState(bool _state) isOwner external {
        presale_enable = _state;
    }

    function setPresaleClaimState(bool _state) isOwner external {
        presale_claim_enable = _state;
    }

    function setPresaleToken(address _address) isOwner external {
        PRESALE_LEAF_TOKEN = ERC20(_address);
    }
        
    function canSign(address signer) private view returns (bool) {
        for(uint256 i = 0; multisig_addresses.length > i; i++ ) {
            if(multisig_addresses[i] == signer) {
                return true;
            }
        }
        return false;
    }

    function setSign(bool state) external {
        require(canSign(msg.sender), "Signer is not in the multisig");
        multiSig[msg.sender] = state;
    }

    function isAllSigned() public view returns (bool) {
        for(uint256 i = 0; multisig_addresses.length > i; i++ ) {
            if(!multiSig[multisig_addresses[i]]) {
                return false;
            }
        }
        return multisig_addresses.length > 0;
    }

    function transfer(address _recipient, uint256 _amount) isOwner public {
        require(isAllSigned(), "MultiSig required");
        MIM.transfer(_recipient, _amount);
    }

    function currentSold() external view returns (uint256) {
        return MIM.balanceOf(address(this));
    }
    
    function isWhiteListed(address recipient) public view returns (bool) {
        return whiteListedMap[recipient];
    }

    function setWhiteListed(address[] memory addresses) isOwner public {
        for(uint256 i = 0; addresses.length > i; i++ ) {
            whiteListedMap[addresses[i]] = true;
        }
    }

    function maxBuyable(address buyer) external view returns (uint) {
        return MAX_PER_ACCOUNT - totalSold[buyer];
    }

    function buyLeafToken(uint256 _amountIn) external {
        require(presale_enable, "Presale is not available yet!");
        require(isWhiteListed(msg.sender), "Not whitelised");
        require(presale_sold + _amountIn <= PRESALE_MAX_TOKEN, "No more token available (limit reached)");
        require(totalSold[msg.sender] + _amountIn >= MIN_PER_ACCOUNT, "Amount is not sufficient");
        require(_amountIn + totalSold[msg.sender] <= MAX_PER_ACCOUNT, "Amount buyable reached");

        presale_sold += _amountIn;
        MIM.transferFrom(msg.sender, address(this), _amountIn * DEFAULT_LEAF_PRICE);
        totalSold[msg.sender] += _amountIn;
    }

    // Get tokens bought by address
    function currentLeaf(address buyer) external view returns (uint) {
        return totalSold[buyer];
    }
    
    function claimLeafToken() external {
        require(presale_claim_enable, "Claim is not available yet!");
        require(totalSold[msg.sender] > dailyClaimed[msg.sender].totalClaimed, "No tokens to claim");
        require(dailyClaimed[msg.sender].lastClaimed < block.timestamp, "Daily claimed already transfered");

        dailyClaimed[msg.sender].amountClaimable = totalSold[msg.sender]* 25/100;
        
        uint amountOut = dailyClaimed[msg.sender].amountClaimable;

        if(dailyClaimed[msg.sender].totalClaimed + amountOut > totalSold[msg.sender]) {
            amountOut = totalSold[msg.sender] - dailyClaimed[msg.sender].totalClaimed;
        }

        PRESALE_LEAF_TOKEN.transfer(msg.sender, amountOut);
        dailyClaimed[msg.sender].totalClaimed += amountOut;
        dailyClaimed[msg.sender].lastClaimed = block.timestamp + 86400;
    }
}
