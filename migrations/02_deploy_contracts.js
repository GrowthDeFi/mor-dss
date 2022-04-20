const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const now = new Date();
const NOW = BigInt(Math.floor(now.getTime() / 1000));
const NOW_PREFIX = now.toISOString().substr(0, 10).split('-').join('');

function units(coins, decimals) {
  if (typeof coins !== 'string') throw new Error('Invalid amount');
  if (typeof decimals !== 'number') throw new Error('Invalid decimals');
  let i = coins.indexOf('.');
  if (i < 0) i = coins.length;
  const s = coins.slice(i + 1);
  if (decimals < s.length) throw new Error('Invalid decimals');
  return BigInt(coins.slice(0, i) + s + '0'.repeat(decimals - s.length));
}

const CONFIG = {
  '1': 'mainnet',     // mainnet
  '3': 'testnet',     // ropsten
  '4': 'testnet',     // rinkeby
  '42': 'testnet',    // kovan
  '5': 'testnet',     // goerli
  '56': 'bscmain',    // bscmain
  '97': 'testnet',    // bsctest
  '137': 'maticmain', // maticmain
  '80001': 'testnet', // matictest
  '43114': 'avaxmain',// avaxmain
  '43113': 'testnet', // avaxtest
  '250': 'ftmmain',   // ftmmain
  '4002': 'testnet',  // ftmtest
};

const MULTISIG_CONFIG = {
  '1': '0x2F80922CF7350e06F4924766Cb7EEEC783c1C8ce',     // mainnet
  '3': '0x2F80922CF7350e06F4924766Cb7EEEC783c1C8ce',     // ropsten
  '4': '0x2F80922CF7350e06F4924766Cb7EEEC783c1C8ce',     // rinkeby
  '42': '0x2F80922CF7350e06F4924766Cb7EEEC783c1C8ce',    // kovan
  '5': '0x2F80922CF7350e06F4924766Cb7EEEC783c1C8ce',     // goerli
  '56': '0x392681Eaf8AD9BC65e74BE37Afe7503D92802b7d',    // bscmain
  '97': '0x2F80922CF7350e06F4924766Cb7EEEC783c1C8ce',    // bsctest
  '137': '0x2F80922CF7350e06F4924766Cb7EEEC783c1C8ce',   // maticmain
  '80001': '0x2F80922CF7350e06F4924766Cb7EEEC783c1C8ce', // matictest
  '43114': '0x1d64CeAF2cDBC9b6d41eB0f2f7CDA8F04c47d1Ac', // avaxmain
  '43113': '0x2F80922CF7350e06F4924766Cb7EEEC783c1C8ce', // avaxtest
  '250': '0x934BF5461795B4a2aC5673c1fb3859E8fA48d9bb',   // ftmmain
  '4002': '0x2F80922CF7350e06F4924766Cb7EEEC783c1C8ce',  // ftmtest
};

module.exports = async (deployer, network, [account]) => {

  function sleep(delay) {
    return new Promise((resolve) => setTimeout(resolve, delay));
  }

  function liftFunc(address, name, func) {
    let i = 0;
    const liftedFunc = (...args) => {
      console.log('>> CALL ' + address + '.' + name + '(' + args.join(', ') + ')');
      const result = func(...args);
      if (Object.prototype.toString.call(result) !== '[object Promise]') return result;
      return new Promise((resolve, reject) => {
        result.then(resolve, (e) => {
          if (i >= 3) return reject(e);
          console.log('! lift.func #' + i + ': ' + e.message);
          i++;
          setTimeout(() => liftedFunc(...args).then(resolve, reject), 3000);
        });
      });
    };
    return liftedFunc;
  }

  function lift(object) {
    return new Proxy(object, {
      'get': (target, property, proxy) => {
        if (property === 'methods') {
          const methods = {};
          for (const sig in target[property]) {
            methods[sig] = liftFunc(target.address, sig, target[property][sig]);
          }
          return methods;
        }
        const func = target[property];
        if (typeof func !== 'function') return func;
        return liftFunc(target.address, property, func);
      },
    });
  }

  async function artifact_deploy(artifact, ...params) {
    console.log('>> CREATE ' + artifact._json.contractName + '(' + params.join(', ') + ')');
    for (let i = 0; ; i++) {
      try {
        await deployer.deploy(artifact, ...params);
        break;
      } catch (e) {
        if (i >= 3) throw e;
        console.log('! deployer.deploy #' + i + ': ' + e.message);
        await sleep(3000);
        continue;
      }
    }
    for (let i = 0; ; i++) {
      try {
        return lift(await artifact.deployed());
      } catch (e) {
        if (i >= 3) throw e;
        console.log('! artifact.deployed #' + i + ': ' + e.message);
        await sleep(3000);
        continue;
      }
    }
  }

  async function artifact_at(artifact, address) {
    for (let i = 0; ; i++) {
      try {
        return lift(await artifact.at(address));
      } catch (e) {
        if (i >= 3) throw e;
        console.log('! artifact.at #' + i + ': ' + e.message);
        await sleep(3000);
        continue;
      }
    }
  }

  const DEPLOYER = account;

  const DssDeploy = artifacts.require('DssDeploy');

  const web3 = DssDeploy.interfaceAdapter.web3;
  const initialBalance = await web3.eth.getBalance(DEPLOYER);

  const chainId = await web3.eth.getChainId();

  const config = require('./config/' + CONFIG[chainId] + '.json');
  const config_import = config.import || {};
  const config_tokens = config.tokens || {};

  const MULTISIG = MULTISIG_CONFIG[chainId];

  // MULTICALL

  console.log('Publishing Multicall...');
  const Multicall = artifacts.require('Multicall');
  const multicall = await artifact_deploy(Multicall);
  const MULTICALL = multicall.address;
  console.log('MULTICALL=' + MULTICALL);

  // FAUCET

  let FAUCET = config_import.faucet;
  let restrictedTokenFaucet;
  const RestrictedTokenFaucet = artifacts.require('RestrictedTokenFaucet');
  if (config_import.faucet === undefined) {
    console.log('Publishing Token Faucet...');
    restrictedTokenFaucet = await artifact_deploy(RestrictedTokenFaucet);
    FAUCET = restrictedTokenFaucet.address;
    console.log('FAUCET=' + FAUCET);
    await restrictedTokenFaucet.hope(ZERO_ADDRESS);
  }

  // PROXY REGISTRY

  let PROXY_FACTORY = ZERO_ADDRESS;
  let PROXY_REGISTRY = config_import.proxyRegistry;
  const ProxyRegistry = artifacts.require('ProxyRegistry');
  if (config_import.proxyRegistry === undefined) {
    console.log('Publishing Proxy Factory...');
    const DSProxyFactory = artifacts.require('DSProxyFactory');
    const dsProxyFactory = await artifact_deploy(DSProxyFactory);
    PROXY_FACTORY = dsProxyFactory.address;
    console.log('PROXY_FACTORY=' + PROXY_FACTORY);

    console.log('Publishing Proxy Registry...');
    const proxyRegistry = await artifact_deploy(ProxyRegistry, PROXY_FACTORY);
    PROXY_REGISTRY = proxyRegistry.address;
    console.log('PROXY_REGISTRY=' + PROXY_REGISTRY);
  }
  const proxyRegistry = await artifact_at(ProxyRegistry, PROXY_REGISTRY);

  // FABS

  console.log('Publishing VatFab...');
  const VatFab = artifacts.require('VatFab');
  const vatFab = await artifact_deploy(VatFab);
  const VAT_FAB = vatFab.address;
  console.log('VAT_FAB=' + VAT_FAB);

  console.log('Publishing JugFab...');
  const JugFab = artifacts.require('JugFab');
  const jugFab = await artifact_deploy(JugFab);
  const JUG_FAB = jugFab.address;
  console.log('JUG_FAB=' + JUG_FAB);

  console.log('Publishing VowFab...');
  const VowFab = artifacts.require('VowFab');
  const vowFab = await artifact_deploy(VowFab);
  const VOW_FAB = vowFab.address;
  console.log('VOW_FAB=' + VOW_FAB);

  console.log('Publishing CatFab...');
  const CatFab = artifacts.require('CatFab');
  const catFab = await artifact_deploy(CatFab);
  const CAT_FAB = catFab.address;
  console.log('CAT_FAB=' + CAT_FAB);

  console.log('Publishing DogFab...');
  const DogFab = artifacts.require('DogFab');
  const dogFab = await artifact_deploy(DogFab);
  const DOG_FAB = dogFab.address;
  console.log('DOG_FAB=' + DOG_FAB);

  console.log('Publishing DaiFab...');
  const DaiFab = artifacts.require('DaiFab');
  const daiFab = await artifact_deploy(DaiFab);
  const DAI_FAB = daiFab.address;
  console.log('DAI_FAB=' + DAI_FAB);

  console.log('Publishing DaiJoinFab...');
  const DaiJoinFab = artifacts.require('DaiJoinFab');
  const daiJoinFab = await artifact_deploy(DaiJoinFab);
  const MCD_JOIN_FAB = daiJoinFab.address;
  console.log('MCD_JOIN_FAB=' + MCD_JOIN_FAB);

  console.log('Publishing FlapFab...');
  const FlapFab = artifacts.require('FlapFab');
  const flapFab = await artifact_deploy(FlapFab);
  const FLAP_FAB = flapFab.address;
  console.log('FLAP_FAB=' + FLAP_FAB);

  console.log('Publishing FlopFab...');
  const FlopFab = artifacts.require('FlopFab');
  const flopFab = await artifact_deploy(FlopFab);
  const FLOP_FAB = flopFab.address;
  console.log('FLOP_FAB=' + FLOP_FAB);

  console.log('Publishing FlipFab...');
  const FlipFab = artifacts.require('FlipFab');
  const flipFab = await artifact_deploy(FlipFab);
  const FLIP_FAB = flipFab.address;
  console.log('FLIP_FAB=' + FLIP_FAB);

  console.log('Publishing ClipFab...');
  const ClipFab = artifacts.require('ClipFab');
  const clipFab = await artifact_deploy(ClipFab);
  const CLIP_FAB = clipFab.address;
  console.log('CLIP_FAB=' + CLIP_FAB);

  console.log('Publishing SpotFab...');
  const SpotFab = artifacts.require('SpotFab');
  const spotFab = await artifact_deploy(SpotFab);
  const SPOT_FAB = spotFab.address;
  console.log('SPOT_FAB=' + SPOT_FAB);

  console.log('Publishing PotFab...');
  const PotFab = artifacts.require('PotFab');
  const potFab = await artifact_deploy(PotFab);
  const POT_FAB = potFab.address;
  console.log('POT_FAB=' + POT_FAB);

  console.log('Publishing EndFab...');
  const EndFab = artifacts.require('EndFab');
  const endFab = await artifact_deploy(EndFab);
  const END_FAB = endFab.address;
  console.log('END_FAB=' + END_FAB);

  console.log('Publishing ESMFab...');
  const ESMFab = artifacts.require('ESMFab');
  const esmFab = await artifact_deploy(ESMFab);
  const ESM_FAB = esmFab.address;
  console.log('ESM_FAB=' + ESM_FAB);

  console.log('Publishing PauseFab...');
  const PauseFab = artifacts.require('PauseFab');
  const pauseFab = await artifact_deploy(PauseFab);
  const PAUSE_FAB = pauseFab.address;
  console.log('PAUSE_FAB=' + PAUSE_FAB);

  // GOV TOKEN

  let MCD_GOV = config_import.gov;
  const DSToken = artifacts.require('DSToken');
  if (config_import.gov === undefined) {
    console.log('Publishing Stock/Gov Token...');
    const govToken = await artifact_deploy(DSToken, 'STK');
    MCD_GOV = govToken.address;
    console.log('MCD_GOV=' + MCD_GOV);
    await govToken.setName('Stock');
  }
  const govToken = await artifact_at(DSToken, MCD_GOV);

  // CORE DEPLOYER

  console.log('Publishing DssDeploy...');
  const dssDeploy = await artifact_deploy(DssDeploy, VAT_FAB, JUG_FAB, VOW_FAB, CAT_FAB, DOG_FAB, DAI_FAB, MCD_JOIN_FAB, FLAP_FAB, FLOP_FAB, FLIP_FAB, CLIP_FAB, SPOT_FAB, POT_FAB, END_FAB, ESM_FAB, PAUSE_FAB);
  const MCD_DEPLOY = dssDeploy.address;
  console.log('MCD_DEPLOY=' + MCD_DEPLOY);

  // AUTHORITY

  console.log('Deploying DSRoles...');
  const DSRoles = artifacts.require('DSRoles');
  const dsRoles = await artifact_deploy(DSRoles);
  const MCD_ADM_TEMP = dsRoles.address;
  console.log('MCD_ADM_TEMP=' + MCD_ADM_TEMP);
  await dsRoles.setRootUser(DEPLOYER, true);

  // CORE

  console.log('Deploying Core...');

  // Deploy Vat
  const Vat = artifacts.require('Vat');
  const vat = await artifact_deploy(Vat);
  const MCD_VAT = vat.address;
  console.log('MCD_VAT=' + MCD_VAT);
  const Spotter = artifacts.require('Spotter');
  const spotter = await artifact_deploy(Spotter, MCD_VAT);
  const MCD_SPOT = spotter.address;
  console.log('MCD_SPOT=' + MCD_SPOT);
  await vat.rely(MCD_SPOT);

  // Deploy Dai
  const Dai = artifacts.require('Dai');
  const dai = await artifact_deploy(Dai, chainId);
  const MCD_DAI = dai.address;
  console.log('MCD_DAI=' + MCD_DAI);
  const dai_name = await dai.symbol();
  const DaiJoin = artifacts.require('DaiJoin');
  const daiJoin = await artifact_deploy(DaiJoin, MCD_VAT, MCD_DAI);
  const MCD_JOIN_DAI = daiJoin.address;
  console.log('MCD_JOIN_DAI=' + MCD_JOIN_DAI);
  await dai.rely(MCD_JOIN_DAI);

  // Deploy Taxation
  const Jug = artifacts.require('Jug');
  const jug = await artifact_deploy(Jug, MCD_VAT);
  const MCD_JUG = jug.address;
  console.log('MCD_JUG=' + MCD_JUG);
  const Pot = artifacts.require('Pot');
  const pot = await artifact_deploy(Pot, MCD_VAT);
  const MCD_POT = pot.address;
  console.log('MCD_POT=' + MCD_POT);
  await vat.rely(MCD_JUG);
  await vat.rely(MCD_POT);

  // Deploy Auctions
  const Flapper = artifacts.require('Flapper');
  const flap = await artifact_deploy(Flapper, MCD_VAT, MCD_GOV);
  const MCD_FLAP = flap.address;
  console.log('MCD_FLAP=' + MCD_FLAP);
  const Flopper = artifacts.require('Flopper');
  const flop = await artifact_deploy(Flopper, MCD_VAT, MCD_GOV);
  const MCD_FLOP = flop.address;
  console.log('MCD_FLOP=' + MCD_FLOP);
  const Vow = artifacts.require('Vow');
  const vow = await artifact_deploy(Vow, MCD_VAT, MCD_FLAP, MCD_FLOP);
  const MCD_VOW = vow.address;
  console.log('MCD_VOW=' + MCD_VOW);
  await jug.file(web3.utils.asciiToHex('vow'), MCD_VOW);
  await pot.file(web3.utils.asciiToHex('vow'), MCD_VOW);
  await vat.rely(MCD_FLOP);
  await flap.rely(MCD_VOW);
  await flop.rely(MCD_VOW);

  // Deploy Liquidator
  const Cat = artifacts.require('Cat');
  const cat = await artifact_deploy(Cat, MCD_VAT);
  const MCD_CAT = cat.address;
  console.log('MCD_CAT=' + MCD_CAT);
  const Dog = artifacts.require('Dog');
  const dog = await artifact_deploy(Dog, MCD_VAT);
  const MCD_DOG = dog.address;
  console.log('MCD_DOG=' + MCD_DOG);
  await cat.file(web3.utils.asciiToHex('vow'), MCD_VOW);
  await dog.file(web3.utils.asciiToHex('vow'), MCD_VOW);
  await vat.rely(MCD_CAT);
  await vat.rely(MCD_DOG);
  await vow.rely(MCD_CAT);
  await vow.rely(MCD_DOG);

  // Deploy End
  const End = artifacts.require('End');
  const end = await artifact_deploy(End);
  const MCD_END = end.address;
  console.log('MCD_END=' + MCD_END);
  await end.file(web3.utils.asciiToHex('vat'), MCD_VAT);
  await end.file(web3.utils.asciiToHex('cat'), MCD_CAT);
  await end.file(web3.utils.asciiToHex('dog'), MCD_DOG);
  await end.file(web3.utils.asciiToHex('vow'), MCD_VOW);
  await end.file(web3.utils.asciiToHex('pot'), MCD_POT);
  await end.file(web3.utils.asciiToHex('spot'), MCD_SPOT);
  await vat.rely(MCD_END);
  await cat.rely(MCD_END);
  await dog.rely(MCD_END);
  await vow.rely(MCD_END);
  await pot.rely(MCD_END);
  await spotter.rely(MCD_END);

  // Deploy Pause
  const DSPause = artifacts.require('DSPause');
  const pause = await artifact_deploy(DSPause, 0, ZERO_ADDRESS, MCD_ADM_TEMP);
  const MCD_PAUSE = pause.address;
  console.log('MCD_PAUSE=' + MCD_PAUSE);
  const MCD_PAUSE_PROXY = await pause.proxy();
  console.log('MCD_PAUSE_PROXY=' + MCD_PAUSE_PROXY);
  await vat.rely(MCD_PAUSE_PROXY);
  await cat.rely(MCD_PAUSE_PROXY);
  await dog.rely(MCD_PAUSE_PROXY);
  await vow.rely(MCD_PAUSE_PROXY);
  await jug.rely(MCD_PAUSE_PROXY);
  await pot.rely(MCD_PAUSE_PROXY);
  await spotter.rely(MCD_PAUSE_PROXY);
  await flap.rely(MCD_PAUSE_PROXY);
  await flop.rely(MCD_PAUSE_PROXY);
  await end.rely(MCD_PAUSE_PROXY);

  // Deploy ESM
  const esm_min = units(config.esm_min, 18);
  const ESM = artifacts.require('ESM');
  console.log('@esm_min', config.esm_min, esm_min);
  const esm = await artifact_deploy(ESM, MCD_GOV, MCD_END, MCD_PAUSE_PROXY, esm_min);
  const MCD_ESM = esm.address;
  console.log('MCD_ESM=' + MCD_ESM);
  await end.rely(MCD_ESM);
  await vat.rely(MCD_ESM);

  await vat.rely(MCD_DEPLOY);
  await spotter.rely(MCD_DEPLOY);
  await dai.rely(MCD_DEPLOY);
  await jug.rely(MCD_DEPLOY);
  await pot.rely(MCD_DEPLOY);
  await flap.rely(MCD_DEPLOY);
  await flop.rely(MCD_DEPLOY);
  await vow.rely(MCD_DEPLOY);
  await cat.rely(MCD_DEPLOY);
  await dog.rely(MCD_DEPLOY);
  await end.rely(MCD_DEPLOY);
  await dssDeploy.updateDeployed(MCD_VAT, MCD_JUG, MCD_VOW, MCD_CAT, MCD_DOG, MCD_DAI, MCD_JOIN_DAI, MCD_FLAP, MCD_FLOP, MCD_SPOT, MCD_POT, MCD_END, MCD_ESM, MCD_PAUSE);

  // FAUCET CONFIG

  let GOV_GUARD  = ZERO_ADDRESS;
  let mkrAuthority;
  if (config_import.gov === undefined) {
    console.log('Configuring Faucet...');
    await govToken.mint(FAUCET, units('1000000', 18));
    await restrictedTokenFaucet.gulp(MCD_GOV);
    await restrictedTokenFaucet.setAmt(MCD_GOV, units('1000', 18));

    console.log('Publishing MKR Authority ...');
    const MkrAuthority = artifacts.require('MkrAuthority');
    mkrAuthority = await artifact_deploy(MkrAuthority);
    GOV_GUARD = mkrAuthority.address;
    console.log('GOV_GUARD=' + GOV_GUARD);
    govToken.setAuthority(GOV_GUARD);
    govToken.setOwner(MCD_PAUSE_PROXY);
    mkrAuthority.rely(MCD_FLOP);
    mkrAuthority.setRoot(MCD_PAUSE_PROXY);
  }

  // DEPLOY COLLATERALS

  const T_ = {};
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_import = token_config.import || {};
    const token_gemDeploy = token_config.gemDeploy || {};

    T_[token_name] = token_import.gem;
    if (token_import.gem === undefined) {
      const src = token_gemDeploy.src;
      const params = token_gemDeploy.params || [];
      let GemToken;
      switch (src) {
      case 'ds-weth/WETH9_': GemToken = artifacts.require('WETH9_'); break;
      case 'dss-gem-joins/AAVE': GemToken = artifacts.require('AAVE'); break;
      case 'dss-gem-joins/BAL': GemToken = artifacts.require('BAL'); break;
      case 'dss-gem-joins/BAT': GemToken = artifacts.require('BAT'); break;
      case 'dss-gem-joins/COMP': GemToken = artifacts.require('COMP'); break;
      case 'dss-gem-joins/DGD': GemToken = artifacts.require('DGD'); break;
      case 'dss-gem-joins/GNT': GemToken = artifacts.require('GNT'); break;
      case 'dss-gem-joins/GUSD': GemToken = artifacts.require('GUSD'); break;
      case 'dss-gem-joins/KNC': GemToken = artifacts.require('KNC'); break;
      case 'dss-gem-joins/LINK': GemToken = artifacts.require('LINK'); break;
      case 'dss-gem-joins/LRC': GemToken = artifacts.require('LRC'); break;
      case 'dss-gem-joins/MANA': GemToken = artifacts.require('MANA'); break;
      case 'dss-gem-joins/OMG': GemToken = artifacts.require('OMG'); break;
      case 'dss-gem-joins/PAXUSD': GemToken = artifacts.require('PAXUSD'); break;
      case 'dss-gem-joins/RENBTC': GemToken = artifacts.require('RENBTC'); break;
      case 'dss-gem-joins/REP': GemToken = artifacts.require('REP'); break;
      case 'dss-gem-joins/TUSD': GemToken = artifacts.require('TUSD'); break;
      case 'dss-gem-joins/UNI': GemToken = artifacts.require('UNI'); break;
      case 'dss-gem-joins/USDC': GemToken = artifacts.require('USDC'); break;
      case 'dss-gem-joins/USDT': GemToken = artifacts.require('USDT'); break;
      case 'dss-gem-joins/WBTC': GemToken = artifacts.require('WBTC'); break;
      case 'dss-gem-joins/YFI': GemToken = artifacts.require('YFI'); break;
      case 'dss-gem-joins/ZRX': GemToken = artifacts.require('ZRX'); break;
      default: throw new Error('Unknown gem: ' + src);
      }
      console.log('Publishing Gem Token...');
      const gemToken = await artifact_deploy(GemToken, ...params);
      T_[token_name] = gemToken.address;
      console.log(token_name.replace('-', '_') + '=' + T_[token_name]);
    }
  }

  // FEEDS

  const VAL_ = {};
  const PIP_ = {};
  const DSValue = artifacts.require('DSValue');
  const Median = artifacts.require('Median');
  const LinkOracle = artifacts.require('LinkOracle');
  const UNIV2LPOracle = artifacts.require('UNIV2LPOracle');
  const CompOracle = artifacts.require('CompOracle');
  const XSushiOracle = artifacts.require('XSushiOracle');
  const VaultOracle = artifacts.require('VaultOracle');
  const UniV2TwapOracle = artifacts.require('UniV2TwapOracle');
  const UniswapV2PairLike = artifacts.require('UniswapV2PairLike');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_import = token_config.import || {};
    const token_pipDeploy = token_config.pipDeploy || {};

    VAL_[token_name] = token_import.pip;
    if (token_import.pip === undefined) {
      if (token_pipDeploy.type === 'twap') {
        console.log('Publishing TWAP Oracle...');
        const stwap = token_pipDeploy.stwap;
        const ltwap = token_pipDeploy.ltwap;
        const src = token_pipDeploy.src;
        const token = await artifact_at(DSToken, T_[token_name]);
        const dec = Number(await token.decimals());
        const cap = units(token_pipDeploy.cap, dec);
        console.log('@pip.cap', token_pipDeploy.cap, cap);
        const orb = token_pipDeploy.quote !== undefined ? VAL_[token_pipDeploy.quote] : ZERO_ADDRESS;
        const pair = await artifact_at(UniswapV2PairLike, src);
        const token0 = await pair.token0();
        const token1 = await pair.token1();
        if (token0 !== T_[token_name] && token1 !== T_[token_name]) {
          throw new Error('Configuration Inconsistency')
        }
        if (token_pipDeploy.quote !== undefined) {
          if (T_[token_name] === T_[token_pipDeploy.quote]) {
            throw new Error('Configuration Inconsistency')
          }
          if (token0 !== T_[token_pipDeploy.quote] && token1 !== T_[token_pipDeploy.quote]) {
            throw new Error('Configuration Inconsistency')
          }
        }
        const univ2twapOracle = await artifact_deploy(UniV2TwapOracle, stwap, ltwap, src, token.address, cap, orb);
        VAL_[token_name] = univ2twapOracle.address;
        console.log('VAL_' + token_name.replace('-', '_') + '=' + VAL_[token_name]);
      }
      if (token_pipDeploy.type === 'vault') {
        console.log('Publishing Vault Oracle...');
        const src = T_[token_name];
        const res = T_[token_pipDeploy.reserve];
        const orb = VAL_[token_pipDeploy.reserve];
        const vaultOracle = await artifact_deploy(VaultOracle, src, res, orb);
        VAL_[token_name] = vaultOracle.address;
        console.log('VAL_' + token_name.replace('-', '_') + '=' + VAL_[token_name]);
      }
      if (token_pipDeploy.type === 'xsushi') {
        console.log('Publishing XSushi Oracle...');
        const src = T_[token_name];
        const res = T_[token_pipDeploy.reserve];
        const orb = VAL_[token_pipDeploy.reserve];
        const xsushiOracle = await artifact_deploy(XSushiOracle, src, res, orb);
        VAL_[token_name] = xsushiOracle.address;
        console.log('VAL_' + token_name.replace('-', '_') + '=' + VAL_[token_name]);
      }
      if (token_pipDeploy.type === 'comp') {
        console.log('Publishing Comp Oracle...');
        const src = T_[token_name];
        const res = T_[token_pipDeploy.reserve];
        const orb = VAL_[token_pipDeploy.reserve];
        const compOracle = await artifact_deploy(CompOracle, src, res, orb);
        VAL_[token_name] = compOracle.address;
        console.log('VAL_' + token_name.replace('-', '_') + '=' + VAL_[token_name]);
      }
      if (token_pipDeploy.type === 'univ2lp') {
        console.log('Publishing Uniswap V2 LP Oracle...');
        const src = T_[token_name];
        const wat = web3.utils.asciiToHex(token_name);
        const orb0 = VAL_[token_pipDeploy.token0];
        const orb1 = VAL_[token_pipDeploy.token1];
        const pair = await artifact_at(UniswapV2PairLike, src);
        const token0 = await pair.token0();
        const token1 = await pair.token1();
        if (token0 !== T_[token_pipDeploy.token0] || token1 !== T_[token_pipDeploy.token1]) {
          throw new Error('Configuration Inconsistency')
        }
        const univ2lpOracle = await artifact_deploy(UNIV2LPOracle, src, wat, orb0, orb1);
        VAL_[token_name] = univ2lpOracle.address;
        console.log('VAL_' + token_name.replace('-', '_') + '=' + VAL_[token_name]);
        const hop = units(token_pipDeploy.hop, 0);
        console.log('@pip.hop', token_pipDeploy.hop, hop);
        await univ2lpOracle.step(hop);
      }
      if (token_pipDeploy.type === 'chainlink') {
        console.log('Publishing LinkOracle...');
        const src = token_pipDeploy.src;
        const linkOracle = await artifact_deploy(LinkOracle, src);
        VAL_[token_name] = linkOracle.address;
        console.log('VAL_' + token_name.replace('-', '_') + '=' + VAL_[token_name]);
      }
      if (token_pipDeploy.type === 'median') {
        console.log('Publishing Median...');
        const wat = web3.utils.asciiToHex(token_name.replace('-', '_') + 'USD');
        const median = await artifact_deploy(Median, wat);
        VAL_[token_name] = median.address;
        console.log('VAL_' + token_name.replace('-', '_') + '=' + VAL_[token_name]);
        await median.lift(token_pipDeploy.signers);
        await median.setBar(3);
      }
      if (token_pipDeploy.type === 'value') {
        console.log('Publishing DsValue...');
        const dsValue = await artifact_deploy(DSValue);
        VAL_[token_name] = dsValue.address;
        console.log('VAL_' + token_name.replace('-', '_') + '=' + VAL_[token_name]);
      }
    }
    PIP_[token_name] = VAL_[token_name];
  }

  // DEPLOY ILKS

  const MCD_JOIN_ = {};
  const MCD_FLIP_ = {};
  const MCD_CLIP_ = {};
  const MCD_CLIP_CALC_ = {};
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_joinDeploy = token_config.joinDeploy || {};
    const token_ilks = token_config.ilks || {};
    const src = token_joinDeploy.src || 'GemJoin';
    const extraParams = token_joinDeploy.extraParams || [];

    MCD_JOIN_[token_name] = MCD_JOIN_[token_name] || {};
    MCD_FLIP_[token_name] = MCD_FLIP_[token_name] || {};
    MCD_CLIP_[token_name] = MCD_CLIP_[token_name] || {};
    MCD_CLIP_CALC_[token_name] = MCD_CLIP_CALC_[token_name] || {};

    let GemJoin;
    switch (src) {
    case 'GemJoin': GemJoin = artifacts.require('GemJoin'); break;
    case 'GemJoin2': GemJoin = artifacts.require('GemJoin2'); break;
    case 'GemJoin3': GemJoin = artifacts.require('GemJoin3'); break;
    case 'GemJoin4': GemJoin = artifacts.require('GemJoin4'); break;
    case 'GemJoin5': GemJoin = artifacts.require('GemJoin5'); break;
    case 'GemJoin6': GemJoin = artifacts.require('GemJoin6'); break;
    case 'GemJoin7': GemJoin = artifacts.require('GemJoin7'); break;
    case 'GemJoin8': GemJoin = artifacts.require('GemJoin8'); break;
    case 'AuthGemJoin': GemJoin = artifacts.require('AuthGemJoin'); break;
    case 'AuthGemJoin5': GemJoin = artifacts.require('AuthGemJoin5'); break;
    default: throw new Error('Unknown join: ' + src);
    }

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_flipDeploy = ilk_config.flipDeploy || {};
      const ilk_clipDeploy = ilk_config.clipDeploy || {};
      const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

      console.log('Publishing Gem Join...');
      const gemJoin = await artifact_deploy(GemJoin, MCD_VAT, ilk_name, T_[token_name], ...extraParams);
      MCD_JOIN_[token_name][ilk] = gemJoin.address;
      console.log('MCD_JOIN_' + token_name.replace('-', '_') + '_' + ilk + '=' + MCD_JOIN_[token_name][ilk]);

      if (ilk_config.flipDeploy !== undefined) {
        console.log('Publishing Flip...');
        await dssDeploy.deployCollateralFlip(ilk_name, MCD_JOIN_[token_name][ilk], PIP_[token_name]);
        const { flip } = await dssDeploy.ilks(ilk_name);
        MCD_FLIP_[token_name][ilk] = flip;
        console.log('MCD_FLIP_' + token_name.replace('-', '_') + '_' + ilk + '=' + MCD_FLIP_[token_name][ilk]);
        // const Flipper = artifacts.require('Flipper');
        // const flip = await artifact_deploy(Flipper, MCD_VAT, MCD_CAT, ilk_name);
        // MCD_FLIP_[token_name][ilk] = flip.address;
        // console.log('MCD_FLIP_' + token_name.replace('-', '_') + '_' + ilk + '=' + MCD_FLIP_[token_name][ilk]);
        // await spotter.file(ilk_name, web3.utils.asciiToHex('pip'), PIP_[token_name]);
        // await cat.file(ilk_name, web3.utils.asciiToHex('flip'), MCD_FLIP_[token_name][ilk]);
        // await vat.init(ilk_name);
        // await jug.init(ilk_name);
        // await vat.rely(MCD_JOIN_[token_name][ilk]);
        // await cat.rely(MCD_FLIP_[token_name][ilk]);
        // await flip.rely(MCD_CAT);
        // await flip.rely(MCD_END);
        // await flip.rely(MCD_ESM);
        // await flip.rely(MCD_PAUSE_PROXY);
      }

      if (ilk_config.clipDeploy !== undefined) {
        const calc_config = ilk_clipDeploy.calc || {};

        let Calc;
        switch (calc_config.type) {
        case 'LinearDecrease': Calc = artifacts.require('LinearDecrease'); break;
        case 'StairstepExponentialDecrease': Calc = artifacts.require('StairstepExponentialDecrease'); break;
        case 'ExponentialDecrease': Calc = artifacts.require('ExponentialDecrease'); break;
        default: throw new Error('Unknown calc: ' + calc_config.type);
        }

        console.log('Publishing Calc...');
        const calc = await artifact_deploy(Calc);
        MCD_CLIP_CALC_[token_name][ilk] = calc.address;
        console.log('MCD_CLIP_CALC_' + token_name.replace('-', '_') + '_' + ilk + '=' + MCD_CLIP_CALC_[token_name][ilk]);
        await calc.rely(MCD_PAUSE_PROXY);
        await calc.deny(DEPLOYER);

        console.log('Publishing Clip...');
        await dssDeploy.deployCollateralClip(ilk_name, MCD_JOIN_[token_name][ilk], PIP_[token_name], MCD_CLIP_CALC_[token_name][ilk]);
        const { clip } = await dssDeploy.ilks(ilk_name);
        MCD_CLIP_[token_name][ilk] = clip;
        console.log('MCD_CLIP_' + token_name.replace('-', '_') + '_' + ilk + '=' + MCD_CLIP_[token_name][ilk]);
        // const Clipper = artifacts.require('Clipper');
        // const clip = await artifact_deploy(Clipper, MCD_VAT, MCD_SPOT, MCD_DOG, ilk_name);
        // MCD_CLIP_[token_name][ilk] = clip.address;
        // console.log('MCD_CLIP_' + token_name.replace('-', '_') + '_' + ilk + '=' + MCD_CLIP_[token_name][ilk]);
        // await spotter.file(ilk_name, web3.utils.asciiToHex('pip'), PIP_[token_name]);
        // await dog.file(ilk_name, web3.utils.asciiToHex('clip'), MCD_CLIP_[token_name][ilk]);
        // await clip.file(web3.utils.asciiToHex('vow'), MCD_VOW);
        // await clip.file(web3.utils.asciiToHex('calc'), MCD_CLIP_CALC_[token_name][ilk]);
        // await vat.init(ilk_name);
        // await jug.init(ilk_name);
        // await vat.rely(MCD_JOIN_[token_name][ilk]);
        // await vat.rely(MCD_CLIP_[token_name][ilk]);
        // await dog.rely(MCD_CLIP_[token_name][ilk]);
        // await clip.rely(MCD_DOG);
        // await clip.rely(MCD_END);
        // await clip.rely(MCD_ESM);
        // await clip.rely(MCD_PAUSE_PROXY);
      }
    }
  }

  // PROXY ACTIONS

  console.log('Deploying Proxy Actions...');
  const DssProxyActions = artifacts.require('DssProxyActions');
  const dssProxyActions = await artifact_deploy(DssProxyActions);
  const PROXY_ACTIONS = dssProxyActions.address;
  console.log('PROXY_ACTIONS=' + PROXY_ACTIONS);

  console.log('Deploying Proxy Actions End...');
  const DssProxyActionsEnd = artifacts.require('DssProxyActionsEnd');
  const dssProxyActionsEnd = await artifact_deploy(DssProxyActionsEnd);
  const PROXY_ACTIONS_END = dssProxyActionsEnd.address;
  console.log('PROXY_ACTIONS_END=' + PROXY_ACTIONS_END);

  console.log('Deploying Proxy Actions Dsr...');
  const DssProxyActionsDsr = artifacts.require('DssProxyActionsDsr');
  const dssProxyActionsDsr = await artifact_deploy(DssProxyActionsDsr);
  const PROXY_ACTIONS_DSR = dssProxyActionsDsr.address;
  console.log('PROXY_ACTIONS_DSR=' + PROXY_ACTIONS_DSR);

  // CDP MANAGER

  console.log('Deploying CDP Manager...');
  const DssCdpManager = artifacts.require('DssCdpManager');
  const dssCdpManager = await artifact_deploy(DssCdpManager, MCD_VAT);
  const CDP_MANAGER = dssCdpManager.address;
  console.log('CDP_MANAGER=' + CDP_MANAGER);

  console.log('Deploying Get CDPs...');
  const GetCdps = artifacts.require('GetCdps');
  const getCdps = await artifact_deploy(GetCdps);
  const GET_CDPS = getCdps.address;
  console.log('GET_CDPS=' + GET_CDPS);

  // DSR MANAGER

  console.log('Deploying DSR Manager...');
  const DsrManager = artifacts.require('DsrManager');
  const dsrManager = await artifact_deploy(DsrManager, MCD_POT, MCD_JOIN_DAI);
  const DSR_MANAGER = dsrManager.address;
  console.log('DSR_MANAGER=' + DSR_MANAGER);

  // OSM MOM

  console.log('Deploying OSM Mom...');
  const OSM = artifacts.require('OSM');
  const OsmMom = artifacts.require('OsmMom');
  const osmMom = await artifact_deploy(OsmMom);
  const OSM_MOM = osmMom.address;
  console.log('OSM_MOM=' + OSM_MOM);

  // FLIPPER MOM

  console.log('Deploying Flipper Mom...');
  const FlipperMom = artifacts.require('FlipperMom');
  const flipperMom = await artifact_deploy(FlipperMom, MCD_CAT);
  const FLIPPER_MOM = flipperMom.address;
  console.log('FLIPPER_MOM=' + FLIPPER_MOM);

  // CLIPPER MOM

  console.log('Deploying Clipper Mom...');
  const ClipperMom = artifacts.require('ClipperMom');
  const clipperMom = await artifact_deploy(ClipperMom, MCD_SPOT);
  const CLIPPER_MOM = clipperMom.address;
  console.log('CLIPPER_MOM=' + CLIPPER_MOM);

  // ILK REGISTRY

  console.log('Deploying ILK Registry...');
  const IlkRegistry = artifacts.require('IlkRegistry');
  const ilkRegistry = await artifact_deploy(IlkRegistry, MCD_VAT, MCD_DOG, MCD_CAT, MCD_SPOT);
  const ILK_REGISTRY = ilkRegistry.address;
  console.log('ILK_REGISTRY=' + ILK_REGISTRY);

  // PSM

  const MCD_PSM_ = {};
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    MCD_PSM_[token_name] = MCD_PSM_[token_name] || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_psmDeploy = ilk_config.psmDeploy;

      if (ilk_psmDeploy !== undefined) {
        const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);
        const tin = units(ilk_psmDeploy.tin, 18);
        const tout = units(ilk_psmDeploy.tout, 18);
        const donors = ilk_psmDeploy.donors || [];
        console.log('@psm.tin', ilk_psmDeploy.tin, tin);
        console.log('@psm.tout', ilk_psmDeploy.tout, tout);
        console.log('@psm.donors', ilk_psmDeploy.donors, donors);

        console.log('Deploying Dss Psm...');
        const DssPsm = artifacts.require('DssPsm');
        const dssPsm = await artifact_deploy(DssPsm, MCD_JOIN_[token_name][ilk], MCD_JOIN_DAI, MCD_VOW);
        MCD_PSM_[token_name][ilk] = dssPsm.address;
        console.log('MCD_' + token_name.replace('-', '_') + '_' + ilk + '=' + MCD_PSM_[token_name][ilk]);
        await dssPsm.file(web3.utils.asciiToHex('tin'), tin);
        await dssPsm.file(web3.utils.asciiToHex('tout'), tout);
        for (const donor of donors) {
          await dssPsm.donor(donor, true);
        }
        await dssPsm.rely(MCD_PAUSE_PROXY);
        await dssPsm.deny(DEPLOYER);

        const AuthGemJoin = artifacts.require('AuthGemJoin');
        const authGemJoin = await artifact_at(AuthGemJoin, MCD_JOIN_[token_name][ilk]);
        await authGemJoin.rely(MCD_PSM_[token_name][ilk]);
      }
    }
  }

  // REMOVE AUTH

  console.log('Releasing Auth...');
  await dssDeploy.releaseAuth();
  await vat.deny(DEPLOYER);
  await cat.deny(DEPLOYER);
  await dog.deny(DEPLOYER);
  await vow.deny(DEPLOYER);
  await jug.deny(DEPLOYER);
  await pot.deny(DEPLOYER);
  await dai.deny(DEPLOYER);
  await spotter.deny(DEPLOYER);
  await flap.deny(DEPLOYER);
  await flop.deny(DEPLOYER);
  await end.deny(DEPLOYER);

  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

      const GemJoin = artifacts.require('GemJoin');
      const gemJoin = await artifact_at(GemJoin, MCD_JOIN_[token_name][ilk]);
      await gemJoin.rely(MCD_PAUSE_PROXY);
      await gemJoin.deny(DEPLOYER);
      if (ilk_config.flipDeploy !== undefined) {
        await dssDeploy.releaseAuthFlip(ilk_name);
        // const Flipper = artifacts.require('Flipper');
        // const flip = await artifact_at(Flipper, MCD_FLIP_[token_name][ilk]);
        // await flip.deny(DEPLOYER);
      }
      if (ilk_config.clipDeploy !== undefined) {
        await dssDeploy.releaseAuthClip(ilk_name);
        // const Clipper = artifacts.require('Clipper');
        // const clip = await artifact_at(Clipper, MCD_CLIP_[token_name][ilk]);
        // await clip.deny(DEPLOYER);
      }
    }
  }
  await dssDeploy.setOwner(MCD_PAUSE_PROXY);

  // GOV ACTIONS

  console.log('Deploying Gov Actions...');
  const GovActions = artifacts.require('GovActions');
  const govActions = await artifact_deploy(GovActions);
  const MCD_GOV_ACTIONS = govActions.address;
  console.log('MCD_GOV_ACTIONS=' + MCD_GOV_ACTIONS);

  // PAUSE PROXY ACTIONS

  console.log('Deploying Pause Proxy Actions...');
  const DssDeployPauseProxyActions = artifacts.require('DssDeployPauseProxyActions');
  const dssDeployPauseProxyActions = await artifact_deploy(DssDeployPauseProxyActions);
  const PROXY_PAUSE_ACTIONS = dssDeployPauseProxyActions.address;
  console.log('PROXY_PAUSE_ACTIONS=' + PROXY_PAUSE_ACTIONS);

  // PROXY DEPLOYER

  let PROXY_DEPLOYER = await proxyRegistry.proxies(DEPLOYER);
  if (PROXY_DEPLOYER === ZERO_ADDRESS) {
    console.log('Building Proxy Deployer...');
    await proxyRegistry.build();
    PROXY_DEPLOYER = await proxyRegistry.proxies(DEPLOYER);
  }
  console.log('PROXY_DEPLOYER=' + PROXY_DEPLOYER);
  const DSProxy = artifacts.require('DSProxy');
  const proxyDeployer = await artifact_at(DSProxy, PROXY_DEPLOYER);
  await dsRoles.setRootUser(PROXY_DEPLOYER, true);

  async function rely(who, to) {
    const jsonInterface = {
      type: 'function',
      name: 'rely',
      inputs: [
        { type: 'address', name: 'pause' },
        { type: 'address', name: 'actions' },
        { type: 'address', name: 'who' },
        { type: 'address', name: 'to' },
      ],
    };
    const calldata = web3.eth.abi.encodeFunctionCall(jsonInterface, [MCD_PAUSE, MCD_GOV_ACTIONS, who, to]);
    return await proxyDeployer.methods['execute(address,bytes)'](PROXY_PAUSE_ACTIONS, calldata);
  }

  async function file(who, what, data) {
    const jsonInterface = {
      type: 'function',
      name: 'file',
      inputs: [
        { type: 'address', name: 'pause' },
        { type: 'address', name: 'actions' },
        { type: 'address', name: 'who' },
        { type: 'bytes32', name: 'what' },
        { type: 'uint256', name: 'data' },
      ],
    };
    const calldata = web3.eth.abi.encodeFunctionCall(jsonInterface, [MCD_PAUSE, MCD_GOV_ACTIONS, who, web3.utils.asciiToHex(what), data]);
    return await proxyDeployer.methods['execute(address,bytes)'](PROXY_PAUSE_ACTIONS, calldata);
  }

  async function filex(who, ilk, what, data) {
    const jsonInterface = {
      type: 'function',
      name: 'file',
      inputs: [
        { type: 'address', name: 'pause' },
        { type: 'address', name: 'actions' },
        { type: 'address', name: 'who' },
        { type: 'bytes32', name: 'ilk' },
        { type: 'bytes32', name: 'what' },
        { type: 'uint256', name: 'data' },
      ],
    };
    const calldata = web3.eth.abi.encodeFunctionCall(jsonInterface, [MCD_PAUSE, MCD_GOV_ACTIONS, who, ilk, web3.utils.asciiToHex(what), data]);
    return await proxyDeployer.methods['execute(address,bytes)'](PROXY_PAUSE_ACTIONS, calldata);
  }

  async function dripAndFile(who, what, data) {
    const jsonInterface = {
      type: 'function',
      name: 'dripAndFile',
      inputs: [
        { type: 'address', name: 'pause' },
        { type: 'address', name: 'actions' },
        { type: 'address', name: 'who' },
        { type: 'bytes32', name: 'what' },
        { type: 'uint256', name: 'data' },
      ],
    };
    const calldata = web3.eth.abi.encodeFunctionCall(jsonInterface, [MCD_PAUSE, MCD_GOV_ACTIONS, who, web3.utils.asciiToHex(what), data]);
    return await proxyDeployer.methods['execute(address,bytes)'](PROXY_PAUSE_ACTIONS, calldata);
  }

  async function dripAndFilex(who, ilk, what, data) {
    const jsonInterface = {
      type: 'function',
      name: 'dripAndFile',
      inputs: [
        { type: 'address', name: 'pause' },
        { type: 'address', name: 'actions' },
        { type: 'address', name: 'who' },
        { type: 'bytes32', name: 'ilk' },
        { type: 'bytes32', name: 'what' },
        { type: 'uint256', name: 'data' },
      ],
    };
    const calldata = web3.eth.abi.encodeFunctionCall(jsonInterface, [MCD_PAUSE, MCD_GOV_ACTIONS, who, ilk, web3.utils.asciiToHex(what), data]);
    return await proxyDeployer.methods['execute(address,bytes)'](PROXY_PAUSE_ACTIONS, calldata);
  }

  async function setAuthorityAndDelay(newAuthority, newDelay) {
    const jsonInterface = {
      type: 'function',
      name: 'setAuthorityAndDelay',
      inputs: [
        { type: 'address', name: 'pause' },
        { type: 'address', name: 'actions' },
        { type: 'address', name: 'newAuthority' },
        { type: 'uint256', name: 'newDelay' },
      ],
    };
    const calldata = web3.eth.abi.encodeFunctionCall(jsonInterface, [MCD_PAUSE, MCD_GOV_ACTIONS, newAuthority, newDelay]);
    return await proxyDeployer.methods['execute(address,bytes)'](PROXY_PAUSE_ACTIONS, calldata);
  }

  // ADM CHIEF

  let VOTE_DELEGATE_PROXY_FACTORY = ZERO_ADDRESS;
  let VOTE_PROXY_FACTORY = ZERO_ADDRESS;
  let MCD_ADM = config_import.authority;
  if (MCD_ADM === undefined) {
    const symbol = await govToken.symbol();
    console.log('Publishing gov' + symbol + '/IOU Token...');
    const iouToken = await artifact_deploy(DSToken, 'gov' + symbol);
    const MCD_IOU = iouToken.address;
    console.log('MCD_IOU=' + MCD_IOU);
    await iouToken.setName('governance ' + symbol);

    console.log('Publishing DS Chief...');
    const DSChief = artifacts.require('DSChief');
    const dsChief = await artifact_deploy(DSChief, MCD_GOV, MCD_IOU, 5);
    MCD_ADM = dsChief.address;
    console.log('MCD_ADM=' + MCD_ADM);
    iouToken.setOwner(MCD_ADM);

    // VOTE PROXY FACTORY

    console.log('Publishing Vote Proxy Factory...');
    const VoteProxyFactory = artifacts.require('VoteProxyFactory');
    const voteProxyFactory = await artifact_deploy(VoteProxyFactory, MCD_ADM);
    VOTE_PROXY_FACTORY = voteProxyFactory.address;
    console.log('VOTE_PROXY_FACTORY=' + VOTE_PROXY_FACTORY);

    // POLLING EMITTER

    console.log('Publishing Polling Emitter...');
    const PollingEmitter = artifacts.require('PollingEmitter');
    const pollingEmitter = await artifact_deploy(PollingEmitter);
    const MCD_POLLING_EMITTER = pollingEmitter.address;
    console.log('MCD_POLLING_EMITTER=' + MCD_POLLING_EMITTER);

    // VOTE DELEGATE FACTORY

    console.log('Publishing Vote Delegate Factory...');
    const VoteDelegateFactory = artifacts.require('VoteDelegateFactory');
    const voteDelegateFactory = await artifact_deploy(VoteDelegateFactory, MCD_ADM, MCD_POLLING_EMITTER);
    VOTE_DELEGATE_PROXY_FACTORY = voteDelegateFactory.address;
    console.log('VOTE_DELEGATE_PROXY_FACTORY=' + VOTE_DELEGATE_PROXY_FACTORY);
  }

  // AUTO LINE

  console.log('Publishing Auto Line...');
  const DssAutoLine = artifacts.require('DssAutoLine');
  const dssAutoLine = await artifact_deploy(DssAutoLine, MCD_VAT);
  const MCD_IAM_AUTO_LINE = dssAutoLine.address;
  console.log('MCD_IAM_AUTO_LINE=' + MCD_IAM_AUTO_LINE);
  await rely(MCD_VAT, MCD_IAM_AUTO_LINE);

  // FLASH

  console.log('Publishing Flash...');
  const DssFlash = artifacts.require('DssFlash');
  const dssFlash = await artifact_deploy(DssFlash, MCD_JOIN_DAI, MCD_VOW);
  const MCD_FLASH = dssFlash.address;
  console.log('MCD_FLASH=' + MCD_FLASH);
  await rely(MCD_VAT, MCD_FLASH);
  await dssFlash.rely(MCD_PAUSE_PROXY);
  await dssFlash.deny(DEPLOYER);

  // AMO

  console.log('Publishing Amo...');
  const DssAmo = artifacts.require('DssAmo');
  const dssAmo = await artifact_deploy(DssAmo, MCD_JOIN_DAI);
  const MCD_AMO = dssAmo.address;
  console.log('MCD_AMO=' + MCD_AMO);
  await rely(MCD_VAT, MCD_AMO);
  await dssAmo.rely(MCD_PAUSE_PROXY);
  await dssAmo.deny(DEPLOYER);

  // CHAIN LOG

  console.log('Publishing Chain Log...');
  const ChainLog = artifacts.require('ChainLog');
  const chainLog = await artifact_deploy(ChainLog);
  const CHANGELOG = chainLog.address;
  console.log('CHANGELOG=' + CHANGELOG);
  await chainLog.rely(MCD_PAUSE_PROXY);

  // CORE CONFIG

  console.log('Configuring Core...');
  if (Number(config.vat_line) > 0) {
    const vat_line = units(config.vat_line, 45);
    console.log('@vat_line', config.vat_line, vat_line);
    await file(MCD_VAT, 'Line', vat_line);
  }
  if (Number(config.vow_wait) >= 0) {
    const vow_wait = units(config.vow_wait, 0);
    console.log('@vow_wait', config.vow_wait, vow_wait);
    await file(MCD_VOW, 'wait', vow_wait);
  }
  if (Number(config.vow_bump) >= 0) {
    const vow_bump = units(config.vow_bump, 45);
    console.log('@vow_bump', config.vow_bump, vow_bump);
    await file(MCD_VOW, 'bump', vow_bump);
  }
  if (Number(config.vow_dump) >= 0) {
    const vow_dump = units(config.vow_dump, 18);
    console.log('@vow_dump', config.vow_dump, vow_dump);
    await file(MCD_VOW, 'dump', vow_dump);
  }
  if (Number(config.vow_sump) >= 0) {
    const vow_sump = units(config.vow_sump, 45);
    console.log('@vow_sump', config.vow_sump, vow_sump);
    await file(MCD_VOW, 'sump', vow_sump);
  }
  if (Number(config.vow_hump) >= 0) {
    const vow_hump = units(config.vow_hump, 45);
    console.log('@vow_hump', config.vow_hump, vow_hump);
    await file(MCD_VOW, 'hump', vow_hump);
  }
  if (Number(config.cat_box) > 0) {
    const cat_box = units(config.cat_box, 45);
    console.log('@cat_box', config.cat_box, cat_box);
    await file(MCD_CAT, 'box', cat_box);
  }
  if (Number(config.dog_hole) > 0) {
    const dog_hole = units(config.dog_hole, 45);
    console.log('@dog_hole', config.dog_hole, dog_hole);
    await file(MCD_DOG, 'Hole', dog_hole);
  }
  if (Number(config.jug_base) >= 0) {
    const jug_base = units(Math.exp(Math.log(Number(config.jug_base) / 100 + 1) / (60 * 60 * 24 * 365)).toFixed(27), 27) - 10n ** 27n;
    console.log('@jug_base', config.jug_base, jug_base);
    await file(MCD_JUG, 'base', jug_base);
  }
  if (Number(config.pot_dsr) >= 0) {
    const pot_dsr = units(Math.exp(Math.log(Number(config.pot_dsr) / 100 + 1) / (60 * 60 * 24 * 365)).toFixed(27), 27);
    console.log('@pot_dsr', config.pot_dsr, pot_dsr);
    await dripAndFile(MCD_POT, 'dsr', pot_dsr);
  }
  if (Number(config.end_wait) >= 0) {
    const end_wait = units(config.end_wait, 0);
    console.log('@end_wait', config.end_wait, end_wait);
    await file(MCD_END, 'wait', end_wait);
  }
  if (Number(config.flap_beg) >= 0) {
    const flap_beg = units(config.flap_beg, 16) + units('100', 16);
    console.log('@flap_beg', config.flap_beg, flap_beg);
    await file(MCD_FLAP, 'beg', flap_beg);
  }
  if (Number(config.flap_ttl) >= 0) {
    const flap_ttl = units(config.flap_ttl, 0);
    console.log('@flap_ttl', config.flap_ttl, flap_ttl);
    await file(MCD_FLAP, 'ttl', flap_ttl);
  }
  if (Number(config.flap_tau) >= 0) {
    const flap_tau = units(config.flap_tau, 0);
    console.log('@flap_tau', config.flap_tau, flap_tau);
    await file(MCD_FLAP, 'tau', flap_tau);
  }
  if (Number(config.flop_beg) >= 0) {
    const flop_beg = units(config.flop_beg, 16) + units('100', 16);
    console.log('@flop_beg', config.flop_beg, flop_beg);
    await file(MCD_FLOP, 'beg', flop_beg);
  }
  if (Number(config.flop_pad) >= 0) {
    const flop_pad = units(config.flop_pad, 16) + units('100', 16);
    console.log('@flop_pad', config.flop_pad, flop_pad);
    await file(MCD_FLOP, 'pad', flop_pad);
  }
  if (Number(config.flop_ttl) >= 0) {
    const flop_ttl = units(config.flop_ttl, 0);
    console.log('@flop_ttl', config.flop_ttl, flop_ttl);
    await file(MCD_FLOP, 'ttl', flop_ttl);
  }
  if (Number(config.flop_tau) >= 0) {
    const flop_tau = units(config.flop_tau, 0);
    console.log('@flop_tau', config.flop_tau, flop_tau);
    await file(MCD_FLOP, 'tau', flop_tau);
  }
  if (Number(config.flash_max) >= 0) {
    const flash_max = units(config.flash_max, 18);
    console.log('@flash_max', config.flash_max, flash_max);
    await file(MCD_FLASH, 'max', flash_max);
  }
  if (Number(config.flash_toll) >= 0) {
    const flash_toll = units(config.flash_toll, 16);
    console.log('@flash_toll', config.flash_toll, flash_toll);
    await file(MCD_FLASH, 'toll', flash_toll);
  }

  // SET ORACLE PRICES VISIBLE BY DEPLOYER

  console.log('Configuring Deployer into Oracle Whitelist...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_import = token_config.import || {};
    const token_pipDeploy = token_config.pipDeploy || {};

    if (token_import.pip === undefined) {
      if (token_pipDeploy.type === 'twap') {
        const univ2twapOracle = await artifact_at(UniV2TwapOracle, VAL_[token_name]);
        await univ2twapOracle.methods['kiss(address)'](DEPLOYER);
      }
      if (token_pipDeploy.type === 'vault') {
        const vaultOracle = await artifact_at(VaultOracle, VAL_[token_name]);
        await vaultOracle.methods['kiss(address)'](DEPLOYER);
      }
      if (token_pipDeploy.type === 'xsushi') {
        const xsushiOracle = await artifact_at(XSushiOracle, VAL_[token_name]);
        await xsushiOracle.methods['kiss(address)'](DEPLOYER);
      }
      if (token_pipDeploy.type === 'comp') {
        const compOracle = await artifact_at(CompOracle, VAL_[token_name]);
        await compOracle.methods['kiss(address)'](DEPLOYER);
      }
      if (token_pipDeploy.type === 'univ2lp') {
        const univ2lpOracle = await artifact_at(UNIV2LPOracle, VAL_[token_name]);
        await univ2lpOracle.methods['kiss(address)'](DEPLOYER);
      }
      if (token_pipDeploy.type === 'chainlink') {
        const linkOracle = await artifact_at(LinkOracle, VAL_[token_name]);
        await linkOracle.methods['kiss(address)'](DEPLOYER);
      }
      if (token_pipDeploy.type === 'median') {
        const median = await artifact_at(Median, VAL_[token_name]);
        await median.methods['kiss(address)'](DEPLOYER);
      }
    }
  }

  // SET ILKS PRICE

  console.log('Configuring ILK Prices...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_import = token_config.import || {};
    const token_pipDeploy = token_config.pipDeploy || {};

    if (token_import.pip === undefined) {
      if (token_pipDeploy.type === 'twap') {
        const univ2twapOracle = await artifact_at(UniV2TwapOracle, VAL_[token_name]);
        await univ2twapOracle.poke();
      }
      if (token_pipDeploy.type === 'value') {
        const token = await artifact_at(DSToken, T_[token_name]);
        const price = units(token_pipDeploy.price, 18);
        console.log('@pip.price', token_pipDeploy.price, price);
        const dsValue = await artifact_at(DSValue, VAL_[token_name]);
        await dsValue.poke('0x' + web3.utils.numberToHex(String(price)).substring(2).padStart(64, '0'));
      }
      if (Number(token_pipDeploy.osmDelay) > 0) {
        const osm = await artifact_at(OSM, PIP_[token_name]);
        await osm.poke();
      }
    }
  }

  // SET ILKS PIP WHITELIST

  console.log('Configuring ILK PIP Whitelists...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_import = token_config.import || {};
    const token_pipDeploy = token_config.pipDeploy || {};
    const token_ilks = token_config.ilks || {};

    if (token_import.pip === undefined) {
      const osm = await artifact_at(OSM, PIP_[token_name]);
      if (token_pipDeploy.type !== 'value' && Number(await osm.wards(DEPLOYER)) === 1) {
        await osm.methods['kiss(address)'](MCD_SPOT);
        await osm.methods['kiss(address)'](MCD_END);
        for (const ilk in token_ilks) {
          const ilk_config = token_ilks[ilk];
          const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

          if (ilk_config.clipDeploy !== undefined) {
            await osm.methods['kiss(address)'](MCD_CLIP_[token_name][ilk]);
            await osm.methods['kiss(address)'](CLIPPER_MOM);
          }
        }
        if (token_pipDeploy.type === 'twap') {
          if (token_pipDeploy.quote !== undefined) {
            const osmReserve = await artifact_at(OSM, VAL_[token_pipDeploy.quote]);
            await osmReserve.methods['kiss(address)'](PIP_[token_name]);
          }
        }
        if (token_pipDeploy.type === 'vault') {
          const osmReserve = await artifact_at(OSM, VAL_[token_pipDeploy.reserve]);
          await osmReserve.methods['kiss(address)'](PIP_[token_name]);
        }
        if (token_pipDeploy.type === 'xsushi') {
          const osmReserve = await artifact_at(OSM, VAL_[token_pipDeploy.reserve]);
          await osmReserve.methods['kiss(address)'](PIP_[token_name]);
        }
        if (token_pipDeploy.type === 'comp') {
          const osmReserve = await artifact_at(OSM, VAL_[token_pipDeploy.reserve]);
          await osmReserve.methods['kiss(address)'](PIP_[token_name]);
        }
        if (token_pipDeploy.type === 'univ2lp') {
          const osmToken0 = await artifact_at(OSM, VAL_[token_pipDeploy.token0]);
          await osmToken0.methods['kiss(address)'](PIP_[token_name]);
          const osmToken1 = await artifact_at(OSM, VAL_[token_pipDeploy.token1]);
          await osmToken1.methods['kiss(address)'](PIP_[token_name]);
        }
      }
    }
  }

  // SET ILKS MAT

  console.log('Configuring ILK Mats...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

      const mat = units(ilk_config.mat, 25);
      console.log('@ilk.mat', ilk_config.mat, mat);
      await filex(MCD_SPOT, ilk_name, 'mat', mat);
    }
  }

  // SET ILKS LINE

  console.log('Configuring ILK Lines...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

      const line = units(ilk_config.line, 45);
      const autoLine = units(ilk_config.autoLine, 45);
      console.log('@ilk.line', ilk_config.line, line);
      console.log('@ilk.autoLine', ilk_config.autoLine, autoLine);
      if (line > 0n && autoLine === 0n) {
        await filex(MCD_VAT, ilk_name, 'line', line);
      }
      if (autoLine > 0n) {
        const autoLineGap = units(ilk_config.autoLineGap, 45);
        const autoLineTtl = units(ilk_config.autoLineTtl, 0);
        console.log('@ilk.autoLineGap', ilk_config.autoLineGap, autoLineGap);
        console.log('@ilk.autoLineTtl', ilk_config.autoLineTtl, autoLineTtl);
        await dssAutoLine.setIlk(ilk_name, autoLine, autoLineGap, autoLineTtl);
        await dssAutoLine.exec(ilk_name);
      }
    }
  }
  await dssAutoLine.rely(MCD_PAUSE_PROXY);
  await dssAutoLine.deny(DEPLOYER);

  // SET ILKS DUST

  console.log('Configuring ILK Dusts...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

      const dust = units(ilk_config.dust, 45);
      console.log('@ilk.dust', ilk_config.dust, dust);
      await filex(MCD_VAT, ilk_name, 'dust', dust);
    }
  }

  // SET ILKS DUTY

  console.log('Configuring ILK Duties...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

      const duty = units(Math.exp(Math.log(Number(ilk_config.duty) / 100 + 1) / (60 * 60 * 24 * 365)).toFixed(27), 27);
      console.log('@ilk.duty', ilk_config.duty, duty);
      await dripAndFilex(MCD_JUG, ilk_name, 'duty', duty);
    }
  }

  // SET ILKS SPOTTER POKE

  console.log('Configuring ILK Spotter Pokes...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_import = token_config.import || {};
    const token_pipDeploy = token_config.pipDeploy || {};
    const token_ilks = token_config.ilks || {};

    if (token_import.pip === undefined) {
      const osm = await artifact_at(OSM, PIP_[token_name]);
      if (token_pipDeploy.type === 'value' || Number(await osm.bud(MCD_SPOT)) === 1) {
        for (const ilk in token_ilks) {
          const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

          await spotter.poke(ilk_name);
        }
      }
    }
  }

  // SET ILKS CHOP

  console.log('Configuring ILK Chops...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_flipDeploy = ilk_config.flipDeploy || {};
      const ilk_clipDeploy = ilk_config.clipDeploy || {};
      const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

      if (ilk_config.flipDeploy !== undefined) {
        const chop = units(ilk_flipDeploy.chop, 16) + units('100', 16);
        console.log('@flip.chop', ilk_flipDeploy.chop, chop);
        await filex(MCD_CAT, ilk_name, 'chop', chop);
      }
      if (ilk_config.clipDeploy !== undefined) {
        const chop = units(ilk_clipDeploy.chop, 16) + units('100', 16);
        console.log('@clip.chop', ilk_clipDeploy.chop, chop);
        await filex(MCD_DOG, ilk_name, 'chop', chop);
        const Clipper = artifacts.require('Clipper');
        const clipper = await artifact_at(Clipper, MCD_CLIP_[token_name][ilk]);
        await clipper.upchost();
      }
    }
  }

  // SET ILKS DUNK

  console.log('Configuring ILK Dunks...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_flipDeploy = ilk_config.flipDeploy || {};
      const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

      if (ilk_config.flipDeploy !== undefined) {
        const dunk = units(ilk_flipDeploy.dunk, 45);
        console.log('@flip.dunk', ilk_flipDeploy.dunk, dunk);
        await filex(MCD_CAT, ilk_name, 'dunk', dunk);
      }
    }
  }

  // SET ILKS BEG

  console.log('Configuring ILK Begs...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_flipDeploy = ilk_config.flipDeploy || {};

      if (ilk_config.flipDeploy !== undefined) {
        const beg = units(ilk_flipDeploy.beg, 16) + units('100', 16);
        console.log('@flip.beg', ilk_flipDeploy.beg, beg);
        await file(MCD_FLIP_[token_name][ilk], 'beg', beg);
      }
    }
  }

  // SET ILKS TTL

  console.log('Configuring ILK TTLs...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_flipDeploy = ilk_config.flipDeploy || {};

      if (ilk_config.flipDeploy !== undefined) {
        const ttl = units(ilk_flipDeploy.ttl, 0);
        console.log('@flip.ttl', ilk_flipDeploy.ttl, ttl);
        await file(MCD_FLIP_[token_name][ilk], 'ttl', ttl);
      }
    }
  }

  // SET ILKS TAU

  console.log('Configuring ILK Taus...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_flipDeploy = ilk_config.flipDeploy || {};

      if (ilk_config.flipDeploy !== undefined) {
        const tau = units(ilk_flipDeploy.tau, 0);
        console.log('@flip.tau', ilk_flipDeploy.tau, tau);
        await file(MCD_FLIP_[token_name][ilk], 'tau', tau);
      }
    }
  }

  // SET ILKS HOLE

  console.log('Configuring ILK Holes...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_clipDeploy = ilk_config.clipDeploy || {};
      const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

      if (ilk_config.clipDeploy !== undefined) {
        const hole = units(ilk_clipDeploy.hole, 45);
        console.log('@clip.hole', ilk_clipDeploy.hole, hole);
        await filex(MCD_DOG, ilk_name, 'hole', hole);
      }
    }
  }

  // SET ILKS CHIP

  console.log('Configuring ILK Chips...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_clipDeploy = ilk_config.clipDeploy || {};

      if (ilk_config.clipDeploy !== undefined) {
        const chip = units(ilk_clipDeploy.chip, 16);
        console.log('@clip.chip', ilk_clipDeploy.chip, chip);
        await file(MCD_CLIP_[token_name][ilk], 'chip', chip);
      }
    }
  }

  // SET ILKS TIP

  console.log('Configuring ILK Tips...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_clipDeploy = ilk_config.clipDeploy || {};

      if (ilk_config.clipDeploy !== undefined) {
        const tip = units(ilk_clipDeploy.tip, 45);
        console.log('@clip.tip', ilk_clipDeploy.tip, tip);
        await file(MCD_CLIP_[token_name][ilk], 'tip', tip);
      }
    }
  }

  // SET ILKS BUF

  console.log('Configuring ILK Bufs...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_clipDeploy = ilk_config.clipDeploy || {};

      if (ilk_config.clipDeploy !== undefined) {
        const buf = units(ilk_clipDeploy.buf, 25);
        console.log('@clip.buf', ilk_clipDeploy.buf, buf);
        await file(MCD_CLIP_[token_name][ilk], 'buf', buf);
      }
    }
  }

  // SET ILKS TAIL

  console.log('Configuring ILK Tails...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_clipDeploy = ilk_config.clipDeploy || {};

      if (ilk_config.clipDeploy !== undefined) {
        const tail = units(ilk_clipDeploy.tail, 0);
        console.log('@clip.tail', ilk_clipDeploy.tail, tail);
        await file(MCD_CLIP_[token_name][ilk], 'tail', tail);
      }
    }
  }

  // SET ILKS CUSP

  console.log('Configuring ILK Cusps...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_clipDeploy = ilk_config.clipDeploy || {};

      if (ilk_config.clipDeploy !== undefined) {
        const cusp = units(ilk_clipDeploy.cusp, 25);
        console.log('@clip.cusp', ilk_clipDeploy.cusp, cusp);
        await file(MCD_CLIP_[token_name][ilk], 'cusp', cusp);
      }
    }
  }

  // SET ILKS CALC PARAMS

  console.log('Configuring ILK Calc Params...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_clipDeploy = ilk_config.clipDeploy || {};
      const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

      if (ilk_config.clipDeploy !== undefined) {
        const calc_config = ilk_clipDeploy.calc || {};

        if (calc_config.type === 'LinearDecrease') {
          const tau = units(calc_config.tau, 0);
          console.log('@calc.tau', calc_config.tau, tau);
          await file(MCD_CLIP_CALC_[token_name][ilk], 'tau', tau);
        }
        if (calc_config.type === 'StairstepExponentialDecrease' || calc_config.type === 'ExponentialDecrease') {
          const cut = units(calc_config.cut, 25);
          console.log('@calc.cut', calc_config.cut, cut);
          await file(MCD_CLIP_CALC_[token_name][ilk], 'cut', cut);
        }
        if (calc_config.type === 'StairstepExponentialDecrease') {
          const step = units(calc_config.step, 0);
          console.log('@calc.step', calc_config.step, step);
          await file(MCD_CLIP_CALC_[token_name][ilk], 'step', step);
        }
      }
    }
  }

  // SET ILKS FAUCET

  console.log('Configuring ILK Faucets...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_import = token_config.import || {};
    const token_gemDeploy = token_config.gemDeploy || {};

    if (Number(token_gemDeploy.faucetSupply) > 0) {
      const supply = units(token_gemDeploy.faucetSupply, 0);
      const newToken = await artifact_at(DSToken, T_[token_name]);
      await newToken.transfer(FAUCET, supply);
    }
    if (config_import.faucet === undefined) {
      if (Number(token_gemDeploy.faucetAmount) > 0) {
        const amount = units(token_gemDeploy.faucetAmount, 0);
        await restrictedTokenFaucet.setAmt(T_[token_name], amount);
      }
    }
  }

  // SET ILKS OSM

  console.log('Configuring ILK OSM...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_import = token_config.import || {};
    const token_pipDeploy = token_config.pipDeploy || {};

    if (token_import.pip === undefined) {
      if (Number(token_pipDeploy.osmDelay) > 0) {
        const osmDelay = units(token_pipDeploy.osmDelay, 0);
        console.log('@pip.osmDelay', token_pipDeploy.osmDelay, osmDelay);
        console.log('Deploying OSM...');
        const osm = await artifact_deploy(OSM, VAL_[token_name]);
        PIP_[token_name] = osm.address;
        console.log('PIP_' + token_name.replace('-', '_') + '=' + PIP_[token_name]);
        await osm.step(osmDelay);
        if (token_pipDeploy.type === 'twap') {
          const univ2twapOracle = await artifact_at(UniV2TwapOracle, VAL_[token_name]);
          await univ2twapOracle.methods['kiss(address)'](PIP_[token_name]);
        }
        if (token_pipDeploy.type === 'vault') {
          const vaultOracle = await artifact_at(VaultOracle, VAL_[token_name]);
          await vaultOracle.methods['kiss(address)'](PIP_[token_name]);
        }
        if (token_pipDeploy.type === 'xsushi') {
          const xsushiOracle = await artifact_at(XSushiOracle, VAL_[token_name]);
          await xsushiOracle.methods['kiss(address)'](PIP_[token_name]);
        }
        if (token_pipDeploy.type === 'comp') {
          const compOracle = await artifact_at(CompOracle, VAL_[token_name]);
          await compOracle.methods['kiss(address)'](PIP_[token_name]);
        }
        if (token_pipDeploy.type === 'univ2lp') {
          const univ2lpOracle = await artifact_at(UNIV2LPOracle, VAL_[token_name]);
          await univ2lpOracle.methods['kiss(address)'](PIP_[token_name]);
        }
        if (token_pipDeploy.type === 'chainlink') {
          const linkOracle = await artifact_at(LinkOracle, VAL_[token_name]);
          await linkOracle.methods['kiss(address)'](PIP_[token_name]);
        }
        if (token_pipDeploy.type === 'median') {
          const median = await artifact_at(Median, VAL_[token_name]);
          await median.methods['kiss(address)'](PIP_[token_name]);
        }
        await osm.methods['kiss(address)'](MCD_SPOT);
        await osm.methods['kiss(address)'](MCD_END);
        for (const ilk in token_ilks) {
          const ilk_config = token_ilks[ilk];
          const ilk_clipDeploy = ilk_config.clipDeploy || {};
          const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

          if (ilk_config.clipDeploy !== undefined) {
            await osm.methods['kiss(address)'](MCD_CLIP_[token][ilk]);
            await osm.methods['kiss(address)'](CLIPPER_MOM);
          }
          await filex(MCD_SPOT, ilk_name, 'pip', PIP_[token_name]);
        }
        await osm.rely(MCD_PAUSE_PROXY);
        await osm.deny(DEPLOYER);
      }
    }
  }

  // SET ILKS OSM-MOM

  console.log('Configuring OSM Mom...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_import = token_config.import || {};
    const token_pipDeploy = token_config.pipDeploy || {};
    const token_ilks = token_config.ilks || {};

    if (token_import.pip === undefined) {
      if (Number(token_pipDeploy.osmDelay) > 0) {
        const osm = await artifact_at(OSM, PIP_[token_name]);
        for (const ilk in token_ilks) {
          const ilk_name = web3.utils.asciiToHex(token_name + '-' + ilk);

          await osmMom.setOsm(ilk_name, PIP_[token_name]);
          if (Number(await osm.wards(DEPLOYER)) === 1) {
            await osm.rely(OSM_MOM);
          }
        }
      }
    }
  }
  await osmMom.setAuthority(MCD_ADM);
  await osmMom.setOwner(MCD_PAUSE_PROXY);

  // SET ILKS FLIPPER-MOM

  console.log('Configuring Flipper Mom...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_flipDeploy = ilk_config.flipDeploy || {};

      if (ilk_config.flipDeploy !== undefined) {
        await rely(MCD_FLIP_[token_name][ilk], FLIPPER_MOM);
      }
    }
  }
  await flipperMom.setAuthority(MCD_ADM);
  await flipperMom.setOwner(MCD_PAUSE_PROXY);

  // SET ILKS CLIPPER-MOM

  console.log('Configuring Clipper Mom...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      const ilk_config = token_ilks[ilk];
      const ilk_clipDeploy = ilk_config.clipDeploy || {};

      if (ilk_config.clipDeploy !== undefined) {
        await rely(MCD_CLIP_[token_name][ilk], CLIPPER_MOM);
        const cm_tolerance = units(ilk_clipDeploy.cm_tolerance, 25);
        console.log('@clip.cm_tolerance', ilk_clipDeploy.cm_tolerance, cm_tolerance);
        await clipperMom.setPriceTolerance(MCD_CLIP_[token_name][ilk], cm_tolerance);
      }
    }
  }
  await clipperMom.setAuthority(MCD_ADM);
  await clipperMom.setOwner(MCD_PAUSE_PROXY);

  // SET PIPS RIGHTS

  console.log('Configuring PIPs Rights...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_import = token_config.import || {};
    const token_pipDeploy = token_config.pipDeploy || {};

    if (token_import.pip === undefined) {
      if (token_pipDeploy.type === 'twap') {
        const univ2twapOracle = await artifact_at(UniV2TwapOracle, VAL_[token_name]);
        await univ2twapOracle.rely(MCD_PAUSE_PROXY);
        await univ2twapOracle.deny(DEPLOYER);
      }
      if (token_pipDeploy.type === 'vault') {
        const vaultOracle = await artifact_at(VaultOracle, VAL_[token_name]);
        await vaultOracle.rely(MCD_PAUSE_PROXY);
        await vaultOracle.deny(DEPLOYER);
      }
      if (token_pipDeploy.type === 'xsushi') {
        const xsushiOracle = await artifact_at(XSushiOracle, VAL_[token_name]);
        await xsushiOracle.rely(MCD_PAUSE_PROXY);
        await xsushiOracle.deny(DEPLOYER);
      }
      if (token_pipDeploy.type === 'comp') {
        const compOracle = await artifact_at(CompOracle, VAL_[token_name]);
        await compOracle.rely(MCD_PAUSE_PROXY);
        await compOracle.deny(DEPLOYER);
      }
      if (token_pipDeploy.type === 'univ2lp') {
        const univ2lpOracle = await artifact_at(UNIV2LPOracle, VAL_[token_name]);
        await univ2lpOracle.rely(MCD_PAUSE_PROXY);
        await univ2lpOracle.deny(DEPLOYER);
      }
      if (token_pipDeploy.type === 'chainlink') {
        const linkOracle = await artifact_at(LinkOracle, VAL_[token_name]);
        await linkOracle.rely(MCD_PAUSE_PROXY);
        await linkOracle.deny(DEPLOYER);
      }
      if (token_pipDeploy.type === 'median') {
        const median = await artifact_at(Median, VAL_[token_name]);
        await median.rely(MCD_PAUSE_PROXY);
        await median.deny(DEPLOYER);
      }
      if (token_pipDeploy.type === 'value') {
        const dsValue = await artifact_at(DSValue, VAL_[token_name]);
        await dsValue.setOwner(MCD_PAUSE_PROXY);
      }
      if (Number(token_pipDeploy.osmDelay) > 0) {
        const osm = await artifact_at(OSM, PIP_[token_name]);
        await osm.rely(MCD_PAUSE_PROXY);
        await osm.deny(DEPLOYER);
      }
    }
  }

  // SET ILK REGISTRY

  console.log('Configuring ILK Registry...');
  for (const token_name in config_tokens) {
    const token_config = config_tokens[token_name];
    const token_ilks = token_config.ilks || {};

    for (const ilk in token_ilks) {
      await ilkRegistry.add(MCD_JOIN_[token_name][ilk]);
    }
  }
  await ilkRegistry.rely(MCD_PAUSE_PROXY);
  await ilkRegistry.deny(DEPLOYER);

  // LERP

  console.log('Deploying Lerp Factory...');
  const LerpFactory = artifacts.require('LerpFactory');
  const lerpFactory = await artifact_deploy(LerpFactory);
  const LERP_FAB = lerpFactory.address;
  console.log('LERP_FAB=' + LERP_FAB);
  await lerpFactory.rely(MCD_PAUSE_PROXY);
  await lerpFactory.deny(DEPLOYER);

  // CONFIGURE CHAIN LOG

  console.log('Configuring Chain Log...');
  for (const token_name in T_) {
    await chainLog.setAddress(web3.utils.asciiToHex(token_name), T_[token_name]);
  }
  for (const token_name in PIP_) {
    await chainLog.setAddress(web3.utils.asciiToHex('PIP_' + token_name.replace('-', '_')), PIP_[token_name]);
  }
  for (const token_name in MCD_JOIN_) {
    for (const ilk in MCD_JOIN_[token_name]) {
      await chainLog.setAddress(web3.utils.asciiToHex('MCD_JOIN_' + token_name.replace('-', '_') + '_' + ilk), MCD_JOIN_[token_name][ilk]);
    }
  }
  for (const token_name in MCD_FLIP_) {
    for (const ilk in MCD_FLIP_[token_name]) {
      await chainLog.setAddress(web3.utils.asciiToHex('MCD_FLIP_' + token_name.replace('-', '_') + '_' + ilk), MCD_FLIP_[token_name][ilk]);
    }
  }
  for (const token_name in MCD_CLIP_) {
    for (const ilk in MCD_CLIP_[token_name]) {
      await chainLog.setAddress(web3.utils.asciiToHex('MCD_CLIP_' + token_name.replace('-', '_') + '_' + ilk), MCD_CLIP_[token_name][ilk]);
    }
  }
  for (const token_name in MCD_CLIP_CALC_) {
    for (const ilk in MCD_CLIP_CALC_[token_name]) {
      await chainLog.setAddress(web3.utils.asciiToHex('MCD_CLIP_CALC_' + token_name.replace('-', '_') + '_' + ilk), MCD_CLIP_CALC_[token_name][ilk]);
    }
  }
  for (const token_name in MCD_PSM_) {
    for (const ilk in MCD_PSM_[token_name]) {
      await chainLog.setAddress(web3.utils.asciiToHex('MCD_' + token_name.replace('-', '_') + '_' + ilk), MCD_PSM_[token_name][ilk]);
    }
  }
  await chainLog.setAddress(web3.utils.asciiToHex('CDP_MANAGER'), CDP_MANAGER);
  await chainLog.setAddress(web3.utils.asciiToHex('CHANGELOG'), CHANGELOG);
  await chainLog.setAddress(web3.utils.asciiToHex('CLIP_FAB'), CLIP_FAB);
  await chainLog.setAddress(web3.utils.asciiToHex('CLIPPER_MOM'), CLIPPER_MOM);
  await chainLog.setAddress(web3.utils.asciiToHex('DSR_MANAGER'), DSR_MANAGER);
  await chainLog.setAddress(web3.utils.asciiToHex('FAUCET'), FAUCET);
  await chainLog.setAddress(web3.utils.asciiToHex('FLIP_FAB'), FLIP_FAB);
  await chainLog.setAddress(web3.utils.asciiToHex('FLIPPER_MOM'), FLIPPER_MOM);
  await chainLog.setAddress(web3.utils.asciiToHex('GET_CDPS'), GET_CDPS);
  await chainLog.setAddress(web3.utils.asciiToHex('GOV_GUARD'), GOV_GUARD);
  await chainLog.setAddress(web3.utils.asciiToHex('ILK_REGISTRY'), ILK_REGISTRY);
  await chainLog.setAddress(web3.utils.asciiToHex('LERP_FAB'), LERP_FAB);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_ADM'), MCD_ADM);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_CAT'), MCD_CAT);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_DAI'), MCD_DAI);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_DEPLOY'), MCD_DEPLOY);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_DOG'), MCD_DOG);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_END'), MCD_END);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_ESM'), MCD_ESM);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_FLAP'), MCD_FLAP);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_FLASH'), MCD_FLASH);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_AMO'), MCD_AMO);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_FLOP'), MCD_FLOP);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_GOV'), MCD_GOV);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_GOV_ACTIONS'), MCD_GOV_ACTIONS);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_IAM_AUTO_LINE'), MCD_IAM_AUTO_LINE);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_JOIN_DAI'), MCD_JOIN_DAI);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_JUG'), MCD_JUG);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_PAUSE'), MCD_PAUSE);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_PAUSE_PROXY'), MCD_PAUSE_PROXY);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_POT'), MCD_POT);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_SPOT'), MCD_SPOT);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_VAT'), MCD_VAT);
  await chainLog.setAddress(web3.utils.asciiToHex('MCD_VOW'), MCD_VOW);
  await chainLog.setAddress(web3.utils.asciiToHex('MULTICALL'), MULTICALL);
  await chainLog.setAddress(web3.utils.asciiToHex('OSM_MOM'), OSM_MOM);
  await chainLog.setAddress(web3.utils.asciiToHex('PROXY_ACTIONS'), PROXY_ACTIONS);
  await chainLog.setAddress(web3.utils.asciiToHex('PROXY_ACTIONS_DSR'), PROXY_ACTIONS_DSR);
  await chainLog.setAddress(web3.utils.asciiToHex('PROXY_ACTIONS_END'), PROXY_ACTIONS_END);
  await chainLog.setAddress(web3.utils.asciiToHex('PROXY_DEPLOYER'), PROXY_DEPLOYER);
  await chainLog.setAddress(web3.utils.asciiToHex('PROXY_FACTORY'), PROXY_FACTORY);
  await chainLog.setAddress(web3.utils.asciiToHex('PROXY_PAUSE_ACTIONS'), PROXY_PAUSE_ACTIONS);
  await chainLog.setAddress(web3.utils.asciiToHex('PROXY_REGISTRY'), PROXY_REGISTRY);
  await chainLog.setAddress(web3.utils.asciiToHex('VOTE_DELEGATE_PROXY_FACTORY'), VOTE_DELEGATE_PROXY_FACTORY);
  await chainLog.setAddress(web3.utils.asciiToHex('VOTE_PROXY_FACTORY'), VOTE_PROXY_FACTORY);
  await chainLog.deny(DEPLOYER);

  // SET PAUSE AUTH DELAY

  console.log('Configuring Authority & Delay...');
  if (Number(config.pauseDelay) > 0) {
    await setAuthorityAndDelay(MCD_ADM, units(config.pauseDelay, 0));
  }

  // TRANSFER DEPLOYER ADMIN RIGHTS TO MULTISIG

  console.log('Transfering Admin Rights to Multisig...');
  await dsRoles.setRootUser(MULTISIG, true);
  await dsRoles.setRootUser(DEPLOYER, false);
  await dsRoles.setOwner(MULTISIG);
  await proxyDeployer.setOwner(MULTISIG);

  const finalBalance = await web3.eth.getBalance(DEPLOYER);
  const gasPrice = await web3.eth.getGasPrice();
  console.log('TOTAL COST:', BigInt(initialBalance) - BigInt(finalBalance), 'GAS:', BigInt(gasPrice));
};
