library api;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';

import 'package:wallet_core/models/api.dart';
import 'package:wallet_core/src/web3.dart';

class WalletApi extends Api {
  late String _base;
  late Client _client;
  String? _jwtToken;
  late String _phoneNumber;

  WalletApi(
    String base,
  )   : _base = base,
        _client = Client();

  void setJwtToken(String jwtToken) {
    _jwtToken = jwtToken;
  }

  Future<Map<String, dynamic>> _get(
    String endpoint, {
    bool private = false,
    bool isRopsten = false,
  }) async {
    print('GET $endpoint');
    Response response;
    String uri = isRopsten ? toRopsten(_base) : _base;
    if (private) {
      response = await _client.get(
        Uri.parse('$uri/$endpoint'),
        headers: {
          "Authorization": "Bearer $_jwtToken",
        },
      );
    } else {
      response = await _client.get(Uri.parse('$uri/$endpoint'));
    }
    return responseHandler(response);
  }

  Future<Map<String, dynamic>> _post(
    String endpoint, {
    dynamic body,
    bool private = false,
    bool isRopsten = false,
  }) async {
    print('POST $endpoint $body');
    Response response;
    body = body == null ? body : json.encode(body);
    String uri = isRopsten ? toRopsten(_base) : _base;
    if (private) {
      response = await _client.post(
        Uri.parse('$uri/$endpoint'),
        body: body,
        headers: {
          "Authorization": "Bearer $_jwtToken",
          "Content-Type": 'application/json'
        },
      );
    } else {
      response = await _client.post(
        Uri.parse('$uri/$endpoint'),
        body: body,
        headers: {
          "Content-Type": 'application/json',
        },
      );
    }
    return responseHandler(response);
  }

  Future<Map<String, dynamic>> _put(
    String endpoint, {
    dynamic body,
    bool private = false,
  }) async {
    print('PUT $endpoint $body');
    Response response;
    body = body == null ? body : json.encode(body);
    if (private) {
      response = await _client.put(
        Uri.parse('$_base/$endpoint'),
        body: body,
        headers: {
          "Authorization": "Bearer $_jwtToken",
          "Content-Type": 'application/json'
        },
      );
    } else {
      response = await _client.put(
        Uri.parse('$_base/$endpoint'),
        body: body,
        headers: {
          "Content-Type": 'application/json',
        },
      );
    }
    return responseHandler(response);
  }

  // Login using Firebase
  Future<String> loginWithFirebase(
    String token,
    String accountAddress,
    String identifier, {
    String? appName,
  }) async {
    Map<String, dynamic> resp = await _post(
      'v1/login/firebase/verify',
      body: {
        "token": token,
        "accountAddress": accountAddress,
        "identifier": identifier,
        "appName": appName
      },
    );
    if (resp["token"] != "") {
      _jwtToken = resp["token"];
      return _jwtToken!;
    } else {
      throw 'Error! Login verify failed - accountAddress: $accountAddress, token: $token, identifier: $identifier';
    }
  }

  // Login using sms
  Future<bool> loginWithSMS(
    String phoneNumber,
  ) async {
    Map<String, dynamic> resp = await _post(
      'v1/login/sms/request',
      body: {
        "phoneNumber": phoneNumber,
      },
    );
    if (resp["response"] == "ok") {
      return true;
    } else {
      throw 'Error! Login request failed - phoneNumber: $phoneNumber';
    }
  }

  // Verify using sms
  Future<String> verifySMS(
    String verificationCode,
    String phoneNumber,
    String accountAddress, {
    String? appName,
  }) async {
    Map<String, dynamic> resp = await _post(
      'v1/login/sms/verify',
      body: {
        "code": verificationCode,
        "phoneNumber": phoneNumber,
        "accountAddress": accountAddress,
        "appName": appName,
      },
    );
    if (resp["token"] != "") {
      _jwtToken = resp["token"];
      _phoneNumber = phoneNumber;
      return _jwtToken!;
    } else {
      throw 'Error! Login verify failed - phoneNumber: $phoneNumber, verificationCode: $verificationCode';
    }
  }

  // Request token
  Future<String> requestToken(
    String phoneNumber,
    String accountAddress, {
    String? appName,
  }) async {
    Map<String, dynamic> resp = await _post(
      'v1/login/request',
      body: {
        "phoneNumber": phoneNumber,
        "accountAddress": accountAddress,
        "appName": appName
      },
    );
    if (resp["token"] != "") {
      _jwtToken = resp["token"];
      _phoneNumber = phoneNumber;
      return _jwtToken!;
    } else {
      throw 'Error! Login verify failed - phoneNumber: $phoneNumber';
    }
  }

  Future<dynamic> createWallet({
    String? communityAddress,
    String? referralAddress,
  }) async {
    dynamic wallet = await getWallet();
    if (wallet != null && wallet["walletAddress"] != null) {
      print('Wallet already exists - wallet: $wallet');
      return wallet;
    }
    final Map body = {};
    if (communityAddress != null) body['communityAddress'] = communityAddress;
    if (referralAddress != null) body['referralAddress'] = referralAddress;
    Map<String, dynamic> resp = await _post(
      'v1/wallets',
      private: true,
      body: body,
    );
    if (resp["job"] != null) {
      return resp;
    } else {
      throw 'Error! Create wallet request failed for phoneNumber: $_phoneNumber';
    }
  }

  Future<dynamic> getWallet() async {
    Map<String, dynamic> resp = await _get('v1/wallets', private: true);
    if (resp["data"] != null) {
      return {
        "phoneNumber": resp["data"]["phoneNumber"],
        "accountAddress": resp["data"]["accountAddress"],
        "walletAddress": resp["data"]["walletAddress"],
        "createdAt": resp["data"]["createdAt"],
        "updatedAt": resp["data"]["updatedAt"],
        "communityManager": resp['data']['walletModules']['CommunityManager'],
        "transferManager": resp['data']['walletModules']['TransferManager'],
        "dAIPointsManager":
            resp['data']['walletModules']['DAIPointsManager'] ?? null,
        "networks": resp['data']['networks'],
        "backup": resp["data"]['backup'],
        "balancesOnForeign": resp['data']['balancesOnForeign'],
        "apy": resp['data']['apy']
      };
    } else {
      return {};
    }
  }

  Future<Map<String, dynamic>> getActionsByWalletAddress(
    String walletAddress, {
    int updatedAt = 0,
    String? tokenAddress,
  }) async {
    String url = 'v1/wallets/actions/$walletAddress?updatedAt=$updatedAt';
    url = tokenAddress != null ? '$url&tokenAddress=$tokenAddress' : url;
    Map<String, dynamic> resp = await _get(
      url,
      private: true,
    );
    return resp['data'];
  }

  Future<Map<String, dynamic>> getPaginatedActionsByWalletAddress(
    String walletAddress,
    int pageIndex, {
    String? tokenAddress,
  }) async {
    String url = 'v1/wallets/actions/paginated/$walletAddress?page=$pageIndex';
    url = tokenAddress != null ? '$url&tokenAddress=$tokenAddress' : url;
    Map<String, dynamic> resp = await _get(
      url,
      private: true,
    );
    return resp['data'];
  }

  Future<dynamic> getAvailableUpgrades(
    String walletAddress,
  ) async {
    Map<String, dynamic> resp = await _get(
      'v1/wallets/upgrades/available/$walletAddress',
      private: true,
    );
    return resp['data'];
  }

  Future<dynamic> installUpgrades(
    Web3 web3,
    String walletAddress,
    String disableModuleName,
    String disableModuleAddress,
    String enableModuleAddress,
    String upgradeId,
  ) async {
    Map<String, dynamic> relayParams = await web3.addModule(
      walletAddress,
      disableModuleName,
      disableModuleAddress,
      enableModuleAddress,
    );
    Map<String, dynamic> resp = await _post(
      'v1/wallets/upgrades/install/$walletAddress',
      private: true,
      body: {
        "upgradeId": upgradeId,
        "relayParams": relayParams,
      },
    );
    return resp['data'];
  }

  Future<Map<String, dynamic>> getNextReward(
    String walletAddress,
  ) async {
    Map<String, dynamic> resp = await _get(
      'v1/wallets/apy/reward/$walletAddress',
      private: true,
    );
    return resp['data'];
  }

  Future<Map<String, dynamic>> claimReward(
    String walletAddress,
  ) async {
    Map<String, dynamic> resp = await _post(
      'v1/wallets/apy/claim/$walletAddress',
      private: true,
    );
    return resp['data'];
  }

  Future<Map<String, dynamic>> enableWalletApy(
    String walletAddress,
  ) async {
    Map<String, dynamic> resp = await _post(
      'v1/wallets/apy/enable/$walletAddress',
      private: true,
    );
    return resp['data'];
  }

  Future<dynamic> getJob(String id) async {
    Map<String, dynamic> resp = await _get(
      'v1/jobs/$id',
      private: true,
    );
    if (resp["data"] != null) {
      return resp["data"];
    } else {
      return null;
    }
  }

  Future<dynamic> getWalletByPhoneNumber(
    String phoneNumber,
  ) async {
    Map<String, dynamic> resp = await _get(
      'v1/wallets/$phoneNumber',
      private: true,
    );
    if (resp["data"] != null) {
      return {
        "phoneNumber": resp["data"]["phoneNumber"],
        "accountAddress": resp["data"]["accountAddress"],
        "walletAddress": resp["data"]["walletAddress"],
        "createdAt": resp["data"]["createdAt"],
        "updatedAt": resp["data"]["updatedAt"]
      };
    } else {
      return {};
    }
  }

  Future<dynamic> updateFirebaseToken(
    String walletAddress,
    String firebaseToken,
  ) async {
    Map<String, dynamic> resp = await _put(
      'v1/wallets/token/$walletAddress',
      body: {"firebaseToken": firebaseToken},
      private: true,
    );
    return resp;
  }

  Future<dynamic> addUserContext(
    Map<dynamic, dynamic> body,
  ) async {
    Map<String, dynamic> resp = await _put(
      'v1/wallets/context',
      body: body,
      private: true,
    );
    return resp;
  }

  Future<dynamic> deleteFirebaseToken(
    String walletAddress,
    String firebaseToken,
  ) async {
    Map<String, dynamic> resp = await _put(
      'v1/wallets/token/$walletAddress/delete',
      body: {"firebaseToken": firebaseToken},
      private: true,
    );
    return resp;
  }

  Future<dynamic> backupWallet({
    String? communityAddress,
    bool isFunderDeprecated = true,
  }) async {
    Map<String, dynamic> resp = await _post(
      'v1/wallets/backup',
      body: {"communityAddress": communityAddress},
      private: true,
    );
    return resp;
  }

  Future<dynamic> joinCommunity(
    Web3 web3,
    String walletAddress,
    String communityAddress, {
    String? tokenAddress,
    String network = 'fuse',
    String? originNetwork,
    String? communityName,
  }) async {
    Map<String, dynamic> data = await web3.joinCommunityOffChain(
      walletAddress,
      communityAddress,
      tokenAddress: tokenAddress,
      network: network,
      originNetwork: originNetwork,
      communityName: communityName,
    );
    Map<String, dynamic> resp = await _post(
      'v1/relay',
      private: true,
      body: data,
    );
    return resp;
  }

  Future<dynamic> transfer(
    Web3 web3,
    String walletAddress,
    String receiverAddress,
    num amountInWei, {
    String network = "fuse",
    Map? transactionBody,
  }) async {
    Map<String, dynamic> data = await web3.transferOffChain(
      walletAddress,
      receiverAddress,
      amountInWei,
      network: network,
      transactionBody: transactionBody,
    );
    Map<String, dynamic> resp = await _post(
      'v1/relay',
      private: true,
      body: data,
    );
    return resp;
  }

  Future<dynamic> tokenTransfer(
    Web3 web3,
    String walletAddress,
    String tokenAddress,
    String receiverAddress,
    num tokensAmount, {
    String network = 'fuse',
    String? externalId,
  }) async {
    Map<String, dynamic> data = await web3.transferTokenOffChain(
      walletAddress,
      tokenAddress,
      receiverAddress,
      tokensAmount,
      network: network,
      externalId: externalId,
    );
    Map<String, dynamic> resp = await _post(
      'v1/relay',
      private: true,
      body: data,
    );
    return resp;
  }

  Future<dynamic> approveTokenTransfer(
    Web3 web3,
    String walletAddress,
    String tokenAddress, {
    String network = 'fuse',
    num? tokensAmount,
    BigInt? amountInWei,
  }) async {
    Map<String, dynamic> data = await web3.approveTokenOffChain(
      walletAddress,
      tokenAddress,
      tokensAmount: tokensAmount,
      amountInWei: amountInWei,
      network: network,
    );
    Map<String, dynamic> resp = await _post(
      'v1/relay',
      private: true,
      body: data,
    );
    return resp;
  }

  Future<dynamic> transferDaiToDaiPointsOffChain(
    Web3 web3,
    String walletAddress,
    num tokensAmount,
    int tokenDecimals, {
    String? network,
  }) async {
    Map<String, dynamic> data = await web3.transferDaiToDAIpOffChain(
      walletAddress,
      tokensAmount,
      tokenDecimals,
      network: network,
    );
    Map<String, dynamic> resp = await _post(
      'v1/relay',
      private: true,
      body: data,
    );
    return resp;
  }

  Future<dynamic> callContract(
    Web3 web3,
    String walletAddress,
    String contractAddress,
    String data, {
    String? network,
    num? ethAmount,
    BigInt? amountInWei,
    Map? transactionBody,
    Map? txMetadata,
  }) async {
    Map<String, dynamic> signedData = await web3.callContractOffChain(
      walletAddress,
      contractAddress,
      data,
      network: network,
      ethAmount: ethAmount,
      amountInWei: amountInWei,
      transactionBody: transactionBody,
      txMetadata: txMetadata,
    );
    Map<String, dynamic> resp = await _post(
      'v1/relay',
      private: true,
      body: signedData,
    );
    return resp;
  }

  Future<dynamic> approveTokenAndCallContract(
    Web3 web3,
    String walletAddress,
    String tokenAddress,
    String contractAddress,
    num tokensAmount,
    String data, {
    String? network,
    Map? transactionBody,
    Map? txMetadata,
  }) async {
    Map<String, dynamic> signedData =
        await web3.approveTokenAndCallContractOffChain(
      walletAddress,
      tokenAddress,
      contractAddress,
      tokensAmount,
      data,
      network: network,
      transactionBody: transactionBody,
      txMetadata: txMetadata,
    );
    Map<String, dynamic> resp = await _post(
      'v1/relay',
      private: true,
      body: signedData,
    );
    return resp;
  }

  Future<dynamic> multiRelay(
    List<dynamic> items,
  ) async {
    Map<String, dynamic> resp = await _post(
      'v1/relay/multi',
      private: true,
      body: {'items': items},
    );
    return resp;
  }

  Future<dynamic> syncContacts(
    List<String> phoneNumbers,
  ) async {
    Map<String, dynamic> resp = await _post(
      'v1/contacts',
      body: {"contacts": phoneNumbers},
      private: true,
    );
    return resp["data"];
  }

  Future<dynamic> ackSync(int nonce) async {
    Map<String, dynamic> resp = await _post(
      'v1/contacts/$nonce',
      private: true,
    );
    return resp;
  }

  Future<dynamic> invite(
    String phoneNumber, {
    String communityAddress = '',
    String name = '',
    String amount = '',
    String symbol = '',
    bool isFunderDeprecated = true,
  }) async {
    Map<String, dynamic> resp = await _post(
      'v1/wallets/invite/$phoneNumber',
      body: {
        "communityAddress": communityAddress,
        "name": name,
        "amount": amount,
        "symbol": symbol,
        'isFunderDeprecated': isFunderDeprecated,
      },
      private: true,
    );
    return resp;
  }

  Future<dynamic> transferTokenToHomeWithAMBBridge(
    Web3 web3,
    String walletAddress,
    String foreignBridgeMediator,
    String tokenAddress,
    num tokensAmount,
    int tokenDecimals, {
    String network = 'mainnet',
  }) async {
    List<dynamic> signData = await web3.transferTokenToHome(
      walletAddress,
      foreignBridgeMediator,
      tokenAddress,
      tokensAmount,
      tokenDecimals,
      network: network,
    );
    Map<String, dynamic> resp = await multiRelay(
      signData,
    );
    return resp;
  }

  Future<dynamic> transferTokenToForeignWithAMBBridge(
    Web3 web3,
    String walletAddress,
    String homeBridgeMediatorAddress,
    String tokenAddress,
    num tokensAmount,
    int tokenDecimals, {
    String network = 'fuse',
  }) async {
    List<dynamic> signData = await web3.transferTokenToForeign(
      walletAddress,
      homeBridgeMediatorAddress,
      tokenAddress,
      tokensAmount,
      tokenDecimals,
      network: network,
    );
    Map<String, dynamic> resp = await multiRelay(
      signData,
    );
    return resp;
  }
}
