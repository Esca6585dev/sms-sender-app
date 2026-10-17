import 'package:dio/dio.dart';


class Contact {
  final int id;
  final String title;
  final String phone_number;
  final bool isSent;

  Contact({
    required this.id,
    required this.title,
    required this.phone_number,
    required this.isSent,
  });


  factory Contact.fromJson(Map<String,dynamic> json){
    return Contact(
      id: json["id"] ?? 0,
      title: json["title"] ?? "",
      phone_number: json["phone_number"] ?? "",
      isSent: json["is_sent"] ?? false,
    );
  }
}


class Message {
  final int id;
  final String messageText;
  final String date;

  Message({
    required this.id,
    required this.messageText,
    required this.date,
  });


  factory Message.fromJson(Map<String,dynamic> json){

    return Message(
      id: json["id"] ?? 0,
      messageText: json["text"] ?? "",
      date: json["created_at"] ?? "",
    );

  }
}

class ApiService {

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: "https://atom.com.tm/elitepanel/sms",

      headers:{
        "Integration-Key":"zSh9UAmeVTyITt2dzeveH7TOozoACKvD0tJmSnI1jEc=",
      },
    ),
  );


  Future<List<Contact>> getAllContacts() async {

    final response = await dio.get("/contacts/all/");

    print("Status: ${response.statusCode}");
    print("Data type: ${response.data.runtimeType}");
    print(response.data);

    final list = response.data;

    return List<Contact>.from(
      list.map(
        (e) => Contact.fromJson(e),
      ),
    );
  }

  Future<Map<String, dynamic>> getContacts({
    String? nextUrl,
  }) async {

    final response = await dio.get(
      nextUrl ?? "/contacts/",
    );

    return response.data;
  }

  Future<void> insertContact(
    String name,
    String phone
  ) async {

    await dio.post(
      "/contacts/",
      data:{
      "title":name,
      "phone_number":phone,
      "is_sent":false
      }
    );

  }

  Future<void> deleteContact(String phone) async {
    await dio.delete(
      "/contacts/$phone/"
    );

  }
  Future<int> getContactsCount() async {

    final r = await dio.get(
      "/contacts/count/"
    );

    print(r.data);

    return r.data["count"];

  }

  Future<int> getSentNumbersCount() async {

    final r = await dio.get(
      "/contacts/sent/count/"
    );

    return r.data["count"];

  }

  Future<void> markNumberAsSent(String phone) async {
    await dio.patch(
      "/contacts/$phone/sent/",
    );
  }

  Future<bool> markNumberAsSentIfNeeded(String phone) async {
    try {
      final alreadySent = await isNumberSent(phone);
      if (alreadySent) {
        return false;
      }

      await markNumberAsSent(phone);
      return true;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 400 || statusCode == 404) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> insertMessage(String text) async {

    await dio.post(
      "/messages/",
      data:{
        "text":text
      }
    );

  }

  Future<List<Message>> getMessages() async {

    final r = await dio.get(
    "/messages/"
    );


    return (r.data as List)
    .map(
      (e)=>Message.fromJson(e)
    )
    .toList();

  }

  Future<void> deleteAllMessages() async {

    await dio.delete(
    "/messages/clear/"
    );

  }

  Future<void> deleteMessage(int id) async {

    await dio.delete(
    "/messages/$id/"
    );

  }

  Future<Map<String,dynamic>> getContactsFirstPage(
    int limit
  ) async {

    final r = await dio.get(
      "/contacts/",
      queryParameters:{
        "limit":limit
      }
    );


    return {
      "data":
        (r.data["results"] ?? [])
        .map<Contact>(
          (e)=>Contact.fromJson(e)
        )
        .map((e)=> {
          "title":e.title,
          "phone_number":e.phone_number,
        })
        .toList(),

      "next":
        r.data["next"]
    };

  }

  Future<Map<String,dynamic>> getContactsNextPage(
    String nextUrl
  ) async {

    if (nextUrl.isEmpty) {
      return {
        "data": <Map<String, String>>[],
        "next": null,
      };
    }

    final r = nextUrl.startsWith('http')
      ? await dio.getUri(Uri.parse(nextUrl))
      : await dio.get(nextUrl);

    return {
      "data":
        (r.data["results"] ?? [])
        .map<Contact>(
          (e)=>Contact.fromJson(e)
        )
        .map((e)=> {
          "title":e.title,
          "phone_number":e.phone_number,
        })
        .toList(),

      "next":
        r.data["next"]
    };

  }

  Future<List<Contact>> searchContacts(String query) async {

    final r = await dio.get(
      "/contacts/",
      queryParameters:{
        "search":query
      }
    );


    return (r.data["results"] ?? [])
    .map<Contact>(
      (e)=>Contact.fromJson(e)
    )
    .toList();

  }

  Future<bool> isNumberSent(String phone) async {

    final response = await dio.get(
      "/contacts/$phone/",
    );

    return response.data["is_sent"] ?? false;

  }

  Future<void> deleteAllContactsBatch() async {

    await dio.delete(
      "/contacts/clear/"
    );

  }

  Future<void> resetAllSent() async {
    try {
      final response = await dio.post(
        "/contacts/batch-update/",
      );

      print("Updated contacts: ${response.data['updated']}");

    } catch (e) {
      print("Error resetting sent status: $e");
    }
  }


  Future<void> insertContactsBatch(
    List<Map<String,String>> contacts
  ) async {

    for(final c in contacts){

      await insertContact(
        c["title"] ?? "",
        c["phone_number"] ?? "",
      );

    }

  }

}