import 'package:canteendesk/API/Cred.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class ImgBBService {
  // Replace with your ImgBB API key - get one for free at https://api.imgbb.com/
  final String apiKey = Cred.imgBB;
  
  Future<String?> uploadImage(File imageFile) async {
    try {
      // Read file as bytes and encode
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      
      // Create request
      var request = http.MultipartRequest('POST', 
          Uri.parse('https://api.imgbb.com/1/upload'));
      
      // Add API key and image data
      request.fields['key'] = apiKey;
      request.fields['image'] = base64Image;
      
      // Send request
      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var result = json.decode(String.fromCharCodes(responseData));
      
      // Check if successful
      if (result['success'] == true) {
        // Return direct URL to image
        return result['data']['url'];
      } else {
        throw Exception('Failed to upload image to ImgBB');
      }
    } catch (e) {
      print('Error uploading to ImgBB: $e');
      return null;
    }
  }
}

class Cred {
  static String imgBB = '';
}