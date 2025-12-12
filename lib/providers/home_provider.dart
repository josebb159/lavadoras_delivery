import 'package:flutter/material.dart';
import '../models/lavadora_model.dart';
import '../services/api_service.dart';
import '../core/constants.dart';

class HomeProvider with ChangeNotifier {
  List<Lavadora> _lavadoras = [];
  String _valorRecaudado = '0';
  String? _bannerUrl;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  List<Lavadora> get lavadoras => _lavadoras;
  String get valorRecaudado => _valorRecaudado;
  String? get bannerUrl => _bannerUrl;
  bool get isLoading => _isLoading;

  Future<void> loadData(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _fetchLavadoras(userId),
        _fetchRecaudado(userId),
        _fetchBanner(),
      ]);
    } catch (e) {
      print('Error loading home data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchLavadoras(String userId) async {
    try {
      final response = await _apiService.post(
        AppConstants.actionLavadorasAsignadas,
        {'user_id': userId},
      );

      if (response['status'] == 'ok') {
        final List<dynamic> list = response['asignadas'];
        _lavadoras = list.map((e) => Lavadora.fromJson(e)).toList();
      } else {
        _lavadoras = [];
      }
    } catch (e) {
      print('Error fetching lavadoras: $e');
      _lavadoras = [];
    }
  }

  Future<void> _fetchRecaudado(String userId) async {
    try {
      final response = await _apiService.post(AppConstants.actionRecaudado, {
        'user_id': userId,
      });

      if (response['status'] == 'ok') {
        _valorRecaudado = response['recaudado']?.toString() ?? '0';
      }
    } catch (e) {
      print('Error fetching recaudado: $e');
    }
  }

  Future<void> _fetchBanner() async {
    try {
      final response = await _apiService.post(AppConstants.actionGetBanner, {});

      if (response['status'] == 'ok') {
        _bannerUrl = response['banner'];
      }
    } catch (e) {
      print('Error fetching banner: $e');
    }
  }
}
