import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/app_config.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 30);
  
  // Base headers
  Map<String, String> get _baseHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Add authorization header
  Map<String, String> _getHeaders({String? token}) {
    final headers = Map<String, String>.from(_baseHeaders);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Check internet connectivity
  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }


  // GET request
  Future<http.Response> get(
    String endpoint, {
    String? token,
    Map<String, String>? queryParams,
  }) async {
    if (!await _checkConnectivity()) {
      throw const SocketException('No internet connection');
    }

    final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
    final uriWithParams = queryParams != null 
        ? uri.replace(queryParameters: queryParams)
        : uri;

    final response = await http.get(
      uriWithParams,
      headers: _getHeaders(token: token),
    ).timeout(_timeout);

    return response;
  }

  // POST request
  Future<http.Response> post(
    String endpoint, {
    String? token,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    if (!await _checkConnectivity()) {
      throw const SocketException('No internet connection');
    }

    final requestHeaders = _getHeaders(token: token);
    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: requestHeaders,
      body: data != null ? jsonEncode(data) : null,
    ).timeout(_timeout);

    return response;
  }

  // PUT request
  Future<http.Response> put(
    String endpoint, {
    String? token,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    if (!await _checkConnectivity()) {
      throw const SocketException('No internet connection');
    }

    final requestHeaders = _getHeaders(token: token);
    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: requestHeaders,
      body: data != null ? jsonEncode(data) : null,
    ).timeout(_timeout);

    return response;
  }

  // DELETE request
  Future<http.Response> delete(
    String endpoint, {
    String? token,
    Map<String, String>? headers,
  }) async {
    if (!await _checkConnectivity()) {
      throw const SocketException('No internet connection');
    }

    final requestHeaders = _getHeaders(token: token);
    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: requestHeaders,
    ).timeout(_timeout);

    return response;
  }

  // Upload file
  Future<http.Response> uploadFile(
    String endpoint, {
    String? token,
    required String filePath,
    required String fieldName,
    Map<String, String>? additionalFields,
  }) async {
    if (!await _checkConnectivity()) {
      throw const SocketException('No internet connection');
    }

    final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri);
    
    // Add headers
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    // Add file
    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    
    // Add additional fields
    if (additionalFields != null) {
      request.fields.addAll(additionalFields);
    }

    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    return response;
  }

  // Download file
  Future<List<int>> downloadFile(
    String endpoint, {
    String? token,
  }) async {
    if (!await _checkConnectivity()) {
      throw const SocketException('No internet connection');
    }

    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: _getHeaders(token: token),
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw HttpException(
        'Download failed: HTTP ${response.statusCode}',
      );
    }
  }

  // WebSocket connection
  Future<WebSocket> connectWebSocket(
    String endpoint, {
    String? token,
  }) async {
    if (!await _checkConnectivity()) {
      throw const SocketException('No internet connection');
    }

    final uri = Uri.parse('${AppConfig.wsUrl}$endpoint');
    final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, dynamic>{};
    
    return WebSocket.connect(
      uri.toString(),
      headers: headers,
    );
  }

  // Health check
  Future<bool> healthCheck() async {
    try {
      final response = await get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

