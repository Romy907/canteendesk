import 'package:canteendesk/API/Cred.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ImgBBService {
  // Replace with your ImgBB API key - get one for free at https://api.imgbb.com/
  final String apiKey = Cred.imgBB;
  
  Future<String?> uploadImage(File imageFile) async {
    try {
      debugPrint('Starting image upload...');
      
      // Read file as bytes and encode
      List<int> imageBytes = await imageFile.readAsBytes();
      debugPrint('Image read as bytes successfully.');
      
      String base64Image = base64Encode(imageBytes);
      debugPrint('Image encoded to Base64 successfully.');
      
      // Create request
      var request = http.MultipartRequest('POST', 
          Uri.parse('https://api.imgbb.com/1/upload'));
      debugPrint('Multipart request created.');
      
      // Add API key and image data
      request.fields['key'] = apiKey;
      request.fields['image'] = base64Image;
      debugPrint('API key and image data added to request.');
      
      // Send request
      var response = await request.send();
      debugPrint('Request sent to ImgBB.');
      
      var responseData = await response.stream.toBytes();
      debugPrint('Response received from ImgBB.');
      
      var result = json.decode(String.fromCharCodes(responseData));
      debugPrint('Response decoded: $result');
      
      // Check if successful
      if (result['success'] == true) {
        debugPrint('Image uploaded successfully. URL: ${result['data']['url']}');
        // Return direct URL to image
        return result['data']['url'];
      } else {
        debugPrint('Failed to upload image: ${result['error']['message']}');
        throw Exception('Failed to upload image to ImgBB');
      }
    } catch (e) {
      debugPrint('Error uploading to ImgBB: $e');
      return null;
    }
  }
}