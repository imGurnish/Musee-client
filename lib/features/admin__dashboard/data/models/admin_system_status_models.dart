class SystemStatusResponse {
  final DateTime timestamp;
  final AzureMetrics azure;
  final SupabaseStorageMetrics supabaseStorage;
  final DatabaseCounts database;
  final SystemResources system;

  SystemStatusResponse({
    required this.timestamp,
    required this.azure,
    required this.supabaseStorage,
    required this.database,
    required this.system,
  });

  factory SystemStatusResponse.fromJson(Map<String, dynamic> json) {
    return SystemStatusResponse(
      timestamp: DateTime.parse(json['timestamp']),
      azure: AzureMetrics.fromJson(json['azure'] ?? {}),
      supabaseStorage: SupabaseStorageMetrics.fromJson(json['supabaseStorage'] ?? {}),
      database: DatabaseCounts.fromJson(json['database'] ?? {}),
      system: SystemResources.fromJson(json['system'] ?? {}),
    );
  }
}

class AzureMetrics {
  final bool enabled;
  final String? container;
  final int blobs;
  final int bytes;
  final AzurePrefixBreakdown byPrefix;
  final String? error;

  AzureMetrics({
    required this.enabled,
    this.container,
    required this.blobs,
    required this.bytes,
    required this.byPrefix,
    this.error,
  });

  factory AzureMetrics.fromJson(Map<String, dynamic> json) {
    return AzureMetrics(
      enabled: json['enabled'] ?? false,
      container: json['container'],
      blobs: json['blobs'] ?? 0,
      bytes: json['bytes'] ?? 0,
      byPrefix: AzurePrefixBreakdown.fromJson(json['byPrefix'] ?? {}),
      error: json['error'],
    );
  }
}

class AzurePrefixBreakdown {
  final AzurePrefixInfo hls;
  final AzurePrefixInfo audio;
  final AzurePrefixInfo other;

  AzurePrefixBreakdown({
    required this.hls,
    required this.audio,
    required this.other,
  });

  factory AzurePrefixBreakdown.fromJson(Map<String, dynamic> json) {
    return AzurePrefixBreakdown(
      hls: AzurePrefixInfo.fromJson(json['hls'] ?? {}),
      audio: AzurePrefixInfo.fromJson(json['audio'] ?? {}),
      other: AzurePrefixInfo.fromJson(json['other'] ?? {}),
    );
  }
}

class AzurePrefixInfo {
  final int count;
  final int bytes;

  AzurePrefixInfo({required this.count, required this.bytes});

  factory AzurePrefixInfo.fromJson(Map<String, dynamic> json) {
    return AzurePrefixInfo(
      count: json['count'] ?? 0,
      bytes: json['bytes'] ?? 0,
    );
  }
}

class SupabaseStorageMetrics {
  final bool enabled;
  final List<SupabaseBucketInfo> buckets;
  final SupabaseStorageTotals totals;
  final String? error;

  SupabaseStorageMetrics({
    required this.enabled,
    required this.buckets,
    required this.totals,
    this.error,
  });

  factory SupabaseStorageMetrics.fromJson(Map<String, dynamic> json) {
    var bucketsList = json['buckets'] as List? ?? [];
    return SupabaseStorageMetrics(
      enabled: json['enabled'] ?? false,
      buckets: bucketsList.map((e) => SupabaseBucketInfo.fromJson(e)).toList(),
      totals: SupabaseStorageTotals.fromJson(json['totals'] ?? {}),
      error: json['error'],
    );
  }
}

class SupabaseBucketInfo {
  final String bucket;
  final int objects;
  final int bytes;

  SupabaseBucketInfo({
    required this.bucket,
    required this.objects,
    required this.bytes,
  });

  factory SupabaseBucketInfo.fromJson(Map<String, dynamic> json) {
    return SupabaseBucketInfo(
      bucket: json['bucket'] ?? '',
      objects: json['objects'] ?? 0,
      bytes: json['bytes'] ?? 0,
    );
  }
}

class SupabaseStorageTotals {
  final int objects;
  final int bytes;

  SupabaseStorageTotals({required this.objects, required this.bytes});

  factory SupabaseStorageTotals.fromJson(Map<String, dynamic> json) {
    return SupabaseStorageTotals(
      objects: json['objects'] ?? 0,
      bytes: json['bytes'] ?? 0,
    );
  }
}

class DatabaseCounts {
  final List<DatabaseTableCount> tables;
  final String? error;

  DatabaseCounts({required this.tables, this.error});

  factory DatabaseCounts.fromJson(Map<String, dynamic> json) {
    var tablesList = json['tables'] as List? ?? [];
    return DatabaseCounts(
      tables: tablesList.map((e) => DatabaseTableCount.fromJson(e)).toList(),
      error: json['error'],
    );
  }
}

class DatabaseTableCount {
  final String table;
  final int count;
  final String? error;

  DatabaseTableCount({required this.table, required this.count, this.error});

  factory DatabaseTableCount.fromJson(Map<String, dynamic> json) {
    return DatabaseTableCount(
      table: json['table'] ?? '',
      count: json['count'] ?? 0,
      error: json['error'],
    );
  }
}

class SystemResources {
  final String platform;
  final String arch;
  final String release;
  final String hostname;
  final String cpuModel;
  final int cpuCores;
  final double uptime;
  final double processUptime;
  final MemoryMetrics memory;
  final DiskMetrics? disk;
  final String? error;

  SystemResources({
    required this.platform,
    required this.arch,
    required this.release,
    required this.hostname,
    required this.cpuModel,
    required this.cpuCores,
    required this.uptime,
    required this.processUptime,
    required this.memory,
    this.disk,
    this.error,
  });

  factory SystemResources.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('error') || json.isEmpty) {
      return SystemResources(
        platform: '',
        arch: '',
        release: '',
        hostname: '',
        cpuModel: '',
        cpuCores: 0,
        uptime: 0.0,
        processUptime: 0.0,
        memory: MemoryMetrics.empty(),
        error: json['error'] ?? 'No system resources returned',
      );
    }
    return SystemResources(
      platform: json['platform'] ?? '',
      arch: json['arch'] ?? '',
      release: json['release'] ?? '',
      hostname: json['hostname'] ?? '',
      cpuModel: json['cpuModel'] ?? '',
      cpuCores: json['cpuCores'] ?? 0,
      uptime: (json['uptime'] ?? 0.0).toDouble(),
      processUptime: (json['processUptime'] ?? 0.0).toDouble(),
      memory: MemoryMetrics.fromJson(json['memory'] ?? {}),
      disk: json['disk'] != null ? DiskMetrics.fromJson(json['disk']) : null,
      error: null,
    );
  }
}

class MemoryMetrics {
  final int hostTotal;
  final int hostFree;
  final int hostUsed;
  final double hostUsagePct;
  final int processRss;
  final int processHeapTotal;
  final int processHeapUsed;
  final int processExternal;

  MemoryMetrics({
    required this.hostTotal,
    required this.hostFree,
    required this.hostUsed,
    required this.hostUsagePct,
    required this.processRss,
    required this.processHeapTotal,
    required this.processHeapUsed,
    required this.processExternal,
  });

  factory MemoryMetrics.empty() {
    return MemoryMetrics(
      hostTotal: 0,
      hostFree: 0,
      hostUsed: 0,
      hostUsagePct: 0.0,
      processRss: 0,
      processHeapTotal: 0,
      processHeapUsed: 0,
      processExternal: 0,
    );
  }

  factory MemoryMetrics.fromJson(Map<String, dynamic> json) {
    return MemoryMetrics(
      hostTotal: json['hostTotal'] ?? 0,
      hostFree: json['hostFree'] ?? 0,
      hostUsed: json['hostUsed'] ?? 0,
      hostUsagePct: (json['hostUsagePct'] ?? 0.0).toDouble(),
      processRss: json['processRss'] ?? 0,
      processHeapTotal: json['processHeapTotal'] ?? 0,
      processHeapUsed: json['processHeapUsed'] ?? 0,
      processExternal: json['processExternal'] ?? 0,
    );
  }
}

class DiskMetrics {
  final int total;
  final int free;
  final int used;
  final double usagePct;

  DiskMetrics({
    required this.total,
    required this.free,
    required this.used,
    required this.usagePct,
  });

  factory DiskMetrics.fromJson(Map<String, dynamic> json) {
    return DiskMetrics(
      total: json['total'] ?? 0,
      free: json['free'] ?? 0,
      used: json['used'] ?? 0,
      usagePct: (json['usagePct'] ?? 0.0).toDouble(),
    );
  }
}
