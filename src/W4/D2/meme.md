解题思路


1. 创建一个最小代理调用合约
   1. deployMeme(string symbol, uint totalSupply, uint perMint, uint price), 
      1. symbol 表示新创建代币的代号（ ERC20 代币名字可以使用固定的），
      2. totalSupply 表示总发行量， 
      3. perMint 表示一次铸造 Meme 的数量（为了公平的铸造，而不是一次性所有的 Meme 都铸造完）， 
      4. price 表示每个 Meme 铸造时需要的支付的费用（wei 计价）。
      5. 每次铸造费用分为两部分，一部分（1%）给到项目方（你），一部分给到 Meme 的发行者（即调用该方法的用户）。
   2. mintMeme(address tokenAddr) payable: 购买 Meme 的用户每次调用该函数时，
会发行 deployInscription 确定的 perMint 数量的 token，并收取相应的费用。
1. ERC20基于 src/W3/D5/TokenV3.sol 实现具体的token业务