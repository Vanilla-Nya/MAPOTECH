import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/location_service.dart';


class LocationSelectorWidget extends StatefulWidget {
  final String initialProvince;
  final String initialDistrict; // Kota/Kabupaten
  final String initialSubDistrict; // Kecamatan
  final String initialVillage; // Kelurahan/Desa
  final Color fieldBg;
  final Color textColor;
  final Color subtitleColor;
  final Color borderColor;
  final Color dropdownColor;
  final double fontSize;
  final bool showVillage;
  final Function(String province, String district, String subDistrict, String village) onChanged;

  const LocationSelectorWidget({
    super.key,
    this.initialProvince = '',
    this.initialDistrict = '',
    this.initialSubDistrict = '',
    this.initialVillage = '',
    required this.fieldBg,
    required this.textColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.dropdownColor,
    this.fontSize = 11,
    this.showVillage = true,
    required this.onChanged,
  });

  @override
  State<LocationSelectorWidget> createState() => _LocationSelectorWidgetState();
}

class _LocationSelectorWidgetState extends State<LocationSelectorWidget> {
  List<Region> _provinces = [];
  List<Region> _regencies = [];
  List<Region> _districts = [];
  List<Region> _villages = [];

  String _selectedProvince = 'Pilih Provinsi';
  String _selectedRegency = 'Pilih Kota/Kabupaten';
  String _selectedDistrict = 'Pilih Kecamatan';
  String _selectedVillage = 'Pilih Kelurahan/Desa';

  String? _provinceId;
  String? _regencyId;
  String? _districtId;

  bool _loadingProvinces = false;
  bool _loadingRegencies = false;
  bool _loadingDistricts = false;
  bool _loadingVillages = false;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void didUpdateWidget(covariant LocationSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if initial values from parent changed AND do not match the current local selection
    final provChanged = widget.initialProvince != oldWidget.initialProvince &&
        _cleanName(widget.initialProvince) != _cleanName(_selectedProvince);
        
    final distChanged = widget.initialDistrict != oldWidget.initialDistrict &&
        _cleanName(widget.initialDistrict) != _cleanName(_selectedRegency);
        
    final subDistChanged = widget.initialSubDistrict != oldWidget.initialSubDistrict &&
        _cleanName(widget.initialSubDistrict) != _cleanName(_selectedDistrict);
        
    final villageChanged = widget.initialVillage != oldWidget.initialVillage &&
        _cleanName(widget.initialVillage) != _cleanName(_selectedVillage);

    if (provChanged || distChanged || subDistChanged || villageChanged) {
      _isInitialized = false;
      _loadProvinces();
    }
  }

  String _cleanName(String name) {
    return name
        .toUpperCase()
        .replaceFirst(RegExp(r'^(PROVINSI|PROV\.?|KABUPATEN|KAB\.?|KOTA|KECAMATAN|KEC\.?|KELURAHAN|KEL\.?|DESA)\s+'), '')
        .trim();
  }

  Future<void> _loadProvinces() async {
    if (mounted) {
      setState(() {
        _loadingProvinces = true;
      });
    }

    final list = await LocationService.getProvinces();

    if (!mounted) return;

    setState(() {
      _provinces = list;
      _loadingProvinces = false;
    });

    if (!_isInitialized) {
      _isInitialized = true;
      await _restoreInitialValues();
    }
  }

  Future<void> _restoreInitialValues() async {
    if (widget.initialProvince.isEmpty) return;

    final cleanInitialProv = _cleanName(widget.initialProvince);
    final matchedProv = _provinces.firstWhere(
      (p) => _cleanName(p.name) == cleanInitialProv,
      orElse: () => Region(id: '', name: ''),
    );

    if (matchedProv.id.isEmpty) return;

    setState(() {
      _selectedProvince = matchedProv.name;
      _provinceId = matchedProv.id;
      _loadingRegencies = true;
    });

    final regs = await LocationService.getRegencies(matchedProv.id);
    if (!mounted) return;

    setState(() {
      _regencies = regs;
      _loadingRegencies = false;
    });

    if (widget.initialDistrict.isEmpty) return;

    final cleanInitialReg = _cleanName(widget.initialDistrict);
    final matchedReg = _regencies.firstWhere(
      (r) => _cleanName(r.name) == cleanInitialReg,
      orElse: () => Region(id: '', name: ''),
    );

    if (matchedReg.id.isEmpty) return;

    setState(() {
      _selectedRegency = matchedReg.name;
      _regencyId = matchedReg.id;
      _loadingDistricts = true;
    });

    final dists = await LocationService.getDistricts(matchedReg.id);
    if (!mounted) return;

    setState(() {
      _districts = dists;
      _loadingDistricts = false;
    });

    if (widget.initialSubDistrict.isEmpty) return;

    final cleanInitialDist = _cleanName(widget.initialSubDistrict);
    final matchedDist = _districts.firstWhere(
      (d) => _cleanName(d.name) == cleanInitialDist,
      orElse: () => Region(id: '', name: ''),
    );

    if (matchedDist.id.isEmpty) return;

    setState(() {
      _selectedDistrict = matchedDist.name;
      _districtId = matchedDist.id;
      _loadingVillages = true;
    });

    final vills = await LocationService.getVillages(matchedDist.id);
    if (!mounted) return;

    setState(() {
      _villages = vills;
      _loadingVillages = false;
    });

    if (widget.initialVillage.isEmpty) return;

    final cleanInitialVill = _cleanName(widget.initialVillage);
    final matchedVill = _villages.firstWhere(
      (v) => _cleanName(v.name) == cleanInitialVill,
      orElse: () => Region(id: '', name: ''),
    );

    if (matchedVill.id.isEmpty) return;

    setState(() {
      _selectedVillage = matchedVill.name;
    });
  }

  void _triggerChanged() {
    widget.onChanged(
      _selectedProvince == 'Pilih Provinsi' ? '' : _selectedProvince,
      _selectedRegency == 'Pilih Kota/Kabupaten' ? '' : _selectedRegency,
      _selectedDistrict == 'Pilih Kecamatan' ? '' : _selectedDistrict,
      _selectedVillage == 'Pilih Kelurahan/Desa' ? '' : _selectedVillage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Provinsi & Kota
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Provinsi',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: widget.subtitleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _SearchableDropdown(
                    value: _selectedProvince,
                    hint: 'Pilih Provinsi',
                    items: _provinces.map((p) => p.name).toList(),
                    enabled: !_loadingProvinces,
                    loading: _loadingProvinces,
                    fieldBg: widget.fieldBg,
                    textColor: widget.textColor,
                    borderColor: widget.borderColor,
                    dropdownColor: widget.dropdownColor,
                    fontSize: widget.fontSize,
                    onChanged: (String? val) async {
                      if (val == null || val == _selectedProvince) return;

                      setState(() {
                        _selectedProvince = val;
                        _selectedRegency = 'Pilih Kota/Kabupaten';
                        _selectedDistrict = 'Pilih Kecamatan';
                        _selectedVillage = 'Pilih Kelurahan/Desa';
                        _regencies = [];
                        _districts = [];
                        _villages = [];
                        _provinceId = null;
                        _regencyId = null;
                        _districtId = null;
                      });

                      if (val != 'Pilih Provinsi') {
                        final prov = _provinces.firstWhere(
                          (p) => p.name == val,
                          orElse: () => Region(id: '', name: ''),
                        );
                        if (prov.id.isNotEmpty) {
                          setState(() {
                            _provinceId = prov.id;
                            _loadingRegencies = true;
                          });
                          final regs = await LocationService.getRegencies(prov.id);
                          setState(() {
                            _regencies = regs;
                            _loadingRegencies = false;
                          });
                        }
                      }
                      _triggerChanged();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kota/Kabupaten',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: widget.subtitleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _SearchableDropdown(
                    value: _selectedRegency,
                    hint: 'Pilih Kota/Kabupaten',
                    items: _regencies.map((r) => r.name).toList(),
                    enabled: !_loadingRegencies && _provinceId != null,
                    loading: _loadingRegencies,
                    fieldBg: widget.fieldBg,
                    textColor: widget.textColor,
                    borderColor: widget.borderColor,
                    dropdownColor: widget.dropdownColor,
                    fontSize: widget.fontSize,
                    onChanged: (String? val) async {
                      if (val == null || val == _selectedRegency) return;

                      setState(() {
                        _selectedRegency = val;
                        _selectedDistrict = 'Pilih Kecamatan';
                        _selectedVillage = 'Pilih Kelurahan/Desa';
                        _districts = [];
                        _villages = [];
                        _regencyId = null;
                        _districtId = null;
                      });

                      if (val != 'Pilih Kota/Kabupaten') {
                        final reg = _regencies.firstWhere(
                          (r) => r.name == val,
                          orElse: () => Region(id: '', name: ''),
                        );
                        if (reg.id.isNotEmpty) {
                          setState(() {
                            _regencyId = reg.id;
                            _loadingDistricts = true;
                          });
                          final dists = await LocationService.getDistricts(reg.id);
                          setState(() {
                            _districts = dists;
                            _loadingDistricts = false;
                          });
                        }
                      }
                      _triggerChanged();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Kecamatan & Kelurahan
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kecamatan',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: widget.subtitleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _SearchableDropdown(
                    value: _selectedDistrict,
                    hint: 'Pilih Kecamatan',
                    items: _districts.map((d) => d.name).toList(),
                    enabled: !_loadingDistricts && _regencyId != null,
                    loading: _loadingDistricts,
                    fieldBg: widget.fieldBg,
                    textColor: widget.textColor,
                    borderColor: widget.borderColor,
                    dropdownColor: widget.dropdownColor,
                    fontSize: widget.fontSize,
                    onChanged: (String? val) async {
                      if (val == null || val == _selectedDistrict) return;

                      setState(() {
                        _selectedDistrict = val;
                        _selectedVillage = 'Pilih Kelurahan/Desa';
                        _villages = [];
                        _districtId = null;
                      });

                      if (val != 'Pilih Kecamatan') {
                        final dist = _districts.firstWhere(
                          (d) => d.name == val,
                          orElse: () => Region(id: '', name: ''),
                        );
                        if (dist.id.isNotEmpty) {
                          setState(() {
                            _districtId = dist.id;
                            _loadingVillages = true;
                          });
                          if (widget.showVillage) {
                            final vills = await LocationService.getVillages(dist.id);
                            setState(() {
                              _villages = vills;
                              _loadingVillages = false;
                            });
                          } else {
                            setState(() {
                              _loadingVillages = false;
                            });
                          }
                        }
                      }
                      _triggerChanged();
                    },
                  ),
                ],
              ),
            ),
            if (widget.showVillage) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kelurahan/Desa',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: widget.subtitleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _SearchableDropdown(
                      value: _selectedVillage,
                      hint: 'Pilih Kelurahan/Desa',
                      items: _villages.map((v) => v.name).toList(),
                      enabled: !_loadingVillages && _districtId != null,
                      loading: _loadingVillages,
                      fieldBg: widget.fieldBg,
                      textColor: widget.textColor,
                      borderColor: widget.borderColor,
                      dropdownColor: widget.dropdownColor,
                      fontSize: widget.fontSize,
                      onChanged: (String? val) {
                        if (val == null || val == _selectedVillage) return;

                        setState(() {
                          _selectedVillage = val;
                        });
                        _triggerChanged();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SearchableDropdown extends StatefulWidget {
  final String value;
  final String hint;
  final List<String> items;
  final bool enabled;
  final bool loading;
  final Color fieldBg;
  final Color textColor;
  final Color borderColor;
  final Color dropdownColor;
  final double fontSize;
  final ValueChanged<String?> onChanged;

  const _SearchableDropdown({
    required this.value,
    required this.hint,
    required this.items,
    this.enabled = true,
    this.loading = false,
    required this.fieldBg,
    required this.textColor,
    required this.borderColor,
    required this.dropdownColor,
    required this.fontSize,
    required this.onChanged,
  });

  @override
  State<_SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<_SearchableDropdown> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  late TextEditingController _controller;
  OverlayEntry? _overlayEntry;
  List<String> _filteredItems = [];
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _filteredItems = widget.items;
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _SearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value;
    }
    if (widget.items != oldWidget.items) {
      _filterItems(_controller.text);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      if (_controller.text == widget.hint) {
        _controller.clear();
      } else {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
      _filterItems(_controller.text);
      _showOverlay();
    } else {
      if (_isSelecting) return;

      if (_controller.text.isEmpty) {
        Future.microtask(() {
          if (mounted) {
            widget.onChanged(widget.hint);
          }
        });
      } else if (!widget.items.contains(_controller.text)) {
        _controller.text = widget.value;
      }
      _hideOverlay();
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: TapRegion(
            groupId: _layerLink,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              color: widget.dropdownColor,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.borderColor),
                ),
                child: _filteredItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          'Tidak ada data ditemukan',
                          style: GoogleFonts.outfit(
                            fontSize: widget.fontSize,
                            color: widget.textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelected = item == widget.value;
                          return Listener(
                            onPointerDown: (_) {
                              _isSelecting = true;
                            },
                            onPointerCancel: (_) {
                              _isSelecting = false;
                              if (!_focusNode.hasFocus) {
                                _handleFocusChange();
                              }
                            },
                            onPointerUp: (_) {
                              Future.delayed(const Duration(milliseconds: 100), () {
                                if (mounted && _isSelecting) {
                                  _isSelecting = false;
                                  if (!_focusNode.hasFocus) {
                                    _handleFocusChange();
                                  }
                                }
                              });
                            },
                            child: InkWell(
                              onTap: () {
                                _controller.text = item;
                                _isSelecting = false;
                                _hideOverlay();
                                _focusNode.unfocus();
                                Future.microtask(() {
                                  if (mounted) {
                                    widget.onChanged(item);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                color: isSelected
                                    ? widget.textColor.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                child: Text(
                                  item,
                                  style: GoogleFonts.outfit(
                                    fontSize: widget.fontSize,
                                    color: widget.textColor,
                                    fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _layerLink,
      onTapOutside: (event) {
        _focusNode.unfocus();
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: widget.enabled ? widget.fieldBg : widget.fieldBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled && !widget.loading,
                  style: GoogleFonts.outfit(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w700,
                    color: widget.textColor,
                  ),
                  onChanged: _filterItems,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.outfit(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w500,
                      color: widget.textColor.withValues(alpha: 0.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              if (widget.loading)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      if (widget.enabled && !widget.loading) {
                        if (_focusNode.hasFocus) {
                          _focusNode.unfocus();
                        } else {
                          _focusNode.requestFocus();
                        }
                      }
                    },
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: widget.textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
