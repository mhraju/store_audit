import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:store_audit/service/file_upload_download.dart';

import '../utility/show_alert.dart';

class ConnectionCheck {
  Future<void> checkConnection(BuildContext context) async {
    var connectivityResults = await Connectivity().checkConnectivity();

    String status;
    final fileUploadDownload = FileUploadDownload(); // Replace with your class

    if (connectivityResults.contains(ConnectivityResult.mobile)) {
      status = 'Connected to a mobile network';
      await fileUploadDownload.uploadFile(context); // Call your upload logic
    } else if (connectivityResults.contains(ConnectivityResult.wifi)) {
      status = 'Connected to a Wi-Fi network';
      await fileUploadDownload.uploadImages(context); // Call your upload logic
    } else if (connectivityResults.contains(ConnectivityResult.none)) {
      status = 'No internet connection';
      // Show a SnackBar with the status
      ShowAlert.showSnackBar(context, status);
    } else {
      status = 'Unknown network status';
      // Show a SnackBar with the status
      ShowAlert.showSnackBar(context, status);
    }
  }
}
