import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectionCheck {
  Future<String> checkConnection(BuildContext context) async {
    var connectivityResults = await Connectivity().checkConnectivity();
    String status;
    if (connectivityResults.contains(ConnectivityResult.mobile)) {
      status = 'data';
      return status;
    } else if (connectivityResults.contains(ConnectivityResult.wifi)) {
      status = 'wifi';
      return status;
    } else if (connectivityResults.contains(ConnectivityResult.none)) {
      status = 'Please connect the internet';
      return status;
    } else {
      status = 'Unknown network status';
      return status;
    }
  }
}
