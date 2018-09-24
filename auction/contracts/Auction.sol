pragma solidity ^0.4.8;

contract Sorter{

    uint[10][10] public mainValues;
    address[] bidderAddresses;

    struct bidderStruct {
        uint index;
    }
    
    mapping(address => bidderStruct) private bidderStructs;
 
    function set(uint[10][10] _mainValues, address[] _bidderAddresses) {
        mainValues = _mainValues;
        bidderAddresses = _bidderAddresses; 
    }
    
    function set_bidderStructs() {
        for (uint id = 0; id < bidderAddresses.length ; id++){
            bidderStructs[bidderAddresses[id]].index = id;
        }
    }

    function sort() public returns(address[]) {
        
        set_bidderStructs();
        address[] storage data = bidderAddresses;
        if (data.length >= 2){
            quickSort(data, 0, int(data.length - 1));
        }

        return data;
    }
    
    function quickSort(address[] arr, int left, int right) internal {
        int i = left;
        int j = right;
        if(i==j) return;
        uint pivot = bidderStructs[arr[uint(left + (right - left) / 2)]].index;
        while (i <= j) {
            while (mainValues[bidderStructs[arr[uint(i)]].index][pivot] == 2) i++;
            while (mainValues[pivot][bidderStructs[arr[uint(i)]].index] == 2) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
        
    }
    
}

contract Auction{
    
    address public auctioneerAddress;
    uint q;
    uint[] M;
    bool auctioneerRegistered;
    // constructor function
    // constructor(uint _q, uint[] _M) public {
    //     auctioneerAddress = msg.sender;
    //     q = _q;
    //     M = _M;
    //     auctioneerRegistered = true;
    // }

    modifier onlyBy(address _account) {
        require(msg.sender == _account);
        _;
    }

    modifier onlyBefore(uint _time) {
        require(now < _time);
        _;
    }

    modifier onlyAfter(uint _time) {
        require(now > _time);
        _;
    }

    constructor() public {
        auctioneerAddress = msg.sender;
        // q = _q;
        // M = _M;
        auctioneerRegistered = true;
    }
    function sendParams(uint _q, uint[] _M) public onlyBy(auctioneerAddress) returns (bool) {
        q = _q;
        M = _M;
        return true;
    }    
    
    // Parameters of auction
    uint public numNotaries = 0;
    uint public numBidders = 0;
    
    function auctioneerExists () public view returns (address) {
        return auctioneerAddress;
    }
    
    //  Notary registration work
    struct notaryStruct {
        uint index;
        uint bidderIndex;
        uint[] retArray;
    }
    
    mapping(address => notaryStruct) public notaryStructs;
    address[] public notaryAddresses;
    event LogNewNotary (address indexed notaryAddress, uint index, uint bidderIndex);
    
    //  checking whether the notary is already registered or not
    function isNotary(address notaryAddress) public constant returns(bool) {
        if(notaryAddresses.length == 0) return false;
        return (notaryAddresses[notaryStructs[notaryAddress].index] == notaryAddress);
    }
    
    //  registering notaries
    function registerNotaries(address notaryAddress) public returns (bool){
        if(isNotary(notaryAddress) == false){
            notaryAddresses.push(notaryAddress);
            notaryStructs[notaryAddress].index = notaryAddresses.length - 1;
            notaryStructs[notaryAddress].bidderIndex = 0;
            emit LogNewNotary(notaryAddress, notaryAddresses.length, notaryStructs[notaryAddress].bidderIndex);
            return true;
        } 
        else{
            return false;
        }
        
    }

    function notariesLength () public view returns (uint) {
        return notaryAddresses.length;
    }
    
    // Structure for a bid where (u, v) are
    // the random representation of the ith item
    // such that x = (u+v)modq
    // And, where valuation_u, valuation_v are the 
    // random representation of valuation wi
    struct Bid {
        uint[] preferredItems;
        uint[] valuation;
    }
    
    struct bidderStruct {
        uint index;
    }
    
    mapping(address => bidderStruct) private bidderStructs;
    
    address[] public bidderAddresses;
    mapping(address => Bid) private bids;
    
    //  registering bidders
    event LogNewBidder   (address indexed bidderAddress, uint index);
    
    //  checking whether the bidder is already registered or not
    function isBidder(address bidderAddress) public constant returns(bool) {
        if(bidderAddresses.length == 0) return false;
        return (bidderAddresses[bidderStructs[bidderAddress].index] == bidderAddress);
    }
    
    //  registering bidders
    function registerBidders(address bidderAddress, uint[] preferredItems, uint[2] valuation) public returns (bool){
        if(isBidder(bidderAddress) == false){
            bidderStructs[bidderAddress].index = bidderAddresses.push(bidderAddress) - 1;
            bids[bidderAddress].preferredItems = preferredItems;
            bids[bidderAddress].valuation = valuation;
            
            emit LogNewBidder(
                bidderAddress, 
                bidderStructs[bidderAddress].index);
            return true;
        } 
        else{
            return false;
        }
    }

    function biddersLength () public view returns (uint) {
        return bidderAddresses.length;
    }
    // uint[] retArray1;
    //  assigning bidders to the notaries 
    function assignBidder(address notaryAddress) public returns (uint[]){
        //  simple i to i mapping
        // delete retArray1;
        uint ind;
        ind = notaryStructs[notaryAddress].index;
        notaryStructs[notaryAddress].bidderIndex = ind;
        notaryStructs[notaryAddress].retArray = bids[bidderAddresses[ind]].preferredItems;
        notaryStructs[notaryAddress].retArray.push(bids[bidderAddresses[ind]].valuation[0]);
        notaryStructs[notaryAddress].retArray.push(bids[bidderAddresses[ind]].valuation[1]);
        notaryStructs[notaryAddress].retArray.push(ind);
        return notaryStructs[notaryAddress].retArray;
    }

    function viewMapping(address notaryAddress) public view returns (uint[]) {
        return notaryStructs[notaryAddress].retArray;
    }
    
   //  Auctioneer will now send the precomputed values which they got by contacting offline with eachother
    uint sendVal = 0;
    uint[10][10] mainValues; //  considering there can be max 100 bidders
    function sendValues(uint[10][10] vals) public onlyBy(auctioneerAddress) returns (bool){
        uint i;
        uint j;
        if(sendVal == 0){
            for(i = 0; i < bidderAddresses.length; i++){
                for(j = 0; j < bidderAddresses.length; j++){
                    mainValues[i][j] = vals[i][j];
                }
            }
            sendVal = 1;
        }
        return true;
    }
    function verifyValues() public returns (bool) {
        if(sendVal == 1){
            return true;
        }
        else{
            return false;
        }    
    }

    address[] winnerAddresses;
    address[] bidder_Addresses;
    function whoIsTheWinner(uint[10][10] vals) public onlyBy(auctioneerAddress) returns (address[]){
        
        // sort(bidderAddresses);
        Sorter sorter = new Sorter();
        sorter.set(mainValues, bidderAddresses);
        
        // calling sort function from Sorter contract
        bidder_Addresses = sorter.sort();

        uint len = bidder_Addresses.length;
        uint i;
        uint j;
        for (i = 0; i < len / 2; i++) {
            j = len - 1 - i;
            (bidder_Addresses[i], bidder_Addresses[j]) = (bidder_Addresses[j], bidder_Addresses[i]);
        }
        
        uint[] set_union;
        // set_union.push(0);        
        for (i = 0; i < len; i++){
            uint idx = bidderStructs[bidder_Addresses[i]].index;
            if (set_union.length == 0) {
                winnerAddresses.push(bidder_Addresses[i]);
                set_union.push(idx);
            }
            
            else {
                uint flag = 1;
                uint k;
                
                for (k = 0; k < set_union.length; k++){
                    if (vals[set_union[k]][idx] == 1){
                        flag = 0;
                        break;
                    }
                }
                
                if (flag == 1){
                    winnerAddresses.push(bidder_Addresses[i]);
                    set_union.push(idx);
                }
            }
        }
        return winnerAddresses;
    }

    
}
