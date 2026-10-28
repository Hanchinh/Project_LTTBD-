part of 'main_map_view.dart';

/// Các hàm xử lý sự kiện (handlers), định vị, mạng và tìm kiếm địa chỉ của MainMapView
extension MainMapViewHandlers on MainMapViewState {
  Future<void> _initConnectivity() async {
    try {
      final res = await Connectivity().checkConnectivity();
      if (mounted) {
        updateState(() => _isOffline = res == ConnectivityResult.none);
      }
    } catch (_) {}
    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (res) {
          if (mounted) {
            updateState(() => _isOffline = res == ConnectivityResult.none);
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  Future<void> _handleCreateShift() async {
    final newShift = await CreateShiftBottomSheet.show(context);
    if (newShift != null && mounted) {
      widget.onActiveShiftChanged?.call(newShift);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShiftMapView(shiftId: newShift.id),
        ),
      );
    }
  }

  Future<void> _handleOpenShiftPicker() async {
    await ShiftPickerBottomSheet.show(
      context: context,
      onShiftSelected: (selectedShift) {
        widget.onActiveShiftChanged?.call(selectedShift);
      },
    );
  }

  Future<void> _loadMasterData() async {
    updateState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final futures = await Future.wait([
        RepositoryProvider.location.getMySavedLocations(),
        RepositoryProvider.customer.getCustomers().catchError((_) => <CustomerDirectoryModel>[]),
      ]);

      if (!mounted) return;

      final locations = futures[0] as List<MasterSavedLocationModel>;
      final customers = futures[1] as List<CustomerDirectoryModel>;

      updateState(() {
        _savedLocations = locations;
        _directoryCustomers = customers;
        _isLoading = false;
        _clusterCache.clear();
        _cachedClusters = MarkerClusterHelper.clusterLocations(locations, _currentZoom);
      });

      if (_isMapReady && locations.isNotEmpty) {
        _fitLocationsBounds();
      }
    } catch (e) {
      if (!mounted) return;
      updateState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSharedLocations(bool enable) async {
    updateState(() {
      _showSharedLocations = enable;
      _isOutOfAreaBannerDismissed = false;
      if (!enable) {
        _selectedSharedLocation = null;
      }
    });

    if (enable) {
      await _loadSharedLocations();
    }
  }

  Future<void> _loadSharedLocations() async {
    updateState(() => _isLoadingShared = true);
    try {
      final res = await RepositoryProvider.sharing.getSharedLocations();
      if (!mounted) return;
      updateState(() {
        _sharedLocations = (res['locations'] as List).cast<SharedLocationPointModel>();
        _skippedOutOfAreaCount = res['skippedOutOfAreaCount'] as int? ?? 0;
        _isLoadingShared = false;
      });
    } catch (_) {
      if (!mounted) return;
      updateState(() {
        _isLoadingShared = false;
      });
    }
  }

  Future<void> _handleImportSingleSharedPoint(SharedLocationPointModel point) async {
    await ImportSharedPointHelper.handleImportSinglePoint(
      context: context,
      point: point,
      onSuccess: () {
        _loadMasterData();
        updateState(() => _selectedSharedLocation = null);
      },
    );
  }

  void _fitLocationsBounds() {
    final validCoords = _savedLocations
        .where((loc) => loc.hasValidCoordinates)
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList();

    if (validCoords.isEmpty) {
      if (_shipperLocation != null) {
        _mapController.move(_shipperLocation!, 15.5);
      }
      return;
    }

    if (validCoords.length == 1) {
      _mapController.move(validCoords.first, 16.5);
      return;
    }

    final bounds = LatLngBounds.fromPoints(validCoords);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 110, 40, 140),
        maxZoom: 17.5,
      ),
    );
  }

  void _recomputeClusters(double zoom, LatLngBounds? bounds) {
    if (!mounted) return;
    if (bounds == null) {
      final res = MarkerClusterHelper.clusterLocations(_savedLocations, zoom);
      updateState(() => _cachedClusters = res);
      return;
    }

    final zoomKey = zoom.toStringAsFixed(1);
    final cacheKey = '${zoomKey}_${bounds.southWest.latitude.toStringAsFixed(2)}_${bounds.northEast.latitude.toStringAsFixed(2)}';
    if (_clusterCache.containsKey(cacheKey)) {
      updateState(() => _cachedClusters = _clusterCache[cacheKey]!);
      return;
    }

    final latPad = (bounds.northEast.latitude - bounds.southWest.latitude).abs() * 0.15;
    final lngPad = (bounds.northEast.longitude - bounds.southWest.longitude).abs() * 0.15;
    final extendedBounds = LatLngBounds(
      LatLng(bounds.southWest.latitude - latPad, bounds.southWest.longitude - lngPad),
      LatLng(bounds.northEast.latitude + latPad, bounds.northEast.longitude + lngPad),
    );

    final visible = _savedLocations.where((loc) {
      if (!loc.hasValidCoordinates) return false;
      return extendedBounds.contains(LatLng(loc.latitude, loc.longitude));
    }).toList();

    final computed = MarkerClusterHelper.clusterLocations(visible, zoom);
    _clusterCache[cacheKey] = computed;
    if (_clusterCache.length > 50) {
      _clusterCache.remove(_clusterCache.keys.first);
    }

    updateState(() => _cachedClusters = computed);
  }

  Future<void> _getShipperLocation() async {
    updateState(() => _isLocatingShipper = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) updateState(() => _isLocatingShipper = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) {
        updateState(() {
          _shipperLocation = LatLng(position.latitude, position.longitude);
          _isLocatingShipper = false;
        });

        if (_savedLocations.isEmpty && _isMapReady) {
          _mapController.move(_shipperLocation!, 16.0);
        }
      }
    } catch (_) {
      if (mounted) updateState(() => _isLocatingShipper = false);
    }
  }

  void _switchMapType() {
    updateState(() {
      _currentMapType = (_currentMapType + 1) % 3;
    });
    ShiftMapTileConfig.showMapTypeSnackBar(context, _currentMapType);
  }

  void _startPinningMode() {
    updateState(() {
      _repinTarget = null;
      _isPinningMode = true;
      _selectedLocation = null;
      try {
        _crosshairCoord = _mapController.camera.center;
      } catch (_) {
        _crosshairCoord = MainMapViewState._hcmDefault;
      }
      _addressSearchCtrl.clear();
      _addressSearchResults = [];
    });
  }

  void _cancelPinningMode() {
    updateState(() {
      _repinTarget = null;
      _isPinningMode = false;
      _addressSearchCtrl.clear();
      _addressSearchResults = [];
    });
  }

  void _onAddressSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    if (query.trim().length < 3) {
      updateState(() => _addressSearchResults = []);
      return;
    }

    if (_isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('offline_address_search_snackbar'),
            content: Text('Cần kết nối mạng để tìm kiếm địa chỉ'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 2),
          ),
        );
      }
      updateState(() {
        _addressSearchResults = [];
        _isSearchingAddress = false;
      });
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      updateState(() => _isSearchingAddress = true);
      try {
        final results = await GeocodingService.searchAddress(query.trim());
        if (mounted) {
          updateState(() {
            _addressSearchResults = results;
            _isSearchingAddress = false;
          });
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              key: Key('offline_address_search_snackbar'),
              content: Text('Cần kết nối mạng để tìm kiếm địa chỉ'),
              backgroundColor: Color(0xFFDC2626),
              duration: Duration(seconds: 2),
            ),
          );
          updateState(() => _isSearchingAddress = false);
        }
      }
    });
  }

  void _selectSearchResult(AddressSearchResult result) {
    final target = LatLng(result.latitude, result.longitude);
    _mapController.move(target, 17.5);
    updateState(() {
      _crosshairCoord = target;
      _addressSearchResults = [];
      _addressSearchCtrl.text = result.displayName;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _showAssignPhoneDialog(LatLng targetCoord) async {
    await AssignPhoneBottomSheet.show(
      context: context,
      targetCoord: targetCoord,
      repinTarget: _repinTarget,
      directoryCustomers: _directoryCustomers,
      onConfirmSave: ({
        required String phone,
        required String fullName,
        required String notes,
        required LatLng targetCoord,
        String? knownCustomerId,
      }) async {
        updateState(() => _isLoading = true);
        final success = await SaveLocationProcessor.processSaveLocation(
          context: context,
          phone: phone,
          fullName: fullName,
          notes: notes,
          targetCoord: targetCoord,
          knownCustomerId: knownCustomerId,
        );
        if (success) {
          await _loadMasterData();
          if (mounted) {
            updateState(() {
              _isPinningMode = false;
              _isLoading = false;
            });
            _mapController.move(targetCoord, 17.5);
          }
        } else {
          if (mounted) updateState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gọi số $phone')),
        );
      }
    }
  }
}
