//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol";

contract AuctionClub is IERC721Receiver{

    struct Auction{
        address creator;
        address[] bidders;
        uint[] bids;
        address tokenAddress;
        address topBidder;
        uint auctionId;
        uint tokenId;
        uint topBid;
        uint duration;
        uint startTime;
        uint endTime;
        uint reservePrice;
        // uint _auctionId;
        string status;
        bool settled;
    }

    uint private nextAuctionId;
    bytes constant active = "Active";
    bytes constant closed = "Closed";
    
    Auction[] internal userAuctions;
     Auction[] activeAuctions;
    // storage for all auctions ever created by an address
    mapping(address => uint[]) auctions;

    // Storage for all auctions using id as key
    mapping(uint => Auction) _auctions;

    // array containing all ever created auctions for reference
    Auction[] internal allAuctions;
    

    function getOwner(address nftContract, uint _id) internal returns(address _balance){
        bytes memory payload = abi.encodeWithSignature(
            "ownerOf(uint256)", _id
            
        );

        (bool success, bytes memory data) = nftContract.call(payload);
        require(success, "Failed to get nft balance");

        assembly {
            _balance := mload(add(data, 32))
        }

    }

     function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4){
        operator;
        from;
        tokenId;
        data;
        return IERC721Receiver.onERC721Received.selector;

    }


    function transferNft(address nftContract, address _from, address _to, uint _id) internal returns(bool, bytes memory){
        bytes memory payload = abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", _from,
        _to, _id);
        (bool success, bytes memory data) = nftContract.call(payload);
        // assembly {
        //     _data := mload(add(data, 32))
        // }
        return (success, data);
    }

    error NotYourNft(uint _nftId, address _owner);

    event CreateAuction(address _creator, uint _auctionId, address _tokenAddress, uint _tokenId);


// Create ERC721 auction

    function createAuction(address _nftContract, uint _tokenId, uint _reservePrice, uint _durationInSeconds) external{
        uint duration = _durationInSeconds;
        delete activeAuctions;

        // Ensure the user owns the nft they are about to auction

        address owner = getOwner(_nftContract, _tokenId);
        if(owner != msg.sender){
            revert NotYourNft(_tokenId, owner);
        }

        // Safely transfer the NFT out of the user's wallet to this contract
        // * Requires the user approve this contract address to allow transfer of ERC721
        (bool success,) = transferNft(_nftContract, msg.sender, address(this), _tokenId);
        require(success, "Transfer Failure");

        
        // Initiate the auction and add it to the list of auctions held by user
        // uint _auctionId = nextAuctionIndex;
        nextAuctionId++;
        Auction storage newAuction = allAuctions.push();
        auctions[msg.sender].push(nextAuctionId); 
        newAuction.creator = msg.sender;
        newAuction.tokenId = _tokenId;
        newAuction.auctionId = nextAuctionId;
        // newAuction._auctionId = nextAuctionId;
        newAuction.duration = duration;
        uint _startTime = block.timestamp;
        newAuction.startTime = _startTime;
        uint _endTime = _startTime + duration;
        newAuction.endTime = _endTime;
        newAuction.tokenAddress = _nftContract;  
        newAuction.reservePrice = _reservePrice;
        newAuction.status = "Active";

         for(uint i=0; i < allAuctions.length; i++){
            if( keccak256(bytes(allAuctions[i].status)) == keccak256(active)){
                activeAuctions.push(allAuctions[i]);
            }
        }
       //  _auctions[nextAuctionId] = newAuction; 
        emit CreateAuction(msg.sender, newAuction.auctionId, _nftContract, _tokenId);

    }

    
// Return only active auctions

    function getActiveAuctions() public view returns(Auction[] memory){
        require(allAuctions.length > 0, "No Auctions Created yet");
        // delete activeAuctions;
        return activeAuctions;
    }


    error SelfBid();


// Allow users to place bid on a particular auction using the auctionId
// Auction creators cannot bid on their auctions

    function placeBid(uint auctionId) external payable returns(string memory){
        if(msg.sender == allAuctions[auctionId - 1].creator){
            revert SelfBid();
        }
        require(block.timestamp < allAuctions[auctionId - 1].endTime, "AuctionEnded");

        // If no prior bids on auction, ensure that the reserve price is met
        if(allAuctions[auctionId - 1].bidders.length == 0){
            require(msg.value >= allAuctions[auctionId - 1].reservePrice, "Bid smaller than reserve price");
        }
        // Ensure that bid is greater than current top bid otherwise 
        else{
            require(msg.value > allAuctions[auctionId -1].topBid, "Bid too small");
        }
    
        allAuctions[auctionId - 1].bidders.push(msg.sender);
        allAuctions[auctionId - 1].bids.push(msg.value);
        allAuctions[auctionId - 1].topBid = msg.value;
        allAuctions[auctionId - 1].topBidder = msg.sender;
        delete activeAuctions;
        for(uint i=0; i < allAuctions.length; i++){
            if(keccak256(bytes(allAuctions[i].status)) == keccak256(active)){
                activeAuctions.push(allAuctions[i]);
        }
        }

        return "Bid Placed Successfully!";
 }

    
// Return current top bidder on an auction

    function getTopBidder(uint _auctionId) public view returns(address, uint){
        return (allAuctions[_auctionId - 1].topBidder, allAuctions[_auctionId - 1].topBid);
    }
    

    modifier onlyCreator(uint _auctionId, address _caller){
        require(_caller == allAuctions[_auctionId - 1].creator, "Not Creator");
        _;
    }

    error AuctionNotEnded(uint _auctionId);
    event AuctionSettled(uint _auctionId);


/* Only called by auction creator;
This function is called byt the creator when auction ends in other to set the auction status to "ended"
Creators can claim their funds by manually calling this function, or when the auction winner calls "Claim"
*/
    function settleAuction(uint _auctionId) onlyCreator(_auctionId, msg.sender) external returns(bool, string memory){
        bool success;
        if(block.timestamp >= allAuctions[_auctionId - 1].endTime){
            require(allAuctions[_auctionId - 1].settled == false, "Funds Sent Already, Check Wallet");
            for(uint i = 0; i < allAuctions[_auctionId - 1].bidders.length; i++){
                if(allAuctions[_auctionId - 1].bidders[i] == allAuctions[_auctionId - 1].topBidder){
                    (success,) = msg.sender.call{value: allAuctions[_auctionId - 1].topBid}("");
                }
                else{
                    (success,) = payable(allAuctions[_auctionId - 1].bidders[i]).call{value: allAuctions[_auctionId - 1].bids[i]}("");
                }
                
            }
            
            allAuctions[_auctionId - 1].settled = true;
            emit AuctionSettled(_auctionId);
            if(keccak256(bytes(allAuctions[_auctionId - 1].status)) != keccak256(closed)){
                if(allAuctions[_auctionId - 1].bidders.length == 0){
                    (bool _success,) = transferNft(allAuctions[_auctionId - 1].tokenAddress, address(this), allAuctions[_auctionId - 1].creator,
                allAuctions[_auctionId - 1].tokenId);
                _success;
                }
                else{
                    (bool _success,) = transferNft(allAuctions[_auctionId - 1].tokenAddress, address(this), allAuctions[_auctionId - 1].topBidder,
                    allAuctions[_auctionId - 1].tokenId);
                    allAuctions[_auctionId - 1].status = "Closed";
                    _success;
                }
            
            }

            delete activeAuctions;
            for(uint i=0; i < allAuctions.length; i++){
                if( keccak256(bytes(allAuctions[i].status)) == keccak256(active)){
                    activeAuctions.push(allAuctions[i]);
            }
        }
            return(success, "Auction Settled");
        }

        else{
            revert AuctionNotEnded(_auctionId);
        }
    }


    modifier onlyWinner(address _caller, uint _auctionId){
        require(allAuctions[_auctionId - 1].topBidder == _caller);
        _;
    }

/* Only auction winners can call claim;
 once called, it automatically settles the auction by calling "settle()" which sends the funds
 to the creator. 

 Auction winners can claim their Nfts by manually calling this function, or when the creator calls "settle()"
*/
    // function claim(uint _auctionId) onlyWinner(msg.sender, _auctionId) external returns(string memory){

    // }
    receive() external payable { }
    // function cancelAuction(uint _auctionId) onlyCreator(_auctionId, msg.sender) external{

    // }
    
}

