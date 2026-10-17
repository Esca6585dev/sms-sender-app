import 'package:dio/dio.dart';

class ApiService {

  final Dio dio = Dio(
    BaseOptions(
      baseUrl:"https://atom.com.tm/elitepanel/sms",
      headers:{
        "Integration-Key": "zSh9UAmeVTyITt2dzeveH7TOozoACKvD0tJmSnI1jEc="
      }
    )
  );

  Future<void> testApi() async {
    try {
      final response = await dio.get("/contacts/count/");
      print("STATUS: ${response.statusCode}");
      print("DATA: ${response.data}");
    } on DioException catch (e) {
      print("STATUS: ${e.response?.statusCode}");
      print("DATA: ${e.response?.data}");
      print("MESSAGE: ${e.message}");
    }
  }
}