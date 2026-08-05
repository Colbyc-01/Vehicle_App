enum MaintenanceFitmentState {
  verified,
  verifyFitment,
  unavailable,
}

MaintenanceFitmentState maintenanceFitmentState(dynamic section) {
  if (!hasMaintenanceContent(section)) {
    return MaintenanceFitmentState.unavailable;
  }

  var hasVerifiedEvidence = false;
  var hasUnverifiedEvidence = false;

  void inspect(dynamic value) {
    if (value is List) {
      for (final item in value) {
        inspect(item);
      }
      return;
    }

    if (value is! Map) return;

    final verified = value['verified'];
    if (verified is bool) {
      hasVerifiedEvidence |= verified;
      hasUnverifiedEvidence |= !verified;
    }

    final status = value['status']?.toString().trim().toUpperCase();
    if (status == 'OEM_VERIFIED') {
      hasVerifiedEvidence = true;
    } else if (status != null && status.isNotEmpty) {
      hasUnverifiedEvidence = true;
    }

    final coverage = value['coverage']?.toString().trim().toLowerCase();
    if (coverage == 'covered' || coverage == 'verified') {
      hasVerifiedEvidence = true;
    } else if (coverage == 'uncovered' || coverage == 'not_covered') {
      hasUnverifiedEvidence = true;
    }

    for (final child in value.values) {
      inspect(child);
    }
  }

  inspect(section);

  if (hasVerifiedEvidence && !hasUnverifiedEvidence) {
    return MaintenanceFitmentState.verified;
  }
  return MaintenanceFitmentState.verifyFitment;
}

bool hasMaintenanceContent(dynamic section) {
  if (section is List) {
    return section.any(hasMaintenanceContent);
  }
  if (section is! Map) {
    return _isUsefulValue(section);
  }

  if (_hasPlaceholderPrimary(section)) {
    return false;
  }

  final positions = section['positions'];
  if (positions is Map && positions.values.any(hasMaintenanceContent)) {
    return true;
  }

  for (final key in const [
    'items',
    'oem',
    'primary',
    'alternatives',
    'oil_products',
    'oil_filter',
    'air_filter',
    'cabin_filter',
    'spark_plugs',
  ]) {
    if (section.containsKey(key) && hasMaintenanceContent(section[key])) {
      return true;
    }
  }

  for (final key in const [
    'label',
    'name',
    'brand',
    'part_number',
    'oil_spec_key',
    'capacity_label_with_filter',
    'length_in',
    'blade_type',
    'connector_type',
  ]) {
    if (_isUsefulValue(section[key])) return true;
  }

  final spec = section['spec'];
  if (spec is Map && spec.values.any(_isUsefulValue)) {
    return true;
  }

  return false;
}

bool _hasPlaceholderPrimary(Map section) {
  final containers = <dynamic>[section];
  for (final key in const [
    'oil_products',
    'oil_filter',
    'air_filter',
    'cabin_filter',
    'spark_plugs',
  ]) {
    if (section[key] is Map) containers.add(section[key]);
  }

  for (final container in containers.whereType<Map>()) {
    final primary = container['oem'] ?? container['primary'];
    if (primary is Map && !hasMaintenanceContent(primary)) {
      return true;
    }
  }
  return false;
}

bool _isUsefulValue(dynamic value) {
  if (value == null) return false;
  if (value is num || value is bool) return true;
  if (value is! String) return false;

  final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
  return normalized.isNotEmpty &&
      normalized != 'tbd' &&
      !normalized.startsWith('tbd ') &&
      normalized != 'unknown' &&
      normalized != 'not covered' &&
      normalized != 'group not found' &&
      !normalized.contains('placeholder');
}
