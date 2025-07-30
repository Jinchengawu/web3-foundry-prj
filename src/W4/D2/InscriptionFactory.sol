/*实现⼀个可升级的工厂合约，工厂合约有两个方法：

deployInscription(string symbol, uint totalSupply, uint perMint) ，该方法用来创建 ERC20 token，（模拟铭文的 deploy）， symbol 表示 Token 的名称，totalSupply 表示可发行的数量，perMint 用来控制每次发行的数量，用于控制mintInscription函数每次发行的数量
mintInscription(address tokenAddr) 用来发行 ERC20 token，每次调用一次，发行perMint指定的数量。
要求：
• 合约的第⼀版本用普通的 new 的方式发行 ERC20 token 。
• 第⼆版本，deployInscription 加入一个价格参数 price  deployInscription(string symbol, uint totalSupply, uint perMint, uint price) , price 表示发行每个 token 需要支付的费用，并且 第⼆版本使用最小代理的方式以更节约 gas 的方式来创建 ERC20 token，需要同时修改 mintInscription 的实现以便收取每次发行的费用。

需要部署到测试⽹，并开源到区块链浏览器，在你的Github的 Readme.md 中备注代理合约及两个实现的合约地址。*/

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

interface IInscriptionToken {
    function mint(address to, uint amount) external;
}

contract InscriptionTokenV1 is ERC20 {
    uint public maxSupply;
    uint public perMint;
    address public owner;

    constructor(string memory _symbol, uint _maxSupply, uint _perMint, address _owner) ERC20(_symbol, _symbol) {
        maxSupply = _maxSupply;
        perMint = _perMint;
        owner = _owner;
    }

    function mint(address to, uint amount) external {
        require(msg.sender == owner, "only owner");
        require(totalSupply() + amount <= maxSupply, "exceed cap");
        _mint(to, amount);
    }
}

contract InscriptionTokenV2 is ERC20 {
    string public myName;
    string public mySymbol;
    uint public maxSupply;
    uint public perMint;
    uint public price;
    address public owner;

    constructor() ERC20("", "") {}

    function initialize(string memory _symbol, uint _maxSupply, uint _perMint, uint _price, address _owner) external {
        myName = _symbol;
        mySymbol = _symbol;
        maxSupply = _maxSupply;
        perMint = _perMint;
        price = _price;
        owner = _owner;
    }

    function name() public view virtual override returns (string memory) {
        return myName;
    }

    function symbol() public view virtual override returns (string memory) {
        return mySymbol;
    }

    function mint(address to, uint amount) external {
        require(msg.sender == owner, "only owner");
        require(totalSupply() + amount <= maxSupply, "exceed cap");
        _mint(to, amount);
    }
}

struct TokenInfo {
    uint perMint;
    uint price;
}

contract InscriptionFactoryV1 {
    mapping(address => TokenInfo) public tokenInfos;

    function deployInscription(string memory symbol, uint totalSupply, uint perMint) external returns (address) {
        address token = address(new InscriptionTokenV1(symbol, totalSupply, perMint, address(this)));
        tokenInfos[token] = TokenInfo({perMint: perMint, price: 0});
        return token;
    }

    function mintInscription(address tokenAddr) external payable {
        TokenInfo memory info = tokenInfos[tokenAddr];
        require(info.perMint > 0, "Unknown token");
        require(msg.value == info.price * info.perMint, "Incorrect payment");
        IInscriptionToken(tokenAddr).mint(msg.sender, info.perMint);
    }
}

contract InscriptionFactoryV2 {
    mapping(address => TokenInfo) public tokenInfos;
    address public tokenImplementation;

    constructor(address _tokenImplementation) {
        tokenImplementation = _tokenImplementation;
    }

    function deployInscription(string memory symbol, uint totalSupply, uint perMint, uint price) external returns (address) {
        address token = Clones.clone(tokenImplementation);
        InscriptionTokenV2(token).initialize(symbol, totalSupply, perMint, price, address(this));
        tokenInfos[token] = TokenInfo({perMint: perMint, price: price});
        return token;
    }

    function deployInscription(string memory symbol, uint totalSupply, uint perMint) external returns (address) {
        revert("Please use the function with price parameter");
    }

    function mintInscription(address tokenAddr) external payable {
        TokenInfo memory info = tokenInfos[tokenAddr];
        require(info.perMint > 0, "Unknown token");
        require(msg.value == info.price * info.perMint, "Incorrect payment");
        IInscriptionToken(tokenAddr).mint(msg.sender, info.perMint);
    }
}